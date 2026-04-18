USE [QCCHECK];
GO

/* WK 78660 (DB part_no WK78660) DUMMY — PNG at server/public/drawings/WK78660_DUMMY.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'WK78660-DM',
        drawing_name = N'DUMMY PROCESS DRAWING',
        file_url = N'/drawings/WK78660_DUMMY.png',
        note = N'Plan/isometric views; tab E callout',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'WK78660'
      AND process_code = N'DUMMY';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'WK78660',
            N'DUMMY',
            N'WK78660-DM',
            N'DUMMY PROCESS DRAWING',
            N'/drawings/WK78660_DUMMY.png',
            N'Plan/isometric views; tab E callout'
        );
    END
END
GO
