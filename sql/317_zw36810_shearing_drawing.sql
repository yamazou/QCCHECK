USE [QCCHECK];
GO

/* ZW 36810 (DB part_no ZW36810) SHEARING: E/F/G length, width, thickness — PNG at server/public/drawings/ZW36810_SHEARING.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZW36810-SH',
        drawing_name = N'SHEARING PROCESS DRAWING',
        file_url = N'/drawings/ZW36810_SHEARING.png',
        note = N'E/F/G: length, width, thickness',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZW36810'
      AND process_code = N'SHEARING';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZW36810',
            N'SHEARING',
            N'ZW36810-SH',
            N'SHEARING PROCESS DRAWING',
            N'/drawings/ZW36810_SHEARING.png',
            N'E/F/G: length, width, thickness'
        );
    END
END
GO

