USE [QCCHECK];
GO

SET NOCOUNT ON;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_fcim_code' AND parent_object_id = OBJECT_ID('dbo.format_check_item_master'))
BEGIN
    ALTER TABLE dbo.format_check_item_master DROP CONSTRAINT CK_fcim_code;
END
GO
ALTER TABLE dbo.format_check_item_master
ADD CONSTRAINT CK_fcim_code CHECK (check_code IN ('A','B','C','D','E','F','G'));
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_crc_code' AND parent_object_id = OBJECT_ID('dbo.checksheet_row_check'))
BEGIN
    ALTER TABLE dbo.checksheet_row_check DROP CONSTRAINT CK_crc_code;
END
GO
ALTER TABLE dbo.checksheet_row_check
ADD CONSTRAINT CK_crc_code CHECK (check_code IN ('A','B','C','D','E','F','G'));
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_pcr_code' AND parent_object_id = OBJECT_ID('dbo.point_check_reference'))
BEGIN
    ALTER TABLE dbo.point_check_reference DROP CONSTRAINT CK_pcr_code;
END
GO
ALTER TABLE dbo.point_check_reference
ADD CONSTRAINT CK_pcr_code CHECK (check_code IN ('A','B','C','D','E','F','G'));
GO

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');
IF @format_id IS NOT NULL
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM dbo.format_check_item_master WHERE format_id = @format_id AND check_code = N'G'
    )
    BEGIN
        INSERT INTO dbo.format_check_item_master (format_id, check_code, check_name, display_order, active_flag)
        VALUES (@format_id, N'G', N'Check G', 7, 1);
    END
END
GO
