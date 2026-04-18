USE [QCCHECK];
GO

/* WJ 17290 (DB part_no WJ17290) SHEARING: E/F/G length, width, thickness — PNG at server/public/drawings/WJ17290_SHEARING.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'WJ17290-SH',
        drawing_name = N'SHEARING PROCESS DRAWING',
        file_url = N'/drawings/WJ17290_SHEARING.png',
        note = N'E/F/G: length, width, thickness',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'WJ17290'
      AND process_code = N'SHEARING';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'WJ17290',
            N'SHEARING',
            N'WJ17290-SH',
            N'SHEARING PROCESS DRAWING',
            N'/drawings/WJ17290_SHEARING.png',
            N'E/F/G: length, width, thickness'
        );
    END
END
GO
