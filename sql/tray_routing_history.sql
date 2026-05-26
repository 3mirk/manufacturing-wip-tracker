-- ============================================================
-- Tray Routing History Query
-- Database: IBM Informix
--
-- Purpose:
--   Reconstructs the station routing path for a given set of
--   trays by anchoring each tray's journey to the generate (gen)
--   scan event, then resolving:
--     - The latest blocker (blk) scan before gen
--     - The earliest scan at each downstream station after gen
--       (pol, eng, coat, dbl, ins)
--
-- Notes:
--   - Date/time formatting uses Informix-native TO_CHAR masks.
--   - Correlated NOT EXISTS subqueries are used in place of
--     ROW_NUMBER() OVER (...) due to Informix version constraints
--     on analytical window functions.
--   - Sub-desc LIKE patterns differ between station groups (e.g.
--     '%1A%' vs '%1-A%') because raw station descriptions are
--     inconsistently formatted across equipment groups in the
--     source system. This is intentional, not a bug.
-- ============================================================

SELECT
    tray.traynum,

    TRIM(TO_CHAR(blk.station_date, '%m-%d-%y') || ' ' || TO_CHAR(blk.station_time, '&&:&&:&&')) AS blk_scan,
    CASE
        WHEN st_blk.sub_desc LIKE '%1A%' THEN '1A'
        WHEN st_blk.sub_desc LIKE '%1B%' THEN '1B'
        WHEN st_blk.sub_desc LIKE '%2A%' THEN '2A'
        WHEN st_blk.sub_desc LIKE '%2B%' THEN '2B'
        WHEN st_blk.sub_desc LIKE '%3A%' THEN '3A'
        WHEN st_blk.sub_desc LIKE '%3B%' THEN '3B'
        WHEN st_blk.sub_desc LIKE '%3C%' THEN '3C'
        WHEN st_blk.sub_desc LIKE '%4A%' THEN '4A'
        WHEN st_blk.sub_desc LIKE '%4B%' THEN '4B'
        WHEN st_blk.sub_desc LIKE '%4C%' THEN '4C'
        ELSE st_blk.sub_desc
    END AS blk,

    TRIM(TO_CHAR(gen.station_date, '%m-%d-%y') || ' ' || TO_CHAR(gen.station_time, '&&:&&:&&')) AS gen_scan,
    CASE
        WHEN st_gen.sub_desc LIKE '%1-A%' THEN '1A'
        WHEN st_gen.sub_desc LIKE '%1-B%' THEN '1B'
        WHEN st_gen.sub_desc LIKE '%2-A%' THEN '2A'
        WHEN st_gen.sub_desc LIKE '%2-B%' THEN '2B'
        WHEN st_gen.sub_desc LIKE '%3-A%' THEN '3A'
        WHEN st_gen.sub_desc LIKE '%3-B%' THEN '3B'
        WHEN st_gen.sub_desc LIKE '%3-C%' THEN '3C'
        WHEN st_gen.sub_desc LIKE '%4-A%' THEN '4A'
        WHEN st_gen.sub_desc LIKE '%4-B%' THEN '4B'
        WHEN st_gen.sub_desc LIKE '%4-C%' THEN '4C'
        ELSE st_gen.sub_desc
    END AS gen,

    TRIM(TO_CHAR(pol.station_date, '%m-%d-%y') || ' ' || TO_CHAR(pol.station_time, '&&:&&:&&')) AS pol_scan,
    CASE
        WHEN st_pol.sub_desc LIKE '%1-A%' THEN '1A'
        WHEN st_pol.sub_desc LIKE '%1-B%' THEN '1B'
        WHEN st_pol.sub_desc LIKE '%2-A%' THEN '2A'
        WHEN st_pol.sub_desc LIKE '%2-B%' THEN '2B'
        WHEN st_pol.sub_desc LIKE '%3-A%' THEN '3A'
        WHEN st_pol.sub_desc LIKE '%3-B%' THEN '3B'
        WHEN st_pol.sub_desc LIKE '%3-C%' THEN '3C'
        WHEN st_pol.sub_desc LIKE '%4-A%' THEN '4A'
        WHEN st_pol.sub_desc LIKE '%4-B%' THEN '4B'
        WHEN st_pol.sub_desc LIKE '%4-C%' THEN '4C'
        ELSE st_pol.sub_desc
    END AS pol,

    TRIM(TO_CHAR(eng.station_date, '%m-%d-%y') || ' ' || TO_CHAR(eng.station_time, '&&:&&:&&')) AS eng_scan,
    CASE
        WHEN st_eng.sub_desc LIKE '%LASER - 1%' THEN 'ILS1'
        WHEN st_eng.sub_desc LIKE '%LASER-ART2%' THEN 'ILS2'
        WHEN st_eng.sub_desc LIKE '%LASER - 3%' THEN 'ILS3'
        WHEN st_eng.sub_desc LIKE '%4-A%'        THEN 'ILS4'
        ELSE st_eng.sub_desc
    END AS eng,

    TRIM(TO_CHAR(coat.station_date, '%m-%d-%y') || ' ' || TO_CHAR(coat.station_time, '&&:&&:&&')) AS coat_scan,
    CASE
        WHEN st_coat.sub_desc LIKE '%ART1%' THEN '44R-1'
        WHEN st_coat.sub_desc LIKE '%ART2%' THEN '44R-2'
        WHEN st_coat.sub_desc LIKE '%ART3%' THEN '44R-3'
        WHEN st_coat.sub_desc LIKE '%4-A%'  THEN '44R-4'
        ELSE st_coat.sub_desc
    END AS coat,

    TRIM(TO_CHAR(dbl.station_date, '%m-%d-%y') || ' ' || TO_CHAR(dbl.station_time, '&&:&&:&&')) AS dbl_scan,
    CASE
        WHEN st_dbl.sub_desc LIKE '%-1%' THEN 'DBA1'
        WHEN st_dbl.sub_desc LIKE '%-2%' THEN 'DBA2'
        WHEN st_dbl.sub_desc LIKE '%-3%' THEN 'DBA3'
        WHEN st_dbl.sub_desc LIKE '%-4%' THEN 'DBA4'
        ELSE st_dbl.sub_desc
    END AS dbl,

    TRIM(TO_CHAR(ins.station_date, '%m-%d-%y') || ' ' || TO_CHAR(ins.station_time, '&&:&&:&&')) AS ins_scan,
    CASE
        WHEN st_ins.sub_desc LIKE '%ART1%' THEN '3001'
        WHEN st_ins.sub_desc LIKE '%ART2%' THEN '3027'
        WHEN st_ins.sub_desc LIKE '%ART3%' THEN '102'
        WHEN st_ins.sub_desc LIKE '%4-A%'  THEN '3026'
        ELSE st_ins.sub_desc
    END AS ins,

    TO_CHAR(ins.station_date, '%m-%d-%y') AS ins_date,
    TO_CHAR(ins.station_time, '&&:&&:&&')  AS ins_time,

    TODAY - gen.station_date AS days_since_gen

FROM tray
INNER JOIN tray_hist_dtl gen
    ON gen.thistd_tx_id = tray.tray_tx_id
   AND gen.tray_station IN (1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 1010)
INNER JOIN sub_head st_gen
    ON st_gen.s_code = gen.tray_station

/* -------- BLOCKER: latest scan BEFORE the anchor (gen) event -------- */
LEFT JOIN tray_hist_dtl blk
    ON blk.thistd_tx_id = tray.tray_tx_id
   AND blk.tray_station IN (2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010)
   AND (
         (blk.station_date < gen.station_date)
      OR (blk.station_date = gen.station_date AND blk.station_time < gen.station_time)
       )
   AND NOT EXISTS (                              -- keep only the latest blk before gen
         SELECT 1
           FROM tray_hist_dtl x
          WHERE x.thistd_tx_id = tray.tray_tx_id
            AND x.tray_station IN (2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010)
            AND (
                  (x.station_date < gen.station_date)
               OR (x.station_date = gen.station_date AND x.station_time < gen.station_time)
                )
            AND (
                  x.station_date > blk.station_date
               OR (x.station_date = blk.station_date AND x.station_time > blk.station_time)
                )
       )
LEFT JOIN sub_head st_blk
    ON st_blk.s_code = blk.tray_station

/* -------- MULTIFLEX (polish): earliest scan AFTER anchor event -------- */
LEFT JOIN tray_hist_dtl pol
    ON pol.thistd_tx_id = tray.tray_tx_id
   AND pol.tray_station IN (3001, 3002, 3003, 3004, 3005, 3006, 3007, 3008, 3009, 3010)
   AND (
         (pol.station_date > gen.station_date)
      OR (pol.station_date = gen.station_date AND pol.station_time > gen.station_time)
       )
   AND NOT EXISTS (                              -- keep only the earliest pol scan after gen
         SELECT 1
           FROM tray_hist_dtl x
          WHERE x.thistd_tx_id = tray.tray_tx_id
            AND x.tray_station IN (3001, 3002, 3003, 3004, 3005, 3006, 3007, 3008, 3009, 3010)
            AND (
                  (x.station_date > gen.station_date)
               OR (x.station_date = gen.station_date AND x.station_time > gen.station_time)
                )
            AND (
                  x.station_date < pol.station_date
               OR (x.station_date = pol.station_date AND x.station_time < pol.station_time)
                )
       )
LEFT JOIN sub_head st_pol
    ON st_pol.s_code = pol.tray_station

/* -------- ENGRAVER: earliest scan AFTER anchor event -------- */
LEFT JOIN tray_hist_dtl eng
    ON eng.thistd_tx_id = tray.tray_tx_id
   AND eng.tray_station IN (4001, 4002, 4003, 4004)
   AND (
         (eng.station_date > gen.station_date)
      OR (eng.station_date = gen.station_date AND eng.station_time > gen.station_time)
       )
   AND NOT EXISTS (                              -- keep only the earliest eng scan after gen
         SELECT 1
           FROM tray_hist_dtl x
          WHERE x.thistd_tx_id = tray.tray_tx_id
            AND x.tray_station IN (4001, 4002, 4003, 4004)
            AND (
                  (x.station_date > gen.station_date)
               OR (x.station_date = gen.station_date AND x.station_time > gen.station_time)
                )
            AND (
                  x.station_date < eng.station_date
               OR (x.station_date = eng.station_date AND x.station_time < eng.station_time)
                )
       )
LEFT JOIN sub_head st_eng
    ON st_eng.s_code = eng.tray_station

/* -------- COAT (coating): earliest scan AFTER anchor event -------- */
LEFT JOIN tray_hist_dtl coat
    ON coat.thistd_tx_id = tray.tray_tx_id
   AND coat.tray_station IN (5001, 5002, 5003, 5004, 5005, 5006, 5007)
   AND (
         (coat.station_date > gen.station_date)
      OR (coat.station_date = gen.station_date AND coat.station_time > gen.station_time)
       )
   AND NOT EXISTS (                              -- keep only the earliest coat scan after gen
         SELECT 1
           FROM tray_hist_dtl x
          WHERE x.thistd_tx_id = tray.tray_tx_id
            AND x.tray_station IN (5001, 5002, 5003, 5004, 5005, 5006, 5007)
            AND (
                  (x.station_date > gen.station_date)
               OR (x.station_date = gen.station_date AND x.station_time > gen.station_time)
                )
            AND (
                  x.station_date < coat.station_date
               OR (x.station_date = coat.station_date AND x.station_time < coat.station_time)
                )
       )
LEFT JOIN sub_head st_coat
    ON st_coat.s_code = coat.tray_station

/* -------- DBL (deblocker): earliest scan AFTER anchor event -------- */
LEFT JOIN tray_hist_dtl dbl
    ON dbl.thistd_tx_id = tray.tray_tx_id
   AND dbl.tray_station IN (6001, 6002, 6003, 6004)
   AND (
         (dbl.station_date > gen.station_date)
      OR (dbl.station_date = gen.station_date AND dbl.station_time > gen.station_time)
       )
   AND NOT EXISTS (                              -- keep only the earliest dbl scan after gen
         SELECT 1
           FROM tray_hist_dtl x
          WHERE x.thistd_tx_id = tray.tray_tx_id
            AND x.tray_station IN (6001, 6002, 6003, 6004)
            AND (
                  (x.station_date > gen.station_date)
               OR (x.station_date = gen.station_date AND x.station_time > gen.station_time)
                )
            AND (
                  x.station_date < dbl.station_date
               OR (x.station_date = dbl.station_date AND x.station_time < dbl.station_time)
                )
       )
LEFT JOIN sub_head st_dbl
    ON st_dbl.s_code = dbl.tray_station

/* -------- INS (optical inspection): earliest scan AFTER anchor event -------- */
LEFT JOIN tray_hist_dtl ins
    ON ins.thistd_tx_id = tray.tray_tx_id
   AND ins.tray_station IN (7001, 7002, 7003, 7004)
   AND (
         (ins.station_date > gen.station_date)
      OR (ins.station_date = gen.station_date AND ins.station_time > gen.station_time)
       )
   AND NOT EXISTS (                              -- keep only the earliest ins scan after gen
         SELECT 1
           FROM tray_hist_dtl x
          WHERE x.thistd_tx_id = tray.tray_tx_id
            AND x.tray_station IN (7001, 7002, 7003, 7004)
            AND (
                  (x.station_date > gen.station_date)
               OR (x.station_date = gen.station_date AND x.station_time > gen.station_time)
                )
            AND (
                  x.station_date < ins.station_date
               OR (x.station_date = ins.station_date AND x.station_time < ins.station_time)
                )
       )
LEFT JOIN sub_head st_ins
    ON st_ins.s_code = ins.tray_station

WHERE
    tray.traynum IN ('1111', '2222', '3333', '4444', '5555', '6666', '7777', '8888', '9999', '1234')
    AND gen.station_date >= TODAY - 40 UNITS DAY

ORDER BY
    gen.station_date DESC;
