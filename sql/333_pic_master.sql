USE [QCCHECK];
GO

SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.pic_master', 'U') IS NULL
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
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_pic_master_active_order' AND object_id = OBJECT_ID('dbo.pic_master'))
    CREATE INDEX IX_pic_master_active_order ON dbo.pic_master (active_flag, display_order, pic_no);
GO
