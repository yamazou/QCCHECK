USE [QCCHECK];
GO

/* Fix typo PNCHING -> PUNCHING in process and reference tables (so DB matches drawing rows and /api/references JOIN works). */

UPDATE dbo.process_master
SET process_name = REPLACE(process_name, N'PNCHING', N'PUNCHING'), updated_at = SYSDATETIME()
WHERE process_name LIKE N'%PNCHING%';

UPDATE dbo.drawing_reference
SET process_code = REPLACE(process_code, N'PNCHING', N'PUNCHING'), updated_at = SYSDATETIME()
WHERE process_code LIKE N'%PNCHING%';

/* file_url must match PNG on disk (e.g. ..._PUNCHING_...png); process_code alone does not fix the browser request path. */
UPDATE dbo.drawing_reference
SET file_url = REPLACE(file_url, N'PNCHING', N'PUNCHING'), updated_at = SYSDATETIME()
WHERE file_url LIKE N'%PNCHING%';

UPDATE dbo.point_check_reference
SET process_code = REPLACE(process_code, N'PNCHING', N'PUNCHING'), updated_at = SYSDATETIME()
WHERE process_code LIKE N'%PNCHING%';

UPDATE dbo.checksheet_process
SET process_name_snapshot = REPLACE(process_name_snapshot, N'PNCHING', N'PUNCHING'), updated_at = SYSDATETIME()
WHERE process_name_snapshot LIKE N'%PNCHING%';

GO
