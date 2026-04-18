USE [QCCHECK];
GO

/* ZW45530 TAPPING M4 ( 2 HOLE ): set drawing file (place PNG at server/public/drawings/ZW45530_TAPPING_M4_2_HOLE.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZW45530-TPM42',
        drawing_name = N'TAPPING M4 ( 2 HOLE ) PROCESS DRAWING',
        file_url = N'/drawings/ZW45530_TAPPING_M4_2_HOLE.png',
        note = N'E/F: tapping locations and thread detail',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZW45530'
      AND process_code = N'TAPPING M4 ( 2 HOLE )';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZW45530',
            N'TAPPING M4 ( 2 HOLE )',
            N'ZW45530-TPM42',
            N'TAPPING M4 ( 2 HOLE ) PROCESS DRAWING',
            N'/drawings/ZW45530_TAPPING_M4_2_HOLE.png',
            N'E/F: tapping locations and thread detail'
        );
    END
END
GO

