USE [QCCHECK];
GO

/* drawing_no / drawing_name optional; file_url + part_no + process_code is enough for per-process previews. */
IF COL_LENGTH('dbo.drawing_reference', 'drawing_no') IS NOT NULL
BEGIN
    ALTER TABLE dbo.drawing_reference ALTER COLUMN drawing_no NVARCHAR(100) NULL;
END
GO
