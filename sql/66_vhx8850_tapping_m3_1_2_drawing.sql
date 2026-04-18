USE [QCCHECK];
GO

/* VHX8850 TAPPING M3 1/2: set drawing file (place PNG at server/public/drawings/VHX8850_TAPPING_M3_1_2.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VHX8850-TPM3H',
        drawing_name = N'TAPPING M3 1/2 PROCESS DRAWING',
        file_url = N'/drawings/VHX8850_TAPPING_M3_1_2.png',
        note = N'E: tapping locations (half positions)',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VHX8850'
      AND process_code = N'TAPPING M3 1/2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VHX8850',
            N'TAPPING M3 1/2',
            N'VHX8850-TPM3H',
            N'TAPPING M3 1/2 PROCESS DRAWING',
            N'/drawings/VHX8850_TAPPING_M3_1_2.png',
            N'E: tapping locations (half positions)'
        );
    END
END
GO

