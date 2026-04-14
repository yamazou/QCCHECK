USE [QCCHECK];
GO

/* Dedicated part master for part code + part name (per format). */

IF OBJECT_ID('dbo.part_master', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.part_master (
        part_master_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        format_id INT NOT NULL,
        part_no NVARCHAR(100) NOT NULL,
        part_name NVARCHAR(200) NOT NULL,
        active_flag BIT NOT NULL DEFAULT 1,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_pm_format FOREIGN KEY (format_id) REFERENCES dbo.format_master(format_id),
        CONSTRAINT UQ_pm_format_part UNIQUE (format_id, part_no)
    );
END
GO

;WITH src AS (
    SELECT
        fmp.format_id,
        UPPER(LTRIM(RTRIM(fmp.part_no))) AS part_no,
        ISNULL((
            SELECT TOP 1 dr.drawing_name
            FROM dbo.drawing_reference dr
            WHERE dr.format_id = fmp.format_id
              AND UPPER(LTRIM(RTRIM(dr.part_no))) = UPPER(LTRIM(RTRIM(fmp.part_no)))
              AND (dr.process_code IS NULL OR LTRIM(RTRIM(dr.process_code)) = '')
              AND dr.active_flag = 1
            ORDER BY dr.updated_at DESC, dr.drawing_ref_id DESC
        ), UPPER(LTRIM(RTRIM(fmp.part_no)))) AS part_name
    FROM dbo.process_master fmp
    WHERE fmp.part_no IS NOT NULL AND LTRIM(RTRIM(fmp.part_no)) <> ''
    GROUP BY fmp.format_id, UPPER(LTRIM(RTRIM(fmp.part_no)))
)
MERGE dbo.part_master AS t
USING src AS s
ON t.format_id = s.format_id AND UPPER(LTRIM(RTRIM(t.part_no))) = s.part_no
WHEN MATCHED AND (t.part_name <> s.part_name OR t.active_flag = 0) THEN
    UPDATE SET part_name = s.part_name, active_flag = 1, updated_at = SYSDATETIME()
WHEN NOT MATCHED THEN
    INSERT (format_id, part_no, part_name, active_flag)
    VALUES (s.format_id, s.part_no, s.part_name, 1);
GO
