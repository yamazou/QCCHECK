USE [QCCHECK];
GO

/* ZN 31480 (DB part_no ZN31480) BUFFING NON WOVEN — PNG at server/public/drawings/ZN31480_BUFFING_NON_WOVEN.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZN31480-BFNW',
        drawing_name = N'BUFFING NON WOVEN PROCESS DRAWING',
        file_url = N'/drawings/ZN31480_BUFFING_NON_WOVEN.png',
        note = N'E: outer perimeter / buff path (offset chain line)',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZN31480'
      AND process_code = N'BUFFING NON WOVEN';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZN31480',
            N'BUFFING NON WOVEN',
            N'ZN31480-BFNW',
            N'BUFFING NON WOVEN PROCESS DRAWING',
            N'/drawings/ZN31480_BUFFING_NON_WOVEN.png',
            N'E: outer perimeter / buff path (offset chain line)'
        );
    END
END
GO
