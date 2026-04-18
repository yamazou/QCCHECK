USE [QCCHECK];
GO

/* ZY71390 PUNCHING CUT BLANK 1/4: set drawing file (place PNG at server/public/drawings/ZY71390_PUNCHING_CUT_BLANK_1_4.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZY71390-PC14',
        drawing_name = N'PUNCHING CUT BLANK 1/4 PROCESS DRAWING',
        file_url = N'/drawings/ZY71390_PUNCHING_CUT_BLANK_1_4.png',
        note = N'E/F: blank shape / punching',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZY71390'
      AND process_code = N'PUNCHING CUT BLANK 1/4';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZY71390',
            N'PUNCHING CUT BLANK 1/4',
            N'ZY71390-PC14',
            N'PUNCHING CUT BLANK 1/4 PROCESS DRAWING',
            N'/drawings/ZY71390_PUNCHING_CUT_BLANK_1_4.png',
            N'E/F: blank shape / punching'
        );
    END
END
GO

