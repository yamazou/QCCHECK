USE [QCCHECK];
GO

/* VDK0970 BENDING 3/3: drawing at server/public/drawings/VDK0970_BENDING_3_3.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VDK0970-BD3',
        drawing_name = N'BENDING 3/3 PROCESS DRAWING',
        file_url = N'/drawings/VDK0970_BENDING_3_3.png',
        note = N'E: Final bend areas (6 locations)',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VDK0970'
      AND process_code = N'BENDING 3/3';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VDK0970',
            N'BENDING 3/3',
            N'VDK0970-BD3',
            N'BENDING 3/3 PROCESS DRAWING',
            N'/drawings/VDK0970_BENDING_3_3.png',
            N'E: Final bend areas (6 locations)'
        );
    END
END
GO
