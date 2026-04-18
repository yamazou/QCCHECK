USE [QCCHECK];
GO

/* WU 13170 (DB part_no WU13170) PUNCHING 1/2 — PNG at server/public/drawings/WU13170_PUNCHING_1_2.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'WU13170-P12',
        drawing_name = N'PUNCHING 1/2 PROCESS DRAWING',
        file_url = N'/drawings/WU13170_PUNCHING_1_2.png',
        note = N'E: punched hole on base (not PUNCHING CUT BLANK 1/2)',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'WU13170'
      AND process_code = N'PUNCHING 1/2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'WU13170',
            N'PUNCHING 1/2',
            N'WU13170-P12',
            N'PUNCHING 1/2 PROCESS DRAWING',
            N'/drawings/WU13170_PUNCHING_1_2.png',
            N'E: punched hole on base (not PUNCHING CUT BLANK 1/2)'
        );
    END
END
GO
