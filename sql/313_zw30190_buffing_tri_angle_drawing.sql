USE [QCCHECK];
GO

/* ZW 30190 (DB part_no ZW30190) BUFFING TRI ANGLE — PNG at server/public/drawings/ZW30190_BUFFING_TRI_ANGLE.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZW30190-BFTRI',
        drawing_name = N'BUFFING TRI ANGLE PROCESS DRAWING',
        file_url = N'/drawings/ZW30190_BUFFING_TRI_ANGLE.png',
        note = N'E: bottom centre edge / tri-angle buff between chamfers',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZW30190'
      AND process_code = N'BUFFING TRI ANGLE';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZW30190',
            N'BUFFING TRI ANGLE',
            N'ZW30190-BFTRI',
            N'BUFFING TRI ANGLE PROCESS DRAWING',
            N'/drawings/ZW30190_BUFFING_TRI_ANGLE.png',
            N'E: bottom centre edge / tri-angle buff between chamfers'
        );
    END
END
GO

