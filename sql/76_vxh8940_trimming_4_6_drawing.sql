USE [QCCHECK];
GO

/* VXH8940 TRIMMING 4/6: drawing file at server/public/drawings/VXH8940_TRIMMING_4_6.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VXH8940-TR46',
        drawing_name = N'TRIMMING 4/6 PROCESS DRAWING',
        file_url = N'/drawings/VXH8940_TRIMMING_4_6.png',
        note = N'E/F/G: trimmed edge and profile',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VXH8940'
      AND process_code = N'TRIMMING 4/6';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VXH8940',
            N'TRIMMING 4/6',
            N'VXH8940-TR46',
            N'TRIMMING 4/6 PROCESS DRAWING',
            N'/drawings/VXH8940_TRIMMING_4_6.png',
            N'E/F/G: trimmed edge and profile'
        );
    END
END
GO

