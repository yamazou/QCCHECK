USE [QCCHECK];
GO

/* ZJ 24790 (DB part_no ZJ24790) PUNCHING PROGRESSIVE 1/1 — PNG at server/public/drawings/ZJ24790_PUNCHING_PROGRESSIVE_1_1.png
   (マスタが「PUNCH PROGRESSIVE 1/1」の場合は index.html の正規化で照合されます) */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZJ24790-PP11',
        drawing_name = N'PUNCHING PROGRESSIVE 1/1 PROCESS DRAWING',
        file_url = N'/drawings/ZJ24790_PUNCHING_PROGRESSIVE_1_1.png',
        note = N'E: strip (plan); F: strip profile / bend sequence; G: leg pilot holes; H: main & tab holes',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZJ24790'
      AND process_code = N'PUNCHING PROGRESSIVE 1/1';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZJ24790',
            N'PUNCHING PROGRESSIVE 1/1',
            N'ZJ24790-PP11',
            N'PUNCHING PROGRESSIVE 1/1 PROCESS DRAWING',
            N'/drawings/ZJ24790_PUNCHING_PROGRESSIVE_1_1.png',
            N'E: strip (plan); F: strip profile / bend sequence; G: leg pilot holes; H: main & tab holes'
        );
    END
END
GO
