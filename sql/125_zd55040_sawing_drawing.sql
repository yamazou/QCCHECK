USE [QCCHECK];
GO

/* ZD55040 SAWING: set drawing file (place PNG at server/public/drawings/ZD55040_SAWING.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZD55040-SW',
        drawing_name = N'SAWING PROCESS DRAWING',
        file_url = N'/drawings/ZD55040_SAWING.png',
        note = N'E/F/G: length, width, thickness',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZD55040'
      AND process_code = N'SAWING';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZD55040',
            N'SAWING',
            N'ZD55040-SW',
            N'SAWING PROCESS DRAWING',
            N'/drawings/ZD55040_SAWING.png',
            N'E/F/G: length, width, thickness'
        );
    END
END
GO

