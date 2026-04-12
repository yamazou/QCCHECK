USE [QCCHECK];
GO

/* VDK0970 BENDING 2/3: drawing at server/public/drawings/VDK0970_BENDING_2_3.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VDK0970-BD2',
        drawing_name = N'BENDING 2/3 PROCESS DRAWING',
        file_url = N'/drawings/VDK0970_BENDING_2_3.png',
        note = N'E: Bend areas (tabs, 90 deg bend)',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VDK0970'
      AND process_code = N'BENDING 2/3';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VDK0970',
            N'BENDING 2/3',
            N'VDK0970-BD2',
            N'BENDING 2/3 PROCESS DRAWING',
            N'/drawings/VDK0970_BENDING_2_3.png',
            N'E: Bend areas (tabs, 90 deg bend)'
        );
    END
END
GO
