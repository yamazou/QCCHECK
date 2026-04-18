USE [QCCHECK];
GO

/* WK65370 PUNCHING CUT BLANK 1/4: drawing file at server/public/drawings/WK65370_PUNCHING_CUT_BLANK_1_4.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'WK65370-PC14',
        drawing_name = N'PUNCHING CUT BLANK 1/4 PROCESS DRAWING',
        file_url = N'/drawings/WK65370_PUNCHING_CUT_BLANK_1_4.png',
        note = N'E/F: blank shape / punching',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'WK65370'
      AND process_code = N'PUNCHING CUT BLANK 1/4';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'WK65370',
            N'PUNCHING CUT BLANK 1/4',
            N'WK65370-PC14',
            N'PUNCHING CUT BLANK 1/4 PROCESS DRAWING',
            N'/drawings/WK65370_PUNCHING_CUT_BLANK_1_4.png',
            N'E/F: blank shape / punching'
        );
    END
END
GO

