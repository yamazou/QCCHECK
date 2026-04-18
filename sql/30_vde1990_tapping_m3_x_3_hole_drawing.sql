USE [QCCHECK];
GO

/* VDE1990 TAPPING M3 x 3 HOLE: set drawing file (place PNG at server/public/drawings/VDE1990_TAPPING_M3_x_3_HOLE.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VDE1990-TP3',
        drawing_name = N'TAPPING M3 x 3 HOLE PROCESS DRAWING',
        file_url = N'/drawings/VDE1990_TAPPING_M3_x_3_HOLE.png',
        note = N'E: tapping hole locations',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VDE1990'
      AND process_code = N'TAPPING M3 x 3 HOLE';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VDE1990',
            N'TAPPING M3 x 3 HOLE',
            N'VDE1990-TP3',
            N'TAPPING M3 x 3 HOLE PROCESS DRAWING',
            N'/drawings/VDE1990_TAPPING_M3_x_3_HOLE.png',
            N'E: tapping hole locations'
        );
    END
END
GO

