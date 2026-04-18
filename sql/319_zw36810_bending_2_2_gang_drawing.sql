USE [QCCHECK];
GO

/* ZW 36810 (DB part_no ZW36810) BENDING 2/2 (GANG) — PNG at server/public/drawings/ZW36810_BENDING_2_2_GANG.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZW36810-BD22G',
        drawing_name = N'BENDING 2/2 (GANG) PROCESS DRAWING',
        file_url = N'/drawings/ZW36810_BENDING_2_2_GANG.png',
        note = N'E: bend profile and formed flange',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZW36810'
      AND process_code = N'BENDING 2/2 (GANG)';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZW36810',
            N'BENDING 2/2 (GANG)',
            N'ZW36810-BD22G',
            N'BENDING 2/2 (GANG) PROCESS DRAWING',
            N'/drawings/ZW36810_BENDING_2_2_GANG.png',
            N'E: bend profile and formed flange'
        );
    END
END
GO

