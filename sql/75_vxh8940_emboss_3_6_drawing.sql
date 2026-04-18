USE [QCCHECK];
GO

/* VXH8940 EMBOSS 3/6: drawing file at server/public/drawings/VXH8940_EMBOSS_3_6.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VXH8940-EM36',
        drawing_name = N'EMBOSS 3/6 PROCESS DRAWING',
        file_url = N'/drawings/VXH8940_EMBOSS_3_6.png',
        note = N'E/F/G: emboss height and outline',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VXH8940'
      AND process_code = N'EMBOSS 3/6';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VXH8940',
            N'EMBOSS 3/6',
            N'VXH8940-EM36',
            N'EMBOSS 3/6 PROCESS DRAWING',
            N'/drawings/VXH8940_EMBOSS_3_6.png',
            N'E/F/G: emboss height and outline'
        );
    END
END
GO

