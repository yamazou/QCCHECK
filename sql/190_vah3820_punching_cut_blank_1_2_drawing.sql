USE [QCCHECK];
GO

/* VAH3820 PUNCHING CUT BLANK 1/2: set drawing file (PNG at server/public/drawings/VAH3820_PUNCHING_CUT_BLANK_1_2.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VAH3820-PC12',
        drawing_name = N'PUNCHING CUT BLANK 1/2 PROCESS DRAWING',
        file_url = N'/drawings/VAH3820_PUNCHING_CUT_BLANK_1_2.png',
        note = N'E: punched holes, slots, and blank profile',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VAH3820'
      AND process_code = N'PUNCHING CUT BLANK 1/2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VAH3820',
            N'PUNCHING CUT BLANK 1/2',
            N'VAH3820-PC12',
            N'PUNCHING CUT BLANK 1/2 PROCESS DRAWING',
            N'/drawings/VAH3820_PUNCHING_CUT_BLANK_1_2.png',
            N'E: punched holes, slots, and blank profile'
        );
    END
END
GO
