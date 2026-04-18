USE [QCCHECK];
GO

/* VXH8940 DRAW 2/6: drawing file at server/public/drawings/VXH8940_DRAW_2_6.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VXH8940-DR26',
        drawing_name = N'DRAW 2/6 PROCESS DRAWING',
        file_url = N'/drawings/VXH8940_DRAW_2_6.png',
        note = N'E/F/G: drawn form dimensions',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VXH8940'
      AND process_code = N'DRAW 2/6';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VXH8940',
            N'DRAW 2/6',
            N'VXH8940-DR26',
            N'DRAW 2/6 PROCESS DRAWING',
            N'/drawings/VXH8940_DRAW_2_6.png',
            N'E/F/G: drawn form dimensions'
        );
    END
END
GO

