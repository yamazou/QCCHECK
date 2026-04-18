USE [QCCHECK];
GO

/* WJ 17290 (DB part_no WJ17290) PUNCHING CUT BLANK 1/2 — PNG at server/public/drawings/WJ17290_PUNCHING_CUT_BLANK_1_2.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'WJ17290-PC12',
        drawing_name = N'PUNCHING CUT BLANK 1/2 PROCESS DRAWING',
        file_url = N'/drawings/WJ17290_PUNCHING_CUT_BLANK_1_2.png',
        note = N'E: punched hole groups; edge notches per drawing',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'WJ17290'
      AND process_code = N'PUNCHING CUT BLANK 1/2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'WJ17290',
            N'PUNCHING CUT BLANK 1/2',
            N'WJ17290-PC12',
            N'PUNCHING CUT BLANK 1/2 PROCESS DRAWING',
            N'/drawings/WJ17290_PUNCHING_CUT_BLANK_1_2.png',
            N'E: punched hole groups; edge notches per drawing'
        );
    END
END
GO
