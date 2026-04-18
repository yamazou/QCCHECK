USE [QCCHECK];
GO

/* ZT 79640 (DB part_no ZT79640) DUMMY — PNG at server/public/drawings/ZT79640_DUMMY.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZT79640-DM',
        drawing_name = N'DUMMY PROCESS DRAWING',
        file_url = N'/drawings/ZT79640_DUMMY.png',
        note = N'Isometric/plan/front views; callout E at tab-to-base inner bend',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZT79640'
      AND process_code = N'DUMMY';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZT79640',
            N'DUMMY',
            N'ZT79640-DM',
            N'DUMMY PROCESS DRAWING',
            N'/drawings/ZT79640_DUMMY.png',
            N'Isometric/plan/front views; callout E at tab-to-base inner bend'
        );
    END
END
GO
