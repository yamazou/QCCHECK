USE [QCCHECK];
GO

/* Customer name abbreviation shown in check sheet header (per format + part). */

IF OBJECT_ID('dbo.part_customer', 'U') IS NULL
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
END
GO

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    MERGE dbo.part_customer AS t
    USING (VALUES
        (@format_id, N'VDE1980', N'YEMI'),
        (@format_id, N'VDK0970', N'YEMI')
    ) AS s (format_id, part_no, customer_abbrev)
    ON t.format_id = s.format_id AND t.part_no = s.part_no
    WHEN MATCHED AND (t.customer_abbrev <> s.customer_abbrev OR t.active_flag = 0) THEN
        UPDATE SET customer_abbrev = s.customer_abbrev, active_flag = 1, updated_at = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (format_id, part_no, customer_abbrev) VALUES (s.format_id, s.part_no, s.customer_abbrev);
END
GO
