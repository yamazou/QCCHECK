USE [QCCHECK];
GO

/* ZF 600700 (DB part_no ZF600700) PUNCH PIN — PNG at server/public/drawings/ZF600700_PUNCH_PIN.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZF600700-PPN',
        drawing_name = N'PUNCH PIN PROCESS DRAWING',
        file_url = N'/drawings/ZF600700_PUNCH_PIN.png',
        note = N'E: center hole; F: press-fit pins',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZF600700'
      AND process_code = N'PUNCH PIN';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZF600700',
            N'PUNCH PIN',
            N'ZF600700-PPN',
            N'PUNCH PIN PROCESS DRAWING',
            N'/drawings/ZF600700_PUNCH_PIN.png',
            N'E: center hole; F: press-fit pins'
        );
    END
END
GO
