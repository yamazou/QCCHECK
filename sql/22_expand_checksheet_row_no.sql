USE [QCCHECK];
GO

IF OBJECT_ID('dbo.checksheet_row', 'U') IS NOT NULL
BEGIN
    IF EXISTS (
        SELECT 1
        FROM sys.check_constraints
        WHERE name = 'CK_cr_row_no'
          AND parent_object_id = OBJECT_ID('dbo.checksheet_row')
    )
    BEGIN
        ALTER TABLE dbo.checksheet_row DROP CONSTRAINT CK_cr_row_no;
    END

    ALTER TABLE dbo.checksheet_row
        ADD CONSTRAINT CK_cr_row_no CHECK (row_no >= 1);
END
GO
