USE [QCCHECK];
GO

/* Existing DBs: rename format_process_master.process_code -> part_no (semantics: parts / BOM item). */

IF COL_LENGTH('dbo.format_process_master', 'process_code') IS NOT NULL
   AND COL_LENGTH('dbo.format_process_master', 'part_no') IS NULL
BEGIN
    EXEC sp_rename 'dbo.format_process_master.process_code', 'part_no', 'COLUMN';
END
GO
