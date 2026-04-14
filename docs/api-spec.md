# QCCheck API Spec (v1)

## Base
- Base URL: `/api`
- Content-Type: `application/json`

## 1. List formats
- `GET /formats`
- Returns all registered formats for the UI.

Response:
```json
[
  {
    "formatId": 1,
    "formatCode": "FM-ASB-CS-001-00",
    "formatName": "CHECK SHEET PRODUCTION"
  }
]
```

## 2. Processes for a part
- `GET /formats/:formatId/processes?partNo=VDE1980`
- Used to build process tabs on the entry screen.

Response:
```json
[
  { "processMasterId": 1, "processName": "SHEARING", "displayOrder": 1 },
  { "processMasterId": 2, "processName": "PUNCHING CUT BLANK 1/1", "displayOrder": 2 }
]
```

## 3. Create checksheet
- `POST /checksheets`
- Saves one sheet (equivalent to one Excel workbook sheet).

Request:
```json
{
  "formatId": 1,
  "partNo": "VDE1980",
  "partName": "POST C BRACKET",
  "effDate": "2026-04-09",
  "revNo": "",
  "department": "Production Department",
  "sheetDate": "2026-04-09",
  "createdBy": "operator01",
  "processes": [
    {
      "processMasterId": 1,
      "processName": "SHEARING",
      "displayOrder": 1,
      "rows": [
        {
          "rowNo": 1,
          "workDate": "2026-04-09",
          "startTime": "08:00",
          "finishTime": "08:30",
          "qty": 100,
          "okCount": 100,
          "ngCount": 0,
          "pic": "Aji",
          "leaderCheck": "OK",
          "remarks": "Line stable",
          "checks": [
            { "checkCode": "A", "result": "OK" },
            { "checkCode": "B", "result": "OK" }
          ]
        }
      ]
    }
  ]
}
```

Response:
```json
{
  "headerId": 101
}
```

## 3.5 Drawing & Point Check references
- `GET /references?formatId=1&partNo=VDE1980`
- Used on the entry screen for drawing preview and point check table.
- `partNo` is matched case-insensitively (normalized to upper case).
- Also returns `customerAbbrev` from `part_customer` (Customer name abbreviation in the sheet header after **Load**). `null` if not set.
- Order: rows with `processCode` null (part-wide) first; then by `process_master.display_order` for that part; then `drawing_no` / `check_code`. Rows whose `processCode` does not match a process in the master sort last.

Response:
```json
{
  "customerAbbrev": "YEMI",
  "drawings": [
    {
      "drawingRefId": 1,
      "processCode": "SHEARING",
      "drawingNo": "VDE1980-SH",
      "drawingName": "SHEARING PROCESS DRAWING",
      "fileUrl": null,
      "note": "Per-process drawing"
    }
  ],
  "pointChecks": [
    {
      "pointCheckRefId": 1,
      "processCode": "SHEARING",
      "checkCode": "A",
      "pointCheckText": "Cut length check",
      "criteria": "Within drawing dimensions",
      "checkMethod": "Caliper",
      "note": null
    }
  ]
}
```
(`customerAbbrev` may be `null`.)

## 4. Get checksheet detail
- `GET /checksheets/:headerId`
- Reload a saved sheet for viewing or editing.

## 5. List checksheets
- `GET /checksheets?partNo=VDE1980&from=2026-04-01&to=2026-04-30`
- History / list view.

## 6. Update status
- `PATCH /checksheets/:headerId/status`

Request:
```json
{
  "status": "SUBMITTED",
  "updatedBy": "leader01"
}
```

## 7. Master data admin (`/admin.html`)

### 7.1 Catalog (parts + processes)
- `GET /admin/catalog?formatId=1`
- Response: `{ "parts": [ { "partNo", "partName", "processes": [ { "processMasterId", "processName", "displayOrder", "activeFlag" } ] } ] }`
- `partName` comes from the assembly row in `drawing_reference` (`process_code` IS NULL, active only).

### 7.2 Part detail (drawings + point checks, includes inactive)
- `GET /admin/part-detail?formatId=1&partNo=VDE1980`
- Response: `{ "drawings": [...], "pointChecks": [...], "customerAbbrev": "YEMI" | null }` (same row fields as references API, plus `activeFlag` on rows).
- Same ordering as `GET /references` (process `display_order`; part-wide rows first).

### 7.3 New part
- `POST /admin/parts`
- Body: `{ "formatId", "partNo", "partName", "firstProcessName?" }`
- Inserts first row in `process_master` and assembly row in `drawing_reference` (`{partNo}-ASM`, `process_code` NULL).
- 409 if `partNo` already exists for the format.

### 7.3b Delete part (full purge)
- `DELETE /admin/parts/:partNo?formatId=1`
- **404** if the part has no rows in `process_master` for that format.
- In one transaction, deletes (for that `format_id` + `part_no`): all `checksheet_row_check` / `checksheet_row` / `checksheet_process` / `checksheet_header` linked to those headers; then `process_master`, `drawing_reference`, `point_check_reference`, and `part_customer` (if the table exists).

### 7.4 Add / update / delete process
- `POST /admin/processes` — Body: `{ "formatId", "partNo", "processName" }` (`display_order` = max for format + 1).
- `PATCH /admin/processes/:processMasterId` — Body: `{ "processName"?, "activeFlag"? }` (at least one required).
- `DELETE /admin/processes/:processMasterId?formatId=1&partNo=VDE1980` — Removes the row. **409** if any saved `checksheet_process` references this `process_master_id`.

### 7.5 Drawings
- `POST /admin/drawings` — Required: `formatId`, `partNo`, `drawingNo`. Omit or blank `processCode` for part-wide (common) drawing. Optional: `drawingName`, `fileUrl`, `note`.
- `PATCH /admin/drawings/:drawingRefId` — Partial update: `processCode`, `drawingNo`, `drawingName`, `fileUrl`, `note`, `activeFlag`.
- `DELETE /admin/drawings/:drawingRefId?formatId=1&partNo=VDE1980` — Hard delete (includes part-wide / assembly rows; after removal, part display name in the catalog falls back to Part No until a new assembly row exists).

### 7.6 Point checks
- `POST /admin/point-checks` — Required: `formatId`, `partNo`, `checkCode` (A–G), `pointCheckText`. Optional: `processCode` (omit for common), `criteria`, `checkMethod`, `note`.
- `PATCH /admin/point-checks/:pointCheckRefId` — Partial update for the above fields and `activeFlag`.
- `DELETE /admin/point-checks/:pointCheckRefId?formatId=1&partNo=VDE1980` — Hard delete.

### 7.7 Part display name (assembly drawing name)
- `PATCH /admin/parts/:partNo/name?formatId=1` — Body: `{ "partName" }` (updates active row with `process_code IS NULL` only).

### 7.8 Customer abbreviation (header)
- `PATCH /admin/parts/:partNo/customer?formatId=1` — Body: `{ "customerAbbrev": "YEMI" }` (upsert into `part_customer`). Empty string removes the row.

---

## Validation rules
- `rowNo` in `1..31`
- `qty` / `okCount` / `ngCount` ≥ 0
- `okCount + ngCount <= qty` when `qty` is set
- `checkCode` is `A..G`
- `result` is `OK` / `NG` / null
