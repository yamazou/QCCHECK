USE [QCCHECK];
GO

/* ZV 31630 (DB part_no ZV31630) PIERCING 2/4 — PNG at server/public/drawings/ZV31630_PIERCING_2_4.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZV31630-PR24',
        drawing_name = N'PIERCING 2/4 PROCESS DRAWING',
        file_url = N'/drawings/ZV31630_PIERCING_2_4.png',
        note = N'E: upper small holes; lower vertical oval slots',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZV31630'
      AND process_code = N'PIERCING 2/4';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZV31630',
            N'PIERCING 2/4',
            N'ZV31630-PR24',
            N'PIERCING 2/4 PROCESS DRAWING',
            N'/drawings/ZV31630_PIERCING_2_4.png',
            N'E: upper small holes; lower vertical oval slots'
        );
    END
END
GO
