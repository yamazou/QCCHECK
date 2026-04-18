USE [QCCHECK];
GO

/* VGC 0160 (DB part_no VGC0160) TAPPING M4: PNG at server/public/drawings/VGC0160_TAPPING_M4.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VGC0160-TPM4',
        drawing_name = N'TAPPING M4 PROCESS DRAWING',
        file_url = N'/drawings/VGC0160_TAPPING_M4.png',
        note = N'E: M4 tapping hole locations',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VGC0160'
      AND process_code = N'TAPPING M4';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VGC0160',
            N'TAPPING M4',
            N'VGC0160-TPM4',
            N'TAPPING M4 PROCESS DRAWING',
            N'/drawings/VGC0160_TAPPING_M4.png',
            N'E: M4 tapping hole locations'
        );
    END
END
GO
