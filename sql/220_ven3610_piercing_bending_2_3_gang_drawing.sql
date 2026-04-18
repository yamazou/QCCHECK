USE [QCCHECK];
GO

/* VEN3610 PIERCING & BENDING 2/3 (GANG): PNG at server/public/drawings/VEN3610_PIERCING_BENDING_2_3_GANG.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VEN3610-PB23G',
        drawing_name = N'PIERCING & BENDING 2/3 (GANG) PROCESS DRAWING',
        file_url = N'/drawings/VEN3610_PIERCING_BENDING_2_3_GANG.png',
        note = N'E/F/G: slots, bend tabs, extruded hole',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VEN3610'
      AND process_code = N'PIERCING & BENDING 2/3 (GANG)';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VEN3610',
            N'PIERCING & BENDING 2/3 (GANG)',
            N'VEN3610-PB23G',
            N'PIERCING & BENDING 2/3 (GANG) PROCESS DRAWING',
            N'/drawings/VEN3610_PIERCING_BENDING_2_3_GANG.png',
            N'E/F/G: slots, bend tabs, extruded hole'
        );
    END
END
GO
