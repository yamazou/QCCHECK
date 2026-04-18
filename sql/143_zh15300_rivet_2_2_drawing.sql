USE [QCCHECK];
GO

/* ZH15300 RIVET 2/2: set drawing file (place PNG at server/public/drawings/ZH15300_RIVET_2_2.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZH15300-RV22',
        drawing_name = N'RIVET 2/2 PROCESS DRAWING',
        file_url = N'/drawings/ZH15300_RIVET_2_2.png',
        note = N'E/F: rivet locations and center feature',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZH15300'
      AND process_code = N'RIVET 2/2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZH15300',
            N'RIVET 2/2',
            N'ZH15300-RV22',
            N'RIVET 2/2 PROCESS DRAWING',
            N'/drawings/ZH15300_RIVET_2_2.png',
            N'E/F: rivet locations and center feature'
        );
    END
END
GO

