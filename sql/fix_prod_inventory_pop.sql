-- ============================================
-- CARTA ERP - Provjera/Popravak prod_inventory_pop
-- ============================================

-- 1. Provjeri postojeće constrainte
SELECT 
    conname AS constraint_name,
    contype AS constraint_type,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint 
WHERE conrelid = 'prod_inventory_pop'::regclass;

-- 2. Provjeri strukturu tablice
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'prod_inventory_pop'
ORDER BY ordinal_position;

-- ============================================
-- AKO TABLICA NE POSTOJI - KREIRAJ JE
-- ============================================

-- Ukloni ako postoji s krivim constraintom
-- DROP TABLE IF EXISTS prod_inventory_pop CASCADE;

CREATE TABLE IF NOT EXISTS prod_inventory_pop (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Šifra POP-a (jedinstvena)
    pop_code VARCHAR(50) NOT NULL UNIQUE,
    
    -- Veza s radnim nalogom
    work_order_id UUID REFERENCES prod_work_orders(id) ON DELETE SET NULL,
    work_order_number VARCHAR(50),
    order_number VARCHAR(50),
    
    -- Artikl info
    article_id UUID REFERENCES prod_articles(id) ON DELETE SET NULL,
    article_name VARCHAR(255),
    article_code VARCHAR(100),
    
    -- Kupac
    customer_name VARCHAR(255),
    
    -- Količine
    quantity INTEGER NOT NULL DEFAULT 0,
    quantity_in_stock INTEGER NOT NULL DEFAULT 0,
    
    -- Status i linija
    status VARCHAR(50) DEFAULT 'Na skladištu',
    production_line VARCHAR(10),
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indeksi
CREATE INDEX IF NOT EXISTS idx_pop_work_order_id ON prod_inventory_pop(work_order_id);
CREATE INDEX IF NOT EXISTS idx_pop_work_order_number ON prod_inventory_pop(work_order_number);
CREATE INDEX IF NOT EXISTS idx_pop_status ON prod_inventory_pop(status);
CREATE INDEX IF NOT EXISTS idx_pop_production_line ON prod_inventory_pop(production_line);

-- RLS
ALTER TABLE prod_inventory_pop ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow read pop" ON prod_inventory_pop;
DROP POLICY IF EXISTS "Allow insert pop" ON prod_inventory_pop;
DROP POLICY IF EXISTS "Allow update pop" ON prod_inventory_pop;
DROP POLICY IF EXISTS "Allow delete pop" ON prod_inventory_pop;

CREATE POLICY "Allow read pop" ON prod_inventory_pop FOR SELECT USING (true);
CREATE POLICY "Allow insert pop" ON prod_inventory_pop FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update pop" ON prod_inventory_pop FOR UPDATE USING (true);
CREATE POLICY "Allow delete pop" ON prod_inventory_pop FOR DELETE USING (true);

-- ============================================
-- PROVJERI REZULTAT
-- ============================================
SELECT 'prod_inventory_pop' AS tablica, COUNT(*) AS broj_zapisa FROM prod_inventory_pop;
