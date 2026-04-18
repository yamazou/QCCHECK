USE [QCCHECK];
GO

/* ZD21920 PUNCHING 1/2: set drawing file (place PNG at server/public/drawings/ZD21920_PUNCHING_1_2.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZD21920-PN12',
        drawing_name = N'PUNCHING 1/2 PROCESS DRAWING',
        file_url = N'/drawings/ZD21920_PUNCHING_1_2.png',
        note = N'E: punching hole locations',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZD21920'
      AND process_code = N'PUNCHING 1/2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZD21920',
            N'PUNCHING 1/2',
            N'ZD21920-PN12',
            N'PUNCHING 1/2 PROCESS DRAWING',
            N'/drawings/ZD21920_PUNCHING_1_2.png',
            N'E: punching hole locations'
        );
    END
END
GO

