USE [QCCHECK];
GO

/* ZD22000 CUTTING CHAMFERING: set drawing file (place PNG at server/public/drawings/ZD22000_CUTTING_CHAMFERING.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZD22000-CCH',
        drawing_name = N'CUTTING CHAMFERING PROCESS DRAWING',
        file_url = N'/drawings/ZD22000_CUTTING_CHAMFERING.png',
        note = N'E: chamfer width',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZD22000'
      AND process_code = N'CUTTING CHAMFERING';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZD22000',
            N'CUTTING CHAMFERING',
            N'ZD22000-CCH',
            N'CUTTING CHAMFERING PROCESS DRAWING',
            N'/drawings/ZD22000_CUTTING_CHAMFERING.png',
            N'E: chamfer width'
        );
    END
END
GO

