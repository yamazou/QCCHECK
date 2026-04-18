USE [QCCHECK];
GO

/* VFF3460 BENDING 3/3: drawing at server/public/drawings/VFF3460_BENDING_3_3.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VFF3460-BD3',
        drawing_name = N'BENDING 3/3 PROCESS DRAWING',
        file_url = N'/drawings/VFF3460_BENDING_3_3.png',
        note = N'E/F/G: final bend areas',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VFF3460'
      AND process_code = N'BENDING 3/3';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VFF3460',
            N'BENDING 3/3',
            N'VFF3460-BD3',
            N'BENDING 3/3 PROCESS DRAWING',
            N'/drawings/VFF3460_BENDING_3_3.png',
            N'E/F/G: final bend areas'
        );
    END
END
GO

