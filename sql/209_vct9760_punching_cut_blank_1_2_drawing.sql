USE [QCCHECK];
GO

/* VCT9760 PUNCHING CUT BLANK 1/2: set drawing file (PNG at server/public/drawings/VCT9760_PUNCHING_CUT_BLANK_1_2.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VCT9760-PC12',
        drawing_name = N'PUNCHING CUT BLANK 1/2 PROCESS DRAWING',
        file_url = N'/drawings/VCT9760_PUNCHING_CUT_BLANK_1_2.png',
        note = N'E: six punch hole locations',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VCT9760'
      AND process_code = N'PUNCHING CUT BLANK 1/2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VCT9760',
            N'PUNCHING CUT BLANK 1/2',
            N'VCT9760-PC12',
            N'PUNCHING CUT BLANK 1/2 PROCESS DRAWING',
            N'/drawings/VCT9760_PUNCHING_CUT_BLANK_1_2.png',
            N'E: six punch hole locations'
        );
    END
END
GO
