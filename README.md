# QCCheck Starter

Starter kit to move Excel-style check sheet entry to the web.

## Contents
- `sql/01_schema.sql`: SQL Server table definitions
- `sql/02_seed_master.sql`: Initial master data for VDE1980 / VDK0970
- `docs/api-spec.md`: API specification
- `server/`: Node.js + Express + mssql API skeleton

## 1) Database setup
1. Connect to `QCCHECK` in SQL Server Management Studio
2. Run `sql/01_schema.sql`
3. Run `sql/02_seed_master.sql`
4. Run `sql/03_reference_master.sql` (drawing & point check reference data)
5. For existing DBs, run `sql/06_add_leadercheck_remarks.sql` (add Leader Check / Remarks on detail rows)
6. For existing DBs, run `sql/07_add_footer_fields.sql` (footer remarks / approval fields)
7. For existing DBs, run `sql/08_add_footer_remarks_3rows.sql` (three footer remark rows)
8. Run `sql/15_part_customer.sql` (customer abbreviation per part for the sheet header)
9. For existing DBs, run `sql/22_expand_checksheet_row_no.sql` (allow detail rows beyond 31 when many records are entered)
10. If duplicate monthly sheets already exist, run `sql/23_cleanup_duplicate_checksheet_headers.sql` (keep newest header per format+part+effDate)
11. To enable numeric input by check point, run `sql/24_add_pointcheck_input_mode_and_flexible_result.sql`
12. To store point-check thresholds as min/max values, run `sql/25_add_pointcheck_criteria_range.sql`
13. To add Machine No / SOP Check fields on checksheet rows, run `sql/26_add_machine_no_and_sop_check.sql`

## 2) Start the API
```bash
cd server
copy .env.example .env
npm install
npm run dev
```

## 3) Smoke test
- Health: `GET http://localhost:3000/api/health`
- Formats: `GET http://localhost:3000/api/formats`
- Processes: `GET http://localhost:3000/api/formats/1/processes?partNo=VDE1980`
- References: `GET http://localhost:3000/api/references?formatId=1&partNo=VDE1980`

## Notes
- The skeleton focuses on create/save; incremental row updates can be added later.
- Prefer a dedicated app user over `sa` in production.
