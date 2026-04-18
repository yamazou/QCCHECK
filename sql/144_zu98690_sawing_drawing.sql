USE [QCCHECK];
GO

/* ZU98690 SAWING: set drawing file (place PNG at server/public/drawings/ZU98690_SAWING.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZU98690-SW',
        drawing_name = N'SAWING PROCESS DRAWING',
        file_url = N'/drawings/ZU98690_SAWING.png',
        note = N'E/F/G: length, width, thickness',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZU98690'
      AND process_code = N'SAWING';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZU98690',
            N'SAWING',
            N'ZU98690-SW',
            N'SAWING PROCESS DRAWING',
            N'/drawings/ZU98690_SAWING.png',
            N'E/F/G: length, width, thickness'
        );
    END
END
GO

