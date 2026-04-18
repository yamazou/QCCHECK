USE [QCCHECK];
GO

/* ZV 31640 (DB part_no ZV31640) CHAMFERING HOLE — PNG at server/public/drawings/ZV31640_CHAMFERING_HOLE.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZV31640-CH',
        drawing_name = N'CHAMFERING HOLE PROCESS DRAWING',
        file_url = N'/drawings/ZV31640_CHAMFERING_HOLE.png',
        note = N'E: chamfer holes on left tab pair',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZV31640'
      AND process_code = N'CHAMFERING HOLE';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZV31640',
            N'CHAMFERING HOLE',
            N'ZV31640-CH',
            N'CHAMFERING HOLE PROCESS DRAWING',
            N'/drawings/ZV31640_CHAMFERING_HOLE.png',
            N'E: chamfer holes on left tab pair'
        );
    END
END
GO
