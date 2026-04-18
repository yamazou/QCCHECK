USE [QCCHECK];
GO

/* ZF 600700 (DB part_no ZF600700) SAWING: E cut length — PNG at server/public/drawings/ZF600700_SAWING.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZF600700-SW',
        drawing_name = N'SAWING PROCESS DRAWING',
        file_url = N'/drawings/ZF600700_SAWING.png',
        note = N'E: cut length (extrusion profile)',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZF600700'
      AND process_code = N'SAWING';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZF600700',
            N'SAWING',
            N'ZF600700-SW',
            N'SAWING PROCESS DRAWING',
            N'/drawings/ZF600700_SAWING.png',
            N'E: cut length (extrusion profile)'
        );
    END
END
GO
