USE [QCCHECK];
GO

/* ZW 30180 (DB part_no ZW30180) BENDING 3/3 — PNG at server/public/drawings/ZW30180_BENDING_3_3.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZW30180-BD33',
        drawing_name = N'BENDING 3/3 PROCESS DRAWING',
        file_url = N'/drawings/ZW30180_BENDING_3_3.png',
        note = N'E: final bend area',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZW30180'
      AND process_code = N'BENDING 3/3';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZW30180',
            N'BENDING 3/3',
            N'ZW30180-BD33',
            N'BENDING 3/3 PROCESS DRAWING',
            N'/drawings/ZW30180_BENDING_3_3.png',
            N'E: final bend area'
        );
    END
END
GO

