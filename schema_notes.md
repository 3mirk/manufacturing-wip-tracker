# Schema notes

This document describes the tables and columns referenced in `tray_routing.sql`. Table and column names reflect the source system as-is. Station codes and tray numbers have been replaced with placeholder values throughout.

---

## Tables

### `tray`

The primary unit of work. Each row represents a physical tray that carries units through the production line.

| Column | Type | Description |
|---|---|---|
| `tray_tx_id` | integer | Unique transaction ID for the tray. Used as the join key to history records. |
| `traynum` | varchar | Human-readable tray identifier. Used in the `WHERE` clause to filter for trays of interest. |

---

### `tray_hist_dtl`

The event log. Every time a tray is scanned at a station, a row is inserted here with a timestamp and station code. A single tray can have many rows — one per scan event across its entire production journey.

| Column | Type | Description |
|---|---|---|
| `thistd_tx_id` | integer | Foreign key back to `tray.tray_tx_id`. |
| `tray_station` | integer | Numeric station code identifying which machine or station group processed the tray. |
| `station_date` | date | Date the scan occurred. |
| `station_time` | integer | Time the scan occurred, stored as an integer in `HHMMSS` format. Formatted using Informix `TO_CHAR` mask `&&:&&:&&` to render as `HH:MM:SS`. |

This table is joined multiple times in the query — once per station group — each join alias representing a different stage of the production flow.

---

### `sub_head`

A reference/lookup table that maps numeric station codes to human-readable station descriptions.

| Column | Type | Description |
|---|---|---|
| `s_code` | integer | Numeric station code. Joins to `tray_hist_dtl.tray_station`. |
| `sub_desc` | varchar | Free-text description of the station or machine. Used in `CASE` expressions to map raw descriptions to clean abbreviated labels. |

> **Note:** `sub_desc` formatting is inconsistent across station groups — some use formats like `1A`, others `1-A`. The `CASE` `LIKE` patterns in the query account for this per station group. This is a known source system inconsistency, not a query bug.

---

## Station groups

Each station group is identified by a set of numeric `tray_station` codes. The query uses placeholder values; in production these are the actual machine IDs registered in `sub_head`.

| Alias in query | Stage | Temporal logic |
|---|---|---|
| `gen` | Generate (inspection) | Anchor event — INNER JOIN, required |
| `blk` | Blocker | Latest scan **before** anchor |
| `pol` | Polish | Earliest scan **after** anchor |
| `eng` | Engraver | Earliest scan **after** anchor |
| `coat` | Coating | Earliest scan **after** anchor |
| `dbl` | Deblocker | Earliest scan **after** anchor |
| `ins` | Optical inspection device | Earliest scan **after** anchor |

The generate scan is the only required station — all others are LEFT JOINed and will appear as NULL if the tray had not yet reached that station at query time, or if no scan record exists.
