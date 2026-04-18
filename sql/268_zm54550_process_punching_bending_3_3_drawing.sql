USE [QCCHECK];
GO

/* ZM 54550 (DB part_no ZM54550) PROCESS PUNCHING BENDING 3/3 — PNG at server/public/drawings/ZM54550_PROCESS_PUNCHING_BENDING_3_3.png
   (マスタが「PROSESS …」の誤記の場合は index.html の正規化で PROCESS と照合されます) */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZM54550-PB33',
        drawing_name = N'PROCESS PUNCHING BENDING 3/3 PROCESS DRAWING',
        file_url = N'/drawings/ZM54550_PROCESS_PUNCHING_BENDING_3_3.png',
        note = N'E: ribs, centre tab & cutout; edge flanges; holes on ribs & ends',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZM54550'
      AND process_code = N'PROCESS PUNCHING BENDING 3/3';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZM54550',
            N'PROCESS PUNCHING BENDING 3/3',
            N'ZM54550-PB33',
            N'PROCESS PUNCHING BENDING 3/3 PROCESS DRAWING',
            N'/drawings/ZM54550_PROCESS_PUNCHING_BENDING_3_3.png',
            N'E: ribs, centre tab & cutout; edge flanges; holes on ribs & ends'
        );
    END
END
GO
