-- ============================================
-- TISAK MODUL - MIGRACIJA BAZE
-- ============================================

-- 1. Dodaj kolone za praćenje potrošnje na rolama papira
ALTER TABLE prod_inventory_rolls 
ADD COLUMN IF NOT EXISTS original_kg NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS consumed_kg NUMERIC DEFAULT 0;

-- Postavi original_kg iz weight_kg za postojeće role
UPDATE prod_inventory_rolls 
SET original_kg = COALESCE(weight_kg, 0) 
WHERE original_kg = 0 OR original_kg IS NULL;

-- 2. Dodaj kolone za praćenje napretka na radnim nalozima tiska
ALTER TABLE prod_work_orders_printing 
ADD COLUMN IF NOT EXISTS produced_kg NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP WITH TIME ZONE;

-- 3. Dodaj kolonu article_code na otiskane role
ALTER TABLE prod_inventory_printed 
ADD COLUMN IF NOT EXISTS article_code TEXT;

-- 4. Opciono: Kreiraj computed kolonu remaining_kg (ako koristite PostgreSQL 12+)
-- Ako remaining_kg već postoji kao obična kolona, preskočite ovaj korak
-- ALTER TABLE prod_inventory_rolls 
-- ADD COLUMN remaining_kg NUMERIC GENERATED ALWAYS AS (COALESCE(original_kg, weight_kg, 0) - COALESCE(consumed_kg, 0)) STORED;

-- 5. Ažuriraj remaining_kg ako je obična kolona
UPDATE prod_inventory_rolls 
SET remaining_kg = COALESCE(original_kg, weight_kg, 0) - COALESCE(consumed_kg, 0)
WHERE remaining_kg IS NULL OR remaining_kg = 0;

-- Provjera strukture
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'prod_inventory_rolls' 
ORDER BY ordinal_position;
