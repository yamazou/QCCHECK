USE [QCCHECK];
GO

/* ZD91920 BENDING 2/2 (GANG): set drawing file (place PNG at server/public/drawings/ZD91920_BENDING_2_2_GANG.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZD91920-BD22G',
        drawing_name = N'BENDING 2/2 (GANG) PROCESS DRAWING',
        file_url = N'/drawings/ZD91920_BENDING_2_2_GANG.png',
        note = N'E/F/G: bend profile and hole locations',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZD91920'
      AND process_code = N'BENDING 2/2 (GANG)';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZD91920',
            N'BENDING 2/2 (GANG)',
            N'ZD91920-BD22G',
            N'BENDING 2/2 (GANG) PROCESS DRAWING',
            N'/drawings/ZD91920_BENDING_2_2_GANG.png',
            N'E/F/G: bend profile and hole locations'
        );
    END
END
GO

