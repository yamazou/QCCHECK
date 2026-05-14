/*
    SSMS execution-only migration script (no PowerShell needed).
    - Creates target DB if missing
    - Creates required 12 tables if missing
    - Clears target table data in FK-safe order
    - Copies data from source DB to target DB

    Usage:
      1) Open this file in SQL Server Management Studio
      2) Edit @SourceDb / @TargetDb
      3) Execute (F5)
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @SourceDb SYSNAME = N'QCCHECK_SOURCE'; -- TODO: 現行DB名に変更
DECLARE @TargetDb SYSNAME = N'QCCHECK';        -- TODO: 客先DB名に変更

IF DB_ID(@SourceDb) IS NULL
    THROW 50001, 'Source database not found. Update @SourceDb.', 1;

IF DB_ID(@TargetDb) IS NULL
BEGIN
    DECLARE @createDbSql NVARCHAR(MAX) = N'CREATE DATABASE [' + @TargetDb + N'];';
    EXEC(@createDbSql);
END

DECLARE @sql NVARCHAR(MAX);

/* -------------------------
   1) CREATE TABLE (if missing)
-------------------------- */

SET @sql = N'
USE [' + @TargetDb + N'];

IF OBJECT_ID(''dbo.format_master'',''U'') IS NULL
BEGIN
    CREATE TABLE dbo.format_master (
        format_id INT IDENTITY(1,1) PRIMARY KEY,
        format_code NVARCHAR(50) NOT NULL UNIQUE,
        format_name NVARCHAR(200) NOT NULL,
        active_flag BIT NOT NULL DEFAULT 1,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME()
    );
END;

IF OBJECT_ID(''dbo.process_master'',''U'') IS NULL
BEGIN
    CREATE TABLE dbo.process_master (
        process_master_id INT IDENTITY(1,1) PRIMARY KEY,
        format_id INT NOT NULL,
        part_no NVARCHAR(50) NULL,
        process_name NVARCHAR(200) NOT NULL,
        display_order INT NOT NULL,
        active_flag BIT NOT NULL DEFAULT 1,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_pm_format FOREIGN KEY (format_id) REFERENCES dbo.format_master(format_id),
        CONSTRAINT UQ_pm_format_part_order UNIQUE (format_id, part_no, display_order)
    );
END;

IF OBJECT_ID(''dbo.checksheet_header'',''U'') IS NULL
BEGIN
    CREATE TABLE dbo.checksheet_header (
        header_id BIGINT IDENTITY(1,1) PRIMARY KEY,
        format_id INT NOT NULL,
        part_no NVARCHAR(100) NOT NULL,
        part_name NVARCHAR(200) NOT NULL,
        eff_date DATE NULL,
        rev_no NVARCHAR(50) NULL,
        department NVARCHAR(200) NULL,
        sheet_date DATE NULL,
        prepared_by NVARCHAR(100) NULL,
        checked_by NVARCHAR(100) NULL,
        approved_by NVARCHAR(100) NULL,
        footer_remarks NVARCHAR(1000) NULL,
        footer_remarks_1 NVARCHAR(500) NULL,
        footer_remarks_2 NVARCHAR(500) NULL,
        footer_remarks_3 NVARCHAR(500) NULL,
        status NVARCHAR(20) NOT NULL DEFAULT ''DRAFT'',
        created_by NVARCHAR(100) NULL,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_by NVARCHAR(100) NULL,
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_ch_format FOREIGN KEY (format_id) REFERENCES dbo.format_master(format_id),
        CONSTRAINT CK_ch_status CHECK (status IN (''DRAFT'',''SUBMITTED''))
    );
END;

IF OBJECT_ID(''dbo.checksheet_process'',''U'') IS NULL
BEGIN
    CREATE TABLE dbo.checksheet_process (
        process_id BIGINT IDENTITY(1,1) PRIMARY KEY,
        header_id BIGINT NOT NULL,
        process_master_id INT NULL,
        process_name_snapshot NVARCHAR(200) NOT NULL,
        display_order INT NOT NULL,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_cp_header FOREIGN KEY (header_id) REFERENCES dbo.checksheet_header(header_id),
        CONSTRAINT FK_cp_master FOREIGN KEY (process_master_id) REFERENCES dbo.process_master(process_master_id),
        CONSTRAINT UQ_cp_header_order UNIQUE(header_id, display_order)
    );
END;

IF OBJECT_ID(''dbo.checksheet_row'',''U'') IS NULL
BEGIN
    CREATE TABLE dbo.checksheet_row (
        row_id BIGINT IDENTITY(1,1) PRIMARY KEY,
        process_id BIGINT NOT NULL,
        row_no INT NOT NULL,
        work_date DATE NULL,
        start_time TIME(0) NULL,
        finish_time TIME(0) NULL,
        qty INT NULL,
        ok_count INT NULL,
        ng_count INT NULL,
        machine_no NVARCHAR(100) NULL,
        pic NVARCHAR(100) NULL,
        sop_check BIT NULL,
        leader_check NVARCHAR(20) NULL,
        remarks NVARCHAR(500) NULL,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_cr_process FOREIGN KEY (process_id) REFERENCES dbo.checksheet_process(process_id),
        CONSTRAINT UQ_cr_process_row UNIQUE(process_id, row_no),
        CONSTRAINT CK_cr_row_no CHECK (row_no >= 1),
        CONSTRAINT CK_cr_qty_nonneg CHECK (
            (qty IS NULL OR qty >= 0) AND
            (ok_count IS NULL OR ok_count >= 0) AND
            (ng_count IS NULL OR ng_count >= 0)
        )
    );
END;

IF OBJECT_ID(''dbo.checksheet_row_check'',''U'') IS NULL
BEGIN
    CREATE TABLE dbo.checksheet_row_check (
        row_check_id BIGINT IDENTITY(1,1) PRIMARY KEY,
        row_id BIGINT NOT NULL,
        check_code NCHAR(1) NOT NULL,
        result NVARCHAR(50) NULL,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_crc_row FOREIGN KEY (row_id) REFERENCES dbo.checksheet_row(row_id),
        CONSTRAINT CK_crc_code CHECK (check_code IN (''A'',''B'',''C'',''D'',''E'',''F'',''G'',''H'',''I'',''J'',''K'',''L'',''M'')),
        CONSTRAINT CK_crc_result CHECK (LEN(LTRIM(RTRIM(result))) <= 50 OR result IS NULL),
        CONSTRAINT UQ_crc_row_code UNIQUE(row_id, check_code)
    );
END;

IF OBJECT_ID(''dbo.drawing_reference'',''U'') IS NULL
BEGIN
    CREATE TABLE dbo.drawing_reference (
        drawing_ref_id BIGINT IDENTITY(1,1) PRIMARY KEY,
        format_id INT NOT NULL,
        part_no NVARCHAR(100) NOT NULL,
        process_code NVARCHAR(50) NULL,
        drawing_no NVARCHAR(100) NULL,
        drawing_name NVARCHAR(200) NULL,
        file_url NVARCHAR(500) NULL,
        note NVARCHAR(500) NULL,
        active_flag BIT NOT NULL DEFAULT 1,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_dr_format FOREIGN KEY (format_id) REFERENCES dbo.format_master(format_id)
    );
END;

IF OBJECT_ID(''dbo.format_header_branding'',''U'') IS NULL
BEGIN
    CREATE TABLE dbo.format_header_branding (
        format_header_branding_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        format_id INT NOT NULL,
        company_name NVARCHAR(200) NOT NULL,
        department_name NVARCHAR(200) NOT NULL,
        logo_url NVARCHAR(500) NULL,
        active_flag BIT NOT NULL DEFAULT 1,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_fhb_format FOREIGN KEY (format_id) REFERENCES dbo.format_master(format_id),
        CONSTRAINT UQ_fhb_format UNIQUE (format_id)
    );
END;

IF OBJECT_ID(''dbo.machine_master'',''U'') IS NULL
BEGIN
    CREATE TABLE dbo.machine_master (
        machine_master_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        machine_no NVARCHAR(100) NOT NULL,
        machine_name NVARCHAR(200) NOT NULL,
        display_order INT NOT NULL CONSTRAINT DF_machine_master_display_order DEFAULT (0),
        active_flag BIT NOT NULL CONSTRAINT DF_machine_master_active DEFAULT (1),
        created_at DATETIME2 NOT NULL CONSTRAINT DF_machine_master_created DEFAULT (SYSDATETIME()),
        updated_at DATETIME2 NOT NULL CONSTRAINT DF_machine_master_updated DEFAULT (SYSDATETIME()),
        CONSTRAINT UQ_machine_master_no UNIQUE (machine_no),
        CONSTRAINT CK_machine_master_no_nonempty CHECK (LEN(LTRIM(RTRIM(machine_no))) >= 1),
        CONSTRAINT CK_machine_master_name_nonempty CHECK (LEN(LTRIM(RTRIM(machine_name))) >= 1)
    );
END;

IF OBJECT_ID(''dbo.pic_master'',''U'') IS NULL
BEGIN
    CREATE TABLE dbo.pic_master (
        pic_master_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        pic_no NVARCHAR(100) NOT NULL,
        pic_name NVARCHAR(200) NOT NULL,
        display_order INT NOT NULL CONSTRAINT DF_pic_master_display_order DEFAULT (0),
        active_flag BIT NOT NULL CONSTRAINT DF_pic_master_active DEFAULT (1),
        created_at DATETIME2 NOT NULL CONSTRAINT DF_pic_master_created DEFAULT (SYSDATETIME()),
        updated_at DATETIME2 NOT NULL CONSTRAINT DF_pic_master_updated DEFAULT (SYSDATETIME()),
        CONSTRAINT UQ_pic_master_no UNIQUE (pic_no),
        CONSTRAINT CK_pic_master_no_nonempty CHECK (LEN(LTRIM(RTRIM(pic_no))) >= 1),
        CONSTRAINT CK_pic_master_name_nonempty CHECK (LEN(LTRIM(RTRIM(pic_name))) >= 1)
    );
END;

IF OBJECT_ID(''dbo.part_customer'',''U'') IS NULL
BEGIN
    CREATE TABLE dbo.part_customer (
        part_customer_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        format_id INT NOT NULL,
        part_no NVARCHAR(100) NOT NULL,
        customer_abbrev NVARCHAR(50) NOT NULL,
        active_flag BIT NOT NULL DEFAULT 1,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_pc_format FOREIGN KEY (format_id) REFERENCES dbo.format_master(format_id),
        CONSTRAINT UQ_pc_format_part UNIQUE (format_id, part_no)
    );
END;

IF OBJECT_ID(''dbo.part_master'',''U'') IS NULL
BEGIN
    CREATE TABLE dbo.part_master (
        part_master_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        format_id INT NOT NULL,
        part_no NVARCHAR(100) NOT NULL,
        part_name NVARCHAR(200) NOT NULL,
        active_flag BIT NOT NULL DEFAULT 1,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_partm_format FOREIGN KEY (format_id) REFERENCES dbo.format_master(format_id),
        CONSTRAINT UQ_partm_format_part UNIQUE (format_id, part_no)
    );
END;

IF OBJECT_ID(''dbo.point_check_reference'',''U'') IS NULL
BEGIN
    CREATE TABLE dbo.point_check_reference (
        point_check_ref_id BIGINT IDENTITY(1,1) PRIMARY KEY,
        format_id INT NOT NULL,
        part_no NVARCHAR(100) NOT NULL,
        process_code NVARCHAR(50) NULL,
        check_code NCHAR(1) NOT NULL,
        check_point NVARCHAR(300) NOT NULL,
        criteria NVARCHAR(300) NULL,
        criteria_min DECIMAL(18,4) NULL,
        criteria_max DECIMAL(18,4) NULL,
        check_method NVARCHAR(300) NULL,
        note NVARCHAR(500) NULL,
        input_mode VARCHAR(20) NOT NULL DEFAULT ''OKNG'',
        active_flag BIT NOT NULL DEFAULT 1,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_pcr_format FOREIGN KEY (format_id) REFERENCES dbo.format_master(format_id),
        CONSTRAINT CK_pcr_code CHECK (check_code IN (''A'',''B'',''C'',''D'',''E'',''F'',''G'',''H'',''I'',''J'',''K'',''L'',''M'')),
        CONSTRAINT CK_pcr_input_mode CHECK (input_mode IN (''OKNG'', ''NUMERIC'')),
        CONSTRAINT CK_pcr_criteria_range CHECK (criteria_min IS NULL OR criteria_max IS NULL OR criteria_min <= criteria_max)
    );
END;
';
EXEC sp_executesql @sql;

/* -------------------------
   2) COPY DATA
-------------------------- */
BEGIN TRANSACTION;

SET @sql = N'
USE [' + @TargetDb + N'];

DELETE FROM dbo.checksheet_row_check;
DELETE FROM dbo.checksheet_row;
DELETE FROM dbo.checksheet_process;
DELETE FROM dbo.checksheet_header;
DELETE FROM dbo.point_check_reference;
DELETE FROM dbo.drawing_reference;
DELETE FROM dbo.part_customer;
DELETE FROM dbo.part_master;
DELETE FROM dbo.format_header_branding;
DELETE FROM dbo.process_master;
DELETE FROM dbo.machine_master;
DELETE FROM dbo.pic_master;
DELETE FROM dbo.format_master;
';
EXEC sp_executesql @sql;

SET @sql = N'
SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[format_master] ON;
INSERT INTO [' + @TargetDb + N'].[dbo].[format_master] (format_id, format_code, format_name, active_flag, created_at, updated_at)
SELECT format_id, format_code, format_name, active_flag, created_at, updated_at
FROM [' + @SourceDb + N'].[dbo].[format_master];
SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[format_master] OFF;

SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[machine_master] ON;
INSERT INTO [' + @TargetDb + N'].[dbo].[machine_master] (machine_master_id, machine_no, machine_name, display_order, active_flag, created_at, updated_at)
SELECT machine_master_id, machine_no, machine_name, display_order, active_flag, created_at, updated_at
FROM [' + @SourceDb + N'].[dbo].[machine_master];
SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[machine_master] OFF;

SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[pic_master] ON;
INSERT INTO [' + @TargetDb + N'].[dbo].[pic_master] (pic_master_id, pic_no, pic_name, display_order, active_flag, created_at, updated_at)
SELECT pic_master_id, pic_no, pic_name, display_order, active_flag, created_at, updated_at
FROM [' + @SourceDb + N'].[dbo].[pic_master];
SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[pic_master] OFF;

SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[process_master] ON;
INSERT INTO [' + @TargetDb + N'].[dbo].[process_master] (process_master_id, format_id, part_no, process_name, display_order, active_flag, created_at, updated_at)
SELECT process_master_id, format_id, part_no, process_name, display_order, active_flag, created_at, updated_at
FROM [' + @SourceDb + N'].[dbo].[process_master];
SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[process_master] OFF;

SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[checksheet_header] ON;
INSERT INTO [' + @TargetDb + N'].[dbo].[checksheet_header] (
    header_id, format_id, part_no, part_name, eff_date, rev_no, department, sheet_date,
    prepared_by, checked_by, approved_by, footer_remarks, footer_remarks_1, footer_remarks_2, footer_remarks_3,
    status, created_by, created_at, updated_by, updated_at
)
SELECT
    header_id, format_id, part_no, part_name, eff_date, rev_no, department, sheet_date,
    prepared_by, checked_by, approved_by, footer_remarks, footer_remarks_1, footer_remarks_2, footer_remarks_3,
    status, created_by, created_at, updated_by, updated_at
FROM [' + @SourceDb + N'].[dbo].[checksheet_header];
SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[checksheet_header] OFF;

SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[checksheet_process] ON;
INSERT INTO [' + @TargetDb + N'].[dbo].[checksheet_process] (
    process_id, header_id, process_master_id, process_name_snapshot, display_order, created_at, updated_at
)
SELECT
    process_id, header_id, process_master_id, process_name_snapshot, display_order, created_at, updated_at
FROM [' + @SourceDb + N'].[dbo].[checksheet_process];
SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[checksheet_process] OFF;

SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[checksheet_row] ON;
INSERT INTO [' + @TargetDb + N'].[dbo].[checksheet_row] (
    row_id, process_id, row_no, work_date, start_time, finish_time, qty, ok_count, ng_count,
    machine_no, pic, sop_check, leader_check, remarks, created_at, updated_at
)
SELECT
    row_id, process_id, row_no, work_date, start_time, finish_time, qty, ok_count, ng_count,
    machine_no, pic, sop_check, leader_check, remarks, created_at, updated_at
FROM [' + @SourceDb + N'].[dbo].[checksheet_row];
SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[checksheet_row] OFF;

SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[checksheet_row_check] ON;
INSERT INTO [' + @TargetDb + N'].[dbo].[checksheet_row_check] (
    row_check_id, row_id, check_code, result, created_at, updated_at
)
SELECT
    row_check_id, row_id, check_code, result, created_at, updated_at
FROM [' + @SourceDb + N'].[dbo].[checksheet_row_check];
SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[checksheet_row_check] OFF;

SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[drawing_reference] ON;
INSERT INTO [' + @TargetDb + N'].[dbo].[drawing_reference] (
    drawing_ref_id, format_id, part_no, process_code, drawing_no, drawing_name, file_url, note, active_flag, created_at, updated_at
)
SELECT
    drawing_ref_id, format_id, part_no, process_code, drawing_no, drawing_name, file_url, note, active_flag, created_at, updated_at
FROM [' + @SourceDb + N'].[dbo].[drawing_reference];
SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[drawing_reference] OFF;

SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[format_header_branding] ON;
INSERT INTO [' + @TargetDb + N'].[dbo].[format_header_branding] (
    format_header_branding_id, format_id, company_name, department_name, logo_url, active_flag, created_at, updated_at
)
SELECT
    format_header_branding_id, format_id, company_name, department_name, logo_url, active_flag, created_at, updated_at
FROM [' + @SourceDb + N'].[dbo].[format_header_branding];
SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[format_header_branding] OFF;

SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[part_customer] ON;
INSERT INTO [' + @TargetDb + N'].[dbo].[part_customer] (
    part_customer_id, format_id, part_no, customer_abbrev, active_flag, created_at, updated_at
)
SELECT
    part_customer_id, format_id, part_no, customer_abbrev, active_flag, created_at, updated_at
FROM [' + @SourceDb + N'].[dbo].[part_customer];
SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[part_customer] OFF;

SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[part_master] ON;
INSERT INTO [' + @TargetDb + N'].[dbo].[part_master] (
    part_master_id, format_id, part_no, part_name, active_flag, created_at, updated_at
)
SELECT
    part_master_id, format_id, part_no, part_name, active_flag, created_at, updated_at
FROM [' + @SourceDb + N'].[dbo].[part_master];
SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[part_master] OFF;

SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[point_check_reference] ON;
INSERT INTO [' + @TargetDb + N'].[dbo].[point_check_reference] (
    point_check_ref_id, format_id, part_no, process_code, check_code, check_point, criteria, criteria_min, criteria_max,
    check_method, note, input_mode, active_flag, created_at, updated_at
)
SELECT
    point_check_ref_id, format_id, part_no, process_code, check_code, check_point, criteria, criteria_min, criteria_max,
    check_method, note, input_mode, active_flag, created_at, updated_at
FROM [' + @SourceDb + N'].[dbo].[point_check_reference];
SET IDENTITY_INSERT [' + @TargetDb + N'].[dbo].[point_check_reference] OFF;
';
EXEC sp_executesql @sql;

COMMIT TRANSACTION;

PRINT 'Completed: 12-table create/copy finished.';
