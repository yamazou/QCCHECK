USE [QCCHECK];
GO

/* ZX71400 BENDING 2/3: set drawing file (place PNG at server/public/drawings/ZX71400_BENDING_2_3.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZX71400-BD23',
        drawing_name = N'BENDING 2/3 PROCESS DRAWING',
        file_url = N'/drawings/ZX71400_BENDING_2_3.png',
        note = N'E/F: bend lines and formed hole alignment',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZX71400'
      AND process_code = N'BENDING 2/3';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZX71400',
            N'BENDING 2/3',
            N'ZX71400-BD23',
            N'BENDING 2/3 PROCESS DRAWING',
            N'/drawings/ZX71400_BENDING_2_3.png',
            N'E/F: bend lines and formed hole alignment'
        );
    END
END
GO

