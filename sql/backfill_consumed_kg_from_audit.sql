-- ============================================================
-- BACKFILL: consumed_kg iz prod_inventory_consumed_rolls
-- Datum: 2026-04-14
-- Svrha: Popraviti 557 rola koje su pogođene GENERATED column bugom
-- ============================================================
-- POZADINA:
-- Od početka veljače 2026. tuber-materijal.html slao je `remaining_kg`
-- u UPDATE payload, ali remaining_kg je GENERATED kolona.
-- Postgres odbijao je SVE takve UPDATE-e, pa consumed_kg i status
-- nisu ažurirani. Operateri su vidjeli lažni success log.
--
-- EVIDENCIJA: sva potrošnja je uredno spremljena u
-- prod_inventory_consumed_rolls (insert tamo je radio).
-- Dakle - bazu popravljamo iz tog audit traila.
-- ============================================================
-- KAKO POKRENUTI:
--   1. Otvori Supabase Dashboard → SQL Editor
--   2. Pokreni sekciju 1 (PREVIEW) - provjeri rezultate
--   3. Pokreni sekciju 2 (BACKFILL) kao transakciju
--   4. Pokreni sekciju 3 (VERIFICATION) za potvrdu
-- ============================================================


-- ============================================================
-- SEKCIJA 1: PREVIEW (SELECT - bez promjena)
-- Pokaži što će se promijeniti
-- ============================================================

-- 1a. prod_inventory_rolls - rola koje će biti ažurirane
WITH evidencija AS (
  SELECT source_roll_id, SUM(consumed_kg) AS ukupno_evid_kg
  FROM prod_inventory_consumed_rolls
  WHERE source_table = 'prod_inventory_rolls'
    AND source_roll_id IS NOT NULL
  GROUP BY source_roll_id
)
SELECT
  r.roll_code,
  r.initial_weight_kg,
  r.consumed_kg AS staro_consumed_kg,
  LEAST(e.ukupno_evid_kg, r.initial_weight_kg)::numeric(10,3) AS novo_consumed_kg,
  (r.initial_weight_kg - LEAST(e.ukupno_evid_kg, r.initial_weight_kg))::numeric(10,3) AS novi_remaining_kg,
  r.status AS stari_status,
  CASE
    WHEN (r.initial_weight_kg - LEAST(e.ukupno_evid_kg, r.initial_weight_kg)) < 20 THEN 'Utrošeno'
    WHEN e.ukupno_evid_kg >= r.initial_weight_kg THEN 'Utrošeno'
    ELSE 'Djelomično'
  END AS novi_status
FROM prod_inventory_rolls r
JOIN evidencija e ON e.source_roll_id = r.id
WHERE e.ukupno_evid_kg > COALESCE(r.consumed_kg, 0) + 0.01  -- pragmatic tolerance
ORDER BY r.updated_at DESC;

-- 1b. prod_inventory_printed - isto
WITH evidencija AS (
  SELECT source_roll_id, SUM(consumed_kg) AS ukupno_evid_kg
  FROM prod_inventory_consumed_rolls
  WHERE source_table = 'prod_inventory_printed'
    AND source_roll_id IS NOT NULL
  GROUP BY source_roll_id
)
SELECT
  p.id,
  p.weight_kg AS inicijalna_tezina,
  p.consumed_kg AS staro_consumed_kg,
  LEAST(e.ukupno_evid_kg, p.weight_kg)::numeric(10,3) AS novo_consumed_kg,
  (p.weight_kg - LEAST(e.ukupno_evid_kg, p.weight_kg))::numeric(10,3) AS novi_remaining_kg,
  p.status AS stari_status,
  CASE
    WHEN (p.weight_kg - LEAST(e.ukupno_evid_kg, p.weight_kg)) < 20 THEN 'Utrošeno'
    WHEN e.ukupno_evid_kg >= p.weight_kg THEN 'Utrošeno'
    ELSE 'Djelomično'
  END AS novi_status
FROM prod_inventory_printed p
JOIN evidencija e ON e.source_roll_id = p.id
WHERE e.ukupno_evid_kg > COALESCE(p.consumed_kg, 0) + 0.01
ORDER BY p.updated_at DESC;


-- ============================================================
-- SEKCIJA 2: BACKFILL (transakcija s rollback opcijom)
-- NAPOMENA: Pokreni u ZASEBNOM query-ju
-- ============================================================

BEGIN;

-- 2a. Backfill prod_inventory_rolls
WITH evidencija AS (
  SELECT source_roll_id, SUM(consumed_kg) AS ukupno_evid_kg
  FROM prod_inventory_consumed_rolls
  WHERE source_table = 'prod_inventory_rolls'
    AND source_roll_id IS NOT NULL
  GROUP BY source_roll_id
)
UPDATE prod_inventory_rolls r
SET
  consumed_kg = LEAST(e.ukupno_evid_kg, r.initial_weight_kg),
  status = CASE
    WHEN (r.initial_weight_kg - LEAST(e.ukupno_evid_kg, r.initial_weight_kg)) < 20 THEN 'Utrošeno'
    WHEN e.ukupno_evid_kg >= r.initial_weight_kg THEN 'Utrošeno'
    ELSE 'Djelomično'
  END,
  updated_at = NOW()
FROM evidencija e
WHERE e.source_roll_id = r.id
  AND e.ukupno_evid_kg > COALESCE(r.consumed_kg, 0) + 0.01;

-- 2b. Backfill prod_inventory_printed
WITH evidencija AS (
  SELECT source_roll_id, SUM(consumed_kg) AS ukupno_evid_kg
  FROM prod_inventory_consumed_rolls
  WHERE source_table = 'prod_inventory_printed'
    AND source_roll_id IS NOT NULL
  GROUP BY source_roll_id
)
UPDATE prod_inventory_printed p
SET
  consumed_kg = LEAST(e.ukupno_evid_kg, p.weight_kg),
  status = CASE
    WHEN (p.weight_kg - LEAST(e.ukupno_evid_kg, p.weight_kg)) < 20 THEN 'Utrošeno'
    WHEN e.ukupno_evid_kg >= p.weight_kg THEN 'Utrošeno'
    ELSE 'Djelomično'
  END,
  updated_at = NOW()
FROM evidencija e
WHERE e.source_roll_id = p.id
  AND e.ukupno_evid_kg > COALESCE(p.consumed_kg, 0) + 0.01;

-- Prije COMMIT-a: provjeri rezultat
-- (možeš pokrenuti SEKCIJU 3 dok si još unutar transakcije)

-- Ako si zadovoljan:
--   COMMIT;
-- Ako nešto ne valja:
--   ROLLBACK;

COMMIT;


-- ============================================================
-- SEKCIJA 3: VERIFIKACIJA (SELECT - nakon backfilla)
-- ============================================================

-- 3a. Koliko rola je ostalo s bugom (trebalo bi biti 0)
WITH ev AS (
  SELECT source_roll_id, source_table, SUM(consumed_kg) AS evid_kg
  FROM prod_inventory_consumed_rolls
  WHERE source_roll_id IS NOT NULL
  GROUP BY source_roll_id, source_table
)
SELECT
  'rolls' AS tip,
  COUNT(*) FILTER (WHERE r.consumed_kg + 0.01 < ev.evid_kg) AS jos_s_bugom,
  COUNT(*) AS ukupno_s_evidencijom
FROM ev
JOIN prod_inventory_rolls r ON r.id = ev.source_roll_id AND ev.source_table='prod_inventory_rolls'
UNION ALL
SELECT
  'printed',
  COUNT(*) FILTER (WHERE p.consumed_kg + 0.01 < ev.evid_kg),
  COUNT(*)
FROM ev
JOIN prod_inventory_printed p ON p.id = ev.source_roll_id AND ev.source_table='prod_inventory_printed';

-- 3b. Novo stanje inventara
SELECT
  'rolls' AS tip,
  COUNT(*) FILTER (WHERE status='Na skladištu') AS na_skladistu,
  COUNT(*) FILTER (WHERE status='Djelomično') AS djelomicno,
  COUNT(*) FILTER (WHERE status='Utrošeno') AS utroseno,
  ROUND(SUM(remaining_kg) FILTER (WHERE status IN ('Na skladištu','Djelomično'))::numeric, 0) AS stvarni_kg_na_skladistu
FROM prod_inventory_rolls
UNION ALL
SELECT
  'printed',
  COUNT(*) FILTER (WHERE status='Na skladištu'),
  COUNT(*) FILTER (WHERE status='Djelomično'),
  COUNT(*) FILTER (WHERE status='Utrošeno'),
  ROUND(SUM(remaining_kg) FILTER (WHERE status IN ('Na skladištu','Djelomično'))::numeric, 0)
FROM prod_inventory_printed;
