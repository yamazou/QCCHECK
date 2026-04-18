USE [QCCHECK];
GO

/* VCA2890 PUNCHING CUT BLANK 1/3: set drawing file (PNG at server/public/drawings/VCA2890_PUNCHING_CUT_BLANK_1_3.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VCA2890-PC13',
        drawing_name = N'PUNCHING CUT BLANK 1/3 PROCESS DRAWING',
        file_url = N'/drawings/VCA2890_PUNCHING_CUT_BLANK_1_3.png',
        note = N'E: top edge / blank profile',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VCA2890'
      AND process_code = N'PUNCHING CUT BLANK 1/3';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VCA2890',
            N'PUNCHING CUT BLANK 1/3',
            N'VCA2890-PC13',
            N'PUNCHING CUT BLANK 1/3 PROCESS DRAWING',
            N'/drawings/VCA2890_PUNCHING_CUT_BLANK_1_3.png',
            N'E: top edge / blank profile'
        );
    END
END
GO
