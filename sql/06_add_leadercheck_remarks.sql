USE [QCCHECK];
GO

IF COL_LENGTH('dbo.checksheet_row', 'leader_check') IS NULL
BEGIN
    ALTER TABLE dbo.checksheet_row
    ADD leader_check NVARCHAR(20) NULL;
END
GO

IF COL_LENGTH('dbo.checksheet_row', 'remarks') IS NULL
BEGIN
    ALTER TABLE dbo.checksheet_row
    ADD remarks NVARCHAR(500) NULL;
END
GO
