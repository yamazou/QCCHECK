/**
 * Reads OITT_TMP.xlsx and writes sql/09_oitt_tmp.sql
 * Usage: node scripts/generate_oitt_tmp_sql.js [path/to/OITT_TMP.xlsx]
 */
const fs = require("fs");
const path = require("path");
const XLSX = require(path.join(__dirname, "..", "server", "node_modules", "xlsx"));

const xlsxPath =
  process.argv[2] || path.join(process.env.USERPROFILE || "", "Downloads", "OITT_TMP.xlsx");
const outPath = path.join(__dirname, "..", "sql", "09_oitt_tmp.sql");

function parseDate(s) {
  if (s == null || s === "") return null;
  if (s instanceof Date && !Number.isNaN(s.getTime())) {
    return s.toISOString().slice(0, 10);
  }
  const str = String(s).trim();
  const m = str.match(/^(\d{1,2})\/(\d{1,2})\/(\d{2,4})$/);
  if (m) {
    let y = parseInt(m[3], 10);
    if (y < 100) y += 2000;
    const mo = parseInt(m[1], 10);
    const d = parseInt(m[2], 10);
    return `${y}-${String(mo).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
  }
  return null;
}

function sqlStr(s) {
  if (s == null || s === "") return "NULL";
  return "N'" + String(s).replace(/'/g, "''") + "'";
}

function sqlInt(v) {
  if (v === "" || v == null) return "NULL";
  const n = Number(v);
  if (Number.isNaN(n)) return "NULL";
  return String(Math.trunc(n));
}

function sqlDec(v) {
  if (v === "" || v == null) return "NULL";
  const n = Number(v);
  if (Number.isNaN(n)) return "NULL";
  return String(n);
}

function sqlDate(v) {
  const d = parseDate(v);
  if (!d) return "NULL";
  return `'${d}'`;
}

function rowToValues(row) {
  const [
    lineNo,
    parentItem,
    bomType,
    priceList,
    noOfUnits,
    creationDate,
    dateOfUpdate,
    postponed,
    dataSource,
    userSig,
    scnCounter,
    displayCurrency,
    whse,
    objectType,
    logInstance,
    updatingUser,
    distRule,
    hideComp,
    dr2,
    dr3,
    dr4,
    dr5,
    timeOfUpdate,
    projectCode,
    plannedAvg,
    productDesc,
    createTimeSecs,
    updateFullTime,
    attachEntry,
    attachments
  ] = row;

  return `(${sqlInt(lineNo)}, ${sqlStr(parentItem)}, ${sqlStr(bomType)}, ${sqlInt(priceList)}, ${sqlDec(
    noOfUnits
  )}, ${sqlDate(creationDate)}, ${sqlDate(dateOfUpdate)}, ${sqlStr(postponed)}, ${sqlStr(
    dataSource
  )}, ${sqlInt(userSig)}, ${sqlInt(scnCounter)}, ${sqlStr(displayCurrency)}, ${sqlStr(whse)}, ${sqlStr(
    objectType
  )}, ${sqlStr(logInstance)}, ${sqlInt(updatingUser)}, ${sqlStr(distRule)}, ${sqlStr(
    hideComp
  )}, ${sqlStr(dr2)}, ${sqlStr(dr3)}, ${sqlStr(dr4)}, ${sqlStr(dr5)}, ${sqlStr(timeOfUpdate)}, ${sqlStr(
    projectCode
  )}, ${sqlInt(plannedAvg)}, ${sqlStr(productDesc)}, ${sqlInt(createTimeSecs)}, ${sqlInt(
    updateFullTime
  )}, ${sqlStr(attachEntry)}, ${sqlStr(attachments)})`;
}

function main() {
  if (!fs.existsSync(xlsxPath)) {
    console.error("File not found:", xlsxPath);
    process.exit(1);
  }
  const wb = XLSX.readFile(xlsxPath, { cellDates: true });
  const ws = wb.Sheets[wb.SheetNames[0]];
  const rows = XLSX.utils.sheet_to_json(ws, { header: 1, defval: null });
  const dataRows = rows.slice(1).filter((r) => r && r.length && r[0] != null);

  const header = `USE [QCCHECK];
GO

/* OITT_TMP: columns aligned with OITT_TMP.xlsx (Sheet1). Replaces prior definition. */

IF OBJECT_ID('dbo.OITT_TMP', 'U') IS NOT NULL
    DROP TABLE dbo.OITT_TMP;
GO

CREATE TABLE dbo.OITT_TMP (
    line_no                         INT             NOT NULL,
    parent_item                     NVARCHAR(100)   NOT NULL,
    bom_type                        NCHAR(1)        NULL,
    price_list                      INT             NULL,
    no_of_units                     DECIMAL(18, 6)  NULL,
    creation_date                   DATE            NULL,
    date_of_update                  DATE            NULL,
    postponed_to_next_year          NCHAR(1)        NULL,
    data_source                     NVARCHAR(20)    NULL,
    user_signature                  INT             NULL,
    scn_counter                     INT             NULL,
    display_currency                NVARCHAR(50)    NULL,
    whse_for_finished_product       NVARCHAR(20)    NULL,
    object_type                     NVARCHAR(20)    NULL,
    log_instance_history            NVARCHAR(200)   NULL,
    updating_user                   INT             NULL,
    distribution_rule               NVARCHAR(200)   NULL,
    hide_components_in_printing     NCHAR(1)        NULL,
    distribution_rule2              NVARCHAR(200)   NULL,
    distribution_rule3              NVARCHAR(200)   NULL,
    distribution_rule4              NVARCHAR(200)   NULL,
    distribution_rule5              NVARCHAR(200)   NULL,
    time_of_update                  NVARCHAR(30)    NULL,
    project_code                    NVARCHAR(100)   NULL,
    planned_avg_production_size     INT             NULL,
    product_description             NVARCHAR(300)   NULL,
    create_time_incl_secs           INT             NULL,
    update_full_time                INT             NULL,
    attachment_entry                NVARCHAR(500)   NULL,
    attachments                     NVARCHAR(500)   NULL,
    imported_at                     DATETIME2       NOT NULL DEFAULT SYSDATETIME()
);
GO
`;

  const cols = `line_no, parent_item, bom_type, price_list, no_of_units, creation_date, date_of_update,
    postponed_to_next_year, data_source, user_signature, scn_counter, display_currency,
    whse_for_finished_product, object_type, log_instance_history, updating_user, distribution_rule,
    hide_components_in_printing, distribution_rule2, distribution_rule3, distribution_rule4, distribution_rule5,
    time_of_update, project_code, planned_avg_production_size, product_description, create_time_incl_secs,
    update_full_time, attachment_entry, attachments`;

  const batchSize = 80;
  const chunks = [];
  for (let i = 0; i < dataRows.length; i += batchSize) {
    const batch = dataRows.slice(i, i + batchSize).map((r) => rowToValues(r));
    chunks.push(
      `INSERT INTO dbo.OITT_TMP (${cols.replace(/\s+/g, " ")})\nVALUES\n${batch.join(",\n")};`
    );
  }

  fs.writeFileSync(outPath, header + "\n" + chunks.join("\n\n") + "\nGO\n", "utf8");
  console.log("Wrote", outPath, "rows:", dataRows.length);
}

main();
