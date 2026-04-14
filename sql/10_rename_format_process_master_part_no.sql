USE [QCCHECK];
GO

/* Existing DBs: rename format_process_master -> process_master, then process_code -> part_no. */

IF OBJECT_ID('dbo.format_process_master', 'U') IS NOT NULL
   AND OBJECT_ID('dbo.process_master', 'U') IS NULL
BEGIN
    EXEC sp_rename 'dbo.format_process_master', 'process_master';
END
GO

IF COL_LENGTH('dbo.process_master', 'process_code') IS NOT NULL
   AND COL_LENGTH('dbo.process_master', 'part_no') IS NULL
BEGIN
    EXEC sp_rename 'dbo.process_master.process_code', 'part_no', 'COLUMN';
END
GO
