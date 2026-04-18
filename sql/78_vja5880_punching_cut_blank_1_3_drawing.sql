USE [QCCHECK];
GO

/* VJA5880 PUNCHING CUT BLANK 1/3: drawing file at server/public/drawings/VJA5880_PUNCHING_CUT_BLANK_1_3.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VJA5880-PC13',
        drawing_name = N'PUNCHING CUT BLANK 1/3 PROCESS DRAWING',
        file_url = N'/drawings/VJA5880_PUNCHING_CUT_BLANK_1_3.png',
        note = N'Blank shape / punching',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VJA5880'
      AND process_code = N'PUNCHING CUT BLANK 1/3';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VJA5880',
            N'PUNCHING CUT BLANK 1/3',
            N'VJA5880-PC13',
            N'PUNCHING CUT BLANK 1/3 PROCESS DRAWING',
            N'/drawings/VJA5880_PUNCHING_CUT_BLANK_1_3.png',
            N'Blank shape / punching'
        );
    END
END
GO

