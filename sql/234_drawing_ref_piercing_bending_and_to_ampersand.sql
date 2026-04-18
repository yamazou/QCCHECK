USE [QCCHECK];
GO

/* Optional: unify "PIERCING AND BENDING" -> "PIERCING & BENDING" in drawing_reference (matches UI normalization). */

UPDATE dbo.drawing_reference
SET process_code = REPLACE(process_code, N'PIERCING AND BENDING', N'PIERCING & BENDING'),
    updated_at = SYSDATETIME()
WHERE process_code LIKE N'PIERCING AND BENDING%';

GO
