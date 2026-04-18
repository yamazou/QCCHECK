USE [QCCHECK];
GO

/* VFU4500 PUNCHING PROGRESSIVE 1/1: set drawing file (place PNG at server/public/drawings/VFU4500_PUNCHING_PROGRESSIVE_1_1.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VFU4500-PP11',
        drawing_name = N'PUNCHING PROGRESSIVE 1/1 PROCESS DRAWING',
        file_url = N'/drawings/VFU4500_PUNCHING_PROGRESSIVE_1_1.png',
        note = N'E/F/G: progressive punching areas',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VFU4500'
      AND process_code = N'PUNCHING PROGRESSIVE 1/1';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VFU4500',
            N'PUNCHING PROGRESSIVE 1/1',
            N'VFU4500-PP11',
            N'PUNCHING PROGRESSIVE 1/1 PROCESS DRAWING',
            N'/drawings/VFU4500_PUNCHING_PROGRESSIVE_1_1.png',
            N'E/F/G: progressive punching areas'
        );
    END
END
GO

