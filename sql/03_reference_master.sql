USE [QCCHECK];
GO

IF OBJECT_ID('dbo.drawing_reference', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.drawing_reference (
        drawing_ref_id BIGINT IDENTITY(1,1) PRIMARY KEY,
        format_id INT NOT NULL,
        part_no NVARCHAR(100) NOT NULL,
        process_code NVARCHAR(50) NULL,
        drawing_no NVARCHAR(100) NOT NULL,
        drawing_name NVARCHAR(200) NULL,
        file_url NVARCHAR(500) NULL,
        note NVARCHAR(500) NULL,
        active_flag BIT NOT NULL DEFAULT 1,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_dr_format FOREIGN KEY (format_id) REFERENCES dbo.format_master(format_id)
    );
    CREATE INDEX IX_dr_lookup ON dbo.drawing_reference(format_id, part_no, active_flag);
END
GO

IF OBJECT_ID('dbo.point_check_reference', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.point_check_reference (
        point_check_ref_id BIGINT IDENTITY(1,1) PRIMARY KEY,
        format_id INT NOT NULL,
        part_no NVARCHAR(100) NOT NULL,
        process_code NVARCHAR(50) NULL,
        check_code NCHAR(1) NOT NULL,
        check_point NVARCHAR(300) NOT NULL,
        criteria NVARCHAR(300) NULL,
        check_method NVARCHAR(300) NULL,
        note NVARCHAR(500) NULL,
        active_flag BIT NOT NULL DEFAULT 1,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_pcr_format FOREIGN KEY (format_id) REFERENCES dbo.format_master(format_id),
        CONSTRAINT CK_pcr_code CHECK (check_code IN ('A','B','C','D','E','F','G'))
    );
    CREATE INDEX IX_pcr_lookup ON dbo.point_check_reference(format_id, part_no, active_flag);
END
GO

DECLARE @format_id INT = (SELECT TOP 1 format_id FROM dbo.format_master WHERE format_code = N'FM-ASB-CS-001-00');

IF @format_id IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.drawing_reference WHERE format_id = @format_id AND part_no = N'VDE1980')
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES
        (@format_id, N'VDE1980', NULL, N'VDE1980-ASM', N'POST C BRACKET ASSY DRAWING', NULL, N'Set master drawing number'),
        (@format_id, N'VDE1980', N'SHEARING', N'VDE1980-SH', N'SHEARING PROCESS DRAWING', NULL, N'Per-process drawing');
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.drawing_reference WHERE format_id = @format_id AND part_no = N'VDK0970')
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES
        (@format_id, N'VDK0970', NULL, N'VDK0970-ASM', N'DM SHIELD COVER ASSY DRAWING', NULL, N'Set master drawing number'),
        (@format_id, N'VDK0970', N'BENDING 2/3', N'VDK0970-BD2', N'BENDING 2/3 PROCESS DRAWING', N'/drawings/VDK0970_BENDING_2_3.png', N'E: Bend areas (tabs, 90 deg bend)');
    END

    IF NOT EXISTS (
        SELECT 1 FROM dbo.drawing_reference
        WHERE format_id = @format_id AND part_no = N'VDK0970' AND process_code = N'SHEARING'
    )
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES
        (@format_id, N'VDK0970', N'SHEARING', N'VDK0970-SH', N'SHEARING PROCESS DRAWING', N'/drawings/VDK0970_SHEARING.png', N'E/F/G: length, width, thickness');
    END

    IF NOT EXISTS (
        SELECT 1 FROM dbo.drawing_reference
        WHERE format_id = @format_id AND part_no = N'VDK0970' AND process_code = N'PUNCHING CUT BLANK 1/3'
    )
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES
        (@format_id, N'VDK0970', N'PUNCHING CUT BLANK 1/3', N'VDK0970-PC13', N'PUNCHING CUT BLANK 1/3 PROCESS DRAWING', N'/drawings/VDK0970_PUNCHING_CUT_BLANK_1_3.png', N'Blank shape / punching');
    END

    IF NOT EXISTS (
        SELECT 1 FROM dbo.drawing_reference
        WHERE format_id = @format_id AND part_no = N'VDK0970' AND process_code = N'BENDING 3/3'
    )
    BEGIN
        INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
        VALUES
        (@format_id, N'VDK0970', N'BENDING 3/3', N'VDK0970-BD3', N'BENDING 3/3 PROCESS DRAWING', N'/drawings/VDK0970_BENDING_3_3.png', N'E: Final bend areas (6 locations)');
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.point_check_reference WHERE format_id = @format_id AND part_no = N'VDE1980')
    BEGIN
        INSERT INTO dbo.point_check_reference (format_id, part_no, process_code, check_code, check_point, criteria, check_method, note)
        VALUES
        (@format_id, N'VDE1980', N'SHEARING', N'A', N'Cut length check', N'Within drawing dimensions', N'Caliper', NULL),
        (@format_id, N'VDE1980', N'SHEARING', N'B', N'Burr check', N'No burr', N'Visual', NULL),
        (@format_id, N'VDE1980', N'PUNCHING CUT BLANK 1/1', N'C', N'Hole position check', N'Within drawing tolerance', N'Gauge', NULL);
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.point_check_reference WHERE format_id = @format_id AND part_no = N'VDK0970')
    BEGIN
        INSERT INTO dbo.point_check_reference (format_id, part_no, process_code, check_code, check_point, criteria, check_method, note)
        VALUES
        (@format_id, N'VDK0970', N'SHEARING', N'A', N'Material: ECOTRIO', NULL, N'Visual', NULL),
        (@format_id, N'VDK0970', N'SHEARING', N'B', N'No Dented', NULL, N'Visual', NULL),
        (@format_id, N'VDK0970', N'SHEARING', N'C', N'No scratch', NULL, N'Visual', NULL),
        (@format_id, N'VDK0970', N'SHEARING', N'D', N'Profil extc', NULL, NULL, NULL),
        (@format_id, N'VDK0970', N'SHEARING', N'E', N'1219', NULL, N'Caliper', NULL),
        (@format_id, N'VDK0970', N'SHEARING', N'F', N'83.5 ± 0.3', N'- 83.2 ~ +83.8', N'Caliper', NULL),
        (@format_id, N'VDK0970', N'SHEARING', N'G', N'0.8', NULL, N'Caliper', NULL),
        (@format_id, N'VDK0970', N'BENDING 2/3', N'A', N'Material', N'ECOTRIO', N'Visual', NULL),
        (@format_id, N'VDK0970', N'BENDING 2/3', N'B', N'No Dented', NULL, N'Visual', NULL),
        (@format_id, N'VDK0970', N'BENDING 2/3', N'C', N'No scratch', NULL, N'Visual', NULL),
        (@format_id, N'VDK0970', N'BENDING 2/3', N'D', N'Profil extc', NULL, NULL, NULL),
        (@format_id, N'VDK0970', N'BENDING 2/3', N'E', N'Bending', N'2 area', N'Visual', NULL);
    END

    IF NOT EXISTS (
        SELECT 1 FROM dbo.point_check_reference
        WHERE format_id = @format_id AND part_no = N'VDK0970' AND process_code = N'PUNCHING CUT BLANK 1/3'
    )
    BEGIN
        INSERT INTO dbo.point_check_reference (format_id, part_no, process_code, check_code, check_point, criteria, check_method, note)
        VALUES
        (@format_id, N'VDK0970', N'PUNCHING CUT BLANK 1/3', N'A', N'Material', N'ECOTRIO', N'Visual', NULL),
        (@format_id, N'VDK0970', N'PUNCHING CUT BLANK 1/3', N'B', N'No Dented', NULL, N'Visual', NULL),
        (@format_id, N'VDK0970', N'PUNCHING CUT BLANK 1/3', N'C', N'No scratch', NULL, N'Visual', NULL),
        (@format_id, N'VDK0970', N'PUNCHING CUT BLANK 1/3', N'D', N'Profil extc', NULL, NULL, NULL);
    END

    IF NOT EXISTS (
        SELECT 1 FROM dbo.point_check_reference
        WHERE format_id = @format_id AND part_no = N'VDK0970' AND process_code = N'BENDING 3/3'
    )
    BEGIN
        INSERT INTO dbo.point_check_reference (format_id, part_no, process_code, check_code, check_point, criteria, check_method, note)
        VALUES
        (@format_id, N'VDK0970', N'BENDING 3/3', N'A', N'Material', N'ECOTRIO', N'Visual', NULL),
        (@format_id, N'VDK0970', N'BENDING 3/3', N'B', N'No Dented', NULL, N'Visual', NULL),
        (@format_id, N'VDK0970', N'BENDING 3/3', N'C', N'No scratch', NULL, N'Visual', NULL),
        (@format_id, N'VDK0970', N'BENDING 3/3', N'D', N'Profil extc', NULL, NULL, NULL),
        (@format_id, N'VDK0970', N'BENDING 3/3', N'E', N'Bending', N'7 area', N'Visual', NULL);
    END
END
GO
