USE [QCCHECK];
GO

/* ZG 73380 (DB part_no ZG73380) BENDING 2/2 (GANG) — PNG at server/public/drawings/ZG73380_BENDING_2_2_GANG.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZG73380-BD22G',
        drawing_name = N'BENDING 2/2 (GANG) PROCESS DRAWING',
        file_url = N'/drawings/ZG73380_BENDING_2_2_GANG.png',
        note = N'E/F/G: hole & extrusion, top plate extents, edge bend / flange',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZG73380'
      AND process_code = N'BENDING 2/2 (GANG)';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZG73380',
            N'BENDING 2/2 (GANG)',
            N'ZG73380-BD22G',
            N'BENDING 2/2 (GANG) PROCESS DRAWING',
            N'/drawings/ZG73380_BENDING_2_2_GANG.png',
            N'E/F/G: hole & extrusion, top plate extents, edge bend / flange'
        );
    END
END
GO
