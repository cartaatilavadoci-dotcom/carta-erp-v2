-- ===========================================================================
-- OEE Shift Reports View v2 — Quality + Tisak + camelCase fix + suspicious flag
-- ===========================================================================
-- Razlozi za migraciju:
--  1. Tuber piše ključeve u camelCase (cekanjeTuljke, vanStroja, skartKom),
--     stari view čitao samo snake_case → 0 vrijednosti za Tuber smjene.
--  2. Tisak modul nije bio podržan (drugačiji "rows" struct, "prestel"/"priprema",
--     production_line=NULL, target speed u m/min ne kom/min).
--  3. quality_pct bio hardkodiran 100 → nema kvalitetne komponente OEE.
--  4. Outlieri (npr. performance 872%) prolazili u dashboard.
--  5. Nije postojao flag za "sumnjive" smjene (typo u rad/kvar/kom).
--
-- Što se mijenja:
--  - v_shift_reports_oee: novi izračun, dodane kolone scrap_pcs, produced_meters,
--    performance_raw_pct, oee_pct, is_suspicious, line_grouped.
--  - v_oee_daily_summary i v_oee_monthly: COALESCE(production_line,'TISAK') da
--    Tisak smjene padaju u svoju grupu umjesto NULL-a.
-- ===========================================================================

DROP VIEW IF EXISTS v_oee_dashboard CASCADE;
DROP VIEW IF EXISTS v_oee_monthly CASCADE;
DROP VIEW IF EXISTS v_oee_daily_summary CASCADE;
DROP VIEW IF EXISTS v_oee_operator_ranking CASCADE;
DROP VIEW IF EXISTS v_shift_reports_oee CASCADE;

-- ---------------------------------------------------------------------------
-- v_shift_reports_oee — jedan red po smjeni × stroj × linija
-- ---------------------------------------------------------------------------
CREATE VIEW v_shift_reports_oee AS
WITH oee_settings AS (
  SELECT key, value AS val
  FROM settings
  WHERE category = 'OEE'
),
parsed AS (
  SELECT
    sr.id,
    sr.production_line,
    sr.shift_date,
    sr.shift_number,
    sr.strojar AS operator_name,
    sr.pomocnici,
    sr.napomena,
    sr.created_at,
    COALESCE(NULLIF(sr.machine_type, ''), 'Bottomer') AS machine_type,
    sr.report_data,
    -- numeric extracts (NULLIF za '' empty stringove iz Tisak modula)
    NULLIF(sr.report_data->'ukupno'->>'kom', '')::numeric                                           AS kom,
    NULLIF(sr.report_data->'ukupno'->>'rad', '')::numeric                                           AS rad_h,
    NULLIF(sr.report_data->'ukupno'->>'kvar', '')::numeric                                          AS kvar_h,
    NULLIF(sr.report_data->'ukupno'->>'skart', '')::numeric                                         AS skart_kg,
    -- skart_kom: snake_case (Bottomer/Tisak) ILI camelCase (Tuber)
    COALESCE(
      NULLIF(sr.report_data->'ukupno'->>'skart_kom', '')::numeric,
      NULLIF(sr.report_data->'ukupno'->>'skartKom', '')::numeric
    )                                                                                               AS skart_kom_raw,
    -- setup: prestelavanje (Bottomer/Tuber) ILI prestel (Tisak)
    COALESCE(
      NULLIF(sr.report_data->'ukupno'->>'prestelavanje', '')::numeric,
      NULLIF(sr.report_data->'ukupno'->>'prestel', '')::numeric
    )                                                                                               AS setup_h,
    NULLIF(sr.report_data->'ukupno'->>'priprema', '')::numeric                                      AS priprema_h,
    NULLIF(sr.report_data->'ukupno'->>'pripremaRad', '')::numeric                                   AS priprema_rad_h,
    NULLIF(sr.report_data->'ukupno'->>'cekanje', '')::numeric                                       AS cekanje_h,
    -- cekanje_tuljke: snake_case ILI camelCase
    COALESCE(
      NULLIF(sr.report_data->'ukupno'->>'cekanje_tuljke', '')::numeric,
      NULLIF(sr.report_data->'ukupno'->>'cekanjeTuljke', '')::numeric
    )                                                                                               AS cekanje_tuljke_h,
    -- van_stroja: snake_case ILI camelCase
    COALESCE(
      NULLIF(sr.report_data->'ukupno'->>'van_stroja', '')::numeric,
      NULLIF(sr.report_data->'ukupno'->>'vanStroja', '')::numeric
    )                                                                                               AS van_stroja_h,
    NULLIF(sr.report_data->'ukupno'->>'ciscenje', '')::numeric                                      AS ciscenje_h,
    NULLIF(sr.report_data->'ukupno'->>'metri', '')::numeric                                         AS metri,
    -- orders_count: nalozi (Bottomer) | work_orders (Tuber) | rows (Tisak)
    COALESCE(
      jsonb_array_length(sr.report_data->'nalozi'),
      jsonb_array_length(sr.report_data->'work_orders'),
      jsonb_array_length(sr.report_data->'rows'),
      0
    )                                                                                               AS orders_count
  FROM prod_shift_reports sr
  WHERE sr.report_data IS NOT NULL
    AND sr.report_data->'ukupno' IS NOT NULL
),
zeroed AS (
  SELECT
    p.*,
    -- Zero-coalesced za izračune
    COALESCE(p.kom, 0)               AS kom_z,
    COALESCE(p.skart_kom_raw, 0)     AS skart_kom_z,
    COALESCE(p.skart_kg, 0)          AS skart_kg_z,
    COALESCE(p.metri, 0)             AS metri_z,
    COALESCE(p.rad_h, 0)             AS rad_h_z,
    COALESCE(p.kvar_h, 0)            AS kvar_h_z,
    COALESCE(p.setup_h, 0)
      + COALESCE(p.priprema_h, 0)
      + COALESCE(p.priprema_rad_h, 0) AS setup_h_z,
    COALESCE(p.cekanje_h, 0)         AS cekanje_h_z,
    COALESCE(p.cekanje_tuljke_h, 0)  AS cekanje_tuljke_h_z,
    COALESCE(p.van_stroja_h, 0)      AS van_stroja_h_z,
    COALESCE(p.ciscenje_h, 0)        AS ciscenje_h_z,
    -- Target speed: prvo (machine_type)_(production_line) granular, pa generic, pa Tisak special
    COALESCE(
      (SELECT val FROM oee_settings
        WHERE key = 'oee_target_speed_'
                  || lower(COALESCE(p.machine_type, ''))
                  || '_'
                  || lower(COALESCE(p.production_line, ''))),
      (SELECT val FROM oee_settings
        WHERE lower(p.machine_type) = 'tisak'
          AND key = 'oee_target_speed_tisak_flexotecnica'),
      (SELECT val FROM oee_settings
        WHERE key = 'oee_target_speed_' || lower(COALESCE(p.machine_type, ''))),
      150
    )                                AS target_speed_ppm
  FROM parsed p
),
calc AS (
  SELECT
    z.*,
    -- Planned production time = run + breakdown + waiting + setup
    -- (cleaning + outside_machine se ne računaju jer su planirani / off-machine)
    (z.rad_h_z + z.kvar_h_z + z.cekanje_h_z + z.cekanje_tuljke_h_z + z.setup_h_z) AS planned_time_h,
    -- Total logged (sve unose, koristi se za suspicious flag)
    (z.rad_h_z + z.kvar_h_z + z.setup_h_z + z.cekanje_h_z
      + z.cekanje_tuljke_h_z + z.van_stroja_h_z + z.ciscenje_h_z)                AS total_logged_h,
    -- Performance numerator: Tisak koristi metre, ostali komade
    CASE WHEN lower(z.machine_type) = 'tisak' THEN z.metri_z ELSE z.kom_z END    AS perf_numerator,
    -- Performance kapacitet (rad_h × 60 × target_speed)
    (z.rad_h_z * 60 * z.target_speed_ppm)                                        AS perf_capacity
  FROM zeroed z
)
SELECT
  c.id,
  c.production_line,
  c.shift_date,
  c.shift_number,
  c.operator_name,
  c.pomocnici,
  c.machine_type,
  c.kom_z::integer                                                               AS produced_quantity,
  c.skart_kg_z                                                                   AS scrap_kg,
  c.setup_h_z                                                                    AS setup_hours,
  c.rad_h_z                                                                      AS run_hours,
  c.kvar_h_z                                                                     AS breakdown_hours,
  c.cekanje_tuljke_h_z                                                           AS waiting_tuljke_hours,
  c.van_stroja_h_z                                                               AS outside_machine_hours,
  c.cekanje_h_z                                                                  AS waiting_hours,
  c.ciscenje_h_z                                                                 AS cleaning_hours,
  c.orders_count,
  c.total_logged_h                                                               AS total_logged_hours,
  (c.kvar_h_z + c.cekanje_h_z + c.cekanje_tuljke_h_z)                            AS total_downtime_hours,
  c.target_speed_ppm::integer                                                    AS target_speed_ppm,
  -- AVAILABILITY (capped 0..100)
  CASE
    WHEN c.planned_time_h > 0
      THEN ROUND(LEAST(100, c.rad_h_z * 100.0 / NULLIF(c.planned_time_h, 0)), 1)
    ELSE 0
  END                                                                            AS availability_pct,
  -- PERFORMANCE (capped 0..100)
  CASE
    WHEN c.perf_capacity > 0
      THEN ROUND(LEAST(100, c.perf_numerator * 100.0 / NULLIF(c.perf_capacity, 0)), 1)
    ELSE 0
  END                                                                            AS performance_pct,
  -- QUALITY: realna ako je skart_kom unesen, inače 100% (NULL = neuneseno)
  CASE
    WHEN c.kom_z > 0 AND c.skart_kom_raw IS NOT NULL
      THEN GREATEST(0, ROUND((c.kom_z - c.skart_kom_z) * 100.0 / NULLIF(c.kom_z, 0), 1))
    ELSE 100.0
  END                                                                            AS quality_pct,
  c.napomena,
  c.created_at,
  -- ===== Nove kolone (v2) =====
  -- line_grouped: za Tisak (production_line=NULL) vrati 'TISAK' da grupiranje radi
  COALESCE(
    c.production_line,
    CASE WHEN lower(c.machine_type) = 'tisak' THEN 'TISAK' ELSE NULL END
  )                                                                              AS line_grouped,
  c.metri_z                                                                      AS produced_meters,
  c.skart_kom_z::integer                                                         AS scrap_pcs,
  c.skart_kom_raw                                                                AS scrap_pcs_raw,  -- NULL = nije unesen
  -- Raw performance (prije cappinga) — za suspicious detection
  CASE
    WHEN c.perf_capacity > 0
      THEN ROUND(c.perf_numerator * 100.0 / NULLIF(c.perf_capacity, 0), 1)
    ELSE 0
  END                                                                            AS performance_raw_pct,
  -- OEE = A × P × Q / 10000  (sve već cappane)
  ROUND(
    CASE WHEN c.planned_time_h > 0
      THEN LEAST(100, c.rad_h_z * 100.0 / NULLIF(c.planned_time_h, 0))
      ELSE 0 END
    *
    CASE WHEN c.perf_capacity > 0
      THEN LEAST(100, c.perf_numerator * 100.0 / NULLIF(c.perf_capacity, 0))
      ELSE 0 END
    *
    CASE
      WHEN c.kom_z > 0 AND c.skart_kom_raw IS NOT NULL
        THEN GREATEST(0, (c.kom_z - c.skart_kom_z) * 100.0 / NULLIF(c.kom_z, 0))
      ELSE 100.0 END
    / 10000.0
  , 1)                                                                           AS oee_pct,
  -- IS_SUSPICIOUS: bilo koji od ovih signala = označi za pregled
  (
    -- raw performance > 150% (prije cappinga, znak typo u rad ili target)
    (c.perf_capacity > 0 AND (c.perf_numerator * 100.0 / NULLIF(c.perf_capacity, 0)) > 150)
    OR (c.total_logged_h > 12)                       -- ukupno > 12h (smjena je 8h)
    OR (c.rad_h_z < 0.5 AND c.kom_z > 1000)          -- rad upisan u h umjesto sati?
    OR (c.kvar_h_z > 8)                              -- cijela smjena je kvar?
    OR (c.kom_z > 0 AND c.skart_kom_raw IS NULL)     -- škart nije unesen
  )                                                                              AS is_suspicious
FROM calc c;

COMMENT ON VIEW v_shift_reports_oee IS
  'OEE per smjena × stroj — izvor: prod_shift_reports (ručno unose voditelji). '
  'Quality dolazi iz scrap_pcs_raw (NULL = neuneseno → 100%). '
  'Performance i Availability cappani na 100%. '
  'is_suspicious = true ako postoje signali typo-a u unosu.';

-- ---------------------------------------------------------------------------
-- v_oee_daily_summary — agregat po danu × liniji × stroju
-- ---------------------------------------------------------------------------
CREATE VIEW v_oee_daily_summary AS
SELECT
  shift_date,
  COALESCE(production_line, line_grouped) AS production_line,
  machine_type,
  SUM(produced_quantity)               AS total_produced,
  SUM(produced_meters)                 AS total_produced_meters,
  SUM(scrap_kg)                        AS total_scrap_kg,
  SUM(scrap_pcs)                       AS total_scrap_pcs,
  SUM(run_hours)                       AS total_run_hours,
  SUM(breakdown_hours)                 AS total_breakdown_hours,
  SUM(waiting_hours + waiting_tuljke_hours) AS total_waiting_hours,
  SUM(setup_hours)                     AS total_setup_hours,
  SUM(orders_count)                    AS total_orders,
  COUNT(*)                             AS shifts_count,
  COUNT(*) FILTER (WHERE is_suspicious) AS suspicious_count,
  ROUND(AVG(availability_pct), 1)      AS avg_availability,
  ROUND(AVG(performance_pct), 1)       AS avg_performance,
  ROUND(AVG(quality_pct), 1)           AS avg_quality,
  ROUND(AVG(oee_pct), 1)               AS avg_oee
FROM v_shift_reports_oee
GROUP BY shift_date, COALESCE(production_line, line_grouped), machine_type
ORDER BY shift_date DESC, COALESCE(production_line, line_grouped);

COMMENT ON VIEW v_oee_daily_summary IS 'OEE agregat po danu × liniji × tipu stroja';

-- ---------------------------------------------------------------------------
-- v_oee_monthly — agregat po mjesecu × liniji × stroju × operateru
-- ---------------------------------------------------------------------------
CREATE VIEW v_oee_monthly AS
SELECT
  date_trunc('month', shift_date::timestamptz)::date AS month,
  COALESCE(production_line, line_grouped) AS production_line,
  machine_type,
  operator_name,
  COUNT(*)                             AS total_shifts,
  COUNT(*) FILTER (WHERE is_suspicious) AS suspicious_shifts,
  SUM(produced_quantity)               AS total_produced,
  SUM(produced_meters)                 AS total_produced_meters,
  SUM(scrap_kg)                        AS total_scrap_kg,
  SUM(scrap_pcs)                       AS total_scrap_pcs,
  SUM(orders_count)                    AS total_orders,
  SUM(run_hours)                       AS total_run_hours,
  SUM(setup_hours)                     AS total_setup_hours,
  SUM(breakdown_hours)                 AS total_breakdown_hours,
  SUM(waiting_hours + waiting_tuljke_hours) AS total_waiting_hours,
  ROUND(AVG(availability_pct), 1)      AS avg_availability,
  ROUND(AVG(performance_pct), 1)       AS avg_performance,
  ROUND(AVG(quality_pct), 1)           AS avg_quality,
  ROUND(AVG(oee_pct), 1)               AS avg_oee,
  ROUND(MIN(oee_pct), 1)               AS min_oee,
  ROUND(MAX(oee_pct), 1)               AS max_oee
FROM v_shift_reports_oee
WHERE produced_quantity > 0
GROUP BY date_trunc('month', shift_date::timestamptz),
         COALESCE(production_line, line_grouped),
         machine_type,
         operator_name
ORDER BY date_trunc('month', shift_date::timestamptz)::date DESC,
         COALESCE(production_line, line_grouped),
         avg_oee DESC;

COMMENT ON VIEW v_oee_monthly IS 'OEE agregat po mjesecu × liniji × stroju × operateru';

-- ---------------------------------------------------------------------------
-- v_oee_dashboard — recreating (bio CASCADE-ovan)
-- ---------------------------------------------------------------------------
-- Per-smjena (NE agregirano) - dashboard.html agregira u JS-u i koristi shift_date filter
CREATE VIEW v_oee_dashboard AS
SELECT
  shift_date,
  COALESCE(production_line, line_grouped) AS production_line,
  machine_type,
  availability_pct,
  performance_pct,
  quality_pct,
  oee_pct
FROM v_shift_reports_oee
WHERE oee_pct > 0 AND oee_pct <= 100;

COMMENT ON VIEW v_oee_dashboard IS 'OEE per smjena (filtrirano valid range) - dashboard.html agregira u JS-u';

-- ---------------------------------------------------------------------------
-- v_oee_operator_ranking — recreating (bio CASCADE-ovan)
-- ---------------------------------------------------------------------------
CREATE VIEW v_oee_operator_ranking AS
SELECT
  operator_name,
  COALESCE(production_line, line_grouped) AS production_line,
  machine_type,
  COUNT(*)                        AS total_shifts,
  ROUND(AVG(oee_pct), 1)          AS avg_oee,
  ROUND(AVG(availability_pct), 1) AS avg_availability,
  ROUND(AVG(performance_pct), 1)  AS avg_performance,
  ROUND(AVG(quality_pct), 1)      AS avg_quality,
  SUM(produced_quantity)          AS total_produced,
  SUM(produced_meters)            AS total_produced_meters
FROM v_shift_reports_oee
WHERE produced_quantity > 0
  AND operator_name IS NOT NULL
  AND shift_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY operator_name, COALESCE(production_line, line_grouped), machine_type
HAVING COUNT(*) >= 3
ORDER BY ROUND(AVG(oee_pct), 1) DESC;

COMMENT ON VIEW v_oee_operator_ranking IS 'Operater ranking po OEE — zadnjih 90 dana, min 3 smjene';
