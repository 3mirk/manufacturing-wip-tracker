# manufacturing-wip-tracker

Manufacturing tray routing tracer built on IBM Informix. Anchors each tray's journey to a key inspection event, then resolves upstream and downstream station scans using correlated subqueries. Query output feeds a Power BI data model joined to optical measurement results for station-level production traceability.

---

## What this does

In high-volume manufacturing, a tray carries units through a sequence of production stations. Each scan creates a timestamped record in a history table. This tool uses subqueries to pivot multiple records into a single-row routing summary per tray from a flat event log that may contain repeated visits, out-of-order scans, and multiple machines per station type.

This query solves that by anchoring each tray's record to a specific inspection event (the **generate** scan), then resolving:

- the **latest** upstream station scan that occurred before that anchor
- the **earliest** scan at each downstream station after that anchor

The result is one row per tray showing exactly which machine processed it at each stage of the production flow, along with timestamps for each station visit.

---

## Production pipeline

```
[blk] → [gen ★] → [pol] → [eng] → [coat] → [dbl] → [ins]
              ↑
         anchor event
```

The generate scan is the anchor point. Everything to the left is resolved backward in time; everything to the right is resolved forward. `★` marks the INNER JOIN — trays without a generate scan are excluded entirely.

---

## Key SQL technique

Standard SQL would handle "latest before" and "earliest after" using `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)`. IBM Informix's support for analytical window functions is version-dependent; this query uses correlated `NOT EXISTS` subqueries as an equivalent, portable alternative.

The pattern for each station follows this logic:

```sql
-- Keep only the earliest downstream scan after the anchor event
LEFT JOIN tray_hist_dtl station_x
    ON station_x.thistd_tx_id = tray.tray_tx_id
   AND station_x.tray_station IN (...)
   AND station_x.station_date >= gen.station_date  -- after anchor
   AND NOT EXISTS (
         SELECT 1 FROM tray_hist_dtl x
          WHERE x.thistd_tx_id = tray.tray_tx_id
            AND x.tray_station IN (...)
            AND x.station_date >= gen.station_date  -- also after anchor
            AND x.station_date < station_x.station_date  -- but earlier
       )
```

For the upstream blocker, the inequality directions are reversed to capture the latest scan before the anchor.

---

## Data model

The query output is loaded into Power BI and joined to a separate measurement results table on tray ID. This creates a data model where every measurement record carries the full station routing context — enabling analysis like:

- which machine produced the highest defect rate
- whether measurement outcomes correlate with specific equipment combinations
- retrospective tracing of a quality excursion back to a production station

```
tray_routing (this query)          measurement_results
─────────────────────────          ───────────────────
traynum          ◄────────────────► traynum
blk, blk_scan                       measurement_value
gen, gen_scan                        result_flag
pol, pol_scan                        ...
eng, eng_scan
coat, coat_scan
dbl, dbl_scan
ins, ins_scan
days_since_gen
```

---

## Database

**IBM Informix** — date/time formatting uses Informix-native `TO_CHAR` masks (`%m-%d-%y`, `&&:&&:&&`). The query will not run as-is on PostgreSQL or SQL Server without syntax adaptation.

Station codes and tray numbers in this repository have been replaced with placeholder values.

---

## Files

| File | Description |
|---|---|
| `sql/tray_routing.sql` | Main routing history query |
| `sql/schema_notes.md` | Table and column reference |
