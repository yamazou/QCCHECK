USE [QCCHECK];
GO

SET NOCOUNT ON;
GO

UPDATE dbo.drawing_reference
SET
    note = N'Set original drawing number',
    file_url = COALESCE(file_url, N'https://example.com/drawings/' + drawing_no + N'.pdf')
WHERE part_no IN (N'VDE1980', N'VDK0970');
GO

UPDATE dbo.point_check_reference
SET
    check_point = CASE
        WHEN part_no = N'VDE1980' AND process_code = N'SHEARING' AND check_code = N'A' THEN N'Cut length check'
        WHEN part_no = N'VDE1980' AND process_code = N'SHEARING' AND check_code = N'B' THEN N'Burr check'
        WHEN part_no = N'VDE1980' AND process_code = N'PUNCHING CUT BLANK 1/1' AND check_code = N'C' THEN N'Hole position check'
        ELSE check_point
    END,
    criteria = CASE
        WHEN part_no = N'VDE1980' AND process_code = N'SHEARING' AND check_code = N'A' THEN N'Within drawing tolerance'
        WHEN part_no = N'VDE1980' AND process_code = N'SHEARING' AND check_code = N'B' THEN N'No burr'
        WHEN part_no = N'VDE1980' AND process_code = N'PUNCHING CUT BLANK 1/1' AND check_code = N'C' THEN N'Within drawing tolerance'
        ELSE criteria
    END,
    check_method = CASE
        WHEN part_no = N'VDE1980' AND process_code = N'SHEARING' AND check_code = N'A' THEN N'Caliper'
        WHEN part_no = N'VDE1980' AND process_code = N'SHEARING' AND check_code = N'B' THEN N'Visual inspection'
        WHEN part_no = N'VDE1980' AND process_code = N'PUNCHING CUT BLANK 1/1' AND check_code = N'C' THEN N'Gauge check'
        ELSE check_method
    END
WHERE part_no IN (N'VDE1980', N'VDK0970');
GO
