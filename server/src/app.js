require("dotenv").config();
const express = require("express");
const fs = require("fs");
const path = require("path");
const multer = require("multer");
const XLSX = require("xlsx");
const { sql, getPool } = require("./db");
const { registerAdminRoutes } = require("./adminRoutes");

const app = express();
app.use(express.json({ limit: "5mb" }));
app.use(express.static(path.join(__dirname, "..", "public")));
/** Browsers treat conditional GETs as 304; fetch() sets ok=false for 304, which breaks JSON clients. */
app.use((req, res, next) => {
  if (String(req.path || "").startsWith("/api")) {
    res.set("Cache-Control", "no-store, no-cache, must-revalidate");
    res.set("Pragma", "no-cache");
  }
  next();
});

function normalizePartNo(input) {
  let s = String(input || "").trim();
  try {
    s = s.normalize("NFKC");
  } catch (_e) {
    /* ignore */
  }
  s = s.replace(/[\u200B-\u200D\uFEFF]/g, "");
  s = s.replace(/\s+/g, "").replace(/-/g, "").toUpperCase();
  return s;
}

/** T-SQL expression aligned with {@link normalizePartNo} for WHERE/JOIN on nvarchar part_no columns. */
function sqlNormPartNoExpr(column) {
  const c = String(column);
  let e = `LTRIM(RTRIM(ISNULL(${c}, N'')))`;
  e = `REPLACE(${e}, NCHAR(0xFEFF), N'')`;
  for (const code of [9, 10, 13, 32]) {
    e = `REPLACE(${e}, CHAR(${code}), N'')`;
  }
  e = `REPLACE(${e}, NCHAR(0x00A0), N'')`;
  e = `REPLACE(${e}, NCHAR(0x3000), N'')`;
  e = `REPLACE(${e}, N'-', N'')`;
  e = `UPPER(${e})`;
  return e;
}

const publicDir = path.join(__dirname, "..", "public");
const uploadRootDir = path.join(publicDir, "uploads");
const uploadLogoDir = path.join(uploadRootDir, "logos");
const uploadDrawingDir = path.join(uploadRootDir, "drawings");
fs.mkdirSync(uploadLogoDir, { recursive: true });
fs.mkdirSync(uploadDrawingDir, { recursive: true });

function sanitizeBaseName(name) {
  return String(name || "image")
    .replace(/\.[^/.]+$/, "")
    .replace(/[^a-zA-Z0-9_-]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 60) || "image";
}

const uploadStorage = multer.diskStorage({
  destination: (req, _file, cb) => {
    const type = String(req.query.type || "").trim().toLowerCase();
    cb(null, type === "logo" ? uploadLogoDir : uploadDrawingDir);
  },
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname || "").toLowerCase() || ".png";
    const base = sanitizeBaseName(file.originalname);
    const stamp = `${Date.now()}-${Math.round(Math.random() * 1e6)}`;
    cb(null, `${base}-${stamp}${ext}`);
  }
});

const uploadImage = multer({
  storage: uploadStorage,
  limits: { fileSize: 8 * 1024 * 1024 }, // 8MB
  fileFilter: (_req, file, cb) => {
    if (!file.mimetype || !file.mimetype.startsWith("image/")) {
      return cb(new Error("Only image files are allowed"));
    }
    cb(null, true);
  }
});

app.post("/api/admin/upload-image", (req, res) => {
  const type = String(req.query.type || "").trim().toLowerCase();
  if (!["logo", "drawing"].includes(type)) {
    return res.status(400).json({ message: "type query must be logo or drawing" });
  }
  uploadImage.single("file")(req, res, (err) => {
    if (err) return res.status(400).json({ message: err.message || "upload failed" });
    if (!req.file) return res.status(400).json({ message: "file is required" });
    const subDir = type === "logo" ? "logos" : "drawings";
    const fileUrl = `/uploads/${subDir}/${req.file.filename}`;
    res.status(201).json({
      ok: true,
      fileUrl,
      fileName: req.file.filename,
      originalName: req.file.originalname
    });
  });
});

/** Avoid TDS errors with nullable fixed-size NVarChar; trim and map blank to null. */
function nullableAscii(value, maxLen) {
  if (value === undefined || value === null) return null;
  const s = String(value).trim();
  if (s === "") return null;
  return s.length > maxLen ? s.slice(0, maxLen) : s;
}

/** Normalize effective month input to first day (YYYY-MM-01). */
function normalizeEffDate(value) {
  if (value === undefined || value === null) return null;
  const s = String(value).trim();
  if (!s) return null;
  const m = s.match(/^(\d{4})-(\d{2})/);
  if (!m) return s;
  return `${m[1]}-${m[2]}-01`;
}

/** Saved checksheet row results: A–G columns only for now (master point checks may use A–M). */
const ALLOWED_SHEET_CHECK_CODES = new Set("ABCDEFG".split(""));

function validateRow(row) {
  if (!row || typeof row !== "object") return "row is required";
  if (row.rowNo < 1) return "rowNo must be >= 1";
  const nums = ["qty", "okCount", "ngCount"];
  for (const key of nums) {
    if (row[key] != null && row[key] < 0) return `${key} must be >= 0`;
  }
  if (row.qty != null && row.okCount != null && row.ngCount != null) {
    if (row.okCount + row.ngCount > row.qty) return "okCount + ngCount must be <= qty";
  }
  if (Array.isArray(row.checks)) {
    for (const c of row.checks) {
      if (!ALLOWED_SHEET_CHECK_CODES.has(c.checkCode)) return "invalid checkCode";
      if (c.result != null && String(c.result).trim().length > 50) return "result must be <= 50 chars";
    }
  }
  return null;
}

async function insertChecksheetProcesses(transaction, headerId, body) {
  for (const p of body.processes) {
    const processRs = await new sql.Request(transaction)
      .input("headerId", sql.BigInt, headerId)
      .input("processMasterId", sql.Int, p.processMasterId || null)
      .input("processName", sql.NVarChar(200), p.processName || "")
      .input("displayOrder", sql.Int, p.displayOrder || 999)
      .query(`
          INSERT INTO dbo.checksheet_process
          (header_id, process_master_id, process_name_snapshot, display_order)
          OUTPUT INSERTED.process_id
          VALUES
          (@headerId, @processMasterId, @processName, @displayOrder)
        `);

    const processId = processRs.recordset[0].process_id;
    const procRows = Array.isArray(p.rows) ? p.rows : [];

    for (const r of procRows) {
      const rowRs = await new sql.Request(transaction)
        .input("processId", sql.BigInt, processId)
        .input("rowNo", sql.Int, r.rowNo)
        .input("workDate", sql.Date, r.workDate || null)
        .input("startTime", sql.VarChar(16), nullableAscii(r.startTime, 16))
        .input("finishTime", sql.VarChar(16), nullableAscii(r.finishTime, 16))
        .input("qty", sql.Int, r.qty ?? null)
        .input("okCount", sql.Int, r.okCount ?? null)
        .input("ngCount", sql.Int, r.ngCount ?? null)
        .input("machineNo", sql.NVarChar(100), r.machineNo != null && String(r.machineNo).trim() !== "" ? String(r.machineNo).trim().slice(0, 100) : null)
        .input("pic", sql.NVarChar(100), r.pic != null && String(r.pic).trim() !== "" ? String(r.pic).trim().slice(0, 100) : null)
        .input("sopCheck", sql.Bit, r.sopCheck == null ? null : !!r.sopCheck)
        .input("leaderCheck", sql.VarChar(20), nullableAscii(r.leaderCheck, 20))
        .input("remarks", sql.NVarChar(500), r.remarks != null && String(r.remarks).trim() !== "" ? String(r.remarks).trim().slice(0, 500) : null)
        .query(`
            INSERT INTO dbo.checksheet_row
            (process_id, row_no, work_date, start_time, finish_time, qty, ok_count, ng_count, machine_no, pic, sop_check, leader_check, remarks)
            OUTPUT INSERTED.row_id
            VALUES
            (@processId, @rowNo, @workDate, TRY_CONVERT(time(0), @startTime), TRY_CONVERT(time(0), @finishTime), @qty, @okCount, @ngCount, @machineNo, @pic, @sopCheck, @leaderCheck, @remarks)
          `);

      const rowId = rowRs.recordset[0].row_id;
      const checks = Array.isArray(r.checks) ? r.checks : [];
      for (const c of checks) {
        await new sql.Request(transaction)
          .input("rowId", sql.BigInt, rowId)
          .input("checkCode", sql.NChar(1), c.checkCode)
          .input("result", sql.NVarChar(50), c.result != null ? String(c.result).trim().slice(0, 50) : null)
          .query(`
              INSERT INTO dbo.checksheet_row_check (row_id, check_code, result)
              VALUES (@rowId, @checkCode, @result)
            `);
      }
    }
  }
}

async function deleteChecksheetProcessRows(transaction, headerId) {
  await new sql.Request(transaction).input("headerId", sql.BigInt, headerId).query(`
      DELETE FROM dbo.checksheet_row_check
      WHERE row_id IN (
        SELECT r.row_id FROM dbo.checksheet_row r
        INNER JOIN dbo.checksheet_process p ON p.process_id = r.process_id
        WHERE p.header_id = @headerId
      );
    `);
  await new sql.Request(transaction).input("headerId", sql.BigInt, headerId).query(`
      DELETE FROM dbo.checksheet_row
      WHERE process_id IN (SELECT process_id FROM dbo.checksheet_process WHERE header_id = @headerId);
    `);
  await new sql.Request(transaction).input("headerId", sql.BigInt, headerId).query(`
      DELETE FROM dbo.checksheet_process WHERE header_id = @headerId;
    `);
}

function validateChecksheetBody(body) {
  if (!body || !body.formatId || !body.partNo || !body.partName) {
    return "formatId, partNo, partName are required";
  }
  if (!Array.isArray(body.processes)) {
    return "processes is required";
  }
  for (const p of body.processes) {
    if (!Array.isArray(p.rows)) continue;
    for (const r of p.rows) {
      const err = validateRow(r);
      if (err) return err;
    }
  }
  return null;
}

function mapChecksheetSaveError(error) {
  const message = error && error.message ? String(error.message) : "unknown error";
  if (message.includes("CK_cr_row_no")) {
    return {
      status: 400,
      message:
        "Too many detail rows for this process (legacy DB limit: 31). Run sql/22_expand_checksheet_row_no.sql, then save again."
    };
  }
  return { status: 500, message };
}

/** Cached once: avoids COL_LENGTH round-trips on every /api/references call. */
let pointCheckRefSchemaCache = null;

async function getPointCheckRefSchema(pool) {
  if (pointCheckRefSchemaCache) return pointCheckRefSchemaCache;
  const colRs = await pool.request().query(`
      SELECT
        CASE WHEN COL_LENGTH('dbo.point_check_reference', 'input_mode') IS NULL THEN 0 ELSE 1 END AS hasInputMode,
        CASE WHEN COL_LENGTH('dbo.point_check_reference', 'criteria_min') IS NULL THEN 0 ELSE 1 END AS hasCriteriaMin,
        CASE WHEN COL_LENGTH('dbo.point_check_reference', 'criteria_max') IS NULL THEN 0 ELSE 1 END AS hasCriteriaMax
    `);
  const row = colRs.recordset[0] || {};
  pointCheckRefSchemaCache = {
    hasInputMode: !!row.hasInputMode,
    hasCriteriaRange: !!(row.hasCriteriaMin && row.hasCriteriaMax)
  };
  return pointCheckRefSchemaCache;
}

/** `res.json` / `JSON.stringify` throw on bigint (common for BIGINT columns in node-mssql). */
function jsonSanitizeForResponse(value) {
  if (value === undefined) return undefined;
  if (value === null) return null;
  if (typeof value === "bigint") return String(value);
  if (Buffer.isBuffer(value)) return value.length > 0 && value[0] === 1;
  if (Array.isArray(value)) return value.map(jsonSanitizeForResponse);
  if (value instanceof Date) {
    const t = value.getTime();
    return Number.isNaN(t) ? null : value.toISOString();
  }
  if (typeof value === "object") {
    const o = {};
    for (const [k, v] of Object.entries(value)) {
      o[k] = jsonSanitizeForResponse(v);
    }
    return o;
  }
  return value;
}

/** Deep clone for API: stringify replacer hits every nested bigint (tedious Row spread can still hide some). */
function serializeChecksheetDetailForClient(raw) {
  try {
    return JSON.parse(
      JSON.stringify(raw, (_key, val) => {
        if (typeof val === "bigint") return val.toString();
        if (Buffer.isBuffer(val)) return val.length > 0 && val[0] === 1;
        if (val instanceof Date) {
          const t = val.getTime();
          return Number.isNaN(t) ? null : val.toISOString();
        }
        return val;
      })
    );
  } catch (_e) {
    return jsonSanitizeForResponse(raw);
  }
}

async function getChecksheetDetail(pool, headerId) {
  const n = Number(headerId);
  if (!Number.isFinite(n) || n <= 0) return null;
  const [headerRs, processRs, rowRs, checkRs] = await Promise.all([
    pool
      .request()
      .input("headerId", sql.BigInt, n)
      .query(`
      SELECT header_id AS headerId, format_id AS formatId, part_no AS partNo, part_name AS partName,
             eff_date AS effDate, rev_no AS revNo, department, sheet_date AS sheetDate,
             status, created_by AS createdBy, prepared_by AS preparedBy, checked_by AS checkedBy,
             approved_by AS approvedBy, footer_remarks AS footerRemarks,
             footer_remarks_1 AS footerRemarks1, footer_remarks_2 AS footerRemarks2, footer_remarks_3 AS footerRemarks3,
             created_at AS createdAt
      FROM dbo.checksheet_header
      WHERE header_id = @headerId
    `),
    pool
      .request()
      .input("headerId", sql.BigInt, n)
      .query(`
      SELECT process_id AS processId, process_master_id AS processMasterId,
             process_name_snapshot AS processName, display_order AS displayOrder
      FROM dbo.checksheet_process
      WHERE header_id = @headerId
      ORDER BY display_order
    `),
    pool
      .request()
      .input("headerId", sql.BigInt, n)
      .query(`
      SELECT r.row_id AS rowId, r.process_id AS processId, r.row_no AS rowNo, r.work_date AS workDate,
             CONVERT(varchar(8), r.start_time, 108) AS startTime,
             CONVERT(varchar(8), r.finish_time, 108) AS finishTime,
             r.qty, r.ok_count AS okCount,
             r.ng_count AS ngCount, r.machine_no AS machineNo, r.pic, r.sop_check AS sopCheck,
             r.leader_check AS leaderCheck, r.remarks
      FROM dbo.checksheet_row r
      JOIN dbo.checksheet_process p ON p.process_id = r.process_id
      WHERE p.header_id = @headerId
      ORDER BY p.display_order, r.row_no
    `),
    pool
      .request()
      .input("headerId", sql.BigInt, n)
      .query(`
      SELECT c.row_id AS rowId, c.check_code AS checkCode, c.result
      FROM dbo.checksheet_row_check c
      JOIN dbo.checksheet_row r ON r.row_id = c.row_id
      JOIN dbo.checksheet_process p ON p.process_id = r.process_id
      WHERE p.header_id = @headerId
      ORDER BY c.row_id, c.check_code
    `)
  ]);
  if (headerRs.recordset.length === 0) return null;

  /** BIGINT / Int can surface as number, string, or BigInt between queries — normalize Map keys. */
  const idKey = (v) => (v == null || v === "" ? "" : String(v));

  const checksByRow = new Map();
  for (const c of checkRs.recordset) {
    const rid = idKey(c.rowId);
    if (!rid) continue;
    if (!checksByRow.has(rid)) checksByRow.set(rid, []);
    checksByRow.get(rid).push(c);
  }

  const rowsByProcess = new Map();
  for (const r of rowRs.recordset) {
    const pid = idKey(r.processId);
    if (!pid) continue;
    if (!rowsByProcess.has(pid)) rowsByProcess.set(pid, []);
    rowsByProcess.get(pid).push({ ...r, checks: checksByRow.get(idKey(r.rowId)) || [] });
  }

  const processes = processRs.recordset.map((p) => ({
    ...p,
    rows: rowsByProcess.get(idKey(p.processId)) || []
  }));

  return serializeChecksheetDetailForClient({ ...headerRs.recordset[0], processes });
}

app.get("/api/health", async (_req, res) => {
  try {
    const pool = await getPool();
    await pool.request().query("SELECT 1 AS ok");
    res.json({ status: "ok" });
  } catch (e) {
    res.status(500).json({ status: "ng", message: e.message });
  }
});

app.get("/api/formats", async (_req, res) => {
  try {
    const pool = await getPool();
    const rs = await pool.request().query(`
      SELECT format_id AS formatId, format_code AS formatCode, format_name AS formatName
      FROM dbo.format_master
      WHERE active_flag = 1
      ORDER BY format_id
    `);
    res.json(rs.recordset);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

/**
 * Machines for checklist suggestions (active only), or full catalog for Monthly History sort (`forSort=1`).
 */
app.get("/api/machines", async (req, res) => {
  const forSort = String(req.query.forSort || "").trim() === "1";
  try {
    const pool = await getPool();
    const activeOnly = forSort ? "" : "WHERE active_flag = 1";
    const rs = await pool.request().query(`
      IF OBJECT_ID('dbo.machine_master', 'U') IS NULL
        SELECT CAST(NULL AS INT) AS machineMasterId,
               CAST(NULL AS NVARCHAR(100)) AS machineNo,
               CAST(NULL AS NVARCHAR(200)) AS machineName,
               CAST(NULL AS INT) AS displayOrder
        WHERE 1 = 0;
      ELSE
        SELECT machine_master_id AS machineMasterId, machine_no AS machineNo, machine_name AS machineName,
               display_order AS displayOrder
        FROM dbo.machine_master
        ${activeOnly}
        ORDER BY display_order, machine_no;
    `);
    res.json(rs.recordset);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get("/api/formats/:formatId/processes", async (req, res) => {
  const { formatId } = req.params;
  const { partNo } = req.query;
  try {
    const pool = await getPool();
    const request = pool.request().input("formatId", sql.Int, Number(formatId));
    let query = `
      SELECT process_master_id AS processMasterId, part_no AS partNo, process_name AS processName, display_order AS displayOrder
      FROM dbo.process_master
      WHERE format_id = @formatId AND active_flag = 1
    `;
    if (partNo) {
      request.input("partNo", sql.NVarChar(50), normalizePartNo(partNo));
      query += ` AND ${sqlNormPartNoExpr("part_no")} = @partNo`;
    }
    query += " ORDER BY display_order";
    const rs = await request.query(query);
    res.json(rs.recordset);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get("/api/formats/:formatId/parts", async (req, res) => {
  const { formatId } = req.params;
  try {
    const pool = await getPool();
    const pnF = sqlNormPartNoExpr("fmp.part_no");
    const pnP = sqlNormPartNoExpr("pm.part_no");
    const rs = await pool.request().input("formatId", sql.Int, Number(formatId)).query(`
      IF OBJECT_ID('dbo.part_master', 'U') IS NULL
      BEGIN
        THROW 50001, 'part_master table not found. Run sql/17_part_master.sql first.', 1;
      END
      SELECT DISTINCT
        LTRIM(RTRIM(fmp.part_no)) AS partNo,
        ISNULL(pm.part_name, fmp.part_no) AS partName
      FROM dbo.process_master fmp
      LEFT JOIN dbo.part_master pm
        ON pm.format_id = fmp.format_id
       AND ${pnP} = ${pnF}
       AND pm.active_flag = 1
      WHERE fmp.format_id = @formatId
        AND fmp.active_flag = 1
        AND fmp.part_no IS NOT NULL
      ORDER BY LTRIM(RTRIM(fmp.part_no))
    `);
    res.json(rs.recordset);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get("/api/formats/:formatId/header-branding", async (req, res) => {
  const formatId = Number(req.params.formatId);
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

app.get("/api/references", async (req, res) => {
  const formatId = Number(req.query.formatId);
  const partNo = normalizePartNo(req.query.partNo);
  if (!formatId || !partNo) {
    return res.status(400).json({ message: "formatId and partNo are required" });
  }

  try {
    const pool = await getPool();
    const schema = await getPointCheckRefSchema(pool);
    const hasInputMode = schema.hasInputMode;
    const hasCriteriaRange = schema.hasCriteriaRange;

    const drPn = sqlNormPartNoExpr("dr.part_no");
    const fpmDrPn = sqlNormPartNoExpr("fpm.part_no");
    const pcrPn = sqlNormPartNoExpr("pcr.part_no");
    const fpmPcrPn = sqlNormPartNoExpr("fpm.part_no");
    const pcustPn = sqlNormPartNoExpr("part_no");

    const drawingSql = `
        SELECT dr.drawing_ref_id AS drawingRefId, dr.process_code AS processCode, dr.drawing_no AS drawingNo,
               dr.drawing_name AS drawingName, dr.file_url AS fileUrl, dr.note
        FROM dbo.drawing_reference dr
        LEFT JOIN dbo.process_master fpm
          ON fpm.format_id = dr.format_id
          AND ${fpmDrPn} = ${drPn}
          AND dr.process_code IS NOT NULL
          AND fpm.process_name = dr.process_code
        WHERE dr.format_id = @formatId AND ${drPn} = @partNo AND dr.active_flag = 1
        ORDER BY
          CASE WHEN dr.process_code IS NULL THEN 0 ELSE 1 END,
          CASE WHEN dr.process_code IS NULL THEN 0 ELSE COALESCE(fpm.display_order, 2147483646) END,
          dr.process_code,
          dr.drawing_no
      `;
    const pointSql = `
        SELECT pcr.point_check_ref_id AS pointCheckRefId, pcr.process_code AS processCode, pcr.check_code AS checkCode,
               pcr.check_point AS pointCheckText, pcr.criteria, pcr.check_method AS checkMethod, pcr.note,
               ${hasInputMode ? "ISNULL(NULLIF(pcr.input_mode, ''), 'OKNG')" : "CAST('OKNG' AS VARCHAR(20))"} AS inputMode
               ${hasCriteriaRange
                  ? ", pcr.criteria_min AS criteriaMin, pcr.criteria_max AS criteriaMax"
                  : ", CAST(NULL AS DECIMAL(18,4)) AS criteriaMin, CAST(NULL AS DECIMAL(18,4)) AS criteriaMax"}
        FROM dbo.point_check_reference pcr
        LEFT JOIN dbo.process_master fpm
          ON fpm.format_id = pcr.format_id
          AND ${fpmPcrPn} = ${pcrPn}
          AND pcr.process_code IS NOT NULL
          AND fpm.process_name = pcr.process_code
        WHERE pcr.format_id = @formatId AND ${pcrPn} = @partNo AND pcr.active_flag = 1
        ORDER BY
          CASE WHEN pcr.process_code IS NULL THEN 0 ELSE 1 END,
          CASE WHEN pcr.process_code IS NULL THEN 0 ELSE COALESCE(fpm.display_order, 2147483646) END,
          pcr.process_code,
          pcr.check_code
      `;
    const custSql = `
        SELECT customer_abbrev AS customerAbbrev
        FROM dbo.part_customer
        WHERE format_id = @formatId AND ${pcustPn} = @partNo AND active_flag = 1
      `;

    const drawingReq = pool.request().input("formatId", sql.Int, formatId).input("partNo", sql.NVarChar(100), partNo);
    const pointReq = pool.request().input("formatId", sql.Int, formatId).input("partNo", sql.NVarChar(100), partNo);
    const custReq = pool.request().input("formatId", sql.Int, formatId).input("partNo", sql.NVarChar(100), partNo);

    const [drawingRs, pointRs, custRs] = await Promise.all([
      drawingReq.query(drawingSql),
      pointReq.query(pointSql),
      custReq.query(custSql)
    ]);
    const customerAbbrev =
      custRs.recordset.length && custRs.recordset[0].customerAbbrev != null
        ? String(custRs.recordset[0].customerAbbrev).trim()
        : null;

    res.json({
      drawings: drawingRs.recordset,
      pointChecks: pointRs.recordset,
      customerAbbrev: customerAbbrev || null
    });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get("/api/drawing-preview", async (req, res) => {
  const partNo = normalizePartNo(req.query.partNo);
  if (!partNo) return res.status(400).json({ message: "partNo is required" });

  const fileMap = {
    VDE1980: process.env.DRAWING_VDE1980_PATH || "C:\\Users\\lenovo\\Desktop\\format\\CS VDE1980.xlsx",
    VDK0970: process.env.DRAWING_VDK0970_PATH || "C:\\Users\\lenovo\\Desktop\\format\\CS VDK0970.xlsx"
  };
  const target = fileMap[partNo];
  if (!target) return res.status(404).json({ message: "drawing file is not mapped for this partNo" });

  try {
    const wb = XLSX.readFile(target, { cellFormula: false, cellStyles: false });
    const sheetName = wb.SheetNames[0];
    const ws = wb.Sheets[sheetName];
    const range = XLSX.utils.decode_range(ws["!ref"] || "A1");
    const maxRows = Math.min(range.e.r + 1, 140);
    const maxCols = Math.min(range.e.c + 1, 30);

    const headers = Array.from({ length: maxCols }, (_, i) => XLSX.utils.encode_col(i));
    const rows = [];
    for (let r = 0; r < maxRows; r++) {
      const row = [];
      let hasData = false;
      for (let c = 0; c < maxCols; c++) {
        const addr = XLSX.utils.encode_cell({ r, c });
        const cell = ws[addr];
        const value = cell ? String(cell.w ?? cell.v ?? "") : "";
        if (value !== "") hasData = true;
        row.push(value);
      }
      if (hasData) rows.push({ rowNo: r + 1, values: row });
    }

    res.json({ partNo, filePath: target, sheetName, headers, rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.post("/api/checksheets", async (req, res) => {
  const body = req.body;
  const verr = validateChecksheetBody(body);
  if (verr) return res.status(400).json({ message: verr });
  const effDate = normalizeEffDate(body.effDate);
  const partNoNorm = normalizePartNo(body.partNo);

  let transaction;
  try {
    const pool = await getPool();
    const hdrPn = sqlNormPartNoExpr("part_no");
    const existingRs = await pool
      .request()
      .input("formatId", sql.Int, body.formatId)
      .input("partNo", sql.NVarChar(100), partNoNorm)
      .input("effDate", sql.Date, effDate)
      .query(`
        SELECT TOP 1 header_id AS headerId
        FROM dbo.checksheet_header
        WHERE format_id = @formatId AND ${hdrPn} = @partNo AND eff_date = @effDate
        ORDER BY updated_at DESC, header_id DESC
      `);

    transaction = new sql.Transaction(pool);
    await transaction.begin();

    let headerId;
    if (existingRs.recordset.length > 0) {
      headerId = existingRs.recordset[0].headerId;
      await deleteChecksheetProcessRows(transaction, headerId);
      await new sql.Request(transaction)
        .input("headerId", sql.BigInt, headerId)
        .input("partName", sql.NVarChar(200), body.partName)
        .input("effDate", sql.Date, effDate)
        .input("revNo", sql.NVarChar(50), body.revNo || null)
        .input("department", sql.NVarChar(200), body.department || null)
        .input("sheetDate", sql.Date, body.sheetDate || null)
        .input("updatedBy", sql.NVarChar(100), body.createdBy || null)
        .input("preparedBy", sql.NVarChar(100), body.preparedBy || null)
        .input("checkedBy", sql.NVarChar(100), body.checkedBy || null)
        .input("approvedBy", sql.NVarChar(100), body.approvedBy || null)
        .input("footerRemarks", sql.NVarChar(1000), body.footerRemarks || null)
        .input("footerRemarks1", sql.NVarChar(500), body.footerRemarks1 || null)
        .input("footerRemarks2", sql.NVarChar(500), body.footerRemarks2 || null)
        .input("footerRemarks3", sql.NVarChar(500), body.footerRemarks3 || null)
        .query(`
          UPDATE dbo.checksheet_header
          SET part_name = @partName,
              eff_date = @effDate,
              rev_no = @revNo,
              department = @department,
              sheet_date = @sheetDate,
              updated_by = @updatedBy,
              updated_at = SYSDATETIME(),
              prepared_by = @preparedBy,
              checked_by = @checkedBy,
              approved_by = @approvedBy,
              footer_remarks = @footerRemarks,
              footer_remarks_1 = @footerRemarks1,
              footer_remarks_2 = @footerRemarks2,
              footer_remarks_3 = @footerRemarks3
          WHERE header_id = @headerId;
        `);
    } else {
      const headerRs = await new sql.Request(transaction)
        .input("formatId", sql.Int, body.formatId)
        .input("partNo", sql.NVarChar(100), partNoNorm)
        .input("partName", sql.NVarChar(200), body.partName)
        .input("effDate", sql.Date, effDate)
        .input("revNo", sql.NVarChar(50), body.revNo || null)
        .input("department", sql.NVarChar(200), body.department || null)
        .input("sheetDate", sql.Date, body.sheetDate || null)
        .input("createdBy", sql.NVarChar(100), body.createdBy || null)
        .input("preparedBy", sql.NVarChar(100), body.preparedBy || null)
        .input("checkedBy", sql.NVarChar(100), body.checkedBy || null)
        .input("approvedBy", sql.NVarChar(100), body.approvedBy || null)
        .input("footerRemarks", sql.NVarChar(1000), body.footerRemarks || null)
        .input("footerRemarks1", sql.NVarChar(500), body.footerRemarks1 || null)
        .input("footerRemarks2", sql.NVarChar(500), body.footerRemarks2 || null)
        .input("footerRemarks3", sql.NVarChar(500), body.footerRemarks3 || null)
        .query(`
          INSERT INTO dbo.checksheet_header
          (format_id, part_no, part_name, eff_date, rev_no, department, sheet_date, created_by, updated_by, prepared_by, checked_by, approved_by, footer_remarks, footer_remarks_1, footer_remarks_2, footer_remarks_3)
          OUTPUT INSERTED.header_id
          VALUES
          (@formatId, @partNo, @partName, @effDate, @revNo, @department, @sheetDate, @createdBy, @createdBy, @preparedBy, @checkedBy, @approvedBy, @footerRemarks, @footerRemarks1, @footerRemarks2, @footerRemarks3)
        `);
      headerId = headerRs.recordset[0].header_id;
    }
    await insertChecksheetProcesses(transaction, headerId, body);

    await transaction.commit();
    res.status(201).json({ headerId });
  } catch (e) {
    if (transaction) {
      try {
        await transaction.rollback();
      } catch (_ignored) {}
    }
    const err = mapChecksheetSaveError(e);
    res.status(err.status).json({ message: err.message });
  }
});

app.put("/api/checksheets/:headerId", async (req, res) => {
  const headerId = Number(req.params.headerId);
  const body = req.body;
  const verr = validateChecksheetBody(body);
  if (verr) return res.status(400).json({ message: verr });
  const effDate = normalizeEffDate(body.effDate);
  const partNoNorm = normalizePartNo(body.partNo);
  if (!Number.isFinite(headerId) || headerId < 1) {
    return res.status(400).json({ message: "invalid headerId" });
  }

  let transaction;
  try {
    const pool = await getPool();
    const hdrPnPut = sqlNormPartNoExpr("part_no");
    const match = await pool
      .request()
      .input("headerId", sql.BigInt, headerId)
      .input("formatId", sql.Int, body.formatId)
      .input("partNo", sql.NVarChar(100), partNoNorm)
      .input("effDate", sql.Date, effDate)
      .query(`
        SELECT header_id FROM dbo.checksheet_header
        WHERE header_id = @headerId AND format_id = @formatId AND ${hdrPnPut} = @partNo AND eff_date = @effDate
      `);
    if (match.recordset.length === 0) {
      return res.status(409).json({
        message: "header not found or does not match formatId, partNo, effDate"
      });
    }

    transaction = new sql.Transaction(pool);
    await transaction.begin();

    await deleteChecksheetProcessRows(transaction, headerId);

    await new sql.Request(transaction)
      .input("headerId", sql.BigInt, headerId)
      .input("partName", sql.NVarChar(200), body.partName)
      .input("effDate", sql.Date, effDate)
      .input("revNo", sql.NVarChar(50), body.revNo || null)
      .input("department", sql.NVarChar(200), body.department || null)
      .input("sheetDate", sql.Date, body.sheetDate || null)
      .input("updatedBy", sql.NVarChar(100), body.createdBy || null)
      .input("preparedBy", sql.NVarChar(100), body.preparedBy || null)
      .input("checkedBy", sql.NVarChar(100), body.checkedBy || null)
      .input("approvedBy", sql.NVarChar(100), body.approvedBy || null)
      .input("footerRemarks", sql.NVarChar(1000), body.footerRemarks || null)
      .input("footerRemarks1", sql.NVarChar(500), body.footerRemarks1 || null)
      .input("footerRemarks2", sql.NVarChar(500), body.footerRemarks2 || null)
      .input("footerRemarks3", sql.NVarChar(500), body.footerRemarks3 || null)
      .query(`
        UPDATE dbo.checksheet_header
        SET part_name = @partName,
            eff_date = @effDate,
            rev_no = @revNo,
            department = @department,
            sheet_date = @sheetDate,
            updated_by = @updatedBy,
            updated_at = SYSDATETIME(),
            prepared_by = @preparedBy,
            checked_by = @checkedBy,
            approved_by = @approvedBy,
            footer_remarks = @footerRemarks,
            footer_remarks_1 = @footerRemarks1,
            footer_remarks_2 = @footerRemarks2,
            footer_remarks_3 = @footerRemarks3
        WHERE header_id = @headerId;
      `);

    await insertChecksheetProcesses(transaction, headerId, body);

    await transaction.commit();
    res.json({ headerId, updated: true });
  } catch (e) {
    if (transaction) {
      try {
        await transaction.rollback();
      } catch (_ignored) {}
    }
    const err = mapChecksheetSaveError(e);
    res.status(err.status).json({ message: err.message });
  }
});

/**
 * Part numbers that have a saved checksheet header for the format + effective month.
 * Used by Monthly History (all parts) — not the same as process_master catalog parts.
 */
app.get("/api/checksheets/parts-for-month", async (req, res) => {
  const formatId = Number(req.query.formatId);
  const effDate = normalizeEffDate(req.query.effDate);
  if (!formatId || !effDate) {
    return res.status(400).json({ message: "formatId and effDate are required" });
  }
  try {
    const pool = await getPool();
    const rs = await pool
      .request()
      .input("formatId", sql.Int, formatId)
      .input("effDate", sql.Date, effDate)
      .query(`
        SELECT LTRIM(RTRIM(part_no)) AS partNoRaw
        FROM dbo.checksheet_header
        WHERE format_id = @formatId
          AND eff_date IS NOT NULL
          AND YEAR(eff_date) = YEAR(@effDate)
          AND MONTH(eff_date) = MONTH(@effDate)
          AND part_no IS NOT NULL AND LTRIM(RTRIM(part_no)) <> N''
      `);
    const seen = new Set();
    const out = [];
    for (const row of rs.recordset || []) {
      const p = normalizePartNo(row.partNoRaw);
      if (!p || seen.has(p)) continue;
      seen.add(p);
      out.push({ partNo: p });
    }
    out.sort((a, b) => a.partNo.localeCompare(b.partNo, "en"));
    res.json(out);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get("/api/checksheets/for-month", async (req, res) => {
  const formatId = Number(req.query.formatId);
  const partNo = normalizePartNo(req.query.partNo);
  const effDate = normalizeEffDate(req.query.effDate);
  if (!formatId || !partNo || !effDate) {
    return res.status(400).json({ message: "formatId, partNo, and effDate are required" });
  }
  try {
    const pool = await getPool();
    /** Match part_no with the same {@link normalizePartNo} as the client — SQL-only norm can diverge (NFKC, etc.). */
    const hRs = await pool
      .request()
      .input("formatId", sql.Int, formatId)
      .input("effDate", sql.Date, effDate)
      .query(`
        SELECT header_id AS headerId, LTRIM(RTRIM(part_no)) AS partNoRaw
        FROM dbo.checksheet_header
        WHERE format_id = @formatId
          AND eff_date IS NOT NULL
          AND YEAR(eff_date) = YEAR(@effDate)
          AND MONTH(eff_date) = MONTH(@effDate)
          AND part_no IS NOT NULL AND LTRIM(RTRIM(part_no)) <> N''
        ORDER BY updated_at DESC, header_id DESC
      `);
    let headerId = null;
    for (const row of hRs.recordset || []) {
      if (normalizePartNo(row.partNoRaw) === partNo) {
        headerId = row.headerId;
        break;
      }
    }
    if (headerId == null) return res.status(404).json({ message: "not found" });
    const detail = await getChecksheetDetail(pool, headerId);
    if (!detail) return res.status(404).json({ message: "not found" });
    res.json(detail);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get("/api/checksheets/:headerId", async (req, res) => {
  try {
    const pool = await getPool();
    const detail = await getChecksheetDetail(pool, Number(req.params.headerId));
    if (!detail) return res.status(404).json({ message: "not found" });
    res.json(detail);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

registerAdminRoutes(app, sql, getPool);

app.patch("/api/checksheets/:headerId/status", async (req, res) => {
  const { status, updatedBy } = req.body;
  if (!["DRAFT", "SUBMITTED"].includes(status)) {
    return res.status(400).json({ message: "invalid status" });
  }

  try {
    const pool = await getPool();
    const rs = await pool.request()
      .input("headerId", sql.BigInt, Number(req.params.headerId))
      .input("status", sql.NVarChar(20), status)
      .input("updatedBy", sql.NVarChar(100), updatedBy || null)
      .query(`
        UPDATE dbo.checksheet_header
        SET status = @status, updated_by = @updatedBy, updated_at = SYSDATETIME()
        WHERE header_id = @headerId;
        SELECT @@ROWCOUNT AS affected;
      `);

    if (rs.recordset[0].affected === 0) return res.status(404).json({ message: "not found" });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

const port = Number(process.env.PORT || 3000);
app.listen(port, () => {
  console.log(`QCCheck API listening on port ${port}`);
});
