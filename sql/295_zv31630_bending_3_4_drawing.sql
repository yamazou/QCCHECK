USE [QCCHECK];
GO

/* ZV 31630 (DB part_no ZV31630) BENDING 3/4 — PNG at server/public/drawings/ZV31630_BENDING_3_4.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZV31630-BD34',
        drawing_name = N'BENDING 3/4 PROCESS DRAWING',
        file_url = N'/drawings/ZV31630_BENDING_3_4.png',
        note = N'E: three offset (Z) bend lines — left tab, centre tab, right tab',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZV31630'
      AND process_code = N'BENDING 3/4';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZV31630',
            N'BENDING 3/4',
            N'ZV31630-BD34',
            N'BENDING 3/4 PROCESS DRAWING',
            N'/drawings/ZV31630_BENDING_3_4.png',
            N'E: three offset (Z) bend lines — left tab, centre tab, right tab'
        );
    END
END
GO
