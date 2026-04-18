USE [QCCHECK];
GO

/* ZU98690 CHAMFERING: set drawing file (place PNG at server/public/drawings/ZU98690_CHAMFERING.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZU98690-CH',
        drawing_name = N'CHAMFERING PROCESS DRAWING',
        file_url = N'/drawings/ZU98690_CHAMFERING.png',
        note = N'E: chamfer specification (front & back)',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZU98690'
      AND process_code = N'CHAMFERING';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZU98690',
            N'CHAMFERING',
            N'ZU98690-CH',
            N'CHAMFERING PROCESS DRAWING',
            N'/drawings/ZU98690_CHAMFERING.png',
            N'E: chamfer specification (front & back)'
        );
    END
END
GO

