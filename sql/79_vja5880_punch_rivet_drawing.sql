USE [QCCHECK];
GO

/* VJA5880 PUNCH RIVET: set drawing file (place PNG at server/public/drawings/VJA5880_PUNCH_RIVET.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VJA5880-RVPR',
        drawing_name = N'PUNCH RIVET PROCESS DRAWING',
        file_url = N'/drawings/VJA5880_PUNCH_RIVET.png',
        note = N'E: punch rivet positions',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VJA5880'
      AND process_code = N'PUNCH RIVET';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VJA5880',
            N'PUNCH RIVET',
            N'VJA5880-RVPR',
            N'PUNCH RIVET PROCESS DRAWING',
            N'/drawings/VJA5880_PUNCH_RIVET.png',
            N'E: punch rivet positions'
        );
    END
END
GO

