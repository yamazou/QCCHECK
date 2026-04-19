USE [QCCHECK];
GO

SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.machine_master', 'U') IS NULL
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
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_machine_master_active_order' AND object_id = OBJECT_ID('dbo.machine_master'))
    CREATE INDEX IX_machine_master_active_order ON dbo.machine_master (active_flag, display_order, machine_no);
GO
