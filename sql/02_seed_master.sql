USE [QCCHECK];
GO

SET NOCOUNT ON;
GO

DECLARE @format_code NVARCHAR(50) = N'FM-ASB-CS-001-00';
DECLARE @format_name NVARCHAR(200) = N'CHECK SHEET PRODUCTION';
DECLARE @format_id INT;

IF NOT EXISTS (SELECT 1 FROM dbo.format_master WHERE format_code = @format_code)
BEGIN
    INSERT INTO dbo.format_master (format_code, format_name)
    VALUES (@format_code, @format_name);
END

SELECT @format_id = format_id
FROM dbo.format_master
WHERE format_code = @format_code;

IF NOT EXISTS (SELECT 1 FROM dbo.format_check_item_master WHERE format_id = @format_id)
BEGIN
    INSERT INTO dbo.format_check_item_master (format_id, check_code, check_name, display_order)
    VALUES
    (@format_id, N'A', N'Check A', 1),
    (@format_id, N'B', N'Check B', 2),
    (@format_id, N'C', N'Check C', 3),
    (@format_id, N'D', N'Check D', 4),
    (@format_id, N'E', N'Check E', 5),
    (@format_id, N'F', N'Check F', 6),
    (@format_id, N'G', N'Check G', 7);
END
GO

DECLARE @format_id2 INT = (SELECT format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF NOT EXISTS (
    SELECT 1
    FROM dbo.format_process_master
    WHERE format_id = @format_id2
      AND part_no = N'VDE1980'
)
BEGIN
    INSERT INTO dbo.format_process_master (format_id, part_no, process_name, display_order)
    VALUES
    (@format_id2, N'VDE1980', N'SHEARING', 1),
    (@format_id2, N'VDE1980', N'PUNCHING CUT BLANK 1/1', 2),
    (@format_id2, N'VDE1980', N'TAPPING M3 x 4 HOLE', 3);
END

IF NOT EXISTS (
    SELECT 1
    FROM dbo.format_process_master
    WHERE format_id = @format_id2
      AND part_no = N'VDK0970'
)
BEGIN
    INSERT INTO dbo.format_process_master (format_id, part_no, process_name, display_order)
    VALUES
    (@format_id2, N'VDK0970', N'SHEARING', 11),
    (@format_id2, N'VDK0970', N'PUNCHING CUT BLANK 1/3', 12),
    (@format_id2, N'VDK0970', N'BENDING 2/3', 13),
    (@format_id2, N'VDK0970', N'BENDING 3/3', 14);
END
GO
