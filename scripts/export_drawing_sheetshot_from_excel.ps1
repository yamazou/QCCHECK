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

function Export-WorkbookFirstSheetAsPng {
  param(
    $ExcelApp,
    [string]$WorkbookPath,
    [string]$OutPngPath
  )

  $wb = $null
  try {
    $wb = $ExcelApp.Workbooks.Open($WorkbookPath, 0, 1)
    $ws = $wb.Worksheets.Item(1)
    $used = $ws.UsedRange

    $ws.Activate() | Out-Null
    $used.CopyPicture(1, 2) | Out-Null
    Start-Sleep -Milliseconds 150

    $w = [Math]::Max(200, [int]([double]$used.Width))
    $h = [Math]::Max(120, [int]([double]$used.Height))
    $chartObj = $ws.ChartObjects().Add(0, 0, $w, $h)
    $chart = $chartObj.Chart
    $chart.ChartArea.Format.Fill.Visible = $true
    $chart.ChartArea.Format.Fill.ForeColor.RGB = 16777215
    $chart.ChartArea.Format.Line.Visible = $false

    $chart.Paste() | Out-Null
    Start-Sleep -Milliseconds 120

    $outDir = Split-Path -Parent $OutPngPath
    if (-not (Test-Path -LiteralPath $outDir)) {
      $null = New-Item -ItemType Directory -Path $outDir -Force
    }
    $null = $chart.Export($OutPngPath, "PNG")
    $chartObj.Delete()
    return (Test-Path -LiteralPath $OutPngPath)
  } catch {
    return $false
  } finally {
    if ($wb -ne $null) {
      try { $wb.Close($false) } catch {}
      try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wb) | Out-Null } catch {}
    }
  }
}

if (-not (Test-Path -LiteralPath $InputDir)) { throw "Input folder not found: $InputDir" }
if (-not (Test-Path -LiteralPath $SqlMapPath)) { throw "SQL map file not found: $SqlMapPath" }
if (-not (Test-Path -LiteralPath $OutputDir)) { $null = New-Item -ItemType Directory -Path $OutputDir -Force }

$map = Get-FileNameMapFromSql -Path $SqlMapPath
$excelFiles = Get-ChildItem -LiteralPath $InputDir -File | Where-Object { $_.Extension -match '^\.(xlsx|xlsm)$' }
if ($excelFiles.Count -eq 0) { throw "No .xlsx/.xlsm files found in $InputDir" }

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
      Write-Host "Skip (no drawing_reference map): $($f.Name)"
      continue
    }

    $tmpPng = Join-Path $OutputDir ("__SHEETSHOT_" + $partStem + ".png")
    $ok = Export-WorkbookFirstSheetAsPng -ExcelApp $excel -WorkbookPath $f.FullName -OutPngPath $tmpPng
    if (-not $ok) {
      Write-Host "Skip (sheet screenshot failed): $($f.Name)"
      continue
    }

    foreach ($name in $map[$partStem]) {
      $dest = Join-Path $OutputDir $name
      Copy-Item -LiteralPath $tmpPng -Destination $dest -Force
      Write-Host "Saved: $dest"
    }
    Remove-Item -LiteralPath $tmpPng -Force -ErrorAction SilentlyContinue
  }
} finally {
  if ($excel -ne $null) {
    try { $excel.Quit() } catch {}
    try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null } catch {}
  }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
