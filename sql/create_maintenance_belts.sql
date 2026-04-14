-- ============================================
-- MAINTENANCE BELTS (TRAKE) - SQL SCHEMA
-- ============================================

-- Tablica za trake i remenje
CREATE TABLE IF NOT EXISTS prod_maintenance_belts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  belt_code TEXT UNIQUE NOT NULL,         -- Šifra trake
  category TEXT,                           -- 'Plosnato remenje', 'Zupčasto remenje', etc.
  position TEXT,                           -- Pozicija na stroju
  type TEXT,                               -- Tip trake
  description TEXT,
  width_mm NUMERIC(10,2),                  -- Širina mm
  length_mm NUMERIC(10,2),                 -- Dužina mm  
  thickness_mm NUMERIC(10,2),              -- Debljina mm
  material TEXT,                           -- Materijal
  supplier TEXT,
  price_eur NUMERIC(10,2),
  quantity_in_stock INTEGER DEFAULT 0,
  min_stock INTEGER DEFAULT 1,
  stock_location TEXT,
  compatible_machines TEXT[],
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexi
CREATE INDEX IF NOT EXISTS idx_belts_code ON prod_maintenance_belts(belt_code);
CREATE INDEX IF NOT EXISTS idx_belts_category ON prod_maintenance_belts(category);
CREATE INDEX IF NOT EXISTS idx_belts_stock ON prod_maintenance_belts(quantity_in_stock);

-- RLS
ALTER TABLE prod_maintenance_belts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all prod_maintenance_belts" ON prod_maintenance_belts;
CREATE POLICY "Allow all prod_maintenance_belts" ON prod_maintenance_belts FOR ALL USING (true);

-- Brojač za narudžbe
INSERT INTO prod_counters (counter_type, prefix, current_value, year)
VALUES ('MaintOrder', 'MO', 0, 2025)
ON CONFLICT (counter_type) DO NOTHING;

-- ============================================
-- PRIMJER SEED DATA
-- ============================================
INSERT INTO prod_maintenance_belts (belt_code, category, position, width_mm, length_mm, thickness_mm, min_stock, quantity_in_stock) VALUES
('TR-001', 'Plosnato remenje', 'S-press (pegla)', 50, 2000, 3, 2, 5),
('TR-002', 'Plosnato remenje', 'MC-120 iza noža', 40, 1500, 2.5, 2, 3),
('TR-003', 'Zupčasto remenje', 'Vuča', 25, 1800, 5, 1, 4),
('TR-004', 'Zupčasto remenje', 'Ventil aparat', 20, 1200, 4, 1, 2),
('TR-005', 'Remenje vuče', 'Samar - vuča dna', 30, 2200, 3, 2, 6)
ON CONFLICT (belt_code) DO NOTHING;
