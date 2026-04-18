USE [QCCHECK];
GO

/* ZP 70420 (DB part_no ZP70420) PUNCHING CUT BLANK 1/2 — PNG at server/public/drawings/ZP70420_PUNCHING_CUT_BLANK_1_2.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZP70420-PC12',
        drawing_name = N'PUNCHING CUT BLANK 1/2 PROCESS DRAWING',
        file_url = N'/drawings/ZP70420_PUNCHING_CUT_BLANK_1_2.png',
        note = N'E: four pierced holes; notched blank from strip',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZP70420'
      AND process_code = N'PUNCHING CUT BLANK 1/2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZP70420',
            N'PUNCHING CUT BLANK 1/2',
            N'ZP70420-PC12',
            N'PUNCHING CUT BLANK 1/2 PROCESS DRAWING',
            N'/drawings/ZP70420_PUNCHING_CUT_BLANK_1_2.png',
            N'E: four pierced holes; notched blank from strip'
        );
    END
END
GO
