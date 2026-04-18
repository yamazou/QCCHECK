/**
 * Master data admin API (parts, processes, drawings, point checks).
 */

function registerAdminRoutes(app, sql, getPool) {
  function normalizePartNo(input) {
    return String(input || "")
      .trim()
      .toUpperCase()
      .replaceAll(/\s+/g, "");
  }

  async function nextProcessDisplayOrder(pool, formatId, partNo) {
    const rs = await pool.request()
      .input("formatId", sql.Int, formatId)
      .input("partNo", sql.NVarChar(100), normalizePartNo(partNo))
      .query(`
        SELECT ISNULL(MAX(display_order), 0) + 1 AS n
        FROM dbo.process_master
        WHERE format_id = @formatId AND UPPER(LTRIM(RTRIM(part_no))) = @partNo
      `);
    return rs.recordset[0].n;
  }

  async function hasPointCheckInputModeColumn(pool) {
    const rs = await pool.request().query(`
      SELECT CASE WHEN COL_LENGTH('dbo.point_check_reference', 'input_mode') IS NULL THEN 0 ELSE 1 END AS hasCol
    `);
    return !!(rs.recordset[0] && rs.recordset[0].hasCol);
  }

  async function hasPointCheckCriteriaRangeColumns(pool) {
    const rs = await pool.request().query(`
      SELECT
        CASE WHEN COL_LENGTH('dbo.point_check_reference', 'criteria_min') IS NULL THEN 0 ELSE 1 END AS hasMin,
        CASE WHEN COL_LENGTH('dbo.point_check_reference', 'criteria_max') IS NULL THEN 0 ELSE 1 END AS hasMax
    `);
    return !!(rs.recordset[0] && rs.recordset[0].hasMin && rs.recordset[0].hasMax);
  }

  function parseNullableDecimal(value, fieldName) {
    if (value == null) return null;
    let s = String(value).trim();
    if (!s) return null;
    // Accept variants like "- 83.2", "+83.8", full-width plus/minus.
    s = s
      .replace(/\u3000/g, " ")
      .replace(/[＋﹢]/g, "+")
      .replace(/[－−—–﹣]/g, "-")
      .replace(/\s+/g, "");
    if (/^[+-]?\d+,\d+$/.test(s)) {
      s = s.replace(",", ".");
    }
    const n = Number(s);
    if (!Number.isFinite(n)) throw new Error(`${fieldName} must be numeric`);
    return n;
  }

  /** Catalog: all active parts + processes per part */
  app.get("/api/admin/catalog", async (req, res) => {
    const formatId = Number(req.query.formatId);
    if (!formatId) return res.status(400).json({ message: "formatId is required" });
    try {
      const pool = await getPool();
      const nameRs = await pool.request()
        .input("formatId", sql.Int, formatId)
        .query(`
          IF OBJECT_ID('dbo.part_master', 'U') IS NULL
          BEGIN
            THROW 50001, 'part_master table not found. Run sql/17_part_master.sql first.', 1;
          END
          SELECT pm.part_no AS partNo, pm.part_name AS partName
          FROM dbo.part_master pm
          WHERE pm.format_id = @formatId AND pm.active_flag = 1
          ORDER BY pm.part_no
        `);
      const nameByPart = {};
      for (const r of nameRs.recordset) {
        nameByPart[r.partNo] = r.partName || r.partNo;
      }

      const procRs = await pool.request()
        .input("formatId", sql.Int, formatId)
        .query(`
          SELECT process_master_id AS processMasterId, part_no AS partNo, process_name AS processName,
                 display_order AS displayOrder, active_flag AS activeFlag
          FROM dbo.process_master
          WHERE format_id = @formatId AND part_no IS NOT NULL
          ORDER BY part_no, display_order
        `);

      const partMap = new Map();
      for (const r of nameRs.recordset) {
        const pn = r.partNo;
        if (!pn || partMap.has(pn)) continue;
        partMap.set(pn, {
          partNo: pn,
          partName: r.partName || pn,
          processes: []
        });
      }
      for (const row of procRs.recordset) {
        const pn = row.partNo;
        if (!partMap.has(pn)) {
          partMap.set(pn, {
            partNo: pn,
            partName: nameByPart[pn] || pn,
            processes: []
          });
        }
        partMap.get(pn).processes.push({
          processMasterId: row.processMasterId,
          processName: row.processName,
          displayOrder: row.displayOrder,
          activeFlag: !!row.activeFlag
        });
      }

      res.json({ parts: [...partMap.values()] });
    } catch (e) {
      res.status(500).json({ message: e.message });
    }
  });

  /** Header branding (company / department / logo) per format */
  app.get("/api/admin/header-branding", async (req, res) => {
    const formatId = Number(req.query.formatId);
    if (!formatId) return res.status(400).json({ message: "formatId is required" });
    try {
      const pool = await getPool();
      const rs = await pool.request()
        .input("formatId", sql.Int, formatId)
        .query(`
          IF OBJECT_ID('dbo.format_header_branding', 'U') IS NULL
          BEGIN
            SELECT
              CAST(NULL AS NVARCHAR(200)) AS companyName,
              CAST(NULL AS NVARCHAR(200)) AS departmentName,
              CAST(NULL AS NVARCHAR(500)) AS logoUrl;
          END
          ELSE
          BEGIN
            SELECT TOP 1
              company_name AS companyName,
              department_name AS departmentName,
              logo_url AS logoUrl
            FROM dbo.format_header_branding
            WHERE format_id = @formatId AND active_flag = 1
            ORDER BY updated_at DESC, format_header_branding_id DESC;
          END
        `);
      const row = rs.recordset[0] || {};
      res.json({
        companyName: row.companyName || null,
        departmentName: row.departmentName || null,
        logoUrl: row.logoUrl || null
      });
    } catch (e) {
      res.status(500).json({ message: e.message });
    }
  });

  app.patch("/api/admin/header-branding", async (req, res) => {
    const formatId = Number(req.query.formatId);
    const companyName = String((req.body || {}).companyName || "").trim();
    const departmentName = String((req.body || {}).departmentName || "").trim();
    const logoUrlRaw = (req.body || {}).logoUrl;
    const logoUrl = logoUrlRaw == null ? "" : String(logoUrlRaw).trim();
    if (!formatId) {
      return res.status(400).json({ message: "formatId is required" });
    }
    if (!companyName || !departmentName) {
      return res.status(400).json({ message: "companyName and departmentName are required" });
    }
    try {
      const pool = await getPool();
      await pool.request()
        .input("formatId", sql.Int, formatId)
        .input("companyName", sql.NVarChar(200), companyName.slice(0, 200))
        .input("departmentName", sql.NVarChar(200), departmentName.slice(0, 200))
        .input("logoUrl", sql.NVarChar(500), logoUrl ? logoUrl.slice(0, 500) : null)
        .query(`
          IF OBJECT_ID('dbo.format_header_branding', 'U') IS NULL
          BEGIN
            THROW 50001, 'format_header_branding table not found. Run sql/16_format_header_branding.sql first.', 1;
          END

          MERGE dbo.format_header_branding AS t
          USING (
            SELECT
              @formatId AS format_id,
              @companyName AS company_name,
              @departmentName AS department_name,
              @logoUrl AS logo_url
          ) AS s
          ON t.format_id = s.format_id
          WHEN MATCHED THEN
            UPDATE SET
              company_name = s.company_name,
              department_name = s.department_name,
              logo_url = s.logo_url,
              active_flag = 1,
              updated_at = SYSDATETIME()
          WHEN NOT MATCHED THEN
            INSERT (format_id, company_name, department_name, logo_url, active_flag)
            VALUES (s.format_id, s.company_name, s.department_name, s.logo_url, 1);
        `);
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ message: e.message });
    }
  });

  /** Drawings + point checks for one part (admin; includes inactive) */
  app.get("/api/admin/part-detail", async (req, res) => {
    const formatId = Number(req.query.formatId);
    const partNo = normalizePartNo(req.query.partNo);
    if (!formatId || !partNo) {
      return res.status(400).json({ message: "formatId and partNo are required" });
    }
    try {
      const pool = await getPool();
      const hasInputMode = await hasPointCheckInputModeColumn(pool);
      const hasCriteriaRange = await hasPointCheckCriteriaRangeColumns(pool);
      const dr = await pool.request()
        .input("formatId", sql.Int, formatId)
        .input("partNo", sql.NVarChar(100), partNo)
        .query(`
          SELECT dr.drawing_ref_id AS drawingRefId, dr.process_code AS processCode, dr.drawing_no AS drawingNo,
                 dr.drawing_name AS drawingName, dr.file_url AS fileUrl, dr.note, dr.active_flag AS activeFlag
          FROM dbo.drawing_reference dr
          LEFT JOIN dbo.process_master fpm
            ON fpm.format_id = dr.format_id
            AND fpm.part_no = dr.part_no
            AND dr.process_code IS NOT NULL
            AND fpm.process_name = dr.process_code
          WHERE dr.format_id = @formatId AND dr.part_no = @partNo
          ORDER BY
            CASE WHEN dr.process_code IS NULL THEN 0 ELSE 1 END,
            CASE WHEN dr.process_code IS NULL THEN 0 ELSE COALESCE(fpm.display_order, 2147483646) END,
            dr.process_code,
            dr.drawing_no
        `);
      const pc = await pool.request()
        .input("formatId", sql.Int, formatId)
        .input("partNo", sql.NVarChar(100), partNo)
        .query(hasInputMode
          ? `
            SELECT pcr.point_check_ref_id AS pointCheckRefId, pcr.process_code AS processCode, pcr.check_code AS checkCode,
                   pcr.check_point AS pointCheckText, pcr.criteria, pcr.check_method AS checkMethod, pcr.note,
                   pcr.active_flag AS activeFlag, ISNULL(NULLIF(pcr.input_mode, ''), 'OKNG') AS inputMode
                   ${hasCriteriaRange
                      ? ", pcr.criteria_min AS criteriaMin, pcr.criteria_max AS criteriaMax"
                      : ", CAST(NULL AS DECIMAL(18,4)) AS criteriaMin, CAST(NULL AS DECIMAL(18,4)) AS criteriaMax"}
            FROM dbo.point_check_reference pcr
            LEFT JOIN dbo.process_master fpm
              ON fpm.format_id = pcr.format_id
              AND fpm.part_no = pcr.part_no
              AND pcr.process_code IS NOT NULL
              AND fpm.process_name = pcr.process_code
            WHERE pcr.format_id = @formatId AND pcr.part_no = @partNo
            ORDER BY
              CASE WHEN NULLIF(LTRIM(RTRIM(ISNULL(pcr.process_code, N''))), N'') IS NULL THEN 1 ELSE 0 END,
              CASE WHEN NULLIF(LTRIM(RTRIM(ISNULL(pcr.process_code, N''))), N'') IS NULL
                THEN 2147483647
                ELSE COALESCE(fpm.display_order, 2147483646)
              END,
              pcr.process_code,
              UPPER(LTRIM(RTRIM(ISNULL(pcr.check_code, N''))))
          `
          : `
            SELECT pcr.point_check_ref_id AS pointCheckRefId, pcr.process_code AS processCode, pcr.check_code AS checkCode,
                   pcr.check_point AS pointCheckText, pcr.criteria, pcr.check_method AS checkMethod, pcr.note,
                   pcr.active_flag AS activeFlag, CAST('OKNG' AS VARCHAR(20)) AS inputMode
                   ${hasCriteriaRange
                      ? ", pcr.criteria_min AS criteriaMin, pcr.criteria_max AS criteriaMax"
                      : ", CAST(NULL AS DECIMAL(18,4)) AS criteriaMin, CAST(NULL AS DECIMAL(18,4)) AS criteriaMax"}
            FROM dbo.point_check_reference pcr
            LEFT JOIN dbo.process_master fpm
              ON fpm.format_id = pcr.format_id
              AND fpm.part_no = pcr.part_no
              AND pcr.process_code IS NOT NULL
              AND fpm.process_name = pcr.process_code
            WHERE pcr.format_id = @formatId AND pcr.part_no = @partNo
            ORDER BY
              CASE WHEN NULLIF(LTRIM(RTRIM(ISNULL(pcr.process_code, N''))), N'') IS NULL THEN 1 ELSE 0 END,
              CASE WHEN NULLIF(LTRIM(RTRIM(ISNULL(pcr.process_code, N''))), N'') IS NULL
                THEN 2147483647
                ELSE COALESCE(fpm.display_order, 2147483646)
              END,
              pcr.process_code,
              UPPER(LTRIM(RTRIM(ISNULL(pcr.check_code, N''))))
          `);
      const cust = await pool.request()
        .input("formatId", sql.Int, formatId)
        .input("partNo", sql.NVarChar(100), partNo)
        .query(`
          SELECT customer_abbrev AS customerAbbrev
          FROM dbo.part_customer
          WHERE format_id = @formatId AND part_no = @partNo AND active_flag = 1
        `);
      const customerAbbrev =
        cust.recordset.length && cust.recordset[0].customerAbbrev != null
          ? String(cust.recordset[0].customerAbbrev).trim()
          : null;
      res.json({
        drawings: dr.recordset,
        pointChecks: pc.recordset,
        customerAbbrev: customerAbbrev || null
      });
    } catch (e) {
      res.status(500).json({ message: e.message });
    }
  });

  /** New part: part master row, and optional first process. */
  app.post("/api/admin/parts", async (req, res) => {
    const { formatId, partNo, partName, firstProcessName } = req.body || {};
    const pn = normalizePartNo(partNo);
    const pname = String(partName || "").trim();
    const proc0 = firstProcessName != null ? String(firstProcessName).trim() : "";
    if (!formatId || !pn || !pname) {
      return res.status(400).json({ message: "formatId, partNo, partName are required" });
    }
    let transaction;
    try {
      const pool = await getPool();
      transaction = new sql.Transaction(pool);
      await transaction.begin();

      const dup = await new sql.Request(transaction)
        .input("formatId", sql.Int, Number(formatId))
        .input("partNo", sql.NVarChar(50), pn)
        .query(`
          IF OBJECT_ID('dbo.part_master', 'U') IS NULL
          BEGIN
            THROW 50001, 'part_master table not found. Run sql/17_part_master.sql first.', 1;
          END
          SELECT 1 AS x FROM dbo.process_master WHERE format_id=@formatId AND part_no=@partNo
          UNION ALL
          SELECT 1 AS x FROM dbo.part_master WHERE format_id=@formatId AND part_no=@partNo
        `);
      if (dup.recordset.length) {
        await transaction.rollback();
        return res.status(409).json({ message: "partNo already exists for this format" });
      }

      await new sql.Request(transaction)
        .input("formatId", sql.Int, Number(formatId))
        .input("partNo", sql.NVarChar(50), pn)
        .input("partName", sql.NVarChar(200), pname)
        .query(`
          IF OBJECT_ID('dbo.part_master', 'U') IS NULL
          BEGIN
            THROW 50001, 'part_master table not found. Run sql/17_part_master.sql first.', 1;
          END
          INSERT INTO dbo.part_master (format_id, part_no, part_name, active_flag)
          VALUES (@formatId, @partNo, @partName, 1)
        `);

      if (proc0) {
        const ord = await nextProcessDisplayOrder(pool, Number(formatId), pn);
        await new sql.Request(transaction)
          .input("formatId", sql.Int, Number(formatId))
          .input("partNo", sql.NVarChar(50), pn)
          .input("processName", sql.NVarChar(200), proc0)
          .input("displayOrder", sql.Int, ord)
          .query(`
            INSERT INTO dbo.process_master (format_id, part_no, process_name, display_order)
            VALUES (@formatId, @partNo, @processName, @displayOrder)
          `);
      }

      await transaction.commit();
      res.status(201).json({ ok: true, partNo: pn });
    } catch (e) {
      if (transaction) try { await transaction.rollback(); } catch (_e) { /* ignore */ }
      res.status(500).json({ message: e.message });
    }
  });

  /**
   * Remove a part and all related rows: saved checksheets (header/process/row/checks),
   * process_master, drawing_reference, point_check_reference, part_customer (if table exists).
   */
  app.delete("/api/admin/parts/:partNo", async (req, res) => {
    const pn = normalizePartNo(req.params.partNo);
    const formatId = Number(req.query.formatId);
    if (!formatId || !pn) {
      return res.status(400).json({ message: "formatId query and partNo path are required" });
    }
    let transaction;
    try {
      const pool = await getPool();
      const exists = await pool.request()
        .input("formatId", sql.Int, formatId)
        .input("partNo", sql.NVarChar(100), pn)
        .query(`
          SELECT 1 AS x FROM dbo.process_master
          WHERE format_id = @formatId AND UPPER(LTRIM(RTRIM(part_no))) = @partNo
          UNION ALL
          SELECT 1 AS x FROM dbo.part_master
          WHERE format_id = @formatId AND UPPER(LTRIM(RTRIM(part_no))) = @partNo
        `);
      if (!exists.recordset.length) {
        return res.status(404).json({ message: "part not found for this format" });
      }

      transaction = new sql.Transaction(pool);
      await transaction.begin();

      const del = (queryText) =>
        new sql.Request(transaction)
          .input("formatId", sql.Int, formatId)
          .input("partNo", sql.NVarChar(100), pn)
          .query(queryText);

      await del(`
        DELETE crc
        FROM dbo.checksheet_row_check crc
        INNER JOIN dbo.checksheet_row cr ON cr.row_id = crc.row_id
        INNER JOIN dbo.checksheet_process cp ON cp.process_id = cr.process_id
        INNER JOIN dbo.checksheet_header ch ON ch.header_id = cp.header_id
        WHERE ch.format_id = @formatId AND UPPER(LTRIM(RTRIM(ch.part_no))) = @partNo
      `);
      await del(`
        DELETE cr
        FROM dbo.checksheet_row cr
        INNER JOIN dbo.checksheet_process cp ON cp.process_id = cr.process_id
        INNER JOIN dbo.checksheet_header ch ON ch.header_id = cp.header_id
        WHERE ch.format_id = @formatId AND UPPER(LTRIM(RTRIM(ch.part_no))) = @partNo
      `);
      await del(`
        DELETE cp
        FROM dbo.checksheet_process cp
        INNER JOIN dbo.checksheet_header ch ON ch.header_id = cp.header_id
        WHERE ch.format_id = @formatId AND UPPER(LTRIM(RTRIM(ch.part_no))) = @partNo
      `);
      await del(`
        DELETE FROM dbo.checksheet_header
        WHERE format_id = @formatId AND UPPER(LTRIM(RTRIM(part_no))) = @partNo
      `);
      await del(`
        DELETE FROM dbo.process_master
        WHERE format_id = @formatId AND UPPER(LTRIM(RTRIM(part_no))) = @partNo
      `);
      await del(`
        DELETE FROM dbo.drawing_reference
        WHERE format_id = @formatId AND UPPER(LTRIM(RTRIM(part_no))) = @partNo
      `);
      await del(`
        DELETE FROM dbo.point_check_reference
        WHERE format_id = @formatId AND UPPER(LTRIM(RTRIM(part_no))) = @partNo
      `);
      await del(`
        IF OBJECT_ID(N'dbo.part_customer', N'U') IS NOT NULL
          DELETE FROM dbo.part_customer WHERE format_id = @formatId AND UPPER(LTRIM(RTRIM(part_no))) = @partNo;
      `);
      await del(`
        IF OBJECT_ID(N'dbo.part_master', N'U') IS NOT NULL
          DELETE FROM dbo.part_master WHERE format_id = @formatId AND UPPER(LTRIM(RTRIM(part_no))) = @partNo;
      `);

      await transaction.commit();
      res.json({ ok: true });
    } catch (e) {
      if (transaction) try { await transaction.rollback(); } catch (_e) { /* ignore */ }
      res.status(500).json({ message: e.message });
    }
  });

  /** Add process to existing part */
  app.post("/api/admin/processes", async (req, res) => {
    const { formatId, partNo, processName } = req.body || {};
    const pn = normalizePartNo(partNo);
    const pname = String(processName || "").trim();
    if (!formatId || !pn || !pname) {
      return res.status(400).json({ message: "formatId, partNo, processName are required" });
    }
    try {
      const pool = await getPool();
      const ord = await nextProcessDisplayOrder(pool, Number(formatId), pn);
      await pool.request()
        .input("formatId", sql.Int, Number(formatId))
        .input("partNo", sql.NVarChar(50), pn)
        .input("processName", sql.NVarChar(200), pname)
        .input("displayOrder", sql.Int, ord)
        .query(`
          INSERT INTO dbo.process_master (format_id, part_no, process_name, display_order)
          VALUES (@formatId, @partNo, @processName, @displayOrder)
        `);
      res.status(201).json({ ok: true, displayOrder: ord });
    } catch (e) {
      res.status(500).json({ message: e.message });
    }
  });

  app.patch("/api/admin/processes/:processMasterId", async (req, res) => {
    const id = Number(req.params.processMasterId);
    const { processName, displayOrder, activeFlag } = req.body || {};
    if (!id) return res.status(400).json({ message: "invalid processMasterId" });
    const hasDisplayOrder = displayOrder != null && String(displayOrder).trim() !== "";
    let displayOrderNum = null;
    if (hasDisplayOrder) {
      displayOrderNum = Number(displayOrder);
      if (!Number.isInteger(displayOrderNum) || displayOrderNum < 0) {
        return res.status(400).json({ message: "displayOrder must be an integer >= 0" });
      }
    }
    try {
      const pool = await getPool();
      if (processName == null && activeFlag == null && !hasDisplayOrder) {
        return res.status(400).json({ message: "nothing to update" });
      }

      const transaction = new sql.Transaction(pool);
      await transaction.begin();
      try {
        const curRs = await new sql.Request(transaction)
          .input("id", sql.Int, id)
          .query(`
            SELECT process_master_id AS processMasterId, format_id AS formatId, part_no AS partNo, display_order AS displayOrder
            FROM dbo.process_master
            WHERE process_master_id = @id
          `);
        if (!curRs.recordset.length) {
          await transaction.rollback();
          return res.status(404).json({ message: "not found" });
        }
        const current = curRs.recordset[0];

        if (hasDisplayOrder && displayOrderNum !== Number(current.displayOrder)) {
          // Process order is unique per part_no, so swap within the same part safely via temporary order.
          const tempOrder = -id;
          await new sql.Request(transaction)
            .input("id", sql.Int, id)
            .input("tempOrder", sql.Int, tempOrder)
            .query(`
              UPDATE dbo.process_master
              SET display_order = @tempOrder, updated_at = SYSDATETIME()
              WHERE process_master_id = @id
            `);

          const conflictRs = await new sql.Request(transaction)
            .input("id", sql.Int, id)
            .input("formatId", sql.Int, Number(current.formatId))
            .input("partNo", sql.NVarChar(100), normalizePartNo(current.partNo))
            .input("displayOrder", sql.Int, displayOrderNum)
            .query(`
              SELECT TOP 1 process_master_id AS processMasterId
              FROM dbo.process_master
              WHERE format_id = @formatId
                AND UPPER(LTRIM(RTRIM(part_no))) = @partNo
                AND display_order = @displayOrder
                AND process_master_id <> @id
            `);

          if (conflictRs.recordset.length) {
            await new sql.Request(transaction)
              .input("conflictId", sql.Int, Number(conflictRs.recordset[0].processMasterId))
              .input("currentOrder", sql.Int, Number(current.displayOrder))
              .query(`
                UPDATE dbo.process_master
                SET display_order = @currentOrder, updated_at = SYSDATETIME()
                WHERE process_master_id = @conflictId
              `);
          }

          await new sql.Request(transaction)
            .input("id", sql.Int, id)
            .input("displayOrder", sql.Int, displayOrderNum)
            .query(`
              UPDATE dbo.process_master
              SET display_order = @displayOrder, updated_at = SYSDATETIME()
              WHERE process_master_id = @id
            `);
        }

        const reqSql = new sql.Request(transaction).input("id", sql.Int, id);
        const sets = ["updated_at = SYSDATETIME()"];
        if (processName != null) {
          reqSql.input("processName", sql.NVarChar(200), String(processName).trim());
          sets.push("process_name = @processName");
        }
        if (activeFlag != null) {
          reqSql.input("activeFlag", sql.Bit, !!activeFlag);
          sets.push("active_flag = @activeFlag");
        }
        if (sets.length > 1) {
          await reqSql.query(`
            UPDATE dbo.process_master SET ${sets.join(", ")}
            WHERE process_master_id = @id
          `);
        }

        await transaction.commit();
      } catch (txErr) {
        try { await transaction.rollback(); } catch (_e) { /* ignore */ }
        throw txErr;
      }
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ message: e.message });
    }
  });

  app.delete("/api/admin/processes/:processMasterId", async (req, res) => {
    const id = Number(req.params.processMasterId);
    const formatId = Number(req.query.formatId);
    const partNo = normalizePartNo(req.query.partNo);
    if (!id || !formatId || !partNo) {
      return res.status(400).json({ message: "processMasterId, formatId and partNo query are required" });
    }
    let transaction;
    try {
      const pool = await getPool();
      const v = await pool.request()
        .input("id", sql.Int, id)
        .input("formatId", sql.Int, formatId)
        .input("partNo", sql.NVarChar(50), partNo)
        .query(`
          SELECT 1 AS x FROM dbo.process_master
          WHERE process_master_id = @id
            AND format_id = @formatId
            AND UPPER(LTRIM(RTRIM(part_no))) = @partNo
        `);
      if (!v.recordset.length) return res.status(404).json({ message: "not found" });

      transaction = new sql.Transaction(pool);
      await transaction.begin();

      // Keep historical checksheet data by detaching process_master_id.
      await new sql.Request(transaction)
        .input("id", sql.Int, id)
        .query(`
          UPDATE dbo.checksheet_process
          SET process_master_id = NULL,
              updated_at = SYSDATETIME()
          WHERE process_master_id = @id
        `);

      await new sql.Request(transaction)
        .input("id", sql.Int, id)
        .query(`DELETE FROM dbo.process_master WHERE process_master_id = @id`);

      await transaction.commit();
      res.json({ ok: true });
    } catch (e) {
      if (transaction) {
        try { await transaction.rollback(); } catch (_e) { /* ignore */ }
      }
      res.status(500).json({ message: e.message });
    }
  });

  app.post("/api/admin/drawings", async (req, res) => {
    const b = req.body || {};
    const formatId = Number(b.formatId);
    const partNo = normalizePartNo(b.partNo);
    const drawingNo =
      b.drawingNo != null && String(b.drawingNo).trim() !== "" ? String(b.drawingNo).trim() : null;
    const drawingName = b.drawingName != null ? String(b.drawingName).trim() : null;
    const fileUrl = b.fileUrl != null ? String(b.fileUrl).trim() : null;
    const note = b.note != null ? String(b.note).trim() : null;
    const processCode = b.processCode != null && String(b.processCode).trim() !== ""
      ? String(b.processCode).trim()
      : null;
    if (!formatId || !partNo) {
      return res.status(400).json({ message: "formatId and partNo are required" });
    }
    if (!drawingNo && !fileUrl) {
      return res.status(400).json({ message: "Provide drawingNo and/or fileUrl" });
    }
    try {
      const pool = await getPool();
      const hasInputMode = await hasPointCheckInputModeColumn(pool);
      const rs = await pool.request()
        .input("formatId", sql.Int, formatId)
        .input("partNo", sql.NVarChar(100), partNo)
        .input("processCode", sql.NVarChar(50), processCode)
        .input("drawingNo", sql.NVarChar(100), drawingNo || null)
        .input("drawingName", sql.NVarChar(200), drawingName)
        .input("fileUrl", sql.NVarChar(500), fileUrl)
        .input("note", sql.NVarChar(500), note)
        .query(`
          INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
          OUTPUT INSERTED.drawing_ref_id AS drawingRefId
          VALUES (@formatId, @partNo, @processCode, @drawingNo, @drawingName, @fileUrl, @note)
        `);
      res.status(201).json({ drawingRefId: rs.recordset[0].drawingRefId });
    } catch (e) {
      res.status(500).json({ message: e.message });
    }
  });

  app.patch("/api/admin/drawings/:drawingRefId", async (req, res) => {
    const drawingRefId = Number(req.params.drawingRefId);
    const b = req.body || {};
    if (!drawingRefId) return res.status(400).json({ message: "invalid id" });
    try {
      const pool = await getPool();
      const r = pool.request().input("id", sql.BigInt, drawingRefId);
      const sets = ["updated_at = SYSDATETIME()"];
      if (b.processCode !== undefined) {
        const pc = b.processCode != null && String(b.processCode).trim() !== "" ? String(b.processCode).trim() : null;
        r.input("processCode", sql.NVarChar(50), pc);
        sets.push("process_code = @processCode");
      }
      if (b.drawingNo != null) {
        r.input("drawingNo", sql.NVarChar(100), String(b.drawingNo).trim());
        sets.push("drawing_no = @drawingNo");
      }
      if (b.drawingName !== undefined) {
        r.input("drawingName", sql.NVarChar(200), b.drawingName != null ? String(b.drawingName).trim() : null);
        sets.push("drawing_name = @drawingName");
      }
      if (b.fileUrl !== undefined) {
        r.input("fileUrl", sql.NVarChar(500), b.fileUrl != null ? String(b.fileUrl).trim() : null);
        sets.push("file_url = @fileUrl");
      }
      if (b.note !== undefined) {
        r.input("note", sql.NVarChar(500), b.note != null ? String(b.note).trim() : null);
        sets.push("note = @note");
      }
      if (b.activeFlag != null) {
        r.input("activeFlag", sql.Bit, !!b.activeFlag);
        sets.push("active_flag = @activeFlag");
      }
      if (sets.length === 1) return res.status(400).json({ message: "nothing to update" });
      const rs = await r.query(`
        UPDATE dbo.drawing_reference SET ${sets.join(", ")}
        WHERE drawing_ref_id = @id;
        SELECT @@ROWCOUNT AS n;
      `);
      if (rs.recordset[0].n === 0) return res.status(404).json({ message: "not found" });
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ message: e.message });
    }
  });

  app.delete("/api/admin/drawings/:drawingRefId", async (req, res) => {
    const drawingRefId = Number(req.params.drawingRefId);
    const formatId = Number(req.query.formatId);
    const partNo = normalizePartNo(req.query.partNo);
    if (!drawingRefId || !formatId || !partNo) {
      return res.status(400).json({ message: "drawingRefId, formatId and partNo query are required" });
    }
    try {
      const pool = await getPool();
      const row = await pool.request()
        .input("id", sql.BigInt, drawingRefId)
        .input("formatId", sql.Int, formatId)
        .input("partNo", sql.NVarChar(100), partNo)
        .query(`
          SELECT process_code AS processCode FROM dbo.drawing_reference
          WHERE drawing_ref_id = @id AND format_id = @formatId AND part_no = @partNo
        `);
      if (!row.recordset.length) return res.status(404).json({ message: "not found" });
      await pool.request()
        .input("id", sql.BigInt, drawingRefId)
        .query(`DELETE FROM dbo.drawing_reference WHERE drawing_ref_id = @id`);
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ message: e.message });
    }
  });

  app.post("/api/admin/point-checks", async (req, res) => {
    const b = req.body || {};
    const formatId = Number(b.formatId);
    const partNo = normalizePartNo(b.partNo);
    const checkCode = String(b.checkCode || "").trim().toUpperCase().slice(0, 1);
    const pointCheckText = String(b.pointCheckText || b.checkPoint || "").trim();
    const processCode = b.processCode != null && String(b.processCode).trim() !== ""
      ? String(b.processCode).trim()
      : null;
    const inputMode = String(b.inputMode || "OKNG").trim().toUpperCase();
    let criteriaMin;
    let criteriaMax;
    try {
      criteriaMin = parseNullableDecimal(b.criteriaMin, "criteriaMin");
      criteriaMax = parseNullableDecimal(b.criteriaMax, "criteriaMax");
    } catch (e) {
      return res.status(400).json({ message: e.message });
    }
    if (!formatId || !partNo || !pointCheckText || !/[A-M]/.test(checkCode)) {
      return res.status(400).json({ message: "formatId, partNo, checkCode A–M, pointCheckText are required" });
    }
    if (!["OKNG", "NUMERIC"].includes(inputMode)) {
      return res.status(400).json({ message: "inputMode must be OKNG or NUMERIC" });
    }
    if (criteriaMin != null && criteriaMax != null && criteriaMin > criteriaMax) {
      return res.status(400).json({ message: "criteriaMin must be <= criteriaMax" });
    }
    try {
      const pool = await getPool();
      const hasInputMode = await hasPointCheckInputModeColumn(pool);
      const hasCriteriaRange = await hasPointCheckCriteriaRangeColumns(pool);
      const rs = await pool.request()
        .input("formatId", sql.Int, formatId)
        .input("partNo", sql.NVarChar(100), partNo)
        .input("processCode", sql.NVarChar(50), processCode)
        .input("checkCode", sql.NChar(1), checkCode)
        .input("checkPoint", sql.NVarChar(300), pointCheckText)
        .input("criteria", sql.NVarChar(300), b.criteria != null ? String(b.criteria).trim() : null)
        .input("checkMethod", sql.NVarChar(300), b.checkMethod != null ? String(b.checkMethod).trim() : null)
        .input("note", sql.NVarChar(500), b.note != null ? String(b.note).trim() : null)
        .input("inputMode", sql.VarChar(20), inputMode)
        .input("criteriaMin", sql.Decimal(18, 4), criteriaMin)
        .input("criteriaMax", sql.Decimal(18, 4), criteriaMax)
        .query(hasInputMode
          ? `
            INSERT INTO dbo.point_check_reference
              (format_id, part_no, process_code, check_code, check_point, criteria, check_method, note, input_mode
              ${hasCriteriaRange ? ", criteria_min, criteria_max" : ""})
            OUTPUT INSERTED.point_check_ref_id AS pointCheckRefId
            VALUES (@formatId, @partNo, @processCode, @checkCode, @checkPoint, @criteria, @checkMethod, @note, @inputMode
            ${hasCriteriaRange ? ", @criteriaMin, @criteriaMax" : ""})
          `
          : `
            INSERT INTO dbo.point_check_reference
              (format_id, part_no, process_code, check_code, check_point, criteria, check_method, note
              ${hasCriteriaRange ? ", criteria_min, criteria_max" : ""})
            OUTPUT INSERTED.point_check_ref_id AS pointCheckRefId
            VALUES (@formatId, @partNo, @processCode, @checkCode, @checkPoint, @criteria, @checkMethod, @note
            ${hasCriteriaRange ? ", @criteriaMin, @criteriaMax" : ""})
          `);
      res.status(201).json({ pointCheckRefId: rs.recordset[0].pointCheckRefId });
    } catch (e) {
      res.status(500).json({ message: e.message });
    }
  });

  app.patch("/api/admin/point-checks/:pointCheckRefId", async (req, res) => {
    const id = Number(req.params.pointCheckRefId);
    const b = req.body || {};
    if (!id) return res.status(400).json({ message: "invalid id" });
    try {
      const pool = await getPool();
      const hasInputMode = await hasPointCheckInputModeColumn(pool);
      const hasCriteriaRange = await hasPointCheckCriteriaRangeColumns(pool);
      const r = pool.request().input("id", sql.BigInt, id);
      const sets = ["updated_at = SYSDATETIME()"];
      if (b.processCode !== undefined) {
        const pc = b.processCode != null && String(b.processCode).trim() !== "" ? String(b.processCode).trim() : null;
        r.input("processCode", sql.NVarChar(50), pc);
        sets.push("process_code = @processCode");
      }
      if (b.checkCode != null) {
        const cc = String(b.checkCode).trim().toUpperCase().slice(0, 1);
        if (!/[A-M]/.test(cc)) return res.status(400).json({ message: "checkCode must be A–M" });
        r.input("checkCode", sql.NChar(1), cc);
        sets.push("check_code = @checkCode");
      }
      if (b.pointCheckText != null) {
        r.input("checkPoint", sql.NVarChar(300), String(b.pointCheckText).trim());
        sets.push("check_point = @checkPoint");
      }
      if (b.criteria !== undefined) {
        r.input("criteria", sql.NVarChar(300), b.criteria != null ? String(b.criteria).trim() : null);
        sets.push("criteria = @criteria");
      }
      if (b.checkMethod !== undefined) {
        r.input("checkMethod", sql.NVarChar(300), b.checkMethod != null ? String(b.checkMethod).trim() : null);
        sets.push("check_method = @checkMethod");
      }
      if (b.note !== undefined) {
        r.input("note", sql.NVarChar(500), b.note != null ? String(b.note).trim() : null);
        sets.push("note = @note");
      }
      if (b.inputMode !== undefined) {
        const inputMode = String(b.inputMode || "OKNG").trim().toUpperCase();
        if (!["OKNG", "NUMERIC"].includes(inputMode)) {
          return res.status(400).json({ message: "inputMode must be OKNG or NUMERIC" });
        }
        if (hasInputMode) {
          r.input("inputMode", sql.VarChar(20), inputMode);
          sets.push("input_mode = @inputMode");
        }
      }
      if ((b.criteriaMin !== undefined || b.criteriaMax !== undefined) && hasCriteriaRange) {
        let criteriaMin;
        let criteriaMax;
        try {
          criteriaMin = b.criteriaMin !== undefined ? parseNullableDecimal(b.criteriaMin, "criteriaMin") : undefined;
          criteriaMax = b.criteriaMax !== undefined ? parseNullableDecimal(b.criteriaMax, "criteriaMax") : undefined;
        } catch (e) {
          return res.status(400).json({ message: e.message });
        }
        if (criteriaMin !== undefined && criteriaMax !== undefined && criteriaMin != null && criteriaMax != null && criteriaMin > criteriaMax) {
          return res.status(400).json({ message: "criteriaMin must be <= criteriaMax" });
        }
        if (criteriaMin !== undefined) {
          r.input("criteriaMin", sql.Decimal(18, 4), criteriaMin);
          sets.push("criteria_min = @criteriaMin");
        }
        if (criteriaMax !== undefined) {
          r.input("criteriaMax", sql.Decimal(18, 4), criteriaMax);
          sets.push("criteria_max = @criteriaMax");
        }
      }
      if (b.activeFlag != null) {
        r.input("activeFlag", sql.Bit, !!b.activeFlag);
        sets.push("active_flag = @activeFlag");
      }
      if (sets.length === 1) return res.status(400).json({ message: "nothing to update" });
      const rs = await r.query(`
        UPDATE dbo.point_check_reference SET ${sets.join(", ")}
        WHERE point_check_ref_id = @id;
        SELECT @@ROWCOUNT AS n;
      `);
      if (rs.recordset[0].n === 0) return res.status(404).json({ message: "not found" });
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ message: e.message });
    }
  });

  app.delete("/api/admin/point-checks/:pointCheckRefId", async (req, res) => {
    const id = Number(req.params.pointCheckRefId);
    const formatId = Number(req.query.formatId);
    const partNo = normalizePartNo(req.query.partNo);
    if (!id || !formatId || !partNo) {
      return res.status(400).json({ message: "pointCheckRefId, formatId and partNo query are required" });
    }
    try {
      const pool = await getPool();
      const v = await pool.request()
        .input("id", sql.BigInt, id)
        .input("formatId", sql.Int, formatId)
        .input("partNo", sql.NVarChar(100), partNo)
        .query(`
          SELECT 1 AS x FROM dbo.point_check_reference
          WHERE point_check_ref_id = @id AND format_id = @formatId AND part_no = @partNo
        `);
      if (!v.recordset.length) return res.status(404).json({ message: "not found" });
      await pool.request()
        .input("id", sql.BigInt, id)
        .query(`DELETE FROM dbo.point_check_reference WHERE point_check_ref_id = @id`);
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ message: e.message });
    }
  });

  /** Customer abbrev for header (part_customer) */
  app.patch("/api/admin/parts/:partNo/customer", async (req, res) => {
    const partNo = normalizePartNo(req.params.partNo);
    const formatId = Number(req.query.formatId);
    let abbrev = (req.body || {}).customerAbbrev;
    abbrev = abbrev != null ? String(abbrev).trim() : "";
    if (!formatId || !partNo) {
      return res.status(400).json({ message: "formatId query and partNo path are required" });
    }
    try {
      const pool = await getPool();
      if (abbrev === "") {
        await pool.request()
          .input("formatId", sql.Int, formatId)
          .input("partNo", sql.NVarChar(100), partNo)
          .query(`DELETE FROM dbo.part_customer WHERE format_id = @formatId AND part_no = @partNo`);
        return res.json({ ok: true, customerAbbrev: null });
      }
      const a = abbrev.slice(0, 50);
      await pool.request()
        .input("formatId", sql.Int, formatId)
        .input("partNo", sql.NVarChar(100), partNo)
        .input("abbrev", sql.NVarChar(50), a)
        .query(`
          MERGE dbo.part_customer AS t
          USING (SELECT @formatId AS format_id, @partNo AS part_no, @abbrev AS customer_abbrev) AS s
          ON t.format_id = s.format_id AND t.part_no = s.part_no
          WHEN MATCHED THEN
            UPDATE SET customer_abbrev = s.customer_abbrev, active_flag = 1, updated_at = SYSDATETIME()
          WHEN NOT MATCHED THEN
            INSERT (format_id, part_no, customer_abbrev, active_flag)
            VALUES (s.format_id, s.part_no, s.customer_abbrev, 1);
        `);
      res.json({ ok: true, customerAbbrev: a });
    } catch (e) {
      res.status(500).json({ message: e.message });
    }
  });

  /** Update part display name on part master */
  app.patch("/api/admin/parts/:partNo/name", async (req, res) => {
    const partNo = normalizePartNo(req.params.partNo);
    const formatId = Number(req.query.formatId);
    const partName = String((req.body || {}).partName || "").trim();
    if (!formatId || !partNo || !partName) {
      return res.status(400).json({ message: "formatId query and partName body required" });
    }
    try {
      const pool = await getPool();
      const rs = await pool.request()
        .input("formatId", sql.Int, formatId)
        .input("partNo", sql.NVarChar(100), partNo)
        .input("partName", sql.NVarChar(200), partName)
        .query(`
          IF OBJECT_ID('dbo.part_master', 'U') IS NULL
          BEGIN
            THROW 50001, 'part_master table not found. Run sql/17_part_master.sql first.', 1;
          END

          UPDATE dbo.part_master
          SET part_name = @partName, active_flag = 1, updated_at = SYSDATETIME()
          WHERE format_id = @formatId
            AND UPPER(LTRIM(RTRIM(part_no))) = @partNo
          ;
          SELECT @@ROWCOUNT AS n;
        `);
      if (rs.recordset[0].n === 0) {
        await pool.request()
          .input("formatId", sql.Int, formatId)
          .input("partNo", sql.NVarChar(100), partNo)
          .input("partName", sql.NVarChar(200), partName)
          .query(`
            INSERT INTO dbo.part_master (format_id, part_no, part_name, active_flag)
            VALUES (@formatId, @partNo, @partName, 1)
          `);
        return res.json({ ok: true, created: true });
      }
      res.json({ ok: true, created: false });
    } catch (e) {
      res.status(500).json({ message: e.message });
    }
  });
}

module.exports = { registerAdminRoutes };
