param(
  [Parameter(Mandatory = $true)]
  [string]$InputDir,
  [Parameter(Mandatory = $true)]
  [string]$OutputDir,
  [Parameter(Mandatory = $true)]
  [string]$SqlMapPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-FileNameMapFromSql {
  param([string]$Path)
  $text = [System.IO.File]::ReadAllText($Path)
  $rx = [regex]"N'/drawings/([^']+\.png)'"
  $map = @{}
  foreach ($m in $rx.Matches($text)) {
    $fileName = [string]$m.Groups[1].Value
    if ([string]::IsNullOrWhiteSpace($fileName)) { continue }
    $partStem = ($fileName -split "_")[0].ToUpperInvariant()
    if (-not $map.ContainsKey($partStem)) {
      $map[$partStem] = New-Object System.Collections.Generic.List[string]
    }
    if (-not $map[$partStem].Contains($fileName)) {
      $null = $map[$partStem].Add($fileName)
    }
  }
  return $map
}

function Get-MediaImagesFromWorkbook {
  param([string]$WorkbookPath)

  $tmp = Join-Path $env:TEMP ("qczip_" + [Guid]::NewGuid().ToString("N"))
  $null = New-Item -ItemType Directory -Path $tmp -Force
  $paths = New-Object System.Collections.Generic.List[string]

  $zip = $null
  try {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($WorkbookPath)
    $entries = $zip.Entries | Where-Object {
      $_.FullName.StartsWith("xl/media/", [System.StringComparison]::OrdinalIgnoreCase)
    } | Sort-Object FullName

    $i = 0
    foreach ($e in $entries) {
      $ext = [System.IO.Path]::GetExtension($e.FullName).ToLowerInvariant()
      if ($ext -notin @(".png", ".jpg", ".jpeg", ".bmp", ".gif")) { continue }
      $i++
      $dest = Join-Path $tmp ("media_{0:D4}{1}" -f $i, $ext)
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dest, $true)
      $null = $paths.Add($dest)
    }
  } finally {
    if ($zip -ne $null) { $zip.Dispose() }
  }

  return @{
    TempDir = $tmp
    Files   = $paths
  }
}

function Save-CompositeWhitePng {
  param(
    [string[]]$ImageFiles,
    [string]$OutputFile
  )

  $images = New-Object System.Collections.Generic.List[System.Drawing.Image]
  try {
    foreach ($p in $ImageFiles) {
      try {
        $images.Add([System.Drawing.Image]::FromFile($p))
      } catch {
        continue
      }
    }
    if ($images.Count -eq 0) { return $false }

    $gap = 20
    $pad = 20
    $maxW = ($images | Measure-Object -Property Width -Maximum).Maximum
    $sumH = ($images | Measure-Object -Property Height -Sum).Sum
    $canvasW = [int]($maxW + ($pad * 2))
    $canvasH = [int]($sumH + ($gap * [Math]::Max(0, $images.Count - 1)) + ($pad * 2))

    $bmp = New-Object System.Drawing.Bitmap($canvasW, $canvasH)
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    try {
      $gfx.Clear([System.Drawing.Color]::White)
      $y = $pad
      foreach ($img in $images) {
        $x = [int](($canvasW - $img.Width) / 2)
        $gfx.DrawImage($img, $x, $y, $img.Width, $img.Height)
        $y += ($img.Height + $gap)
      }
      $outDir = Split-Path -Parent $OutputFile
      if (-not (Test-Path -LiteralPath $outDir)) {
        $null = New-Item -ItemType Directory -Path $outDir -Force
      }
      $bmp.Save($OutputFile, [System.Drawing.Imaging.ImageFormat]::Png)
      return $true
    } finally {
      $gfx.Dispose()
      $bmp.Dispose()
    }
  } finally {
    foreach ($img in $images) { $img.Dispose() }
  }
}

if (-not (Test-Path -LiteralPath $InputDir)) { throw "Input folder not found: $InputDir" }
if (-not (Test-Path -LiteralPath $SqlMapPath)) { throw "SQL map file not found: $SqlMapPath" }
if (-not (Test-Path -LiteralPath $OutputDir)) { $null = New-Item -ItemType Directory -Path $OutputDir -Force }

$map = Get-FileNameMapFromSql -Path $SqlMapPath
$excelFiles = Get-ChildItem -LiteralPath $InputDir -File | Where-Object { $_.Extension -match '^\.(xlsx|xlsm)$' }

if ($excelFiles.Count -eq 0) { throw "No .xlsx/.xlsm files found in $InputDir" }

foreach ($f in $excelFiles) {
  $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name).ToUpperInvariant()
  $partStem = ($base -replace '[^A-Z0-9]', '')
  if (-not $map.ContainsKey($partStem)) {
    Write-Host "Skip (no drawing_reference map): $($f.Name)"
    continue
  }

  $media = Get-MediaImagesFromWorkbook -WorkbookPath $f.FullName
  try {
    if ($media.Files.Count -eq 0) {
      Write-Host "Skip (no xl/media images): $($f.Name)"
      continue
    }

    $tmpComposite = Join-Path $OutputDir ("__TMP_" + $partStem + ".png")
    $ok = Save-CompositeWhitePng -ImageFiles $media.Files -OutputFile $tmpComposite
    if (-not $ok) {
      Write-Host "Skip (media images unreadable): $($f.Name)"
      continue
    }

    foreach ($name in $map[$partStem]) {
      $dest = Join-Path $OutputDir $name
      Copy-Item -LiteralPath $tmpComposite -Destination $dest -Force
      Write-Host "Saved: $dest"
    }
    Remove-Item -LiteralPath $tmpComposite -Force -ErrorAction SilentlyContinue
  } finally {
    Remove-Item -LiteralPath $media.TempDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}
