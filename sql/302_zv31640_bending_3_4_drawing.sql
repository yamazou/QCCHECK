USE [QCCHECK];
GO

/* ZV 31640 (DB part_no ZV31640) BENDING 3/4 — PNG at server/public/drawings/ZV31640_BENDING_3_4.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZV31640-BD34',
        drawing_name = N'BENDING 3/4 PROCESS DRAWING',
        file_url = N'/drawings/ZV31640_BENDING_3_4.png',
        note = N'E: three offset (Z) bend lines — left, center, right',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZV31640'
      AND process_code = N'BENDING 3/4';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZV31640',
            N'BENDING 3/4',
            N'ZV31640-BD34',
            N'BENDING 3/4 PROCESS DRAWING',
            N'/drawings/ZV31640_BENDING_3_4.png',
            N'E: three offset (Z) bend lines — left, center, right'
        );
    END
END
GO
