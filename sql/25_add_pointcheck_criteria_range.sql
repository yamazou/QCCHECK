USE [QCCHECK];
GO

IF COL_LENGTH('dbo.point_check_reference', 'criteria_min') IS NULL
BEGIN
    ALTER TABLE dbo.point_check_reference ADD criteria_min DECIMAL(18,4) NULL;
END
GO

IF COL_LENGTH('dbo.point_check_reference', 'criteria_max') IS NULL
BEGIN
    ALTER TABLE dbo.point_check_reference ADD criteria_max DECIMAL(18,4) NULL;
END
GO

IF EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_pcr_criteria_range'
      AND parent_object_id = OBJECT_ID('dbo.point_check_reference')
)
BEGIN
    ALTER TABLE dbo.point_check_reference DROP CONSTRAINT CK_pcr_criteria_range;
END
GO

ALTER TABLE dbo.point_check_reference
    ADD CONSTRAINT CK_pcr_criteria_range
    CHECK (criteria_min IS NULL OR criteria_max IS NULL OR criteria_min <= criteria_max);
GO
