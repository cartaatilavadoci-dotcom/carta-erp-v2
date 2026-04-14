-- ============================================================
-- B5: FK constraints na core production tablice
-- Datum: 2026-04-14
-- ============================================================
-- POZADINA:
-- Od 77 tablica, samo 28 ima FK constraint. Core production lanac
-- (RN → POP → GOP → Otprema → consumed_rolls) nije imao niti jedan
-- FK. Soft references preko UUID/text bez enforcement-a dovode do
-- orphan zapisa i gubitka traceability.
--
-- ORPHAN ANALIZA (14.04.2026):
-- - prod_inventory_pop orphans (work_order_id): 0
-- - prod_inventory_gop orphans (work_order_id): 1 (RN772/25 iz 12/2025)
-- - prod_inventory_consumed_rolls orphans (work_order_id): 0
-- - prod_inventory_gop orphans (dispatch_id): 0
-- - article_id orphans: 0 (ali FK nemoguć - type mismatch)
--
-- STRATEGIJA: ON DELETE RESTRICT
-- - Sprečava brisanje RN-a koji ima proizvodnju (POP/GOP/consumed_rolls)
-- - Operateri moraju koristiti soft delete (status='Otkazano') umjesto
-- - Neproizveden RN se i dalje može slobodno obrisati
--
-- ARTICLE_ID FK NIJE UKLJUČEN:
-- - prod_articles ima 'article_id' TEXT (business key)
-- - prod_inventory_gop/pop koriste 'article_id' UUID
-- - prod_orders/work_orders koriste 'article_id' TEXT
-- - Treba zasebnu schema migraciju za usuglašavanje tipova
-- ============================================================


-- ============================================================
-- KORAK 1: Cleanup orphan GOP (RN772/25 od 12/2025, 3500 paleta)
-- ============================================================
-- Zadržavamo zapis kao historical, samo nullam neispravnu referencu

UPDATE prod_inventory_gop
SET work_order_id = NULL
WHERE work_order_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM prod_work_orders wo WHERE wo.id = prod_inventory_gop.work_order_id);


-- ============================================================
-- KORAK 2: FK constraints (RESTRICT - prevents accidental deletion)
-- ============================================================

-- POP → WO
ALTER TABLE prod_inventory_pop
  DROP CONSTRAINT IF EXISTS fk_pop_work_order;
ALTER TABLE prod_inventory_pop
  ADD CONSTRAINT fk_pop_work_order
  FOREIGN KEY (work_order_id) REFERENCES prod_work_orders(id)
  ON DELETE RESTRICT
  DEFERRABLE INITIALLY DEFERRED;

-- GOP → WO
ALTER TABLE prod_inventory_gop
  DROP CONSTRAINT IF EXISTS fk_gop_work_order;
ALTER TABLE prod_inventory_gop
  ADD CONSTRAINT fk_gop_work_order
  FOREIGN KEY (work_order_id) REFERENCES prod_work_orders(id)
  ON DELETE RESTRICT
  DEFERRABLE INITIALLY DEFERRED;

-- consumed_rolls → WO
ALTER TABLE prod_inventory_consumed_rolls
  DROP CONSTRAINT IF EXISTS fk_consumed_rolls_work_order;
ALTER TABLE prod_inventory_consumed_rolls
  ADD CONSTRAINT fk_consumed_rolls_work_order
  FOREIGN KEY (work_order_id) REFERENCES prod_work_orders(id)
  ON DELETE RESTRICT
  DEFERRABLE INITIALLY DEFERRED;


-- ============================================================
-- KORAK 3: Indexi na FK kolone (ako ne postoje)
-- Ubrzava JOIN-ove i sprečava sequential scan kod cascade checks
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_pop_work_order_id ON prod_inventory_pop(work_order_id);
CREATE INDEX IF NOT EXISTS idx_gop_work_order_id ON prod_inventory_gop(work_order_id);
CREATE INDEX IF NOT EXISTS idx_consumed_rolls_wo_id ON prod_inventory_consumed_rolls(work_order_id);


-- ============================================================
-- VERIFIKACIJA
-- ============================================================
SELECT
  tc.table_name,
  tc.constraint_name,
  kcu.column_name,
  ccu.table_name AS references_table,
  ccu.column_name AS references_column,
  rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
  ON tc.constraint_name = rc.constraint_name
WHERE tc.table_schema = 'public'
  AND tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name IN ('prod_inventory_pop','prod_inventory_gop','prod_inventory_consumed_rolls')
ORDER BY tc.table_name;
