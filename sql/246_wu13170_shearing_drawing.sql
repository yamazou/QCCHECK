USE [QCCHECK];
GO

/* WU 13170 (DB part_no WU13170) SAWING: E/F/G cut length, profile width, profile height — PNG at server/public/drawings/WU13170_SAWING.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'WU13170-SW',
        drawing_name = N'SAWING PROCESS DRAWING',
        file_url = N'/drawings/WU13170_SAWING.png',
        note = N'E/F/G: cut length, profile width, profile height',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'WU13170'
      AND process_code = N'SAWING';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'WU13170',
            N'SAWING',
            N'WU13170-SW',
            N'SAWING PROCESS DRAWING',
            N'/drawings/WU13170_SAWING.png',
            N'E/F/G: cut length, profile width, profile height'
        );
    END
END
GO
