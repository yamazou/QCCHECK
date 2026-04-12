USE [QCCHECK];
GO

IF OBJECT_ID('dbo.format_master', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.format_master (
        format_id INT IDENTITY(1,1) PRIMARY KEY,
        format_code NVARCHAR(50) NOT NULL UNIQUE,
        format_name NVARCHAR(200) NOT NULL,
        active_flag BIT NOT NULL DEFAULT 1,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME()
    );
END
GO

IF OBJECT_ID('dbo.format_process_master', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.format_process_master (
        process_master_id INT IDENTITY(1,1) PRIMARY KEY,
        format_id INT NOT NULL,
        part_no NVARCHAR(50) NULL,
        process_name NVARCHAR(200) NOT NULL,
        display_order INT NOT NULL,
        active_flag BIT NOT NULL DEFAULT 1,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_fpm_format FOREIGN KEY (format_id) REFERENCES dbo.format_master(format_id),
        CONSTRAINT UQ_fpm_format_order UNIQUE(format_id, display_order)
    );
END
GO

IF OBJECT_ID('dbo.format_check_item_master', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.format_check_item_master (
        check_item_id INT IDENTITY(1,1) PRIMARY KEY,
        format_id INT NOT NULL,
        check_code NCHAR(1) NOT NULL,
        check_name NVARCHAR(200) NULL,
        display_order INT NOT NULL,
        active_flag BIT NOT NULL DEFAULT 1,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_fcim_format FOREIGN KEY (format_id) REFERENCES dbo.format_master(format_id),
        CONSTRAINT CK_fcim_code CHECK (check_code IN ('A','B','C','D','E','F','G')),
        CONSTRAINT UQ_fcim_format_code UNIQUE(format_id, check_code)
    );
END
GO

IF OBJECT_ID('dbo.checksheet_header', 'U') IS NULL
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
        status NVARCHAR(20) NOT NULL DEFAULT 'DRAFT',
        created_by NVARCHAR(100) NULL,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_by NVARCHAR(100) NULL,
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_ch_format FOREIGN KEY (format_id) REFERENCES dbo.format_master(format_id),
        CONSTRAINT CK_ch_status CHECK (status IN ('DRAFT','SUBMITTED'))
    );
END
GO

IF OBJECT_ID('dbo.checksheet_process', 'U') IS NULL
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
        CONSTRAINT FK_cp_master FOREIGN KEY (process_master_id) REFERENCES dbo.format_process_master(process_master_id),
        CONSTRAINT UQ_cp_header_order UNIQUE(header_id, display_order)
    );
END
GO

IF OBJECT_ID('dbo.checksheet_row', 'U') IS NULL
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
        pic NVARCHAR(100) NULL,
        leader_check NVARCHAR(20) NULL,
        remarks NVARCHAR(500) NULL,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_cr_process FOREIGN KEY (process_id) REFERENCES dbo.checksheet_process(process_id),
        CONSTRAINT UQ_cr_process_row UNIQUE(process_id, row_no),
        CONSTRAINT CK_cr_row_no CHECK (row_no BETWEEN 1 AND 31),
        CONSTRAINT CK_cr_qty_nonneg CHECK (
            (qty IS NULL OR qty >= 0) AND
            (ok_count IS NULL OR ok_count >= 0) AND
            (ng_count IS NULL OR ng_count >= 0)
        )
    );
END
GO

IF OBJECT_ID('dbo.checksheet_row_check', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.checksheet_row_check (
        row_check_id BIGINT IDENTITY(1,1) PRIMARY KEY,
        row_id BIGINT NOT NULL,
        check_code NCHAR(1) NOT NULL,
        result NVARCHAR(2) NULL,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_crc_row FOREIGN KEY (row_id) REFERENCES dbo.checksheet_row(row_id),
        CONSTRAINT CK_crc_code CHECK (check_code IN ('A','B','C','D','E','F','G')),
        CONSTRAINT CK_crc_result CHECK (result IN ('OK','NG') OR result IS NULL),
        CONSTRAINT UQ_crc_row_code UNIQUE(row_id, check_code)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ch_format_created_at' AND object_id = OBJECT_ID('dbo.checksheet_header'))
    CREATE INDEX IX_ch_format_created_at ON dbo.checksheet_header(format_id, created_at DESC);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_cp_header' AND object_id = OBJECT_ID('dbo.checksheet_process'))
    CREATE INDEX IX_cp_header ON dbo.checksheet_process(header_id);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_cr_process' AND object_id = OBJECT_ID('dbo.checksheet_row'))
    CREATE INDEX IX_cr_process ON dbo.checksheet_row(process_id, row_no);
GO
