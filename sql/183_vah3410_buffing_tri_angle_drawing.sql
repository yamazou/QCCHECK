USE [QCCHECK];
GO

/* VAH3410 BUFFING TRI ANGLE: set drawing file (PNG at server/public/drawings/VAH3410_BUFFING_TRI_ANGLE.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VAH3410-BFTRI',
        drawing_name = N'BUFFING TRI ANGLE PROCESS DRAWING',
        file_url = N'/drawings/VAH3410_BUFFING_TRI_ANGLE.png',
        note = N'E: buffing area / profile',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VAH3410'
      AND process_code = N'BUFFING TRI ANGLE';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VAH3410',
            N'BUFFING TRI ANGLE',
            N'VAH3410-BFTRI',
            N'BUFFING TRI ANGLE PROCESS DRAWING',
            N'/drawings/VAH3410_BUFFING_TRI_ANGLE.png',
            N'E: buffing area / profile'
        );
    END
END
GO
