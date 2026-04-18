USE [QCCHECK];
GO

/* VEN3610 TAPPING M3: set drawing file (PNG at server/public/drawings/VEN3610_TAPPING_M3.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VEN3610-TPM3',
        drawing_name = N'TAPPING M3 PROCESS DRAWING',
        file_url = N'/drawings/VEN3610_TAPPING_M3.png',
        note = N'E: tapping hole locations',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VEN3610'
      AND process_code = N'TAPPING M3';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VEN3610',
            N'TAPPING M3',
            N'VEN3610-TPM3',
            N'TAPPING M3 PROCESS DRAWING',
            N'/drawings/VEN3610_TAPPING_M3.png',
            N'E: tapping hole locations'
        );
    END
END
GO
