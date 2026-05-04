-- =============================================================================
-- BACKFILL: prod_pop_roll_link za 519 POP-ova s material_deducted=true bez linka
-- =============================================================================
-- Strategija: za svaki orphan POP, pronađi consumed_rolls redove istog work_order_id
-- i poveži ih kroz prod_pop_roll_link. Ako 1 POP po RN-u, link je trivial; ako više
-- POP-ova, sve consumed_rolls povežemo sa svim POP-ovima istog RN-a.
--
-- IZVRŠAVA SE RUČNO. Pokreni dry-run prvo, pregledaj izvještaj, pa apply.
-- =============================================================================

-- -------------------------------------------------------------
-- DRY-RUN: što će se dogoditi
-- -------------------------------------------------------------
SELECT 'BEFORE: orphan POP-ovi (deducted=true, bez linka)' AS step,
       COUNT(*) AS broj
FROM prod_inventory_pop p
WHERE COALESCE(material_deducted, false) = true
  AND NOT EXISTS (SELECT 1 FROM prod_pop_roll_link l WHERE l.pop_id = p.id);

-- Koliko bi linkova nastalo iz consumed_rolls match-a
SELECT 'PROJEKCIJA: novi linkovi koji bi nastali' AS step,
       COUNT(*) AS broj
FROM prod_inventory_pop p
JOIN prod_inventory_consumed_rolls cr
  ON cr.work_order_id = p.work_order_id
 AND cr.work_order_id IS NOT NULL
WHERE COALESCE(p.material_deducted, false) = true
  AND NOT EXISTS (SELECT 1 FROM prod_pop_roll_link l
                  WHERE l.pop_id = p.id AND l.consumed_roll_id = cr.id);

-- POP-ovi koji NEĆE biti backfill-ani (work_order_id NULL ili nema consumed_rolls)
SELECT 'OSTAJE OSIROTJELO: bez match-a' AS step, COUNT(*) AS broj
FROM prod_inventory_pop p
WHERE COALESCE(p.material_deducted, false) = true
  AND NOT EXISTS (SELECT 1 FROM prod_pop_roll_link l WHERE l.pop_id = p.id)
  AND NOT EXISTS (SELECT 1 FROM prod_inventory_consumed_rolls cr
                   WHERE cr.work_order_id = p.work_order_id);

-- -------------------------------------------------------------
-- APPLY (otkomentiraj kad si zadovoljan dry-run rezultatima)
-- -------------------------------------------------------------
/*
BEGIN;

INSERT INTO prod_pop_roll_link (pop_id, consumed_roll_id, layer_number, created_at)
SELECT DISTINCT p.id, cr.id, cr.layer_number, NOW()
FROM prod_inventory_pop p
JOIN prod_inventory_consumed_rolls cr
  ON cr.work_order_id = p.work_order_id
 AND cr.work_order_id IS NOT NULL
WHERE COALESCE(p.material_deducted, false) = true
  AND NOT EXISTS (
    SELECT 1 FROM prod_pop_roll_link l
    WHERE l.pop_id = p.id AND l.consumed_roll_id = cr.id
  )
ON CONFLICT DO NOTHING;

-- Verifikacija nakon backfill-a
SELECT 'AFTER: orphan POP-ovi' AS step,
       COUNT(*) AS broj
FROM prod_inventory_pop p
WHERE COALESCE(material_deducted, false) = true
  AND NOT EXISTS (SELECT 1 FROM prod_pop_roll_link l WHERE l.pop_id = p.id);

COMMIT;
*/

-- -------------------------------------------------------------
-- ROLLBACK (ako nešto pođe po krivu, otkomentiraj i pokreni)
-- -------------------------------------------------------------
/*
DELETE FROM prod_pop_roll_link
WHERE created_at >= '2026-05-01' AND created_at < '2026-05-02';
*/
