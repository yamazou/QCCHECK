USE [QCCHECK];
GO

/* VDY1520 PUNCHING CUT BLANK (no step suffix): PNG at server/public/drawings/VDY1520_PUNCHING_CUT_BLANK.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VDY1520-PC',
        drawing_name = N'PUNCHING CUT BLANK PROCESS DRAWING',
        file_url = N'/drawings/VDY1520_PUNCHING_CUT_BLANK.png',
        note = N'E/F: strip and blank hole locations',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VDY1520'
      AND process_code = N'PUNCHING CUT BLANK';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VDY1520',
            N'PUNCHING CUT BLANK',
            N'VDY1520-PC',
            N'PUNCHING CUT BLANK PROCESS DRAWING',
            N'/drawings/VDY1520_PUNCHING_CUT_BLANK.png',
            N'E/F: strip and blank hole locations'
        );
    END
END
GO
