USE [QCCHECK];
GO

IF NOT EXISTS (SELECT 1 FROM dbo.format_master WHERE format_id = 1)
  THROW 50001, N'format_id 1 not found', 1;
GO

IF OBJECT_ID('dbo.drawing_reference', 'U') IS NULL
  THROW 50002, N'dbo.drawing_reference missing', 1;
GO

DELETE FROM dbo.drawing_reference WHERE format_id = 1;
GO

INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note, active_flag) VALUES (1, UPPER(LTRIM(RTRIM(N'90-AD09I1'))), N'SAWING', NULL, NULL, N'/drawings/90AD09I1_SAWING.png', NULL, 1);
GO

INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note, active_flag) VALUES (1, UPPER(LTRIM(RTRIM(N'90-AD09I1'))), N'PUNCHING 1/2', NULL, NULL, N'/drawings/90AD09I1_PUNCHING_1_2.png', NULL, 1);
GO

INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note, active_flag) VALUES (1, UPPER(LTRIM(RTRIM(N'90-AD09I1'))), N'BENDING 2/2 (GANG)', NULL, NULL, N'/drawings/90AD09I1_BENDING_2_2_GANG.png', NULL, 1);
GO

INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note, active_flag) VALUES (1, UPPER(LTRIM(RTRIM(N'90-AD09I1'))), N'TAPPING M3', NULL, NULL, N'/drawings/90AD09I1_TAPPING_M3.png', NULL, 1);
GO

INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note, active_flag) VALUES (1, UPPER(LTRIM(RTRIM(N'90-AD09I2'))), N'SAWING', NULL, NULL, N'/drawings/90AD09I2_SAWING.png', NULL, 1);
GO

INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note, active_flag) VALUES (1, UPPER(LTRIM(RTRIM(N'90-AD09I2'))), N'PUNCHING CUT BLANK 1/2', NULL, NULL, N'/drawings/90AD09I2_PUNCHING_CUT_BLANK_1_2.png', NULL, 1);
GO

INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note, active_flag) VALUES (1, UPPER(LTRIM(RTRIM(N'90-AD09I2'))), N'BENDING 2/2 (GANG)', NULL, NULL, N'/drawings/90AD09I2_BENDING_2_2_GANG.png', NULL, 1);
GO

INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note, active_flag) VALUES (1, UPPER(LTRIM(RTRIM(N'90-AD09I2'))), N'TAPPING M3', NULL, NULL, N'/drawings/90AD09I2_TAPPING_M3.png', NULL, 1);
GO
