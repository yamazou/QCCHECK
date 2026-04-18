USE [QCCHECK];
GO

/* ZM 54550 (DB part_no ZM54550) PROCESS PUNCHING PIERCING & EMBOSS 1/3 — PNG at server/public/drawings/ZM54550_PROCESS_PUNCHING_PIERCING_EMBOSS_1_3.png
   (マスタが「PROSESS …」の誤記の場合は index.html の正規化で PROCESS と照合されます) */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZM54550-PPE13',
        drawing_name = N'PROCESS PUNCHING PIERCING & EMBOSS 1/3 PROCESS DRAWING',
        file_url = N'/drawings/ZM54550_PROCESS_PUNCHING_PIERCING_EMBOSS_1_3.png',
        note = N'D/E: length & width; F: thickness; G: emboss slots / boss; H: pierced hole',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZM54550'
      AND process_code = N'PROCESS PUNCHING PIERCING & EMBOSS 1/3';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZM54550',
            N'PROCESS PUNCHING PIERCING & EMBOSS 1/3',
            N'ZM54550-PPE13',
            N'PROCESS PUNCHING PIERCING & EMBOSS 1/3 PROCESS DRAWING',
            N'/drawings/ZM54550_PROCESS_PUNCHING_PIERCING_EMBOSS_1_3.png',
            N'D/E: length & width; F: thickness; G: emboss slots / boss; H: pierced hole'
        );
    END
END
GO
