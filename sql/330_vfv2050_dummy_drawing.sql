USE [QCCHECK];
GO

/* VFV 2050 (DB part_no VFV2050) DUMMY — PNG at server/public/drawings/VFV2050_DUMMY.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VFV2050-DM',
        drawing_name = N'DUMMY PROCESS DRAWING',
        file_url = N'/drawings/VFV2050_DUMMY.png',
        note = N'Isometric + detail views; callout E: bolt holes on upper horizontal tabs',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VFV2050'
      AND process_code = N'DUMMY';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VFV2050',
            N'DUMMY',
            N'VFV2050-DM',
            N'DUMMY PROCESS DRAWING',
            N'/drawings/VFV2050_DUMMY.png',
            N'Isometric + detail views; callout E: bolt holes on upper horizontal tabs'
        );
    END
END
GO
