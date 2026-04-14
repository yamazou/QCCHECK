USE [QCCHECK];
GO

SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.format_check_item_master', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.format_check_item_master;
END
GO
