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
