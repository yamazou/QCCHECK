USE [QCCHECK];
GO

/* WK65300 BUFFING TRI ANGLE: set drawing file (place PNG at server/public/drawings/WK65300_BUFFING_TRI_ANGLE.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'WK65300-BFTRI',
        drawing_name = N'BUFFING TRI ANGLE PROCESS DRAWING',
        file_url = N'/drawings/WK65300_BUFFING_TRI_ANGLE.png',
        note = N'E: buffing area / profile',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'WK65300'
      AND process_code = N'BUFFING TRI ANGLE';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'WK65300',
            N'BUFFING TRI ANGLE',
            N'WK65300-BFTRI',
            N'BUFFING TRI ANGLE PROCESS DRAWING',
            N'/drawings/WK65300_BUFFING_TRI_ANGLE.png',
            N'E: buffing area / profile'
        );
    END
END
GO

