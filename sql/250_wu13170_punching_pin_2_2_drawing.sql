USE [QCCHECK];
GO

/* WU 13170 (DB part_no WU13170) PUNCHING PIN 2/2 — PNG at server/public/drawings/WU13170_PUNCHING_PIN_2_2.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'WU13170-PP22',
        drawing_name = N'PUNCHING PIN 2/2 PROCESS DRAWING',
        file_url = N'/drawings/WU13170_PUNCHING_PIN_2_2.png',
        note = N'E: pin positions / press-fit pins',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'WU13170'
      AND process_code = N'PUNCHING PIN 2/2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'WU13170',
            N'PUNCHING PIN 2/2',
            N'WU13170-PP22',
            N'PUNCHING PIN 2/2 PROCESS DRAWING',
            N'/drawings/WU13170_PUNCHING_PIN_2_2.png',
            N'E: pin positions / press-fit pins'
        );
    END
END
GO
