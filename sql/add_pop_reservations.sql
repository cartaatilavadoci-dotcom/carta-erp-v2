-- ============================================
-- REZERVACIJE POP-a - SQL Skripta
-- Datum: 01. Veljače 2026
-- ============================================

-- 1. Dodaj kolonu quantity_reserved u prod_inventory_pop
ALTER TABLE prod_inventory_pop
ADD COLUMN IF NOT EXISTS quantity_reserved INTEGER DEFAULT 0;

-- 2. Dodaj komentar za objašnjenje
COMMENT ON COLUMN prod_inventory_pop.quantity_reserved IS
'Količina rezervirana od strane Bottomer-a dok POP još nije fizički na skladištu';

-- 3. Indeks za brže pretraživanje rezervacija
CREATE INDEX IF NOT EXISTS idx_pop_reserved
ON prod_inventory_pop(work_order_number)
WHERE quantity_reserved > 0;

-- 4. Indeks za dohvat po work_order_number i statusu
CREATE INDEX IF NOT EXISTS idx_pop_wo_status_reserved
ON prod_inventory_pop(work_order_number, status, quantity_reserved);

-- 5. Dodaj GENERATED kolonu za dostupnu količinu
ALTER TABLE prod_inventory_pop
ADD COLUMN IF NOT EXISTS quantity_available INTEGER
GENERATED ALWAYS AS (quantity_in_stock - COALESCE(quantity_reserved, 0)) STORED;

COMMENT ON COLUMN prod_inventory_pop.quantity_available IS
'Dostupna količina za potrošnju (in_stock - reserved). GENERATED kolona - ne ažurirati ručno!';

-- 6. Indeks na quantity_available
CREATE INDEX IF NOT EXISTS idx_pop_available
ON prod_inventory_pop(quantity_available)
WHERE quantity_available > 0;

-- ============================================
-- Verifikacija
-- ============================================

-- Provjeri dodane kolone
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'prod_inventory_pop'
  AND column_name IN ('quantity_reserved', 'quantity_available');

-- Provjeri indekse
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'prod_inventory_pop'
  AND indexname LIKE '%reserved%';
