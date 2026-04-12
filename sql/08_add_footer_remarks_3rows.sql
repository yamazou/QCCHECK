USE [QCCHECK];
GO

IF COL_LENGTH('dbo.checksheet_header', 'footer_remarks_1') IS NULL
BEGIN
    ALTER TABLE dbo.checksheet_header
    ADD footer_remarks_1 NVARCHAR(500) NULL;
END
GO

IF COL_LENGTH('dbo.checksheet_header', 'footer_remarks_2') IS NULL
BEGIN
    ALTER TABLE dbo.checksheet_header
    ADD footer_remarks_2 NVARCHAR(500) NULL;
END
GO

IF COL_LENGTH('dbo.checksheet_header', 'footer_remarks_3') IS NULL
BEGIN
    ALTER TABLE dbo.checksheet_header
    ADD footer_remarks_3 NVARCHAR(500) NULL;
END
GO
