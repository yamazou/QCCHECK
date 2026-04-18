USE [QCCHECK];
GO

/* ZD21910 PUNCHING 2/2: set drawing file (place PNG at server/public/drawings/ZD21910_PUNCHING_2_2.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZD21910-PN22',
        drawing_name = N'PUNCHING 2/2 PROCESS DRAWING',
        file_url = N'/drawings/ZD21910_PUNCHING_2_2.png',
        note = N'E: final punching holes',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZD21910'
      AND process_code = N'PUNCHING 2/2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZD21910',
            N'PUNCHING 2/2',
            N'ZD21910-PN22',
            N'PUNCHING 2/2 PROCESS DRAWING',
            N'/drawings/ZD21910_PUNCHING_2_2.png',
            N'E: final punching holes'
        );
    END
END
GO

