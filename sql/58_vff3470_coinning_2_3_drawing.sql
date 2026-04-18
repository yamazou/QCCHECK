USE [QCCHECK];
GO

/* VFF3470 COINNING 2/3: set drawing file (place PNG at server/public/drawings/VFF3470_COINNING_2_3.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VFF3470-CN23',
        drawing_name = N'COINNING 2/3 PROCESS DRAWING',
        file_url = N'/drawings/VFF3470_COINNING_2_3.png',
        note = N'E: coinning area / profile',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VFF3470'
      AND process_code = N'COINNING 2/3';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VFF3470',
            N'COINNING 2/3',
            N'VFF3470-CN23',
            N'COINNING 2/3 PROCESS DRAWING',
            N'/drawings/VFF3470_COINNING_2_3.png',
            N'E: coinning area / profile'
        );
    END
END
GO

