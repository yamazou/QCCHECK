USE [QCCHECK];
GO

/* VEN3620 PIERCING & BENDING 2/2: PNG at server/public/drawings/VEN3620_PIERCING_BENDING_2_2.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VEN3620-PB22',
        drawing_name = N'PIERCING & BENDING 2/2 PROCESS DRAWING',
        file_url = N'/drawings/VEN3620_PIERCING_BENDING_2_2.png',
        note = N'E/F/G: pierced holes, form features, bend / vertical face',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VEN3620'
      AND process_code = N'PIERCING & BENDING 2/2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VEN3620',
            N'PIERCING & BENDING 2/2',
            N'VEN3620-PB22',
            N'PIERCING & BENDING 2/2 PROCESS DRAWING',
            N'/drawings/VEN3620_PIERCING_BENDING_2_2.png',
            N'E/F/G: pierced holes, form features, bend / vertical face'
        );
    END
END
GO
