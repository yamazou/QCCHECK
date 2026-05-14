param(
    [string]$EnvPath = "C:\Users\lenovo\QCCheck\server\.env",
    [string]$OutputPath = "C:\Users\lenovo\QCCheck\scripts\insert_12_tables_customer.sql",
    [string]$TargetDbPlaceholder = "QCCHECK"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-Env([string]$path) {
    $map = @{}
    foreach ($line in [System.IO.File]::ReadAllLines($path)) {
        $s = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($s) -or $s.StartsWith("#")) { continue }
        $idx = $s.IndexOf("=")
        if ($idx -lt 1) { continue }
        $k = $s.Substring(0, $idx).Trim()
        $v = $s.Substring($idx + 1).Trim()
        $map[$k] = $v
    }
    return $map
}

function New-Cs([hashtable]$envMap) {
    $server = $envMap["DB_SERVER"]
    $port = $envMap["DB_PORT"]
    $db = $envMap["DB_DATABASE"]
    $user = $envMap["DB_USER"]
    $pw = $envMap["DB_PASSWORD"]
    $ds = if ([string]::IsNullOrWhiteSpace($port)) { $server } else { "$server,$port" }
    return "Server=$ds;Database=$db;User ID=$user;Password=$pw;TrustServerCertificate=True;"
}

function Get-DataTable([string]$cs, [string]$sql) {
    $dt = New-Object System.Data.DataTable
    $conn = New-Object System.Data.SqlClient.SqlConnection($cs)
    try {
        $conn.Open()
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $sql
        $cmd.CommandTimeout = 0
        $adp = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
        [void]$adp.Fill($dt)
    } finally {
        $conn.Dispose()
    }
    return ,$dt
}

function Escape-SqlString([string]$v) {
    return $v.Replace("'", "''")
}

function To-SqlLiteral($v, [string]$typeName) {
    if ($null -eq $v -or $v -is [System.DBNull]) { return "NULL" }
    $t = $typeName.ToLowerInvariant()
    if ($t -in @("nvarchar", "nchar", "ntext")) {
        return "N'" + (Escape-SqlString ([string]$v)) + "'"
    }
    if ($t -in @("varchar", "char", "text", "xml")) {
        return "'" + (Escape-SqlString ([string]$v)) + "'"
    }
    if ($t -in @("datetime", "datetime2", "smalldatetime", "date", "time", "datetimeoffset")) {
        if ($v -is [datetime]) {
            return "'" + $v.ToString("yyyy-MM-ddTHH:mm:ss.fffffff") + "'"
        }
        return "'" + (Escape-SqlString ([string]$v)) + "'"
    }
    if ($t -eq "uniqueidentifier") {
        return "'" + [string]$v + "'"
    }
    if ($t -eq "bit") {
        if ([bool]$v) { return "1" } else { return "0" }
    }
    if ($t -in @("binary", "varbinary", "image", "timestamp", "rowversion")) {
        $bytes = [byte[]]$v
        return "0x" + (($bytes | ForEach-Object { $_.ToString("X2") }) -join "")
    }
    if ($t -in @("float", "real")) {
        return ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, "{0:R}", $v))
    }
    if ($t -in @("decimal", "numeric", "money", "smallmoney")) {
        return ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, "{0}", $v))
    }
    return [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, "{0}", $v)
}

$envMap = Read-Env $EnvPath
$cs = New-Cs $envMap

$tables = @(
    "format_master",
    "machine_master",
    "pic_master",
    "process_master",
    "checksheet_header",
    "checksheet_process",
    "checksheet_row",
    "checksheet_row_check",
    "drawing_reference",
    "format_header_branding",
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

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("/* Auto-generated from source DB. */")
[void]$sb.AppendLine("SET NOCOUNT ON;")
[void]$sb.AppendLine("SET XACT_ABORT ON;")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("DECLARE @TargetDb SYSNAME = N'$TargetDbPlaceholder'; -- TODO: 客先DB名に変更")
[void]$sb.AppendLine("IF DB_ID(@TargetDb) IS NULL THROW 50001, 'Target DB not found.', 1;")
[void]$sb.AppendLine("DECLARE @sql NVARCHAR(MAX) = N'USE [' + @TargetDb + N'];';")
[void]$sb.AppendLine("EXEC sp_executesql @sql;")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("BEGIN TRANSACTION;")
[void]$sb.AppendLine("USE [$TargetDbPlaceholder];")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("-- clear existing rows")
foreach ($t in $deleteOrder) { [void]$sb.AppendLine("DELETE FROM dbo.[$t];") }
[void]$sb.AppendLine("")

foreach ($table in $tables) {
    $colMetaSql = @"
SELECT c.name AS col_name, ty.name AS type_name,
       COLUMNPROPERTY(c.object_id, c.name, 'IsIdentity') AS is_identity
FROM sys.columns c
JOIN sys.types ty ON c.user_type_id = ty.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.$table')
ORDER BY c.column_id;
"@
    $meta = Get-DataTable $cs $colMetaSql
    if ($meta.Rows.Count -eq 0) { continue }

    $isIdentity = $false
    $colNames = @()
    foreach ($r in $meta.Rows) {
        $colNames += ("[" + $r["col_name"] + "]")
        if ([int]$r["is_identity"] -eq 1) { $isIdentity = $true }
    }
    $colCsv = ($colNames -join ", ")
    $data = Get-DataTable $cs "SELECT * FROM dbo.[$table];"

    [void]$sb.AppendLine("-- $table ($($data.Rows.Count) rows)")
    if ($isIdentity) { [void]$sb.AppendLine("SET IDENTITY_INSERT dbo.[$table] ON;") }

    foreach ($dr in $data.Rows) {
        $vals = @()
        foreach ($r in $meta.Rows) {
            $cn = [string]$r["col_name"]
            $tn = [string]$r["type_name"]
            $vals += (To-SqlLiteral $dr[$cn] $tn)
        }
        $valCsv = ($vals -join ", ")
        [void]$sb.AppendLine("INSERT INTO dbo.[$table] ($colCsv) VALUES ($valCsv);")
    }
    if ($isIdentity) { [void]$sb.AppendLine("SET IDENTITY_INSERT dbo.[$table] OFF;") }
    [void]$sb.AppendLine("")
}

[void]$sb.AppendLine("COMMIT TRANSACTION;")
[void]$sb.AppendLine("PRINT 'Completed: data load finished.';")

[System.IO.File]::WriteAllText($OutputPath, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
Write-Output "Generated: $OutputPath"
