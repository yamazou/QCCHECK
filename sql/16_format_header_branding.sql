USE [QCCHECK];
GO

/* Header branding shown on Check Sheet (per format). */

IF OBJECT_ID('dbo.format_header_branding', 'U') IS NULL
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
END
GO

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    MERGE dbo.format_header_branding AS t
    USING (VALUES
        (@format_id, N'PT YAN JIN INDONESIA', N'Production Department', N'/drawings/UACJ_logo.png')
    ) AS s (format_id, company_name, department_name, logo_url)
    ON t.format_id = s.format_id
    WHEN MATCHED THEN
        UPDATE SET
            company_name = s.company_name,
            department_name = s.department_name,
            logo_url = s.logo_url,
            active_flag = 1,
            updated_at = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (format_id, company_name, department_name, logo_url)
        VALUES (s.format_id, s.company_name, s.department_name, s.logo_url);
END
GO
