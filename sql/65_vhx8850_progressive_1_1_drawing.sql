USE [QCCHECK];
GO

/* VHX8850 PROGRESSIVE 1/1: set drawing file (place PNG at server/public/drawings/VHX8850_PROGRESSIVE_1_1.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VHX8850-PR11',
        drawing_name = N'PROGRESSIVE 1/1 PROCESS DRAWING',
        file_url = N'/drawings/VHX8850_PROGRESSIVE_1_1.png',
        note = N'E/F: progressive forming / hole areas',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VHX8850'
      AND process_code = N'PROGRESSIVE 1/1';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VHX8850',
            N'PROGRESSIVE 1/1',
            N'VHX8850-PR11',
            N'PROGRESSIVE 1/1 PROCESS DRAWING',
            N'/drawings/VHX8850_PROGRESSIVE_1_1.png',
            N'E/F: progressive forming / hole areas'
        );
    END
END
GO

