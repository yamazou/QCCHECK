USE [QCCHECK];
GO

/* VP 00660 (DB part_no VP00660) PUNCHING CUT BLANK 1/2 — PNG at server/public/drawings/VP00660_PUNCHING_CUT_BLANK_1_2.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VP00660-PC12',
        drawing_name = N'PUNCHING CUT BLANK 1/2 PROCESS DRAWING',
        file_url = N'/drawings/VP00660_PUNCHING_CUT_BLANK_1_2.png',
        note = N'E: blank outline / punch reference',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VP00660'
      AND process_code = N'PUNCHING CUT BLANK 1/2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VP00660',
            N'PUNCHING CUT BLANK 1/2',
            N'VP00660-PC12',
            N'PUNCHING CUT BLANK 1/2 PROCESS DRAWING',
            N'/drawings/VP00660_PUNCHING_CUT_BLANK_1_2.png',
            N'E: blank outline / punch reference'
        );
    END
END
GO
