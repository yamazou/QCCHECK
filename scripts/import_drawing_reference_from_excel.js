/**
 * Import dbo.drawing_reference from Excel check sheets (same process discovery as import_process_master).
 *
 * Part number: **sheet only** — Part No / 品番 + wide value scan (first ~80×20); file name ignored.
 * For each distinct process name on the workbook: one row with
 *   drawing_no = NULL, drawing_name = NULL,
 *   file_url = /drawings/{PARTSLUG}_{PROCSLUG}.png
 *   (e.g. VDK0970 + BENDING 3/3 → /drawings/VDK0970_BENDING_3_3.png; hyphens removed from part for the file stem).
 * process_code = process label value (trimmed, max 50 to match column).
 *
 * DB: DELETE all dbo.drawing_reference for format_id, then INSERT.
 *
 * Apply sql/27_drawing_reference_nullable_drawing_no.sql once if drawing_no is still NOT NULL.
 *
 *   node scripts/import_drawing_reference_from_excel.js "C:\\Users\\lenovo\\Documents\\format check sheet"
 *   node scripts/import_drawing_reference_from_excel.js --dry-run "C:\\path\\to\\folder"
 *   node scripts/import_drawing_reference_from_excel.js --emit-sql sql/99_import_dr.sql --format 1 "C:\\path\\to\\folder"
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
const PROCESS_SCAN_MAX_ROW = 3000;
const PROCESS_LABEL_MAX_COL = 35;
const PROCESS_VALUE_SPAN = 25;
const PROCESS_NAME_MAX = 200;
const PROCESS_CODE_DB = 50;
const FILE_URL_MAX = 500;

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
  for (const name of wb.SheetNames || []) {
    const ws = wb.Sheets[name];
    if (!ws) continue;
    const hit = extractPartFromSheet(ws);
    if (hit && hit.partNo) return { ...hit, sheet: name };
  }
  return null;
}

function normalizeProcessName(s) {
  const t = stripLeadingColonValue(s).replace(/\s+/g, " ").trim();
  if (!t || t.length < 2) return "";
  return t.slice(0, PROCESS_NAME_MAX);
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

function extractProcessNamesFromSheet(ws) {
  const ref = ws["!ref"];
  if (!ref) return [];
  const range = XLSX.utils.decode_range(ref);
  const maxR = Math.min(range.e.r, PROCESS_SCAN_MAX_ROW);
  const maxC = Math.min(range.e.c, PROCESS_LABEL_MAX_COL);
  const found = [];

  for (let R = range.s.r; R <= maxR; R++) {
    for (let C = range.s.c; C <= maxC; C++) {
      const raw = cellText(ws[XLSX.utils.encode_cell({ r: R, c: C })]?.v);
      if (!raw || !isProcessLabel(raw)) continue;
      const wideEnd = Math.min(range.e.c, C + PROCESS_VALUE_SPAN);
      let val = "";
      for (let CC = C + 1; CC <= wideEnd; CC++) {
        const t = normalizeProcessName(cellText(ws[XLSX.utils.encode_cell({ r: R, c: CC })]?.v));
        if (t) {
          val = t;
          break;
        }
      }
      if (val) found.push(val);
    }
  }
  return found;
}

function dedupeProcessNamesPreserveOrder(names) {
  const out = [];
  const seen = new Set();
  for (const n of names) {
    const k = n.toUpperCase();
    if (seen.has(k)) continue;
    seen.add(k);
    out.push(n);
  }
  return out;
}

function extractProcessNamesFromWorkbook(wb) {
  const all = [];
  for (const name of wb.SheetNames || []) {
    const ws = wb.Sheets[name];
    if (!ws) continue;
    all.push(...extractProcessNamesFromSheet(ws));
  }
  return dedupeProcessNamesPreserveOrder(all);
}

/** Part stem for filenames (matches examples like VDK0970_BENDING_3_3). */
function fileStemPart(partNo) {
  return normalizePartNo(partNo).replace(/-/g, "");
}

function fileStemProcess(processName) {
  return String(processName || "")
    .trim()
    .toUpperCase()
    .replace(/[/\\]+/g, "_")
    .replace(/[^A-Z0-9]+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_|_$/g, "");
}

function buildDrawingFileUrl(partNo, processName) {
  const a = fileStemPart(partNo);
  const b = fileStemProcess(processName);
  if (!a || !b) return null;
  let u = `/drawings/${a}_${b}.png`;
  if (u.length > FILE_URL_MAX) u = u.slice(0, FILE_URL_MAX);
  return u;
}

function buildDrawingRowsForPart(partNo, processNames) {
  const rows = [];
  for (const proc of processNames) {
    const processCode = proc.slice(0, PROCESS_CODE_DB);
    const fileUrl = buildDrawingFileUrl(partNo, proc);
    if (!fileUrl) continue;
    rows.push({
      processCode,
      drawingNo: null,
      drawingName: null,
      fileUrl,
      note: null
    });
  }
  return rows;
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

function buildEmitSql(formatId, flatRows) {
  const db = process.env.DB_DATABASE || "QCCHECK";
  const lines = [
    `USE [${db}];`,
    "GO",
    "",
    `IF NOT EXISTS (SELECT 1 FROM dbo.format_master WHERE format_id = ${formatId})`,
    `  THROW 50001, N'format_id ${formatId} not found', 1;`,
    "GO",
    "",
    `IF OBJECT_ID('dbo.drawing_reference', 'U') IS NULL`,
    `  THROW 50002, N'dbo.drawing_reference missing', 1;`,
    "GO",
    "",
    `DELETE FROM dbo.drawing_reference WHERE format_id = ${formatId};`,
    "GO",
    ""
  ];
  for (const r of flatRows) {
    const pc = r.processCode == null ? "NULL" : sqlLiteral(r.processCode);
    const dn = r.drawingNo == null || String(r.drawingNo).trim() === "" ? "NULL" : sqlLiteral(r.drawingNo);
    const dname = r.drawingName == null || String(r.drawingName).trim() === "" ? "NULL" : sqlLiteral(r.drawingName);
    const fu = r.fileUrl == null || String(r.fileUrl).trim() === "" ? "NULL" : sqlLiteral(r.fileUrl);
    const nt = r.note == null || String(r.note).trim() === "" ? "NULL" : sqlLiteral(r.note);
    lines.push(
      `INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note, active_flag) VALUES (${formatId}, UPPER(LTRIM(RTRIM(${sqlLiteral(
        r.partNo
      )}))), ${pc}, ${dn}, ${dname}, ${fu}, ${nt}, 1);`
    );
    lines.push("GO");
    lines.push("");
  }
  return lines.join("\n");
}

async function deleteAllAndInsert(pool, sqlMod, formatId, flatRows) {
  const transaction = new sqlMod.Transaction(pool);
  await transaction.begin();
  try {
    await new sqlMod.Request(transaction).input("formatId", sqlMod.Int, formatId).query(`
        DELETE FROM dbo.drawing_reference WHERE format_id = @formatId
      `);
    for (const r of flatRows) {
      await new sqlMod.Request(transaction)
        .input("formatId", sqlMod.Int, formatId)
        .input("partNo", sqlMod.NVarChar(100), r.partNo)
        .input("processCode", sqlMod.NVarChar(50), r.processCode || null)
        .input("drawingNo", sqlMod.NVarChar(100), r.drawingNo || null)
        .input("drawingName", sqlMod.NVarChar(200), r.drawingName || null)
        .input("fileUrl", sqlMod.NVarChar(500), r.fileUrl || null)
        .input("note", sqlMod.NVarChar(500), r.note || null)
        .query(`
          INSERT INTO dbo.drawing_reference (format_id, part_no, process_code, drawing_no, drawing_name, file_url, note, active_flag)
          VALUES (@formatId, UPPER(LTRIM(RTRIM(@partNo))), @processCode, @drawingNo, @drawingName, @fileUrl, @note, 1)
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
      '  node scripts/import_drawing_reference_from_excel.js "C:\\Users\\lenovo\\Documents\\format check sheet"'
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
    const processNames = extractProcessNamesFromWorkbook(wb);
    if (!processNames.length) {
      skipped.push({ file: fp, reason: "No process labels (Prosess/Process/工程…) with values found" });
      continue;
    }
    const pn = normalizePartNo(partHit.partNo);
    const rows = buildDrawingRowsForPart(pn, processNames);
    if (!rows.length) {
      skipped.push({ file: fp, reason: "Could not build file_url for any process" });
      continue;
    }
    const key = pn.toUpperCase();
    if (!byPart.has(key)) {
      byPart.set(key, {
        partNo: pn,
        rows,
        source: path.relative(root, fp)
      });
    }
  }

  const parts = [...byPart.values()].sort((a, b) => a.partNo.localeCompare(b.partNo, "en"));
  const flatRows = [];
  for (const p of parts) {
    for (const r of p.rows) {
      flatRows.push({
        partNo: p.partNo,
        processCode: r.processCode,
        drawingNo: r.drawingNo,
        drawingName: r.drawingName,
        fileUrl: r.fileUrl,
        note: r.note
      });
    }
  }

  console.log("Unique parts with drawings:", parts.length, "| total drawing_reference rows:", flatRows.length);
  if (skipped.length) {
    console.log("Skipped:", skipped.length);
    for (const s of skipped.slice(0, 15)) {
      console.log(" -", s.file, "→", s.reason);
    }
    if (skipped.length > 15) console.log(" ...", skipped.length - 15, "more");
  }

  if (args.dryRun) {
    parts.slice(0, 8).forEach((p) => {
      const ex = p.rows[0];
      console.log(" ", p.partNo, "\t", p.rows.length, "rows\t", ex && ex.fileUrl, "\t", p.source);
    });
    if (parts.length > 8) console.log(" ...", parts.length - 8, "more parts (dry-run)");
    return;
  }

  if (flatRows.length === 0) {
    console.log("Nothing to write; DB unchanged.");
    return;
  }

  const { sql, getPool } = require(path.join(serverRoot, "src", "db"));
  const pool = await getPool();

  if (args.emitSql) {
    const sqlText = buildEmitSql(args.formatId, flatRows);
    const outPath = path.isAbsolute(args.emitSql) ? args.emitSql : path.join(__dirname, "..", args.emitSql);
    fs.mkdirSync(path.dirname(outPath), { recursive: true });
    fs.writeFileSync(outPath, sqlText, "utf8");
    console.log("Wrote SQL file:", outPath);
    await pool.close();
    return;
  }

  await deleteAllAndInsert(pool, sql, args.formatId, flatRows);
  console.log(
    "Replaced dbo.drawing_reference for format_id =",
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
