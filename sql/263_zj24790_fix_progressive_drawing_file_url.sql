USE [QCCHECK];
GO

/* If drawing_reference was pointed at ...PUNCH_PROGRESSIVE_1_1.png (no ING), align URL with canonical filename. */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        file_url = N'/drawings/ZJ24790_PUNCHING_PROGRESSIVE_1_1.png',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZJ24790'
      AND process_code = N'PUNCHING PROGRESSIVE 1/1'
      AND file_url = N'/drawings/ZJ24790_PUNCH_PROGRESSIVE_1_1.png';
END
GO
