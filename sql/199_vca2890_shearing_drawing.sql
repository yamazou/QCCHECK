USE [QCCHECK];
GO

/* VCA2890 SHEARING: E/F/G length, width, thickness — PNG at server/public/drawings/VCA2890_SHEARING.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VCA2890-SH',
        drawing_name = N'SHEARING PROCESS DRAWING',
        file_url = N'/drawings/VCA2890_SHEARING.png',
        note = N'E/F/G: length, width, thickness',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VCA2890'
      AND process_code = N'SHEARING';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VCA2890',
            N'SHEARING',
            N'VCA2890-SH',
            N'SHEARING PROCESS DRAWING',
            N'/drawings/VCA2890_SHEARING.png',
            N'E/F/G: length, width, thickness'
        );
    END
END
GO
