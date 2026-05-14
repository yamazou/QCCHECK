/*
    Customer-side data load template (SSMS run).
    - Use AFTER create_12_tables_customer.sql
    - Paste/replace VALUES or SELECT results per table
    - Insert order is FK-safe
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @TargetDb SYSNAME = N'QCCHECK'; -- TODO: 客先DB名に変更

IF DB_ID(@TargetDb) IS NULL
    THROW 50001, 'Target database not found. Run create_12_tables_customer.sql first.', 1;

DECLARE @sql NVARCHAR(MAX) = N'
USE [' + @TargetDb + N'];

BEGIN TRANSACTION;

-- Optional: clear existing data before load
DELETE FROM dbo.checksheet_row_check;
DELETE FROM dbo.checksheet_row;
DELETE FROM dbo.checksheet_process;
DELETE FROM dbo.checksheet_header;
DELETE FROM dbo.point_check_reference;
DELETE FROM dbo.drawing_reference;
DELETE FROM dbo.part_customer;
DELETE FROM dbo.part_master;
DELETE FROM dbo.format_header_branding;
DELETE FROM dbo.process_master;
DELETE FROM dbo.pic_master;
DELETE FROM dbo.machine_master;
DELETE FROM dbo.format_master;

/* 1) format_master */
SET IDENTITY_INSERT dbo.format_master ON;
-- TODO: replace with actual rows
-- INSERT INTO dbo.format_master (format_id, format_code, format_name, active_flag, created_at, updated_at)
-- VALUES (1, N''FM-ASB-CS-001-00'', N''Sample'', 1, SYSDATETIME(), SYSDATETIME());
SET IDENTITY_INSERT dbo.format_master OFF;

/* 2) machine_master */
SET IDENTITY_INSERT dbo.machine_master ON;
-- TODO: INSERT INTO dbo.machine_master (...)
SET IDENTITY_INSERT dbo.machine_master OFF;

/* 2b) pic_master */
SET IDENTITY_INSERT dbo.pic_master ON;
-- TODO: INSERT INTO dbo.pic_master (...)
SET IDENTITY_INSERT dbo.pic_master OFF;

/* 3) process_master */
SET IDENTITY_INSERT dbo.process_master ON;
-- TODO: INSERT INTO dbo.process_master (...)
SET IDENTITY_INSERT dbo.process_master OFF;

/* 4) checksheet_header */
SET IDENTITY_INSERT dbo.checksheet_header ON;
-- TODO: INSERT INTO dbo.checksheet_header (...)
SET IDENTITY_INSERT dbo.checksheet_header OFF;

/* 5) checksheet_process */
SET IDENTITY_INSERT dbo.checksheet_process ON;
-- TODO: INSERT INTO dbo.checksheet_process (...)
SET IDENTITY_INSERT dbo.checksheet_process OFF;

/* 6) checksheet_row */
SET IDENTITY_INSERT dbo.checksheet_row ON;
-- TODO: INSERT INTO dbo.checksheet_row (...)
SET IDENTITY_INSERT dbo.checksheet_row OFF;

/* 7) checksheet_row_check */
SET IDENTITY_INSERT dbo.checksheet_row_check ON;
-- TODO: INSERT INTO dbo.checksheet_row_check (...)
SET IDENTITY_INSERT dbo.checksheet_row_check OFF;

/* 8) drawing_reference */
SET IDENTITY_INSERT dbo.drawing_reference ON;
-- TODO: INSERT INTO dbo.drawing_reference (...)
SET IDENTITY_INSERT dbo.drawing_reference OFF;

/* 9) format_header_branding */
SET IDENTITY_INSERT dbo.format_header_branding ON;
-- TODO: INSERT INTO dbo.format_header_branding (...)
SET IDENTITY_INSERT dbo.format_header_branding OFF;

/* 10) part_customer */
SET IDENTITY_INSERT dbo.part_customer ON;
-- TODO: INSERT INTO dbo.part_customer (...)
SET IDENTITY_INSERT dbo.part_customer OFF;

/* 11) part_master */
SET IDENTITY_INSERT dbo.part_master ON;
-- TODO: INSERT INTO dbo.part_master (...)
SET IDENTITY_INSERT dbo.part_master OFF;

/* 12) point_check_reference */
SET IDENTITY_INSERT dbo.point_check_reference ON;
-- TODO: INSERT INTO dbo.point_check_reference (...)
SET IDENTITY_INSERT dbo.point_check_reference OFF;

COMMIT TRANSACTION;
';

EXEC sp_executesql @sql;
PRINT 'Completed: template executed.';
