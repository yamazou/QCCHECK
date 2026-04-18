USE [QCCHECK];
GO

/* ZZ55210 BENDING 2/3: set drawing file (place PNG at server/public/drawings/ZZ55210_BENDING_2_3.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZZ55210-BD23',
        drawing_name = N'BENDING 2/3 PROCESS DRAWING',
        file_url = N'/drawings/ZZ55210_BENDING_2_3.png',
        note = N'E: bend lines and tab areas',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZZ55210'
      AND process_code = N'BENDING 2/3';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZZ55210',
            N'BENDING 2/3',
            N'ZZ55210-BD23',
            N'BENDING 2/3 PROCESS DRAWING',
            N'/drawings/ZZ55210_BENDING_2_3.png',
            N'E: bend lines and tab areas'
        );
    END
END
GO

