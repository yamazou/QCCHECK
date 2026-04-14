USE [QCCHECK];
GO

/*
Cleanup legacy part-name usage in drawing_reference assembly rows.

Background:
- Part Name is now managed by dbo.part_master.
- Legacy data may still have the same Part Name in assembly drawing rows
  (process_code IS NULL / blank), which can cause data ownership confusion.

How to use:
1) Run as-is (@apply = 0) to preview target rows and count.
2) Set @apply = 1 to apply update.
*/

DECLARE @apply BIT = 0;  -- 0 = preview only, 1 = apply update

IF OBJECT_ID('dbo.part_master', 'U') IS NULL
BEGIN
    THROW 50001, 'part_master table not found. Run sql/17_part_master.sql first.', 1;
END

;WITH target_rows AS (
    SELECT
        dr.drawing_ref_id,
        dr.format_id,
        dr.part_no,
        dr.drawing_no,
        dr.drawing_name
    FROM dbo.drawing_reference dr
    INNER JOIN dbo.part_master pm
        ON pm.format_id = dr.format_id
       AND UPPER(LTRIM(RTRIM(pm.part_no))) = UPPER(LTRIM(RTRIM(dr.part_no)))
       AND pm.active_flag = 1
    WHERE (dr.process_code IS NULL OR LTRIM(RTRIM(dr.process_code)) = '')
      AND dr.active_flag = 1
      AND LTRIM(RTRIM(ISNULL(dr.drawing_name, ''))) <> ''
      AND UPPER(LTRIM(RTRIM(dr.drawing_name))) = UPPER(LTRIM(RTRIM(pm.part_name)))
)
SELECT COUNT(*) AS target_count FROM target_rows;

;WITH target_rows AS (
    SELECT
        dr.drawing_ref_id,
        dr.format_id,
        dr.part_no,
        dr.drawing_no,
        dr.drawing_name
    FROM dbo.drawing_reference dr
    INNER JOIN dbo.part_master pm
        ON pm.format_id = dr.format_id
       AND UPPER(LTRIM(RTRIM(pm.part_no))) = UPPER(LTRIM(RTRIM(dr.part_no)))
       AND pm.active_flag = 1
    WHERE (dr.process_code IS NULL OR LTRIM(RTRIM(dr.process_code)) = '')
      AND dr.active_flag = 1
      AND LTRIM(RTRIM(ISNULL(dr.drawing_name, ''))) <> ''
      AND UPPER(LTRIM(RTRIM(dr.drawing_name))) = UPPER(LTRIM(RTRIM(pm.part_name)))
)
SELECT drawing_ref_id, format_id, part_no, drawing_no, drawing_name
FROM target_rows
ORDER BY format_id, part_no, drawing_ref_id;

IF @apply = 1
BEGIN
    ;WITH target_rows AS (
        SELECT
            dr.drawing_ref_id
        FROM dbo.drawing_reference dr
        INNER JOIN dbo.part_master pm
            ON pm.format_id = dr.format_id
           AND UPPER(LTRIM(RTRIM(pm.part_no))) = UPPER(LTRIM(RTRIM(dr.part_no)))
           AND pm.active_flag = 1
        WHERE (dr.process_code IS NULL OR LTRIM(RTRIM(dr.process_code)) = '')
          AND dr.active_flag = 1
          AND LTRIM(RTRIM(ISNULL(dr.drawing_name, ''))) <> ''
          AND UPPER(LTRIM(RTRIM(dr.drawing_name))) = UPPER(LTRIM(RTRIM(pm.part_name)))
    )
    UPDATE dr
    SET
        drawing_name = NULL,
        updated_at = SYSDATETIME(),
        note = CASE
            WHEN dr.note IS NULL OR LTRIM(RTRIM(dr.note)) = '' THEN N'Legacy part name cleared: now managed in part_master'
            ELSE dr.note + N' | Legacy part name cleared: now managed in part_master'
        END
    FROM dbo.drawing_reference dr
    INNER JOIN target_rows t ON t.drawing_ref_id = dr.drawing_ref_id;

    SELECT @@ROWCOUNT AS updated_count;
END
ELSE
BEGIN
    SELECT CAST(0 AS INT) AS updated_count, N'Preview mode only. Set @apply = 1 to apply.' AS message;
END
GO
