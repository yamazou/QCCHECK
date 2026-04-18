USE [QCCHECK];
GO

/* VGC 0160 (DB part_no VGC0160) PUNCHING CUT BLANK 1/2 — PNG at server/public/drawings/VGC0160_PUNCHING_CUT_BLANK_1_2.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VGC0160-PC12',
        drawing_name = N'PUNCHING CUT BLANK 1/2 PROCESS DRAWING',
        file_url = N'/drawings/VGC0160_PUNCHING_CUT_BLANK_1_2.png',
        note = N'E/F/G: hole positions, boss, tab features',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VGC0160'
      AND process_code = N'PUNCHING CUT BLANK 1/2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VGC0160',
            N'PUNCHING CUT BLANK 1/2',
            N'VGC0160-PC12',
            N'PUNCHING CUT BLANK 1/2 PROCESS DRAWING',
            N'/drawings/VGC0160_PUNCHING_CUT_BLANK_1_2.png',
            N'E/F/G: hole positions, boss, tab features'
        );
    END
END
GO
