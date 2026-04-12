USE [QCCHECK];
GO

IF COL_LENGTH('dbo.checksheet_header', 'prepared_by') IS NULL
BEGIN
    ALTER TABLE dbo.checksheet_header
    ADD prepared_by NVARCHAR(100) NULL;
END
GO

IF COL_LENGTH('dbo.checksheet_header', 'checked_by') IS NULL
BEGIN
    ALTER TABLE dbo.checksheet_header
    ADD checked_by NVARCHAR(100) NULL;
END
GO

IF COL_LENGTH('dbo.checksheet_header', 'approved_by') IS NULL
BEGIN
    ALTER TABLE dbo.checksheet_header
    ADD approved_by NVARCHAR(100) NULL;
END
GO

IF COL_LENGTH('dbo.checksheet_header', 'footer_remarks') IS NULL
BEGIN
    ALTER TABLE dbo.checksheet_header
    ADD footer_remarks NVARCHAR(1000) NULL;
END
GO
