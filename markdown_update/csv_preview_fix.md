# Fix: CSV preview modal shows raw JSON, no loading state

## Problem

"Preview first rows" currently dumps the parsed row objects straight into a
`Text` widget — effectively `row.toString()` / a JSON-ish map literal
(`{ID: L0001, Breed: Holstein, Age: 4, ...}`) rendered as one long paragraph.
It's technically correct but unreadable: no columns, no alignment, no way to
scan values at a glance. There's also no loading indicator between picking
the file and the preview appearing, or between tapping **Import** and the
import finishing.

## Fix 1 — render rows as a table, not text

Replace the `Text(row.toString())` block with a `DataTable` (or a
horizontally scrollable row-of-cells layout), one column per CSV field.

```dart
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: DataTable(
    columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
    rows: previewRows.map((row) => DataRow(
      cells: row.map((v) => DataCell(Text(v.toString()))).toList(),
    )).toList(),
  ),
),
```

- Wrap in `SingleChildScrollView(scrollDirection: Axis.horizontal)` since
  there are ~14 columns — a mobile screen can't show them all at once.
- Label the truncation explicitly: **"Showing 4 of 128 rows"** instead of
  silently cutting off after row 4.

## Fix 2 — add loading states

Two separate gaps need a spinner:

**a) Parsing the file** (between file picked and the preview dialog
appearing) — larger CSVs can take a noticeable moment to parse.

```dart
bool isParsing = true;
...
isParsing
  ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
  : previewTable
```

**b) Importing** (between tapping Import and the dialog closing) — disable
the button and swap its label for a small inline spinner so it's clear the
tap registered and nothing else can be tapped mid-import.

```dart
ElevatedButton(
  onPressed: isImporting ? null : _handleImport,
  child: isImporting
      ? const SizedBox(
          height: 16, width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : const Text('Import'),
),
```

## Checklist

- [ ] Preview body is a `DataTable` (or equivalent), not a `Text` of the raw
      row object.
- [ ] Preview is horizontally scrollable.
- [ ] Preview states the total row count vs. rows shown.
- [ ] A loading indicator shows while the file is being parsed, before the
      dialog appears.
- [ ] The Import button disables and shows a spinner while the import is
      running, instead of staying tappable with no feedback.