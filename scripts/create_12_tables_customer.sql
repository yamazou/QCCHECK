/*
    Customer-side DDL only script (SSMS run).
    Purpose:
      - Create empty DB (if missing)
      - Create required 12 tables (if missing)
      - No data copy from source DB

    Usage:
      1) Edit @TargetDb
      2) Execute in SSMS
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @TargetDb SYSNAME = N'QCCHECK'; -- TODO: 客先DB名に変更

IF DB_ID(@TargetDb) IS NULL
BEGIN
    DECLARE @createDbSql NVARCHAR(MAX) = N'CREATE DATABASE [' + @TargetDb + N'];';
    EXEC(@createDbSql);
END

DECLARE @sql NVARCHAR(MAX) = N'
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

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''IX_ch_format_created_at'' AND object_id = OBJECT_ID(''dbo.checksheet_header''))
    CREATE INDEX IX_ch_format_created_at ON dbo.checksheet_header(format_id, created_at DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''IX_cp_header'' AND object_id = OBJECT_ID(''dbo.checksheet_process''))
    CREATE INDEX IX_cp_header ON dbo.checksheet_process(header_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''IX_cr_process'' AND object_id = OBJECT_ID(''dbo.checksheet_row''))
    CREATE INDEX IX_cr_process ON dbo.checksheet_row(process_id, row_no);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''IX_dr_lookup'' AND object_id = OBJECT_ID(''dbo.drawing_reference''))
    CREATE INDEX IX_dr_lookup ON dbo.drawing_reference(format_id, part_no, active_flag);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''IX_pcr_lookup'' AND object_id = OBJECT_ID(''dbo.point_check_reference''))
    CREATE INDEX IX_pcr_lookup ON dbo.point_check_reference(format_id, part_no, active_flag);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''IX_machine_master_active_order'' AND object_id = OBJECT_ID(''dbo.machine_master''))
    CREATE INDEX IX_machine_master_active_order ON dbo.machine_master(active_flag, display_order, machine_no);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''IX_pic_master_active_order'' AND object_id = OBJECT_ID(''dbo.pic_master''))
    CREATE INDEX IX_pic_master_active_order ON dbo.pic_master(active_flag, display_order, pic_no);
';

EXEC sp_executesql @sql;
PRINT 'Completed: 12 tables created (empty).';
