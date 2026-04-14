-- ============================================
-- CARTA ERP - Tablica šifri boja (prod_color_codes)
-- Struktura iz formule_boja.xlsx
-- ============================================

-- Kreiranje tablice
CREATE TABLE IF NOT EXISTS prod_color_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,           -- Šifra boje (npr. P186U-Tuber002)
  customer_name TEXT,                   -- Kupac (npr. Agrana)
  color_name TEXT,                      -- Naziv boje (npr. Crvena)
  cost NUMERIC(10,2),                   -- Cijena
  number_of_items INTEGER,              -- Broj komponenti
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indeksi
CREATE INDEX IF NOT EXISTS idx_color_codes_code ON prod_color_codes(code);
CREATE INDEX IF NOT EXISTS idx_color_codes_customer ON prod_color_codes(customer_name);
CREATE INDEX IF NOT EXISTS idx_color_codes_color ON prod_color_codes(color_name);

-- Komentar
COMMENT ON TABLE prod_color_codes IS 'Šifre boja za tisak - formule boja';
COMMENT ON COLUMN prod_color_codes.code IS 'Jedinstvena šifra boje (Pantone kod + sufiks)';
COMMENT ON COLUMN prod_color_codes.customer_name IS 'Naziv kupca za kojeg je boja';
COMMENT ON COLUMN prod_color_codes.color_name IS 'Naziv boje (Crvena, Plava, Zelena...)';
COMMENT ON COLUMN prod_color_codes.cost IS 'Cijena boje po kg';
COMMENT ON COLUMN prod_color_codes.number_of_items IS 'Broj komponenti u formuli';

-- RLS politike (ako koristiš Supabase RLS)
ALTER TABLE prod_color_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all for authenticated" ON prod_color_codes
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow read for anon" ON prod_color_codes
  FOR SELECT TO anon USING (true);

-- ============================================
-- PRIMJER UNOSA (iz formule_boja.xlsx)
-- Ovo će se popuniti iz Excel-a
-- ============================================
/*
INSERT INTO prod_color_codes (code, customer_name, color_name, cost, number_of_items) VALUES
('P186U-Tuber002', 'Agrana', 'Crvena', 2.21, 5),
('P220U-001', 'Agrana', 'Crvena', 4.37, 6),
('P227U-001', 'Agrana', 'Crveno-Ljub.', 2.73, 6),
('P287U-003', 'Agrana', 'Plava', 2.31, 5),
('P2935U-001', 'Agrana', 'Plava', 3.41, 5)
ON CONFLICT (code) DO UPDATE SET
  customer_name = EXCLUDED.customer_name,
  color_name = EXCLUDED.color_name,
  cost = EXCLUDED.cost,
  number_of_items = EXCLUDED.number_of_items,
  updated_at = NOW();
*/

-- Provjera strukture
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'prod_color_codes'
ORDER BY ordinal_position;
