USE [QCCHECK];
GO

/* ZF 600700 (DB part_no ZF600700) TAPPING M3 — PNG at server/public/drawings/ZF600700_TAPPING_M3.png
   (シート誤記「Tapping Me」は index.html の正規化で TAPPING M3 と照合されます) */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    /* Drop legacy row from earlier "TAPPING ME" script so process_code matches master (TAPPING M3). */
    DELETE FROM dbo.drawing_reference
    WHERE format_id = @format_id
      AND part_no = N'ZF600700'
      AND process_code = N'TAPPING ME';

    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZF600700-TPM3',
        drawing_name = N'TAPPING M3 PROCESS DRAWING',
        file_url = N'/drawings/ZF600700_TAPPING_M3.png',
        note = N'E: M3 tap / before-after thread',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZF600700'
      AND process_code = N'TAPPING M3';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZF600700',
            N'TAPPING M3',
            N'ZF600700-TPM3',
            N'TAPPING M3 PROCESS DRAWING',
            N'/drawings/ZF600700_TAPPING_M3.png',
            N'E: M3 tap / before-after thread'
        );
    END
END
GO
