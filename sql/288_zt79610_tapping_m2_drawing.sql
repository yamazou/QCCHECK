USE [QCCHECK];
GO

/* ZT 79610 (DB part_no ZT79610) TAPPING M2 — PNG at server/public/drawings/ZT79610_TAPPING_M2.png */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.drawing_reference
    SET
        drawing_no = N'ZT79610-TPM2',
        drawing_name = N'TAPPING M2 PROCESS DRAWING',
        file_url = N'/drawings/ZT79610_TAPPING_M2.png',
        note = N'E: M2 tap column (five holes); tool / thread seat',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'ZT79610'
      AND process_code = N'TAPPING M2';

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES (
            @format_id,
            N'ZT79610',
            N'TAPPING M2',
            N'ZT79610-TPM2',
            N'TAPPING M2 PROCESS DRAWING',
            N'/drawings/ZT79610_TAPPING_M2.png',
            N'E: M2 tap column (five holes); tool / thread seat'
        );
    END
END
GO
