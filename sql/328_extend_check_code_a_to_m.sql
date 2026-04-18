USE [QCCHECK];
GO

SET NOCOUNT ON;
GO

/* Extend point check / row check codes from A–G to A–M (matches app + admin validation). */

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_crc_code' AND parent_object_id = OBJECT_ID('dbo.checksheet_row_check'))
BEGIN
    ALTER TABLE dbo.checksheet_row_check DROP CONSTRAINT CK_crc_code;
END;
GO

ALTER TABLE dbo.checksheet_row_check
ADD CONSTRAINT CK_crc_code CHECK (check_code IN ('A','B','C','D','E','F','G','H','I','J','K','L','M'));
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_pcr_code' AND parent_object_id = OBJECT_ID('dbo.point_check_reference'))
BEGIN
    ALTER TABLE dbo.point_check_reference DROP CONSTRAINT CK_pcr_code;
END;
GO

ALTER TABLE dbo.point_check_reference
ADD CONSTRAINT CK_pcr_code CHECK (check_code IN ('A','B','C','D','E','F','G','H','I','J','K','L','M'));
GO
