/**
 * Import part_no / part_name into dbo.part_master from Excel check sheets in a folder.
 *
 * Part number is read **only from the workbook sheets** (file name is ignored).
 * First match wins per workbook, scanning the first ~80 rows × ~20 cols for labels:
 *   - Label cell "Part No" / "Part No." / "品番" → value on the same row in the next non-empty cell up to ~28 cols right (e.g. ": 3K-010646" in column Y).
 *   - Optional "Part Name" / "品名" / "部品名" on the row above or below the Part No row → value to the right (same wide scan).
 *
 * Usage (from repo root, uses server/.env for DB). format_id defaults to 1 when --format is omitted.
 *   node scripts/import_part_master_from_excel.js "C:\Users\lenovo\Documents\format check sheet"
 *   node scripts/import_part_master_from_excel.js --dry-run "C:\path\to\folder"
 *   node scripts/import_part_master_from_excel.js --emit-sql sql/99_import_part_master.sql "C:\path\to\folder"
 *
 * DB write: DELETE all dbo.part_master for format_id, then INSERT (no leftover parts for that format).
 *
 * Requires: npm install in server/ (xlsx + mssql). Run sql/17_part_master.sql on the DB first if part_master is missing.
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
const PART_NAME_MAX = 200;
const PART_LABEL_SCAN_MAX_ROW = 80;
const PART_VALUE_SPAN = 28;

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

function normalizePartName(s, fallbackPartNo) {
  const t = stripLeadingColonValue(String(s || "").trim());
  if (!t) return fallbackPartNo.slice(0, PART_NAME_MAX);
  return t.slice(0, PART_NAME_MAX);
}

/** Scan sheet for Part No / 品番 label; value may be several columns right (e.g. T label, Y value). */
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

function extractFromWorkbook(wb) {
  const sheetNames = wb.SheetNames || [];
  for (const name of sheetNames) {
    const ws = wb.Sheets[name];
    if (!ws) continue;
    const hit = extractPartFromSheet(ws);
    if (hit && hit.partNo) return { ...hit, sheet: name };
  }
  return null;
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
    `IF OBJECT_ID('dbo.part_master', 'U') IS NULL`,
    `  THROW 50002, N'dbo.part_master missing', 1;`,
    "GO",
    "",
    `DELETE FROM dbo.part_master WHERE format_id = ${formatId};`,
    "GO",
    ""
  ];
  for (const { partNo, partName } of rows) {
    lines.push(
      `INSERT INTO dbo.part_master (format_id, part_no, part_name, active_flag) VALUES (${formatId}, UPPER(LTRIM(RTRIM(${sqlLiteral(
        partNo
      )}))), ${sqlLiteral(partName)}, 1);`
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
        DELETE FROM dbo.part_master WHERE format_id = @formatId
      `);
    for (const { partNo, partName } of rows) {
      await new sqlMod.Request(transaction)
        .input("formatId", sqlMod.Int, formatId)
        .input("partNo", sqlMod.NVarChar(PART_NO_MAX), partNo)
        .input("partName", sqlMod.NVarChar(PART_NAME_MAX), partName)
        .query(`
          INSERT INTO dbo.part_master (format_id, part_no, part_name, active_flag)
          VALUES (@formatId, UPPER(LTRIM(RTRIM(@partNo))), @partName, 1)
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
      '  node scripts/import_part_master_from_excel.js "C:\\Users\\lenovo\\Documents\\format check sheet"'
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
    const key = ext.partNo.toUpperCase();
    if (!byPart.has(key)) {
      byPart.set(key, {
        partNo: ext.partNo,
        partName: ext.partName || ext.partNo,
        source: path.relative(root, fp) + (ext.sheet ? ` (${ext.sheet})` : "")
      });
    }
  }

  const rows = [...byPart.values()].sort((a, b) => a.partNo.localeCompare(b.partNo, "en"));
  console.log("Unique parts (delete all part_master for format, then insert):", rows.length);
  if (skipped.length) {
    console.log("Skipped:", skipped.length);
    for (const s of skipped.slice(0, 30)) {
      console.log(" -", s.file, "→", s.reason);
    }
    if (skipped.length > 30) console.log(" ...", skipped.length - 30, "more");
  }

  if (args.dryRun) {
    rows.slice(0, 50).forEach((r) => console.log(" ", r.partNo, "\t", r.partName, "\t", r.source));
    if (rows.length > 50) console.log(" ...", rows.length - 50, "more (dry-run)");
    return;
  }

  if (rows.length === 0) {
    console.log("Nothing to write; DB unchanged (no workbooks with Part No / 品番 on sheet).");
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
    "Replaced dbo.part_master for format_id =",
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
