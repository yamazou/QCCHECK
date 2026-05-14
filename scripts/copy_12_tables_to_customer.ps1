param(
    [string]$SourceEnvPath = "C:\Users\lenovo\QCCheck\server\.env"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-EnvMap {
    param([string]$Path)
    $map = @{}
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            continue
        }
        $idx = $trimmed.IndexOf("=")
        if ($idx -lt 1) {
            continue
        }
        $key = $trimmed.Substring(0, $idx).Trim()
        $val = $trimmed.Substring($idx + 1).Trim()
        $map[$key] = $val
    }
    return $map
}

function New-ConnectionString {
    param(
        [string]$Server,
        [string]$Database,
        [string]$User,
        [string]$Password,
        [string]$Port
    )
    if ([string]::IsNullOrWhiteSpace($Port)) {
        $dataSource = $Server
    } else {
        $dataSource = "$Server,$Port"
    }
    return "Server=$dataSource;Database=$Database;User ID=$User;Password=$Password;TrustServerCertificate=True;"
}

function Invoke-NonQuery {
    param(
        [string]$ConnectionString,
        [string]$Sql
    )
    $conn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    try {
        $conn.Open()
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $Sql
        $cmd.CommandTimeout = 0
        [void]$cmd.ExecuteNonQuery()
    } finally {
        $conn.Dispose()
    }
}

function Invoke-Scalar {
    param(
        [string]$ConnectionString,
        [string]$Sql
    )
    $conn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    try {
        $conn.Open()
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $Sql
        $cmd.CommandTimeout = 0
        return $cmd.ExecuteScalar()
    } finally {
        $conn.Dispose()
    }
}

function Get-DataTable {
    param(
        [string]$ConnectionString,
        [string]$Sql
    )
    $dt = New-Object System.Data.DataTable
    $conn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    try {
        $conn.Open()
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $Sql
        $cmd.CommandTimeout = 0
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
        [void]$adapter.Fill($dt)
    } finally {
        $conn.Dispose()
    }
    return $dt
}

function Invoke-SqlScriptFile {
    param(
        [string]$ConnectionString,
        [string]$Path
    )
    $text = [System.IO.File]::ReadAllText($Path)
    $batches = [System.Text.RegularExpressions.Regex]::Split(
        $text,
        "(?im)^\s*GO\s*$"
    )
    foreach ($batch in $batches) {
        $sql = $batch.Trim()
        if ($sql.Length -eq 0) {
            continue
        }
        Invoke-NonQuery -ConnectionString $ConnectionString -Sql $sql
    }
}

function Table-Exists {
    param(
        [string]$ConnectionString,
        [string]$TableName
    )
    $sql = "SELECT CASE WHEN OBJECT_ID('dbo.$TableName','U') IS NULL THEN 0 ELSE 1 END;"
    return [int](Invoke-Scalar -ConnectionString $ConnectionString -Sql $sql) -eq 1
}

function Has-IdentityColumn {
    param(
        [string]$ConnectionString,
        [string]$TableName
    )
    $sql = @"
SELECT CASE WHEN EXISTS (
    SELECT 1
    FROM sys.identity_columns
    WHERE object_id = OBJECT_ID('dbo.$TableName')
) THEN 1 ELSE 0 END;
"@
    return [int](Invoke-Scalar -ConnectionString $ConnectionString -Sql $sql) -eq 1
}

function Copy-TableData {
    param(
        [string]$SourceConnectionString,
        [string]$TargetConnectionString,
        [string]$TableName
    )
    $dt = Get-DataTable -ConnectionString $SourceConnectionString -Sql "SELECT * FROM dbo.[$TableName];"
    Write-Host ("[{0}] source rows: {1}" -f $TableName, $dt.Rows.Count)
    if ($dt.Rows.Count -eq 0) {
        return
    }

    $hasIdentity = Has-IdentityColumn -ConnectionString $TargetConnectionString -TableName $TableName
    if ($hasIdentity) {
        Invoke-NonQuery -ConnectionString $TargetConnectionString -Sql "SET IDENTITY_INSERT dbo.[$TableName] ON;"
    }

    try {
        $bulk = New-Object System.Data.SqlClient.SqlBulkCopy($TargetConnectionString)
        $bulk.DestinationTableName = "dbo.[$TableName]"
        $bulk.BulkCopyTimeout = 0
        foreach ($col in $dt.Columns) {
            [void]$bulk.ColumnMappings.Add($col.ColumnName, $col.ColumnName)
        }
        $bulk.WriteToServer($dt)
        $bulk.Close()
    } finally {
        if ($hasIdentity) {
            Invoke-NonQuery -ConnectionString $TargetConnectionString -Sql "SET IDENTITY_INSERT dbo.[$TableName] OFF;"
        }
    }
}

if (-not (Test-Path -Path $SourceEnvPath)) {
    throw ".env not found: $SourceEnvPath"
}

$sourceEnv = Get-EnvMap -Path $SourceEnvPath

$sourceServer = $sourceEnv["DB_SERVER"]
$sourceDatabase = $sourceEnv["DB_DATABASE"]
$sourceUser = $sourceEnv["DB_USER"]
$sourcePassword = $sourceEnv["DB_PASSWORD"]
$sourcePort = $sourceEnv["DB_PORT"]

if ([string]::IsNullOrWhiteSpace($sourceServer) -or
    [string]::IsNullOrWhiteSpace($sourceDatabase) -or
    [string]::IsNullOrWhiteSpace($sourceUser) -or
    [string]::IsNullOrWhiteSpace($sourcePassword)) {
    throw "Source .env is missing DB settings."
}

# TODO: Replace dummy values with customer server information.
$targetServer = "CUSTOMER-SQLSERVER\INSTANCE"
$targetPort = "1433"
$targetDatabase = "QCCHECK"
$targetUser = "customer_user"
$targetPassword = "customer_password"

$sourceCs = New-ConnectionString -Server $sourceServer -Port $sourcePort -Database $sourceDatabase -User $sourceUser -Password $sourcePassword
$targetMasterCs = New-ConnectionString -Server $targetServer -Port $targetPort -Database "master" -User $targetUser -Password $targetPassword
$targetCs = New-ConnectionString -Server $targetServer -Port $targetPort -Database $targetDatabase -User $targetUser -Password $targetPassword

Write-Host "Ensuring target database exists..."
Invoke-NonQuery -ConnectionString $targetMasterCs -Sql "IF DB_ID(N'$targetDatabase') IS NULL CREATE DATABASE [$targetDatabase];"

$repoRoot = Split-Path -Parent $PSScriptRoot
$ddlScripts = @(
    "sql/01_schema.sql",
    "sql/03_reference_master.sql",
    "sql/15_part_customer.sql",
    "sql/16_format_header_branding.sql",
    "sql/17_part_master.sql",
    "sql/326_process_master_order_unique_per_part.sql",
    "sql/328_extend_check_code_a_to_m.sql",
    "sql/332_machine_master.sql",
    "sql/333_pic_master.sql"
)

Write-Host "Applying DDL scripts on target..."
foreach ($relative in $ddlScripts) {
    $path = Join-Path $repoRoot $relative
    if (-not (Test-Path -Path $path)) {
        throw "DDL file not found: $path"
    }
    Write-Host ("  - {0}" -f $relative)
    Invoke-SqlScriptFile -ConnectionString $targetCs -Path $path
}

$tablesInCopyOrder = @(
    "format_master",
    "process_master",
    "checksheet_header",
    "checksheet_process",
    "checksheet_row",
    "checksheet_row_check",
    "drawing_reference",
    "format_header_branding",
    "machine_master",
    "pic_master",
    "part_customer",
    "part_master",
    "point_check_reference"
)

$deleteOrder = @(
    "checksheet_row_check",
    "checksheet_row",
    "checksheet_process",
    "checksheet_header",
    "point_check_reference",
    "drawing_reference",
    "part_customer",
    "part_master",
    "format_header_branding",
    "process_master",
    "machine_master",
    "pic_master",
    "format_master"
)

Write-Host "Clearing destination table data..."
foreach ($table in $deleteOrder) {
    if (Table-Exists -ConnectionString $targetCs -TableName $table) {
        Invoke-NonQuery -ConnectionString $targetCs -Sql "DELETE FROM dbo.[$table];"
    }
}

Write-Host "Copying table data..."
foreach ($table in $tablesInCopyOrder) {
    if (-not (Table-Exists -ConnectionString $sourceCs -TableName $table)) {
        throw "Source table not found: dbo.$table"
    }
    if (-not (Table-Exists -ConnectionString $targetCs -TableName $table)) {
        throw "Target table not found: dbo.$table"
    }
    Copy-TableData -SourceConnectionString $sourceCs -TargetConnectionString $targetCs -TableName $table
}

Write-Host "Done. 12 tables copied to target."
