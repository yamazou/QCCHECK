USE [QCCHECK];
GO

/* ZZ05080 BUFFING NON WOVEN: set drawing file (place PNG at server/public/drawings/ZZ05080_BUFFING_NON_WOVEN.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZZ05080-BFNW',
        drawing_name = N'BUFFING NON WOVEN PROCESS DRAWING',
        file_url = N'/drawings/ZZ05080_BUFFING_NON_WOVEN.png',
        note = N'E: buffing non-woven area',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZZ05080'
      AND process_code = N'BUFFING NON WOVEN';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZZ05080',
            N'BUFFING NON WOVEN',
            N'ZZ05080-BFNW',
            N'BUFFING NON WOVEN PROCESS DRAWING',
            N'/drawings/ZZ05080_BUFFING_NON_WOVEN.png',
            N'E: buffing non-woven area'
        );
    END
END
GO

