USE [QCCHECK];
GO

/* VDY1530 BENDING 2/2 (GANG): set drawing file (PNG at server/public/drawings/VDY1530_BENDING_2_2_GANG.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VDY1530-BD22G',
        drawing_name = N'BENDING 2/2 (GANG) PROCESS DRAWING',
        file_url = N'/drawings/VDY1530_BENDING_2_2_GANG.png',
        note = N'E: bend areas',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VDY1530'
      AND process_code = N'BENDING 2/2 (GANG)';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VDY1530',
            N'BENDING 2/2 (GANG)',
            N'VDY1530-BD22G',
            N'BENDING 2/2 (GANG) PROCESS DRAWING',
            N'/drawings/VDY1530_BENDING_2_2_GANG.png',
            N'E: bend areas'
        );
    END
END
GO
