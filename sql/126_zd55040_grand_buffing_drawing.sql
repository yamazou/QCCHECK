USE [QCCHECK];
GO

/* ZD55040 GRAND BUFFING: set drawing file (place PNG at server/public/drawings/ZD55040_GRAND_BUFFING.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZD55040-GB',
        drawing_name = N'GRAND BUFFING PROCESS DRAWING',
        file_url = N'/drawings/ZD55040_GRAND_BUFFING.png',
        note = N'E: edge/side buffing finish',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZD55040'
      AND process_code = N'GRAND BUFFING';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZD55040',
            N'GRAND BUFFING',
            N'ZD55040-GB',
            N'GRAND BUFFING PROCESS DRAWING',
            N'/drawings/ZD55040_GRAND_BUFFING.png',
            N'E: edge/side buffing finish'
        );
    END
END
GO

