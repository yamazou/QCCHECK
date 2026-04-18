USE [QCCHECK];
GO

IF COL_LENGTH('dbo.checksheet_row', 'machine_no') IS NULL
BEGIN
    ALTER TABLE dbo.checksheet_row ADD machine_no NVARCHAR(100) NULL;
END
GO

IF COL_LENGTH('dbo.checksheet_row', 'sop_check') IS NULL
BEGIN
    ALTER TABLE dbo.checksheet_row ADD sop_check BIT NULL;
END
GO
