USE [QCCHECK];
GO

/* VCF9810 PUNCHING CUT BLANK 1/1: set drawing file (PNG at server/public/drawings/VCF9810_PUNCHING_CUT_BLANK_1_1.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VCF9810-PC11',
        drawing_name = N'PUNCHING CUT BLANK 1/1 PROCESS DRAWING',
        file_url = N'/drawings/VCF9810_PUNCHING_CUT_BLANK_1_1.png',
        note = N'E/F: hole/slot punching locations',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VCF9810'
      AND process_code = N'PUNCHING CUT BLANK 1/1';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VCF9810',
            N'PUNCHING CUT BLANK 1/1',
            N'VCF9810-PC11',
            N'PUNCHING CUT BLANK 1/1 PROCESS DRAWING',
            N'/drawings/VCF9810_PUNCHING_CUT_BLANK_1_1.png',
            N'E/F: hole/slot punching locations'
        );
    END
END
GO
