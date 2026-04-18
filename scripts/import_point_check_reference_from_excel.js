/**
 * Import dbo.point_check_reference from Excel check sheets (FM layout).
 *
 * Part number: **sheet only** (Part No / 品番 + wide value scan; file name ignored — same keys as part_master / process_master).
 * Part name: read from Part Name / 品名 row above or below the Part No row when present (same as part_master).
 *
 * Point checks: find cells matching /^POINT\\s*CHECK$/i (any column, used rows up to 3000). For each anchor:
 *   - process_code = nearest "Prosess" / "Process" row *above* the anchor (value to the right, same rules as process import).
 *   - Data rows start 4 rows below the anchor; every 2 rows: check_code in anchor column (A–M), check_point at anchor+2,
 *     optional min/max decimals in anchor+3..anchor+25, check_method = rightmost non-numeric text in anchor+8..anchor+22.
 *   - input_mode NUMERIC when at least two finite numbers found on the row (min/max); otherwise OKNG.
 *
 * DB write: DELETE all dbo.point_check_reference for format_id, then INSERT (no duplicates within DB for that format).
 *
 * Usage (from repo root, uses server/.env). format_id defaults to 1.
 *   node scripts/import_point_check_reference_from_excel.js "C:\\path\\to\\folder"
 *   node scripts/import_point_check_reference_from_excel.js --dry-run "C:\\path\\to\\folder"
 *   node scripts/import_point_check_reference_from_excel.js --emit-sql sql/99_import_pcr.sql "C:\\path\\to\\folder"
 */

const fs = require("fs");
const path = require("path");

const { readPartNameNearPartNoRow } = require(path.join(__dirname, "excelReadPartNameNearPartNo.js"));

const serverRoot = path.join(__dirname, "..", "server");
const XLSX = require(path.join(serverRoot, "node_modules", "xlsx"));

require(path.join(serverRoot, "node_modules", "dotenv")).config({
  path: path.join(serverRoot, ".env")
});

const PART_NO_MAX = 100;
const PART_LABEL_SCAN_MAX_ROW = 80;
const PART_VALUE_SPAN = 28;
const POINT_CHECK_SCAN_MAX_ROW = 3000;
const POINT_CHECK_SCAN_MAX_COL = 80;
const PROCESS_LABEL_MAX_COL = 35;
const PROCESS_VALUE_SPAN = 25;

const CHECK_POINT_MAX = 300;
const CRITERIA_MAX = 300;
const METHOD_MAX = 300;
const NOTE_MAX = 500;
const PROCESS_CODE_MAX = 50;

const DEFAULT_FORMAT_ID = 1;

function parseArgs(argv) {
  const out = { formatId: DEFAULT_FORMAT_ID, dryRun: false, emitSql: null, dir: null, recursive: true };
  const rest = [];
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--dry-run") out.dryRun = true;
    else if (a === "--no-recursive") out.recursive = false;
    else if (a === "--format" || a === "-f") out.formatId = Number(argv[++i]);
    else if (a === "--emit-sql") out.emitSql = argv[++i] || null;
    else if (!a.startsWith("-")) rest.push(a);
  }
  out.dir = rest[0] || null;
  return out;
}

function cellText(v) {
  if (v == null) return "";
  if (typeof v === "string") return v.trim();
  if (typeof v === "number" && Number.isFinite(v)) return String(v);
  if (v instanceof Date && !Number.isNaN(v.getTime())) return v.toISOString().slice(0, 10);
  return String(v).trim();
}

function stripLeadingColonValue(s) {
  return String(s || "")
    .trim()
    .replace(/^\s*:\s*/, "")
    .trim();
}

function isPartNoLike(s) {
  const t = String(s || "").trim();
  if (t.length < 2 || t.length > PART_NO_MAX) return false;
  return /^[A-Z0-9][A-Z0-9._\-/]*$/i.test(t);
}

function normalizePartNo(s) {
  return String(s || "")
    .trim()
    .replace(/\s+/g, "")
    .toUpperCase()
    .slice(0, PART_NO_MAX);
}

function normalizePartName(s, fallbackPartNo) {
  const t = stripLeadingColonValue(String(s || "").trim());
  if (!t) return fallbackPartNo.slice(0, 200);
  return t.slice(0, 200);
}

function extractPartFromSheet(ws) {
  const ref = ws["!ref"];
  if (!ref) return null;
  const range = XLSX.utils.decode_range(ref);
  const maxR = Math.min(range.e.r, PART_LABEL_SCAN_MAX_ROW);
  const maxC = Math.min(range.e.c, 20);

  for (let R = range.s.r; R <= maxR; R++) {
    for (let C = range.s.c; C <= maxC; C++) {
      const addr = XLSX.utils.encode_cell({ r: R, c: C });
      const raw = cellText(ws[addr]?.v);
      if (!raw) continue;
      const keyNorm = raw.replace(/\s+/g, " ").trim();
      if (!/^part\s*no\.?$/i.test(keyNorm) && !/^品番$/i.test(keyNorm)) continue;

      const valEnd = Math.min(range.e.c, C + PART_VALUE_SPAN);
      let partNo = "";
      for (let CC = C + 1; CC <= valEnd; CC++) {
        const cellRaw = stripLeadingColonValue(cellText(ws[XLSX.utils.encode_cell({ r: R, c: CC })]?.v));
        const pn = normalizePartNo(cellRaw);
        if (pn && isPartNoLike(pn)) {
          partNo = pn;
          break;
        }
      }
      if (!partNo) continue;

      const partName = readPartNameNearPartNoRow(ws, range, R, C, valEnd, partNo, {
        cellText,
        stripLeadingColonValue,
        normalizePartName,
        XLSX
      });
      return { partNo, partName };
    }
  }
  return null;
}

function extractPartFromWorkbook(wb) {
  const sheetNames = wb.SheetNames || [];
  for (const name of sheetNames) {
    const ws = wb.Sheets[name];
    if (!ws) continue;
    const hit = extractPartFromSheet(ws);
    if (hit && hit.partNo) return { ...hit, sheet: name };
  }
  return null;
}

function isProcessLabel(raw) {
  const keyNorm = raw.replace(/\s+/g, " ").trim();
  if (!keyNorm) return false;
  const compact = keyNorm.replace(/\s+/g, "");
  if (/^prosess$/i.test(keyNorm)) return true;
  if (/^process$/i.test(keyNorm)) return true;
  if (/^process\s*name$/i.test(keyNorm)) return true;
  if (/^process\s*code$/i.test(keyNorm)) return true;
  if (compact === "工程") return true;
  if (compact === "作業工程") return true;
  if (compact === "工序") return true;
  return false;
}

function normalizeProcessName(s) {
  const t = stripLeadingColonValue(s).replace(/\s+/g, " ").trim();
  if (!t || t.length < 2) return "";
  return t.slice(0, PROCESS_CODE_MAX);
}

function extractProcessValueAtRow(ws, R, labelCol) {
  const ref = ws["!ref"];
  if (!ref) return "";
  const range = XLSX.utils.decode_range(ref);
  const wideEnd = Math.min(range.e.c, labelCol + PROCESS_VALUE_SPAN);
  for (let CC = labelCol + 1; CC <= wideEnd; CC++) {
    const t = normalizeProcessName(cellText(ws[XLSX.utils.encode_cell({ r: R, c: CC })]?.v));
    if (t) return t;
  }
  return "";
}

/** Nearest Prosess/Process row strictly above anchorR (same column band as process import). */
function lastProcessNameAbove(ws, anchorR) {
  const ref = ws["!ref"];
  if (!ref) return null;
  const range = XLSX.utils.decode_range(ref);
  const maxC = Math.min(range.e.c, PROCESS_LABEL_MAX_COL);
  for (let R = anchorR - 1; R >= range.s.r; R--) {
    for (let C = range.s.c; C <= maxC; C++) {
      const raw = cellText(ws[XLSX.utils.encode_cell({ r: R, c: C })]?.v);
      if (!raw || !isProcessLabel(raw)) continue;
      const v = extractProcessValueAtRow(ws, R, C);
      if (v) return v.length > PROCESS_CODE_MAX ? v.slice(0, PROCESS_CODE_MAX) : v;
    }
  }
  return null;
}

function isPointCheckAnchorLabel(raw) {
  return /^point\s*check$/i.test(String(raw || "").replace(/\s+/g, " ").trim());
}

function findPointCheckAnchors(ws) {
  const ref = ws["!ref"];
  if (!ref) return [];
  const range = XLSX.utils.decode_range(ref);
  const maxR = Math.min(range.e.r, POINT_CHECK_SCAN_MAX_ROW);
  const maxC = Math.min(range.e.c, POINT_CHECK_SCAN_MAX_COL);
  const out = [];
  for (let R = range.s.r; R <= maxR; R++) {
    for (let C = range.s.c; C <= maxC; C++) {
      const raw = cellText(ws[XLSX.utils.encode_cell({ r: R, c: C })]?.v);
      if (raw && isPointCheckAnchorLabel(raw)) out.push({ R, C });
    }
  }
  return out.sort((a, b) => a.R - b.R || a.C - b.C);
}

function parseNullableDecimal(value) {
  if (value == null) return null;
  let s = String(value).trim();
  if (!s) return null;
  s = s
    .replace(/\u3000/g, " ")
    .replace(/[＋﹢]/g, "+")
    .replace(/[－−—–﹣]/g, "-")
    .replace(/\s+/g, "");
  if (/^[+-]?\d+,\d+$/.test(s)) s = s.replace(",", ".");
  const n = Number(s);
  if (!Number.isFinite(n)) return null;
  return n;
}

function pickMethodText(ws, R, anchorC) {
  const ref = ws["!ref"];
  if (!ref) return "";
  const range = XLSX.utils.decode_range(ref);
  const c0 = Math.min(anchorC + 8, range.e.c);
  const c1 = Math.min(anchorC + 22, range.e.c);
  let last = "";
  for (let CC = c0; CC <= c1; CC++) {
    const t = stripLeadingColonValue(cellText(ws[XLSX.utils.encode_cell({ r: R, c: CC })]?.v));
    if (!t) continue;
    if (parseNullableDecimal(t) != null && !/[A-Za-z\u3040-\u30ff\u4e00-\u9faf]/.test(t)) continue;
    last = t;
  }
  return last.slice(0, METHOD_MAX);
}

function extractRowsFromPointCheckAnchor(ws, anchor) {
  const ref = ws["!ref"];
  if (!ref) return [];
  const range = XLSX.utils.decode_range(ref);
  const { R: anchorR, C: anchorC } = anchor;
  const processName = lastProcessNameAbove(ws, anchorR);
  const processCode = processName && processName.length ? processName.slice(0, PROCESS_CODE_MAX) : null;

  const out = [];
  const firstDataR = anchorR + 4;
  for (let R = firstDataR; R <= Math.min(range.e.r, anchorR + 40); R += 2) {
    const codeRaw = cellText(ws[XLSX.utils.encode_cell({ r: R, c: anchorC })]?.v).toUpperCase();
    if (!/^[A-M]$/.test(codeRaw)) break;

    const checkPoint = stripLeadingColonValue(
      cellText(ws[XLSX.utils.encode_cell({ r: R, c: anchorC + 2 })]?.v)
    ).slice(0, CHECK_POINT_MAX);
    if (!checkPoint) continue;

    const nums = [];
    for (let CC = anchorC + 3; CC <= Math.min(range.e.c, anchorC + 25); CC++) {
      const n = parseNullableDecimal(ws[XLSX.utils.encode_cell({ r: R, c: CC })]?.v);
      if (n != null && Number.isFinite(n)) nums.push(n);
    }
    let criteriaMin = null;
    let criteriaMax = null;
    let inputMode = "OKNG";
    if (nums.length >= 2) {
      criteriaMin = Math.min(...nums);
      criteriaMax = Math.max(...nums);
      if (criteriaMin <= criteriaMax) inputMode = "NUMERIC";
      else {
        criteriaMin = null;
        criteriaMax = null;
      }
    }

    const criteria = checkPoint.slice(0, CRITERIA_MAX);
    const checkMethod = pickMethodText(ws, R, anchorC).slice(0, METHOD_MAX);

    out.push({
      processCode,
      checkCode: codeRaw,
      checkPoint,
      criteria,
      criteriaMin,
      criteriaMax,
      checkMethod: checkMethod || null,
      note: null,
      inputMode
    });
  }
  return out;
}

function extractPointChecksFromWorkbook(wb) {
  const all = [];
  for (const name of wb.SheetNames || []) {
    const ws = wb.Sheets[name];
    if (!ws) continue;
    const anchors = findPointCheckAnchors(ws);
    for (const a of anchors) {
      all.push(...extractRowsFromPointCheckAnchor(ws, a));
    }
  }
  return all;
}

function listExcelFiles(rootDir, recursive) {
  const exts = new Set([".xlsx", ".xlsm"]);
  const out = [];
  function walk(dir) {
    let entries;
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch (e) {
      console.error("Cannot read directory:", dir, e.message);
      return;
    }
    for (const ent of entries) {
      if (ent.name.startsWith("~$")) continue;
      const full = path.join(dir, ent.name);
      if (ent.isDirectory()) {
        if (recursive) walk(full);
        continue;
      }
      const ext = path.extname(ent.name).toLowerCase();
      if (exts.has(ext)) out.push(full);
    }
  }
  walk(rootDir);
  return out.sort((a, b) => a.localeCompare(b, "en"));
}

function sqlLiteral(s) {
  if (s == null) return "NULL";
  return "N'" + String(s).replace(/'/g, "''") + "'";
}

function sqlDecimalOrNull(n) {
  if (n == null || !Number.isFinite(n)) return "NULL";
  return String(n);
}

function buildEmitSql(formatId, flatRows, flags) {
  const db = process.env.DB_DATABASE || "QCCHECK";
  const lines = [
    `USE [${db}];`,
    "GO",
    "",
    `IF NOT EXISTS (SELECT 1 FROM dbo.format_master WHERE format_id = ${formatId})`,
    `  THROW 50001, N'format_id ${formatId} not found', 1;`,
    "GO",
    "",
    `IF OBJECT_ID('dbo.point_check_reference', 'U') IS NULL`,
    `  THROW 50002, N'dbo.point_check_reference missing', 1;`,
    "GO",
    "",
    `DELETE FROM dbo.point_check_reference WHERE format_id = ${formatId};`,
    "GO",
    ""
  ];
  const hasRange = !!(flags.hasMin && flags.hasMax);
  for (const r of flatRows) {
    const pc = r.processCode == null ? "NULL" : sqlLiteral(r.processCode);
    const cmins =
      hasRange && r.criteriaMin != null && r.criteriaMax != null
        ? `${sqlDecimalOrNull(r.criteriaMin)}, ${sqlDecimalOrNull(r.criteriaMax)}`
        : "NULL, NULL";
    let cols =
      "format_id, part_no, process_code, check_code, check_point, criteria, check_method, note";
    const meth =
      r.checkMethod == null || String(r.checkMethod).trim() === "" ? "NULL" : sqlLiteral(r.checkMethod);
    let vals = `${formatId}, UPPER(LTRIM(RTRIM(${sqlLiteral(r.partNo)}))), ${pc}, N'${r.checkCode}', ${sqlLiteral(
      r.checkPoint
    )}, ${sqlLiteral(r.criteria)}, ${meth}, NULL`;
    if (flags.hasInputMode) {
      cols += ", input_mode";
      vals += `, '${r.inputMode}'`;
    }
    if (hasRange) {
      cols += ", criteria_min, criteria_max";
      vals += `, ${cmins}`;
    }
    cols += ", active_flag";
    vals += ", 1";
    lines.push(`INSERT INTO dbo.point_check_reference (${cols}) VALUES (${vals});`);
    lines.push("GO");
    lines.push("");
  }
  return lines.join("\n");
}

async function readPcrColumnFlags(pool) {
  const rs = await pool.request().query(`
    SELECT
      CASE WHEN COL_LENGTH('dbo.point_check_reference', 'input_mode') IS NULL THEN 0 ELSE 1 END AS hasInputMode,
      CASE WHEN COL_LENGTH('dbo.point_check_reference', 'criteria_min') IS NULL THEN 0 ELSE 1 END AS hasMin,
      CASE WHEN COL_LENGTH('dbo.point_check_reference', 'criteria_max') IS NULL THEN 0 ELSE 1 END AS hasMax
  `);
  const row = rs.recordset[0] || {};
  return {
    hasInputMode: !!row.hasInputMode,
    hasMin: !!row.hasMin,
    hasMax: !!row.hasMax
  };
}

async function deleteAllAndInsert(pool, sqlMod, formatId, flatRows, flags) {
  const hasRange = !!(flags.hasMin && flags.hasMax);
  const transaction = new sqlMod.Transaction(pool);
  await transaction.begin();
  try {
    await new sqlMod.Request(transaction).input("formatId", sqlMod.Int, formatId).query(`
        DELETE FROM dbo.point_check_reference WHERE format_id = @formatId
      `);
    for (const r of flatRows) {
      const req = new sqlMod.Request(transaction)
        .input("formatId", sqlMod.Int, formatId)
        .input("partNo", sqlMod.NVarChar(100), r.partNo)
        .input("processCode", sqlMod.NVarChar(50), r.processCode)
        .input("checkCode", sqlMod.NChar(1), r.checkCode)
        .input("checkPoint", sqlMod.NVarChar(300), r.checkPoint)
        .input("criteria", sqlMod.NVarChar(300), r.criteria)
        .input("checkMethod", sqlMod.NVarChar(300), r.checkMethod == null ? null : r.checkMethod)
        .input("note", sqlMod.NVarChar(500), r.note ? String(r.note).trim() : null);

      let cols =
        "format_id, part_no, process_code, check_code, check_point, criteria, check_method, note";
      let vals =
        "@formatId, UPPER(LTRIM(RTRIM(@partNo))), @processCode, @checkCode, @checkPoint, @criteria, @checkMethod, @note";
      if (flags.hasInputMode) {
        req.input("inputMode", sqlMod.VarChar(20), r.inputMode);
        cols += ", input_mode";
        vals += ", @inputMode";
      }
      if (hasRange) {
        req.input(
          "criteriaMin",
          sqlMod.Decimal(18, 4),
          r.criteriaMin != null && r.criteriaMax != null ? r.criteriaMin : null
        );
        req.input(
          "criteriaMax",
          sqlMod.Decimal(18, 4),
          r.criteriaMin != null && r.criteriaMax != null ? r.criteriaMax : null
        );
        cols += ", criteria_min, criteria_max";
        vals += ", @criteriaMin, @criteriaMax";
      }
      cols += ", active_flag";
      vals += ", 1";
      await req.query(`INSERT INTO dbo.point_check_reference (${cols}) VALUES (${vals})`);
    }
    await transaction.commit();
  } catch (e) {
    try {
      await transaction.rollback();
    } catch (_e) {
      /* ignore */
    }
    throw e;
  }
}

async function main() {
  const args = parseArgs(process.argv);
  if (args.formatId == null || Number.isNaN(args.formatId)) {
    args.formatId = DEFAULT_FORMAT_ID;
  }
  if (!args.dir) {
    console.error("Missing folder path. Example:");
    console.error(
      '  node scripts/import_point_check_reference_from_excel.js "C:\\Users\\lenovo\\Documents\\format check sheet"'
    );
    process.exit(1);
  }
  const root = path.resolve(args.dir);
  if (!fs.existsSync(root)) {
    console.error("Folder not found:", root);
    console.error(
      "Use the real folder that contains your .xlsx / .xlsm files (documentation examples like C:\\path\\to\\excel\\folder are placeholders)."
    );
    process.exit(1);
  }

  const files = listExcelFiles(root, args.recursive);
  console.log("format_id:", args.formatId, "(default 1 if --format omitted)");
  console.log("Excel files:", files.length, "under", root);

  const byPart = new Map();
  const skipped = [];

  for (const fp of files) {
    let wb;
    try {
      wb = XLSX.readFile(fp, { cellDates: true, dense: false });
    } catch (e) {
      skipped.push({ file: fp, reason: e.message || String(e) });
      continue;
    }
    const partHit = extractPartFromWorkbook(wb);
    if (!partHit || !partHit.partNo) {
      skipped.push({
        file: fp,
        reason: "Could not detect Part No / 品番 on any sheet (label in first ~80×20, value up to 28 cols right)"
      });
      continue;
    }
    if (!isPartNoLike(partHit.partNo)) {
      skipped.push({ file: fp, reason: "Invalid part no: " + partHit.partNo });
      continue;
    }
    const checks = extractPointChecksFromWorkbook(wb);
    if (!checks.length) {
      skipped.push({ file: fp, reason: "No POINT CHECK block with A–M rows detected" });
      continue;
    }
    const key = partHit.partNo.toUpperCase();
    if (!byPart.has(key)) {
      byPart.set(key, {
        partNo: normalizePartNo(partHit.partNo),
        checks,
        source: path.relative(root, fp)
      });
    }
  }

  const parts = [...byPart.values()].sort((a, b) => a.partNo.localeCompare(b.partNo, "en"));
  const flatRows = [];
  for (const p of parts) {
    for (const c of p.checks) {
      flatRows.push({
        partNo: p.partNo,
        processCode: c.processCode,
        checkCode: c.checkCode,
        checkPoint: c.checkPoint,
        criteria: c.criteria,
        criteriaMin: c.criteriaMin,
        criteriaMax: c.criteriaMax,
        checkMethod: c.checkMethod,
        note: c.note,
        inputMode: c.inputMode
      });
    }
  }

  console.log("Unique parts with point checks:", parts.length, "| total point_check rows:", flatRows.length);
  if (skipped.length) {
    console.log("Skipped:", skipped.length);
    for (const s of skipped.slice(0, 25)) {
      console.log(" -", s.file, "→", s.reason);
    }
    if (skipped.length > 25) console.log(" ...", skipped.length - 25, "more");
  }

  if (args.dryRun) {
    parts.slice(0, 15).forEach((p) =>
      console.log(" ", p.partNo, "\t", p.checks.length, "checks\t", p.source)
    );
    if (parts.length > 15) console.log(" ...", parts.length - 15, "more parts (dry-run)");
    return;
  }

  if (flatRows.length === 0) {
    console.log("Nothing to write; DB unchanged.");
    return;
  }

  const { sql, getPool } = require(path.join(serverRoot, "src", "db"));
  const pool = await getPool();
  const flags = await readPcrColumnFlags(pool);

  if (args.emitSql) {
    const sqlText = buildEmitSql(args.formatId, flatRows, flags);
    const outPath = path.isAbsolute(args.emitSql) ? args.emitSql : path.join(__dirname, "..", args.emitSql);
    fs.mkdirSync(path.dirname(outPath), { recursive: true });
    fs.writeFileSync(outPath, sqlText, "utf8");
    console.log("Wrote SQL file:", outPath);
    await pool.close();
    return;
  }

  await deleteAllAndInsert(pool, sql, args.formatId, flatRows, flags);
  console.log(
    "Replaced dbo.point_check_reference for format_id =",
    args.formatId,
    "(delete all for format, insert",
    flatRows.length,
    "rows)"
  );
  await pool.close();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
