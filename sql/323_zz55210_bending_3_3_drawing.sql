USE [QCCHECK];
GO

/* ZZ 55210 (DB part_no ZZ55210) BENDING 3/3 — PNG at server/public/drawings/ZZ55210_BENDING_3_3.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZZ55210-BD33',
        drawing_name = N'BENDING 3/3 PROCESS DRAWING',
        file_url = N'/drawings/ZZ55210_BENDING_3_3.png',
        note = N'E: final bend area',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZZ55210'
      AND process_code = N'BENDING 3/3';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZZ55210',
            N'BENDING 3/3',
            N'ZZ55210-BD33',
            N'BENDING 3/3 PROCESS DRAWING',
            N'/drawings/ZZ55210_BENDING_3_3.png',
            N'E: final bend area'
        );
    END
END
GO

