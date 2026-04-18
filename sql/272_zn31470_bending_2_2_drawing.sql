USE [QCCHECK];
GO

/* ZN 31470 (DB part_no ZN31470) BENDING 2/2 — PNG at server/public/drawings/ZN31470_BENDING_2_2.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZN31470-BD22',
        drawing_name = N'BENDING 2/2 PROCESS DRAWING',
        file_url = N'/drawings/ZN31470_BENDING_2_2.png',
        note = N'E: upright flange; 90° bend; slot on flange face',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZN31470'
      AND process_code = N'BENDING 2/2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZN31470',
            N'BENDING 2/2',
            N'ZN31470-BD22',
            N'BENDING 2/2 PROCESS DRAWING',
            N'/drawings/ZN31470_BENDING_2_2.png',
            N'E: upright flange; 90° bend; slot on flange face'
        );
    END
END
GO
