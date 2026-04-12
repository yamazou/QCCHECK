/**
 * Master data admin API (parts, processes, drawings, point checks).
 */

function registerAdminRoutes(app, sql, getPool) {
  async function nextProcessDisplayOrder(pool, formatId) {
    const rs = await pool.request()
      .input("formatId", sql.Int, formatId)
      .query(`
        SELECT ISNULL(MAX(display_order), 0) + 1 AS n
        FROM dbo.format_process_master
        WHERE format_id = @formatId
      `);
    return rs.recordset[0].n;
  }

  /** Catalog: all parts (from process master) + processes per part */
  app.get("/api/admin/catalog", async (req, res) => {
    const formatId = Number(req.query.formatId);
    if (!formatId) return res.status(400).json({ message: "formatId is required" });
    try {
      const pool = await getPool();
      const nameRs = await pool.request()
        .input("formatId", sql.Int, formatId)
        .query(`
          SELECT dr.part_no AS partNo, dr.drawing_name AS partName
          FROM dbo.drawing_reference dr
          WHERE dr.format_id = @formatId AND dr.process_code IS NULL AND dr.active_flag = 1
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
          FROM dbo.format_process_master
          WHERE format_id = @formatId AND part_no IS NOT NULL
          ORDER BY part_no, display_order
        `);

      const partMap = new Map();
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

  /** Drawings + point checks for one part (admin; includes inactive) */
  app.get("/api/admin/part-detail", async (req, res) => {
    const formatId = Number(req.query.formatId);
    const partNo = String(req.query.partNo || "").trim().toUpperCase();
    if (!formatId || !partNo) {
      return res.status(400).json({ message: "formatId and partNo are required" });
    }
    try {
      const pool = await getPool();
      const dr = await pool.request()
        .input("formatId", sql.Int, formatId)
        .input("partNo", sql.NVarChar(100), partNo)
        .query(`
          SELECT dr.drawing_ref_id AS drawingRefId, dr.process_code AS processCode, dr.drawing_no AS drawingNo,
                 dr.drawing_name AS drawingName, dr.file_url AS fileUrl, dr.note, dr.active_flag AS activeFlag
          FROM dbo.drawing_reference dr
          LEFT JOIN dbo.format_process_master fpm
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
        .query(`
          SELECT pcr.point_check_ref_id AS pointCheckRefId, pcr.process_code AS processCode, pcr.check_code AS checkCode,
                 pcr.check_point AS pointCheckText, pcr.criteria, pcr.check_method AS checkMethod, pcr.note, pcr.active_flag AS activeFlag
          FROM dbo.point_check_reference pcr
          LEFT JOIN dbo.format_process_master fpm
            ON fpm.format_id = pcr.format_id
            AND fpm.part_no = pcr.part_no
            AND pcr.process_code IS NOT NULL
            AND fpm.process_name = pcr.process_code
          WHERE pcr.format_id = @formatId AND pcr.part_no = @partNo
          ORDER BY
            CASE WHEN pcr.process_code IS NULL THEN 0 ELSE 1 END,
            CASE WHEN pcr.process_code IS NULL THEN 0 ELSE COALESCE(fpm.display_order, 2147483646) END,
            pcr.process_code,
            pcr.check_code
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

  /** New part: assembly drawing row + one initial process */
  app.post("/api/admin/parts", async (req, res) => {
    const { formatId, partNo, partName, firstProcessName } = req.body || {};
    const pn = String(partNo || "").trim().toUpperCase();
    const pname = String(partName || "").trim();
    const proc0 = String(firstProcessName || "SHEARING").trim() || "SHEARING";
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
        .query(`SELECT 1 AS x FROM dbo.format_process_master WHERE format_id=@formatId AND part_no=@partNo`);
      if (dup.recordset.length) {
        await transaction.rollback();
        return res.status(409).json({ message: "partNo already exists for this format" });
      }

      const ord = await nextProcessDisplayOrder(pool, Number(formatId));

      await new sql.Request(transaction)
        .input("formatId", sql.Int, Number(formatId))
        .input("partNo", sql.NVarChar(50), pn)
        .input("processName", sql.NVarChar(200), proc0)
        .input("displayOrder", sql.Int, ord)
        .query(`
          INSERT INTO dbo.format_process_master (format_id, part_no, process_name, display_order)
          VALUES (@formatId, @partNo, @processName, @displayOrder)
        `);

      await new sql.Request(transaction)
        .input("formatId", sql.Int, Number(formatId))
        .input("partNo", sql.NVarChar(100), pn)
        .input("drawingNo", sql.NVarChar(100), `${pn}-ASM`)
        .input("drawingName", sql.NVarChar(200), pname)
        .query(`
          INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note)
          VALUES (@formatId, @partNo, NULL, @drawingNo, @drawingName, NULL, N'Registered from part master')
        `);

      await transaction.commit();
      res.status(201).json({ ok: true, partNo: pn });
    } catch (e) {
      if (transaction) try { await transaction.rollback(); } catch (_e) { /* ignore */ }
      res.status(500).json({ message: e.message });
    }
  });

  /**
   * Remove a part and all related rows: saved checksheets (header/process/row/checks),
   * format_process_master, drawing_reference, point_check_reference, part_customer (if table exists).
   */
  app.delete("/api/admin/parts/:partNo", async (req, res) => {
    const pn = String(req.params.partNo || "").trim().toUpperCase();
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
          SELECT 1 AS x FROM dbo.format_process_master
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
        DELETE FROM dbo.format_process_master
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
    const pn = String(partNo || "").trim().toUpperCase();
    const pname = String(processName || "").trim();
    if (!formatId || !pn || !pname) {
      return res.status(400).json({ message: "formatId, partNo, processName are required" });
    }
    try {
      const pool = await getPool();
      const ord = await nextProcessDisplayOrder(pool, Number(formatId));
      await pool.request()
        .input("formatId", sql.Int, Number(formatId))
        .input("partNo", sql.NVarChar(50), pn)
        .input("processName", sql.NVarChar(200), pname)
        .input("displayOrder", sql.Int, ord)
        .query(`
          INSERT INTO dbo.format_process_master (format_id, part_no, process_name, display_order)
          VALUES (@formatId, @partNo, @processName, @displayOrder)
        `);
      res.status(201).json({ ok: true, displayOrder: ord });
    } catch (e) {
      res.status(500).json({ message: e.message });
    }
  });

  app.patch("/api/admin/processes/:processMasterId", async (req, res) => {
    const id = Number(req.params.processMasterId);
    const { processName, activeFlag } = req.body || {};
    if (!id) return res.status(400).json({ message: "invalid processMasterId" });
    try {
      const pool = await getPool();
      const reqSql = pool.request().input("id", sql.Int, id);
      const sets = ["updated_at = SYSDATETIME()"];
      if (processName != null) {
        reqSql.input("processName", sql.NVarChar(200), String(processName).trim());
        sets.push("process_name = @processName");
      }
      if (activeFlag != null) {
        reqSql.input("activeFlag", sql.Bit, !!activeFlag);
        sets.push("active_flag = @activeFlag");
      }
      if (sets.length === 1) return res.status(400).json({ message: "nothing to update" });
      const rs = await reqSql.query(`
        UPDATE dbo.format_process_master SET ${sets.join(", ")}
        WHERE process_master_id = @id;
        SELECT @@ROWCOUNT AS n;
      `);
      if (rs.recordset[0].n === 0) return res.status(404).json({ message: "not found" });
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ message: e.message });
    }
  });

  app.delete("/api/admin/processes/:processMasterId", async (req, res) => {
    const id = Number(req.params.processMasterId);
    const formatId = Number(req.query.formatId);
    const partNo = String(req.query.partNo || "").trim().toUpperCase();
    if (!id || !formatId || !partNo) {
      return res.status(400).json({ message: "processMasterId, formatId and partNo query are required" });
    }
    try {
      const pool = await getPool();
      const v = await pool.request()
        .input("id", sql.Int, id)
        .input("formatId", sql.Int, formatId)
        .input("partNo", sql.NVarChar(50), partNo)
        .query(`
          SELECT 1 AS x FROM dbo.format_process_master
          WHERE process_master_id = @id AND format_id = @formatId AND part_no = @partNo
        `);
      if (!v.recordset.length) return res.status(404).json({ message: "not found" });
      const cnt = await pool.request()
        .input("id", sql.Int, id)
        .query(`SELECT COUNT(*) AS n FROM dbo.checksheet_process WHERE process_master_id = @id`);
      if (cnt.recordset[0].n > 0) {
        return res.status(409).json({ message: "Cannot delete: process is referenced by saved checksheets" });
      }
      await pool.request()
        .input("id", sql.Int, id)
        .query(`DELETE FROM dbo.format_process_master WHERE process_master_id = @id`);
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ message: e.message });
    }
  });

  app.post("/api/admin/drawings", async (req, res) => {
    const b = req.body || {};
    const formatId = Number(b.formatId);
    const partNo = String(b.partNo || "").trim().toUpperCase();
    const drawingNo = String(b.drawingNo || "").trim();
    const drawingName = b.drawingName != null ? String(b.drawingName).trim() : null;
    const fileUrl = b.fileUrl != null ? String(b.fileUrl).trim() : null;
    const note = b.note != null ? String(b.note).trim() : null;
    const processCode = b.processCode != null && String(b.processCode).trim() !== ""
      ? String(b.processCode).trim()
      : null;
    if (!formatId || !partNo || !drawingNo) {
      return res.status(400).json({ message: "formatId, partNo, drawingNo are required" });
    }
    try {
      const pool = await getPool();
      const rs = await pool.request()
        .input("formatId", sql.Int, formatId)
        .input("partNo", sql.NVarChar(100), partNo)
        .input("processCode", sql.NVarChar(50), processCode)
        .input("drawingNo", sql.NVarChar(100), drawingNo)
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
    const partNo = String(req.query.partNo || "").trim().toUpperCase();
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
    const partNo = String(b.partNo || "").trim().toUpperCase();
    const checkCode = String(b.checkCode || "").trim().toUpperCase().slice(0, 1);
    const pointCheckText = String(b.pointCheckText || b.checkPoint || "").trim();
    const processCode = b.processCode != null && String(b.processCode).trim() !== ""
      ? String(b.processCode).trim()
      : null;
    if (!formatId || !partNo || !pointCheckText || !/[A-G]/.test(checkCode)) {
      return res.status(400).json({ message: "formatId, partNo, checkCode A–G, pointCheckText are required" });
    }
    try {
      const pool = await getPool();
      const rs = await pool.request()
        .input("formatId", sql.Int, formatId)
        .input("partNo", sql.NVarChar(100), partNo)
        .input("processCode", sql.NVarChar(50), processCode)
        .input("checkCode", sql.NChar(1), checkCode)
        .input("checkPoint", sql.NVarChar(300), pointCheckText)
        .input("criteria", sql.NVarChar(300), b.criteria != null ? String(b.criteria).trim() : null)
        .input("checkMethod", sql.NVarChar(300), b.checkMethod != null ? String(b.checkMethod).trim() : null)
        .input("note", sql.NVarChar(500), b.note != null ? String(b.note).trim() : null)
        .query(`
          INSERT INTO dbo.point_check_reference
            (format_id, part_no, process_code, check_code, check_point, criteria, check_method, note)
          OUTPUT INSERTED.point_check_ref_id AS pointCheckRefId
          VALUES (@formatId, @partNo, @processCode, @checkCode, @checkPoint, @criteria, @checkMethod, @note)
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
      const r = pool.request().input("id", sql.BigInt, id);
      const sets = ["updated_at = SYSDATETIME()"];
      if (b.processCode !== undefined) {
        const pc = b.processCode != null && String(b.processCode).trim() !== "" ? String(b.processCode).trim() : null;
        r.input("processCode", sql.NVarChar(50), pc);
        sets.push("process_code = @processCode");
      }
      if (b.checkCode != null) {
        const cc = String(b.checkCode).trim().toUpperCase().slice(0, 1);
        if (!/[A-G]/.test(cc)) return res.status(400).json({ message: "checkCode must be A–G" });
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
    const partNo = String(req.query.partNo || "").trim().toUpperCase();
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
    const partNo = String(req.params.partNo || "").trim().toUpperCase();
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

  /** Update part display name (assembly drawing row, process_code IS NULL) */
  app.patch("/api/admin/parts/:partNo/name", async (req, res) => {
    const partNo = String(req.params.partNo || "").trim().toUpperCase();
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
        .input("drawingName", sql.NVarChar(200), partName)
        .query(`
          UPDATE dbo.drawing_reference
          SET drawing_name = @drawingName, updated_at = SYSDATETIME()
          WHERE format_id = @formatId AND part_no = @partNo AND process_code IS NULL AND active_flag = 1;
          SELECT @@ROWCOUNT AS n;
        `);
      if (rs.recordset[0].n === 0) {
        return res.status(404).json({ message: "assembly drawing row not found; create part first" });
      }
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ message: e.message });
    }
  });
}

module.exports = { registerAdminRoutes };
