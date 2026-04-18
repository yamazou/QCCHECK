USE [QCCHECK];
GO

IF COL_LENGTH('dbo.point_check_reference', 'input_mode') IS NULL
BEGIN
    ALTER TABLE dbo.point_check_reference
        ADD input_mode VARCHAR(20) NOT NULL CONSTRAINT DF_pcr_input_mode DEFAULT 'OKNG';
END
GO

IF EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_pcr_input_mode'
      AND parent_object_id = OBJECT_ID('dbo.point_check_reference')
)
BEGIN
    ALTER TABLE dbo.point_check_reference DROP CONSTRAINT CK_pcr_input_mode;
END
GO

ALTER TABLE dbo.point_check_reference
    ADD CONSTRAINT CK_pcr_input_mode CHECK (input_mode IN ('OKNG', 'NUMERIC'));
GO

UPDATE dbo.point_check_reference
SET input_mode = 'NUMERIC'
WHERE input_mode <> 'NUMERIC'
  AND (
    UPPER(ISNULL(check_method, '')) LIKE '%CALIPER%'
    OR UPPER(ISNULL(check_method, '')) LIKE '%MICRO%'
    OR UPPER(ISNULL(check_method, '')) LIKE '%MEASURE%'
  );
GO

IF EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_crc_result'
      AND parent_object_id = OBJECT_ID('dbo.checksheet_row_check')
)
BEGIN
    ALTER TABLE dbo.checksheet_row_check DROP CONSTRAINT CK_crc_result;
END
GO

IF EXISTS (
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.checksheet_row_check')
      AND name = 'result'
      AND max_length < 100
)
BEGIN
    ALTER TABLE dbo.checksheet_row_check ALTER COLUMN result NVARCHAR(50) NULL;
END
GO

ALTER TABLE dbo.checksheet_row_check
    ADD CONSTRAINT CK_crc_result CHECK (LEN(LTRIM(RTRIM(result))) <= 50 OR result IS NULL);
GO
