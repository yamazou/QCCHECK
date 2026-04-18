/**
 * Import customer_abbrev into dbo.part_customer from Excel check sheets in a folder.
 * Part number: **sheet only** (same Part No / 品番 scan as import_part_master_from_excel.js; file name is ignored).
 * Plus header / BJ9-style heuristics for customer abbrev.
 *
 * FM-format check sheets: customer sign is usually BJ9 (with BJ4 "Prepare" five rows above).
 * Some files shift down one row (Prepare at BJ5 → YEMI at BJ10) or omit Prepare (CS No at BH2 → JVC at BH4).
 * The script tries BJ9, then "Prepare" +5 rows same column, then "CS No" +2 rows same column, then labels.
 *
 * Then: label scan (first match wins, first ~80 rows × up to column BK):
 *   - "Customer Abbrev" / "Cust. Abbrev" / "Customer Abbr." / "Customer Code"
 *   - "客先略称" (internal spaces in the label are ignored) / "得意先略称" / "顧客略称" / "客先コード" / "得意先コード"
 *   - "Customer" (generic; value trimmed, max 50 chars)
 *
 * Only rows with a non-empty customer abbrev are written.
 * DB write: DELETE all dbo.part_customer for format_id, then INSERT (same row count as unique parts in folder; no stale part_no left from MERGE).
 * Parts with no matching label are skipped (logged).
 *
 * Usage (from repo root, uses server/.env for DB). format_id defaults to 1 when --format is omitted.
 *   node scripts/import_part_customer_from_excel.js "C:\Users\lenovo\Documents\format check sheet"
 *   node scripts/import_part_customer_from_excel.js --dry-run "C:\path\to\folder"
 *   node scripts/import_part_customer_from_excel.js --emit-sql sql/99_import_part_customer.sql "C:\path\to\folder"
 *
 * Requires: npm install in server/ (xlsx + mssql). Run sql/15_part_customer.sql on the DB first if part_customer is missing.
 */

const fs = require("fs");
const path = require("path");

const serverRoot = path.join(__dirname, "..", "server");
const XLSX = require(path.join(serverRoot, "node_modules", "xlsx"));

require(path.join(serverRoot, "node_modules", "dotenv")).config({
  path: path.join(serverRoot, ".env")
});

const PART_NO_MAX = 100;
const PART_LABEL_SCAN_MAX_ROW = 80;
const PART_VALUE_SPAN = 28;
const CUSTOMER_ABBREV_MAX = 50;

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

function stripLeadingColonValue(s) {
  return String(s || "")
    .trim()
    .replace(/^\s*:\s*/, "")
    .trim();
}

function normalizeCustomerAbbrev(s) {
  const t = String(s || "").trim().replace(/\s+/g, " ");
  if (!t) return "";
  return t.slice(0, CUSTOMER_ABBREV_MAX);
}

/** Fixed cell on common FM layout (column BJ ≈ index 61). */
const CUSTOMER_SIGN_CELL = "BJ9";
/** "Prepare" / "CS No" anchor search — BC..BM covers shifted templates (BC ≈ 54). */
const CUSTOMER_ANCHOR_MIN_COL = 50;
const CUSTOMER_ANCHOR_MAX_COL = 66;
const CUSTOMER_ANCHOR_MAX_ROW = 14;
/** Include BJ with margin for label scan. */
const CUSTOMER_LABEL_MAX_COL = 70;

const HEADER_NOISE = new Set(
  [
    "POINT CHECK",
    "PREPARE",
    "PART NAME",
    "PART NO",
    "EFF DATE",
    "REV NO",
    "PROSESS",
    "PROCESS",
    "DIMENSI",
    "MATERIAL"
  ].map((s) => s.toUpperCase())
);

/** BJ9-style sign / abbrev: short, not a known header token, no colon (avoids ": VDE1980" style). */
function isPlausibleCustomerAbbrev(s) {
  const a = normalizeCustomerAbbrev(s);
  if (!a) return false;
  if (/:/.test(a)) return false;
  const up = a.toUpperCase();
  if (HEADER_NOISE.has(up)) return false;
  return true;
}

/** @param {string} raw */
function isCustomerLabel(raw) {
  const keyNorm = raw.replace(/\s+/g, " ").trim();
  if (!keyNorm) return false;
  const compact = keyNorm.replace(/\s+/g, "");
  if (/^customer\s*abbrev\.?$/i.test(keyNorm)) return true;
  if (/^cust\.?\s*abbrev\.?$/i.test(keyNorm)) return true;
  if (/^customer\s*abbr\.?$/i.test(keyNorm)) return true;
  if (/^customer\s*code$/i.test(keyNorm)) return true;
  if (compact === "客先略称") return true;
  if (compact === "得意先略称") return true;
  if (compact === "顧客略称") return true;
  if (compact === "客先コード") return true;
  if (compact === "得意先コード") return true;
  if (compact === "顧客コード") return true;
  if (compact === "客先") return true;
  if (compact === "得意先") return true;
  if (/^customer$/i.test(keyNorm)) return true;
  return false;
}

/** Scan sheet for customer abbrev: BJ9, Prepare+5, CS No+2, then label (value to the right). */
function extractCustomerAbbrevFromSheet(ws) {
  const fromSign = normalizeCustomerAbbrev(cellText(ws[CUSTOMER_SIGN_CELL]?.v));
  if (fromSign && isPlausibleCustomerAbbrev(fromSign)) return fromSign;

  const ref = ws["!ref"];
  if (ref) {
    const range = XLSX.utils.decode_range(ref);
    const maxR = Math.min(range.e.r, CUSTOMER_ANCHOR_MAX_ROW);
    const minC = Math.max(range.s.c, CUSTOMER_ANCHOR_MIN_COL);
    const maxC = Math.min(range.e.c, CUSTOMER_ANCHOR_MAX_COL);

    for (let R = range.s.r; R <= maxR; R++) {
      for (let C = minC; C <= maxC; C++) {
        const raw = cellText(ws[XLSX.utils.encode_cell({ r: R, c: C })]?.v);
        if (!/^prepare$/i.test(raw)) continue;
        const below = cellText(ws[XLSX.utils.encode_cell({ r: R + 5, c: C })]?.v);
        const abbrev = normalizeCustomerAbbrev(below);
        if (abbrev && isPlausibleCustomerAbbrev(abbrev)) return abbrev;
      }
    }

    for (let R = range.s.r; R <= maxR; R++) {
      for (let C = minC; C <= maxC; C++) {
        const raw = cellText(ws[XLSX.utils.encode_cell({ r: R, c: C })]?.v);
        if (!/^cs\s*no/i.test(raw)) continue;
        const below = cellText(ws[XLSX.utils.encode_cell({ r: R + 2, c: C })]?.v);
        const abbrev = normalizeCustomerAbbrev(below);
        if (abbrev && isPlausibleCustomerAbbrev(abbrev)) return abbrev;
      }
    }
  }

  if (!ref) return "";
  const range = XLSX.utils.decode_range(ref);
  const maxR = Math.min(range.e.r, 80);
  const maxC = Math.min(range.e.c, CUSTOMER_LABEL_MAX_COL);

  for (let R = range.s.r; R <= maxR; R++) {
    for (let C = range.s.c; C <= maxC; C++) {
      const addr = XLSX.utils.encode_cell({ r: R, c: C });
      const raw = cellText(ws[addr]?.v);
      if (!raw || !isCustomerLabel(raw)) continue;

      const vAddr = XLSX.utils.encode_cell({ r: R, c: C + 1 });
      let val = cellText(ws[vAddr]?.v);
      if (!val && C + 2 <= maxC) {
        val = cellText(ws[XLSX.utils.encode_cell({ r: R, c: C + 2 })]?.v);
      }
      const abbrev = normalizeCustomerAbbrev(val);
      if (abbrev && isPlausibleCustomerAbbrev(abbrev)) return abbrev;
    }
  }
  return "";
}

/** Scan sheet for Part No / 品番 label; value may be several columns right (e.g. Y column). */
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
      for (let CC = C + 1; CC <= valEnd; CC++) {
        const cellRaw = stripLeadingColonValue(cellText(ws[XLSX.utils.encode_cell({ r: R, c: CC })]?.v));
        const pn = normalizePartNo(cellRaw);
        if (pn && isPartNoLike(pn)) return { partNo: pn };
      }
    }
  }
  return null;
}

function extractFromWorkbook(wb) {
  const sheetNames = wb.SheetNames || [];
  let partNo = null;
  let partSheet = null;
  for (const name of sheetNames) {
    const ws = wb.Sheets[name];
    if (!ws) continue;
    const partHit = extractPartFromSheet(ws);
    if (partHit && partHit.partNo) {
      partNo = partHit.partNo;
      partSheet = name;
      break;
    }
  }
  if (!partNo) return null;

  let customerAbbrev = "";
  for (const name of sheetNames) {
    const ws = wb.Sheets[name];
    if (!ws) continue;
    customerAbbrev = extractCustomerAbbrevFromSheet(ws);
    if (customerAbbrev) break;
  }
  return {
    partNo,
    customerAbbrev,
    sheet: partSheet
  };
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
  return "N'" + String(s).replace(/'/g, "''") + "'";
}

function buildEmitSql(formatId, rows) {
  const db = process.env.DB_DATABASE || "QCCHECK";
  const lines = [
    `USE [${db}];`,
    "GO",
    "",
    `IF NOT EXISTS (SELECT 1 FROM dbo.format_master WHERE format_id = ${formatId})`,
    `  THROW 50001, N'format_id ${formatId} not found', 1;`,
    "GO",
    "",
    `IF OBJECT_ID('dbo.part_customer', 'U') IS NULL`,
    `  THROW 50002, N'dbo.part_customer missing — run sql/15_part_customer.sql', 1;`,
    "GO",
    "",
    `DELETE FROM dbo.part_customer WHERE format_id = ${formatId};`,
    "GO",
    ""
  ];
  for (const { partNo, customerAbbrev } of rows) {
    lines.push(
      `INSERT INTO dbo.part_customer (format_id, part_no, customer_abbrev, active_flag) VALUES (${formatId}, UPPER(LTRIM(RTRIM(${sqlLiteral(
        partNo
      )}))), ${sqlLiteral(customerAbbrev)}, 1);`
    );
    lines.push("GO");
    lines.push("");
  }
  return lines.join("\n");
}

async function deleteAllAndInsert(sqlMod, pool, formatId, rows) {
  const transaction = new sqlMod.Transaction(pool);
  await transaction.begin();
  try {
    await new sqlMod.Request(transaction).input("formatId", sqlMod.Int, formatId).query(`
        DELETE FROM dbo.part_customer WHERE format_id = @formatId
      `);
    for (const { partNo, customerAbbrev } of rows) {
      await new sqlMod.Request(transaction)
        .input("formatId", sqlMod.Int, formatId)
        .input("partNo", sqlMod.NVarChar(PART_NO_MAX), partNo)
        .input("abbrev", sqlMod.NVarChar(CUSTOMER_ABBREV_MAX), customerAbbrev)
        .query(`
          INSERT INTO dbo.part_customer (format_id, part_no, customer_abbrev, active_flag)
          VALUES (@formatId, UPPER(LTRIM(RTRIM(@partNo))), @abbrev, 1)
        `);
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
      '  node scripts/import_part_customer_from_excel.js "C:\\Users\\lenovo\\Documents\\format check sheet"'
    );
    process.exit(1);
  }
  const root = path.resolve(args.dir);
  if (!fs.existsSync(root)) {
    console.error("Folder not found:", root);
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
    const ext = extractFromWorkbook(wb);
    if (!ext || !ext.partNo) {
      skipped.push({
        file: fp,
        reason: "Could not detect Part No / 品番 on any sheet (label in first ~80×20, value up to 28 cols right)"
      });
      continue;
    }
    if (!isPartNoLike(ext.partNo)) {
      skipped.push({ file: fp, reason: "Invalid part no: " + ext.partNo });
      continue;
    }
    if (!ext.customerAbbrev) {
      skipped.push({
        file: fp,
        reason: "No customer abbrev (BJ9 / Prepare+5 / CS No+2 / header labels)"
      });
      continue;
    }
    const key = ext.partNo.toUpperCase();
    if (!byPart.has(key)) {
      byPart.set(key, {
        partNo: ext.partNo,
        customerAbbrev: ext.customerAbbrev,
        source: path.relative(root, fp) + (ext.sheet ? ` (${ext.sheet})` : "")
      });
    }
  }

  const rows = [...byPart.values()].sort((a, b) => a.partNo.localeCompare(b.partNo, "en"));
  console.log("Unique parts with customer abbrev (delete all part_customer for format, then insert):", rows.length);
  if (skipped.length) {
    console.log("Skipped:", skipped.length);
    for (const s of skipped.slice(0, 30)) {
      console.log(" -", s.file, "→", s.reason);
    }
    if (skipped.length > 30) console.log(" ...", skipped.length - 30, "more");
  }

  if (args.dryRun) {
    rows.slice(0, 50).forEach((r) => console.log(" ", r.partNo, "\t", r.customerAbbrev, "\t", r.source));
    if (rows.length > 50) console.log(" ...", rows.length - 50, "more (dry-run)");
    return;
  }

  if (rows.length === 0) {
    console.log("Nothing to write (no workbooks with both part no and customer abbrev).");
    return;
  }

  const sqlText = buildEmitSql(args.formatId, rows);
  if (args.emitSql) {
    const outPath = path.isAbsolute(args.emitSql) ? args.emitSql : path.join(__dirname, "..", args.emitSql);
    fs.mkdirSync(path.dirname(outPath), { recursive: true });
    fs.writeFileSync(outPath, sqlText, "utf8");
    console.log("Wrote SQL file:", outPath);
    return;
  }

  const { sql, getPool } = require(path.join(serverRoot, "src", "db"));
  const pool = await getPool();
  await deleteAllAndInsert(sql, pool, args.formatId, rows);
  console.log(
    "Replaced dbo.part_customer for format_id =",
    args.formatId,
    "(delete all for format, insert",
    rows.length,
    "rows)"
  );
  await pool.close();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
