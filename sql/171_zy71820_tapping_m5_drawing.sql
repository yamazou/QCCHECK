USE [QCCHECK];
GO

/* ZY71820 TAPPING M5: set drawing file (place PNG at server/public/drawings/ZY71820_TAPPING_M5.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZY71820-TPM5',
        drawing_name = N'TAPPING M5 PROCESS DRAWING',
        file_url = N'/drawings/ZY71820_TAPPING_M5.png',
        note = N'E: tapping location and thread detail',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZY71820'
      AND process_code = N'TAPPING M5';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZY71820',
            N'TAPPING M5',
            N'ZY71820-TPM5',
            N'TAPPING M5 PROCESS DRAWING',
            N'/drawings/ZY71820_TAPPING_M5.png',
            N'E: tapping location and thread detail'
        );
    END
END
GO

