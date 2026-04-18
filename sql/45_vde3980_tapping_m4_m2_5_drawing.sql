USE [QCCHECK];
GO

/* VDE3980 TAPPING M4 & M2,5: set drawing file (place PNG at server/public/drawings/VDE3980_TAPPING_M4_M2_5.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VDE3980-TPM4M25',
        drawing_name = N'TAPPING M4 & M2,5 PROCESS DRAWING',
        file_url = N'/drawings/VDE3980_TAPPING_M4_M2_5.png',
        note = N'E: tapping hole locations (M4 & M2.5)',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VDE3980'
      AND process_code = N'TAPPING M4 & M2,5';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VDE3980',
            N'TAPPING M4 & M2,5',
            N'VDE3980-TPM4M25',
            N'TAPPING M4 & M2,5 PROCESS DRAWING',
            N'/drawings/VDE3980_TAPPING_M4_M2_5.png',
            N'E: tapping hole locations (M4 & M2.5)'
        );
    END
END
GO

