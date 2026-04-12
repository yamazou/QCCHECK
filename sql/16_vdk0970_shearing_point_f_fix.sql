USE [QCCHECK];
GO

/* VDK0970 SHEARING F: nominal/tolerance and range text correction */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    UPDATE dbo.point_check_reference
    SET
        check_point = N'83.5 ± 0.3',
        criteria = N'- 83.2 ～ +83.8',
        updated_at = SYSDATETIME()
    WHERE format_id = @format_id
      AND part_no = N'VDK0970'
      AND process_code = N'SHEARING'
      AND check_code = N'F';
END
GO
