USE [QCCHECK];
GO

/* VEN3610 BENDING 3/3 (GANG): set drawing file (PNG at server/public/drawings/VEN3610_BENDING_3_3_GANG.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VEN3610-BD33G',
        drawing_name = N'BENDING 3/3 (GANG) PROCESS DRAWING',
        file_url = N'/drawings/VEN3610_BENDING_3_3_GANG.png',
        note = N'E: bend areas',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VEN3610'
      AND process_code = N'BENDING 3/3 (GANG)';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VEN3610',
            N'BENDING 3/3 (GANG)',
            N'VEN3610-BD33G',
            N'BENDING 3/3 (GANG) PROCESS DRAWING',
            N'/drawings/VEN3610_BENDING_3_3_GANG.png',
            N'E: bend areas'
        );
    END
END
GO
