USE [QCCHECK];
GO

/* ZD21920 BUFFING CUP BRUSH: set drawing file (place PNG at server/public/drawings/ZD21920_BUFFING_CUP_BRUSH.png). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZD21920-BCB',
        drawing_name = N'BUFFING CUP BRUSH PROCESS DRAWING',
        file_url = N'/drawings/ZD21920_BUFFING_CUP_BRUSH.png',
        note = N'E: cup-brush buffing area',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZD21920'
      AND process_code = N'BUFFING CUP BRUSH';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZD21920',
            N'BUFFING CUP BRUSH',
            N'ZD21920-BCB',
            N'BUFFING CUP BRUSH PROCESS DRAWING',
            N'/drawings/ZD21920_BUFFING_CUP_BRUSH.png',
            N'E: cup-brush buffing area'
        );
    END
END
GO

