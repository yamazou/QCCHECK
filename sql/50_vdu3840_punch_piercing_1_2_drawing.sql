USE [QCCHECK];
GO

/* VDU3840 PUNCH PIERCING 1/2: set drawing file (place PNG at server/public/drawings/VDU3840_PUNCH_PIERCING_1_2.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'VDU3840-PP12',
        drawing_name = N'PUNCH PIERCING 1/2 PROCESS DRAWING',
        file_url = N'/drawings/VDU3840_PUNCH_PIERCING_1_2.png',
        note = N'E: hole punching locations',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VDU3840'
      AND process_code = N'PUNCH PIERCING 1/2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'VDU3840',
            N'PUNCH PIERCING 1/2',
            N'VDU3840-PP12',
            N'PUNCH PIERCING 1/2 PROCESS DRAWING',
            N'/drawings/VDU3840_PUNCH_PIERCING_1_2.png',
            N'E: hole punching locations'
        );
    END
END
GO

