USE [QCCHECK];
GO

/* ZW 30190 (DB part_no ZW30190) CHAMFERING HOLE — PNG at server/public/drawings/ZW30190_CHAMFERING_HOLE.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZW30190-CH',
        drawing_name = N'CHAMFERING HOLE PROCESS DRAWING',
        file_url = N'/drawings/ZW30190_CHAMFERING_HOLE.png',
        note = N'E: chamfered hole locations',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZW30190'
      AND process_code = N'CHAMFERING HOLE';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZW30190',
            N'CHAMFERING HOLE',
            N'ZW30190-CH',
            N'CHAMFERING HOLE PROCESS DRAWING',
            N'/drawings/ZW30190_CHAMFERING_HOLE.png',
            N'E: chamfered hole locations'
        );
    END
END
GO

