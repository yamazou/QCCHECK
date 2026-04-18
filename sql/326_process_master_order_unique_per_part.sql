/*
  Change process_master order uniqueness scope:
  from (format_id, display_order)
  to   (format_id, part_no, display_order)
*/

SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.process_master', N'U') IS NULL
BEGIN
  THROW 50001, 'process_master table not found. Run sql/01_schema.sql first.', 1;
END

DECLARE @dropSql NVARCHAR(MAX) = N'';

;WITH uniq AS (
  SELECT
    kc.name AS constraint_name,
    STUFF((
      SELECT N',' + c2.name
      FROM sys.indexes i2
      INNER JOIN sys.index_columns ic2
        ON ic2.object_id = i2.object_id
       AND ic2.index_id = i2.index_id
       AND ic2.key_ordinal > 0
      INNER JOIN sys.columns c2
        ON c2.object_id = ic2.object_id
       AND c2.column_id = ic2.column_id
      WHERE i2.object_id = kc.parent_object_id
        AND i2.index_id = kc.unique_index_id
      ORDER BY ic2.key_ordinal
      FOR XML PATH(''), TYPE
    ).value('.', 'nvarchar(max)'), 1, 1, N'') AS key_cols
  FROM sys.key_constraints kc
  WHERE kc.parent_object_id = OBJECT_ID(N'dbo.process_master')
    AND kc.type = 'UQ'
)
SELECT @dropSql = STUFF((
  SELECT CHAR(10) + N'ALTER TABLE dbo.process_master DROP CONSTRAINT [' + u.constraint_name + N'];'
  FROM uniq u
  WHERE u.key_cols IN (N'format_id,display_order', N'format_id,part_no,display_order')
  FOR XML PATH(''), TYPE
).value('.', 'nvarchar(max)'), 1, 1, N'');

IF @dropSql IS NOT NULL AND LEN(@dropSql) > 0
BEGIN
  EXEC sp_executesql @dropSql;
END

ALTER TABLE dbo.process_master
  ADD CONSTRAINT UQ_pm_format_part_order UNIQUE (format_id, part_no, display_order);

/*
  Normalize existing orders to be sequential per part:
  for each (format_id, part_no), set display_order = 1..N by current order.
*/
BEGIN TRANSACTION;

IF OBJECT_ID('tempdb..#pm_new_order') IS NOT NULL
  DROP TABLE #pm_new_order;

SELECT
  pm.process_master_id,
  ROW_NUMBER() OVER (
    PARTITION BY pm.format_id, pm.part_no
    ORDER BY pm.process_master_id
  ) AS new_display_order
INTO #pm_new_order
FROM dbo.process_master pm;

-- Step 1: move to temporary unique negative values to avoid uniqueness collision during renumbering.
UPDATE pm
SET pm.display_order = -pm.process_master_id
FROM dbo.process_master pm
INNER JOIN #pm_new_order t
  ON t.process_master_id = pm.process_master_id;

-- Step 2: set final sequential order per part.
UPDATE pm
SET pm.display_order = t.new_display_order
FROM dbo.process_master pm
INNER JOIN #pm_new_order t
  ON t.process_master_id = pm.process_master_id;

COMMIT TRANSACTION;

-- Quick check example for part 3K015327.
SELECT
  process_master_id,
  format_id,
  part_no,
  process_name,
  display_order
FROM dbo.process_master
WHERE UPPER(LTRIM(RTRIM(part_no))) IN ('3K015327', '3K-015327')
ORDER BY format_id, display_order, process_master_id;

