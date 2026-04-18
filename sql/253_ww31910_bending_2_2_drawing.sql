USE [QCCHECK];
GO

/* WW 31910 (DB part_no WW31910) BENDING 2/2 — PNG at server/public/drawings/WW31910_BENDING_2_2.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'WW31910-BD22',
        drawing_name = N'BENDING 2/2 PROCESS DRAWING',
        file_url = N'/drawings/WW31910_BENDING_2_2.png',
        note = N'E: bent tabs / vertical flanges',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'WW31910'
      AND process_code = N'BENDING 2/2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'WW31910',
            N'BENDING 2/2',
            N'WW31910-BD22',
            N'BENDING 2/2 PROCESS DRAWING',
            N'/drawings/WW31910_BENDING_2_2.png',
            N'E: bent tabs / vertical flanges'
        );
    END
END
GO
