USE [QCCHECK];
GO

/* ZW45530 PUNCHING CUT BLANK 1/2: set drawing file (place PNG at server/public/drawings/ZW45530_PUNCHING_CUT_BLANK_1_2.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZW45530-PC12',
        drawing_name = N'PUNCHING CUT BLANK 1/2 PROCESS DRAWING',
        file_url = N'/drawings/ZW45530_PUNCHING_CUT_BLANK_1_2.png',
        note = N'E/F: hole positions and special slot direction',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZW45530'
      AND process_code = N'PUNCHING CUT BLANK 1/2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZW45530',
            N'PUNCHING CUT BLANK 1/2',
            N'ZW45530-PC12',
            N'PUNCHING CUT BLANK 1/2 PROCESS DRAWING',
            N'/drawings/ZW45530_PUNCHING_CUT_BLANK_1_2.png',
            N'E/F: hole positions and special slot direction'
        );
    END
END
GO

