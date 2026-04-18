USE [QCCHECK];
GO

/* ZG98500 PUNCHING CUT BLANK 1/1: set drawing file (place PNG at server/public/drawings/ZG98500_PUNCHING_CUT_BLANK_1_1.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZG98500-PC11',
        drawing_name = N'PUNCHING CUT BLANK 1/1 PROCESS DRAWING',
        file_url = N'/drawings/ZG98500_PUNCHING_CUT_BLANK_1_1.png',
        note = N'E: hole/slot punching locations',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZG98500'
      AND process_code = N'PUNCHING CUT BLANK 1/1';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZG98500',
            N'PUNCHING CUT BLANK 1/1',
            N'ZG98500-PC11',
            N'PUNCHING CUT BLANK 1/1 PROCESS DRAWING',
            N'/drawings/ZG98500_PUNCHING_CUT_BLANK_1_1.png',
            N'E: hole/slot punching locations'
        );
    END
END
GO

