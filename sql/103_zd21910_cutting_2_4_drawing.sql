USE [QCCHECK];
GO

/* ZD21910 CUTTING 2/4: set drawing file (place PNG at server/public/drawings/ZD21910_CUTTING_2_4.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZD21910-CT24',
        drawing_name = N'CUTTING 2/4 PROCESS DRAWING',
        file_url = N'/drawings/ZD21910_CUTTING_2_4.png',
        note = N'E: cut profile and stepped geometry',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZD21910'
      AND process_code = N'CUTTING 2/4';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZD21910',
            N'CUTTING 2/4',
            N'ZD21910-CT24',
            N'CUTTING 2/4 PROCESS DRAWING',
            N'/drawings/ZD21910_CUTTING_2_4.png',
            N'E: cut profile and stepped geometry'
        );
    END
END
GO

