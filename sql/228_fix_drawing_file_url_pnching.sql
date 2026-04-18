USE [QCCHECK];
GO

/* If sql/227 was already applied before file_url was added there, run this once.
   Fixes 404 e.g. GET /drawings/VEN3620_PNCHING_CUT_BLANK_1_2.png when the file is ..._PUNCHING_....png */

UPDATE dbo.drawing_reference
SET file_url = REPLACE(file_url, N'PNCHING', N'PUNCHING'), updated_at = SYSDATETIME()
WHERE file_url LIKE N'%PNCHING%';

GO
