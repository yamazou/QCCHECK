USE [QCCHECK];
GO

/* VDK0970 SHEARING: Point Check A–G per QC sheet (replaces prior SHEARING rows only). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    DELETE FROM dbo.point_check_reference
    WHERE format_id = @format_id
      AND part_no = N'VDK0970'
      AND process_code = N'SHEARING';

    INSERT INTO dbo.point_check_reference (format_id, part_no, process_code, check_code, check_point, criteria, check_method, note)
    VALUES
    (@format_id, N'VDK0970', N'SHEARING', N'A', N'Material: ECOTRIO', NULL, N'Visual', NULL),
    (@format_id, N'VDK0970', N'SHEARING', N'B', N'No Dented', NULL, N'Visual', NULL),
    (@format_id, N'VDK0970', N'SHEARING', N'C', N'No scratch', NULL, N'Visual', NULL),
    (@format_id, N'VDK0970', N'SHEARING', N'D', N'Profil extc', NULL, NULL, NULL),
    (@format_id, N'VDK0970', N'SHEARING', N'E', N'1219', NULL, N'Caliper', NULL),
    (@format_id, N'VDK0970', N'SHEARING', N'F', N'83.5 ± 0.3', N'- 83.2 ～ +83.8', N'Caliper', NULL),
    (@format_id, N'VDK0970', N'SHEARING', N'G', N'0.8', NULL, N'Caliper', NULL);
END
GO
