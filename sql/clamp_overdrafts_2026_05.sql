-- =============================================================================
-- CLAMP: 66 rola s consumed_kg > initial_weight_kg (negativan remaining_kg)
-- =============================================================================
-- Strategija: za svaku takvu rolu, postavi consumed_kg = initial_weight_kg
-- (clamp na 0 remaining), i logaj u discrepancy_log s reason='legacy_overdraft'.
-- Razlika delta_kg ide kao "izgubljeno" — admin može kasnije pregledati.
--
-- IZVRŠAVA SE RUČNO. Pokreni dry-run prvo, pa apply.
-- =============================================================================

-- -------------------------------------------------------------
-- DRY-RUN: što će se clamp-ati
-- -------------------------------------------------------------
SELECT 'BEFORE: rola s overdraft-om' AS step, COUNT(*) AS broj,
       ROUND(SUM(consumed_kg - initial_weight_kg)::numeric, 1) AS total_overdraft_kg
FROM prod_inventory_rolls
WHERE consumed_kg > initial_weight_kg AND initial_weight_kg IS NOT NULL;

-- Detaljnije po roli (top 20 najvećih overdraft-a)
SELECT roll_code, internal_id, initial_weight_kg, consumed_kg,
       ROUND((consumed_kg - initial_weight_kg)::numeric, 1) AS overdraft_kg,
       status
FROM prod_inventory_rolls
WHERE consumed_kg > initial_weight_kg AND initial_weight_kg IS NOT NULL
ORDER BY (consumed_kg - initial_weight_kg) DESC
LIMIT 20;

-- Rola sa NULL initial_weight (6 njih)
SELECT 'BEFORE: rola sa NULL initial_weight' AS step, COUNT(*) AS broj
FROM prod_inventory_rolls
WHERE initial_weight_kg IS NULL;

-- -------------------------------------------------------------
-- APPLY (otkomentiraj kad si pregledao dry-run)
-- -------------------------------------------------------------
/*
BEGIN;

-- 1) Log u discrepancy za svaku rolu s overdraft-om
INSERT INTO prod_consumption_discrepancy_log (
  machine, scanned_code, resolved_roll_id, resolved_source_table,
  internal_id, reason, declared_kg, available_kg, delta_kg,
  operator_name, shift_date, resolution_note
)
SELECT
  'legacy' AS machine,
  roll_code,
  id,
  'prod_inventory_rolls',
  internal_id,
  'legacy_overdraft',
  consumed_kg AS declared_kg,
  initial_weight_kg AS available_kg,
  -(consumed_kg - initial_weight_kg) AS delta_kg,
  'system_backfill_2026_05',
  CURRENT_DATE,
  'Auto-clamp: consumed_kg veći od initial_weight_kg. Pre-refactor stanje. Razlika je izgubljena.'
FROM prod_inventory_rolls
WHERE consumed_kg > initial_weight_kg
  AND initial_weight_kg IS NOT NULL;

-- 2) Clamp consumed_kg na initial_weight_kg
UPDATE prod_inventory_rolls
SET consumed_kg = initial_weight_kg,
    status = 'Utrošeno',
    updated_at = NOW(),
    notes = COALESCE(notes || E'\n\n', '') ||
            '[' || NOW()::TEXT || '] Auto-clamp (legacy overdraft, sustav backfill 2026_05).'
WHERE consumed_kg > initial_weight_kg
  AND initial_weight_kg IS NOT NULL;

-- 3) Log za 6 rola s NULL initial_weight (admin treba ručno popraviti)
INSERT INTO prod_consumption_discrepancy_log (
  machine, scanned_code, resolved_roll_id, resolved_source_table,
  internal_id, reason, declared_kg, available_kg, delta_kg,
  operator_name, shift_date, resolution_note
)
SELECT
  'legacy', roll_code, id, 'prod_inventory_rolls',
  internal_id, 'null_initial_weight',
  consumed_kg, NULL, NULL,
  'system_backfill_2026_05', CURRENT_DATE,
  'Rola ima NULL initial_weight_kg. Admin treba ručno unijeti težinu.'
FROM prod_inventory_rolls
WHERE initial_weight_kg IS NULL;

-- Verifikacija
SELECT 'AFTER: rola s overdraft-om' AS step, COUNT(*) AS broj
FROM prod_inventory_rolls
WHERE consumed_kg > initial_weight_kg
  AND initial_weight_kg IS NOT NULL;

SELECT 'AFTER: discrepancy_log unosi' AS step, COUNT(*) AS broj
FROM prod_consumption_discrepancy_log
WHERE reason IN ('legacy_overdraft','null_initial_weight')
  AND operator_name = 'system_backfill_2026_05';

COMMIT;
*/

-- -------------------------------------------------------------
-- ROLLBACK (ako nešto pode po krivu)
-- -------------------------------------------------------------
/*
-- POZOR: ovo briše sve discrepancy redove iz backfill-a, ali ne vraća consumed_kg
-- vrijednosti. Za to bi trebao snapshot iz prije migracije.
DELETE FROM prod_consumption_discrepancy_log
WHERE operator_name = 'system_backfill_2026_05'
  AND reason IN ('legacy_overdraft','null_initial_weight');
*/
