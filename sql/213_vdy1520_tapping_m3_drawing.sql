USE [QCCHECK];
GO

/* VDY1520 TAPPING M3: set drawing file (PNG at server/public/drawings/VDY1520_TAPPING_M3.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VDY1520-TPM3',
        drawing_name = N'TAPPING M3 PROCESS DRAWING',
        file_url = N'/drawings/VDY1520_TAPPING_M3.png',
        note = N'E: tapping hole locations',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VDY1520'
      AND process_code = N'TAPPING M3';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VDY1520',
            N'TAPPING M3',
            N'VDY1520-TPM3',
            N'TAPPING M3 PROCESS DRAWING',
            N'/drawings/VDY1520_TAPPING_M3.png',
            N'E: tapping hole locations'
        );
    END
END
GO
