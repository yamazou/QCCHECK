USE [QCCHECK];
GO

/* ZT 79610 (DB part_no ZT79610) BUFFING TRI ANGLE — PNG at server/public/drawings/ZT79610_BUFFING_TRI_ANGLE.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZT79610-BFTRI',
        drawing_name = N'BUFFING TRI ANGLE PROCESS DRAWING',
        file_url = N'/drawings/ZT79610_BUFFING_TRI_ANGLE.png',
        note = N'E: tri-angle buff land / edge inside top recess',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZT79610'
      AND process_code = N'BUFFING TRI ANGLE';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZT79610',
            N'BUFFING TRI ANGLE',
            N'ZT79610-BFTRI',
            N'BUFFING TRI ANGLE PROCESS DRAWING',
            N'/drawings/ZT79610_BUFFING_TRI_ANGLE.png',
            N'E: tri-angle buff land / edge inside top recess'
        );
    END
END
GO
