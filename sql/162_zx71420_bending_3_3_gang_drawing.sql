USE [QCCHECK];
GO

/* ZX71420 BENDING 3/3 (GANG): set drawing file (place PNG at server/public/drawings/ZX71420_BENDING_3_3_GANG.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZX71420-BD33G',
        drawing_name = N'BENDING 3/3 (GANG) PROCESS DRAWING',
        file_url = N'/drawings/ZX71420_BENDING_3_3_GANG.png',
        note = N'E: final bend geometry and side profile',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZX71420'
      AND process_code = N'BENDING 3/3 (GANG)';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZX71420',
            N'BENDING 3/3 (GANG)',
            N'ZX71420-BD33G',
            N'BENDING 3/3 (GANG) PROCESS DRAWING',
            N'/drawings/ZX71420_BENDING_3_3_GANG.png',
            N'E: final bend geometry and side profile'
        );
    END
END
GO

