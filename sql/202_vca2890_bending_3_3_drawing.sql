USE [QCCHECK];
GO

/* VCA2890 BENDING 3/3: set drawing file (PNG at server/public/drawings/VCA2890_BENDING_3_3.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VCA2890-BD3',
        drawing_name = N'BENDING 3/3 PROCESS DRAWING',
        file_url = N'/drawings/VCA2890_BENDING_3_3.png',
        note = N'E: overall width / final form',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VCA2890'
      AND process_code = N'BENDING 3/3';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VCA2890',
            N'BENDING 3/3',
            N'VCA2890-BD3',
            N'BENDING 3/3 PROCESS DRAWING',
            N'/drawings/VCA2890_BENDING_3_3.png',
            N'E: overall width / final form'
        );
    END
END
GO
