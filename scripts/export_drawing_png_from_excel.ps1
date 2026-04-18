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

function Get-FileNameMapFromSql {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "SQL map file not found: $Path"
  }
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

function Export-WorkbookComposite {
  param(
    $ExcelApp,
    [string]$WorkbookPath,
    [string]$OutPngPath
  )

  $tempDir = Join-Path $env:TEMP ("qcdraw_" + [Guid]::NewGuid().ToString("N"))
  $null = New-Item -ItemType Directory -Path $tempDir -Force
  $tempPngs = New-Object System.Collections.Generic.List[string]

  $wb = $null
  try {
    $wb = $ExcelApp.Workbooks.Open($WorkbookPath, 0, 1)
    $shapeNo = 0

    foreach ($ws in $wb.Worksheets) {
      $chartObjects = $ws.ChartObjects()
      foreach ($shape in $ws.Shapes) {
        try {
          $w = [double]$shape.Width
          $h = [double]$shape.Height
          if ($w -lt 2 -or $h -lt 2) { continue }

          $shapeNo++
          $chartObj = $chartObjects.Add(0, 0, [Math]::Max(4, $w), [Math]::Max(4, $h))
          $chart = $chartObj.Chart

          $chart.ChartArea.Format.Fill.Visible = $true
          $chart.ChartArea.Format.Fill.ForeColor.RGB = 16777215
          $chart.ChartArea.Format.Line.Visible = $false

          $null = $shape.Copy()
          Start-Sleep -Milliseconds 40
          $null = $chart.Paste()

          $tmpPng = Join-Path $tempDir ("shape_{0:D4}.png" -f $shapeNo)
          $null = $chart.Export($tmpPng, "PNG")
          if (Test-Path -LiteralPath $tmpPng) {
            $null = $tempPngs.Add($tmpPng)
          }
          $chartObj.Delete()
        } catch {
          continue
        }
      }
    }
  } finally {
    if ($wb -ne $null) {
      $wb.Close($false)
      [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wb) | Out-Null
    }
  }

  if ($tempPngs.Count -eq 0) {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    return $false
  }

  $images = New-Object System.Collections.Generic.List[System.Drawing.Image]
  try {
    foreach ($p in $tempPngs) {
      $images.Add([System.Drawing.Image]::FromFile($p))
    }

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
      $outDir = Split-Path -Parent $OutPngPath
      if (-not (Test-Path -LiteralPath $outDir)) {
        $null = New-Item -ItemType Directory -Path $outDir -Force
      }
      $bmp.Save($OutPngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
      $gfx.Dispose()
      $bmp.Dispose()
    }
  } finally {
    foreach ($img in $images) {
      $img.Dispose()
    }
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  return $true
}

if (-not (Test-Path -LiteralPath $InputDir)) {
  throw "Input folder not found: $InputDir"
}
if (-not (Test-Path -LiteralPath $OutputDir)) {
  $null = New-Item -ItemType Directory -Path $OutputDir -Force
}

$map = Get-FileNameMapFromSql -Path $SqlMapPath
$excelFiles = Get-ChildItem -LiteralPath $InputDir -File | Where-Object {
  $_.Extension -match '^\.(xlsx|xlsm)$'
}

if ($excelFiles.Count -eq 0) {
  throw "No .xlsx/.xlsm files found in $InputDir"
}

$excel = $null
try {
  $excel = New-Object -ComObject Excel.Application
  $excel.Visible = $false
  $excel.DisplayAlerts = $false
  $excel.ScreenUpdating = $false

  foreach ($f in $excelFiles) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name).ToUpperInvariant()
    $partStem = ($base -replace '[^A-Z0-9]', '')
    if (-not $map.ContainsKey($partStem)) {
      Write-Host "Skip (no drawing_reference name map): $($f.FullName)"
      continue
    }

    $tmpComposite = Join-Path $OutputDir ("__TMP_" + $partStem + ".png")
    $ok = Export-WorkbookComposite -ExcelApp $excel -WorkbookPath $f.FullName -OutPngPath $tmpComposite
    if (-not $ok) {
      Write-Host "Skip (no drawable shapes found): $($f.FullName)"
      continue
    }

    foreach ($name in $map[$partStem]) {
      $dest = Join-Path $OutputDir $name
      Copy-Item -LiteralPath $tmpComposite -Destination $dest -Force
      Write-Host "Saved: $dest"
    }

    Remove-Item -LiteralPath $tmpComposite -Force -ErrorAction SilentlyContinue
  }
} finally {
  if ($excel -ne $null) {
    $excel.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
  }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
