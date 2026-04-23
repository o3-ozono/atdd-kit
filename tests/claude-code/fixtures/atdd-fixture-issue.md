# Issue #999: feat: add CSV export to report page

## Labels
type:development, ready-to-go

## Body

As a user, I want to export the report table as CSV so I can analyze the data in Excel.

## Acceptance Criteria

### AC1: Export button present on report page
- **Given:** The user is on the report page
- **When:** The page loads
- **Then:** An "Export CSV" button is visible in the toolbar

### AC2: CSV file is downloaded on click
- **Given:** The user is on the report page with data
- **When:** The user clicks "Export CSV"
- **Then:** A CSV file is downloaded with filename `report-YYYY-MM-DD.csv`

### AC3: CSV columns match table columns
- **Given:** The report table has columns: Date, Category, Amount
- **When:** The user exports to CSV
- **Then:** The CSV file contains the same columns in the same order

## Test and Implementation Strategy

### Test approach
- AC1: E2E test using Playwright — verify button presence
- AC2: E2E test — trigger click and assert file download
- AC3: Unit test — assert column headers match

### Implementation approach
- Add `ExportButton` component to `ReportPage`
- Implement `generateCsv(data, columns)` utility
- Wire download via `URL.createObjectURL`

## Plan
- Branch: `feat/999-csv-export`
- Estimated ACs: 3
