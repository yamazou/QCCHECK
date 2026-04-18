USE [QCCHECK];
GO

/* Optional: fix SAWING spellings/spacing in master and drawing rows so they match /drawings/..._SAWING.png keys. */

UPDATE dbo.process_master
SET process_name = LTRIM(RTRIM(REPLACE(REPLACE(process_name, N'SAW ING', N'SAWING'), N'SAWNING', N'SAWING'))),
    updated_at = SYSDATETIME()
WHERE process_name LIKE N'%SAW ING%'
   OR process_name LIKE N'%SAWNING%';

UPDATE dbo.drawing_reference
SET process_code = LTRIM(RTRIM(REPLACE(REPLACE(process_code, N'SAW ING', N'SAWING'), N'SAWNING', N'SAWING'))),
    updated_at = SYSDATETIME()
WHERE process_code LIKE N'%SAW ING%'
   OR process_code LIKE N'%SAWNING%';

UPDATE dbo.point_check_reference
SET process_code = LTRIM(RTRIM(REPLACE(REPLACE(process_code, N'SAW ING', N'SAWING'), N'SAWNING', N'SAWING'))),
    updated_at = SYSDATETIME()
WHERE process_code LIKE N'%SAW ING%'
   OR process_code LIKE N'%SAWNING%';

GO
