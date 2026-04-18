USE [QCCHECK];
GO

/* ZT 79610 (DB part_no ZT79610) BENDING 2/2 — PNG at server/public/drawings/ZT79610_BENDING_2_2.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZT79610-BD22',
        drawing_name = N'BENDING 2/2 PROCESS DRAWING',
        file_url = N'/drawings/ZT79610_BENDING_2_2.png',
        note = N'E: 90° up-bent tabs (edge + centre lance)',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZT79610'
      AND process_code = N'BENDING 2/2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZT79610',
            N'BENDING 2/2',
            N'ZT79610-BD22',
            N'BENDING 2/2 PROCESS DRAWING',
            N'/drawings/ZT79610_BENDING_2_2.png',
            N'E: 90° up-bent tabs (edge + centre lance)'
        );
    END
END
GO
