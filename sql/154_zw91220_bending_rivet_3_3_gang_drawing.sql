USE [QCCHECK];
GO

/* ZW91220 BENDING & RIVET 3/3 (GANG): set drawing file (place PNG at server/public/drawings/ZW91220_BENDING_RIVET_3_3_GANG.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZW91220-BR33G',
        drawing_name = N'BENDING & RIVET 3/3 (GANG) PROCESS DRAWING',
        file_url = N'/drawings/ZW91220_BENDING_RIVET_3_3_GANG.png',
        note = N'E/F: bend profile and rivet positions',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZW91220'
      AND process_code = N'BENDING & RIVET 3/3 (GANG)';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZW91220',
            N'BENDING & RIVET 3/3 (GANG)',
            N'ZW91220-BR33G',
            N'BENDING & RIVET 3/3 (GANG) PROCESS DRAWING',
            N'/drawings/ZW91220_BENDING_RIVET_3_3_GANG.png',
            N'E/F: bend profile and rivet positions'
        );
    END
END
GO

