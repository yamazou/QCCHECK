USE [QCCHECK];
GO

/* VDK0970 BENDING 2/3: Point Check A–E (replaces prior single D row). */

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    DELETE FROM dbo.point_check_reference
    WHERE format_id = @format_id
      AND part_no = N'VDK0970'
      AND process_code = N'BENDING 2/3';

    INSERT INTO dbo.point_check_reference (format_id, part_no, process_code, check_code, check_point, criteria, check_method, note)
    VALUES
    (@format_id, N'VDK0970', N'BENDING 2/3', N'A', N'Material', N'ECOTRIO', N'Visual', NULL),
    (@format_id, N'VDK0970', N'BENDING 2/3', N'B', N'No Dented', NULL, N'Visual', NULL),
    (@format_id, N'VDK0970', N'BENDING 2/3', N'C', N'No scratch', NULL, N'Visual', NULL),
    (@format_id, N'VDK0970', N'BENDING 2/3', N'D', N'Profil extc', NULL, NULL, NULL),
    (@format_id, N'VDK0970', N'BENDING 2/3', N'E', N'Bending', N'2 area', N'Visual', NULL);
END
GO
