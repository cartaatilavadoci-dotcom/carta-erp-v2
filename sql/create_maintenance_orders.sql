-- ============================================
-- MAINTENANCE ORDERS - KOMPLETNA TABLICA
-- Za naručivanje traka s tracking statusom
-- ============================================

-- Drop existing table if needed
-- DROP TABLE IF EXISTS prod_maintenance_orders;

CREATE TABLE IF NOT EXISTS prod_maintenance_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Identifikacija
  order_id TEXT UNIQUE NOT NULL,              -- MO-2025-0001
  
  -- Dobavljač
  supplier TEXT,                               -- Naziv dobavljača
  recipients TEXT[],                           -- Email adrese
  
  -- Stavke
  items_count INTEGER DEFAULT 0,
  items_description TEXT,                      -- "TRK-001 x2, TRK-005 x1"
  items_json JSONB,                            -- Puni podaci o stavkama
  
  -- Rokovi
  requested_delivery DATE,                     -- Željeni rok isporuke
  actual_delivery DATE,                        -- Stvarni datum isporuke
  
  -- Status workflow
  status TEXT DEFAULT 'Kreirano',              -- Kreirano, Poslano, Potvrđeno, Isporučeno, Otkazano
  priority TEXT DEFAULT 'Normalan',            -- Normalan, Hitan
  
  -- Povijest statusa (JSON array)
  status_history JSONB DEFAULT '[]'::jsonb,    -- [{status, timestamp, user, comment}]
  
  -- Napomene
  notes TEXT,
  
  -- Audit
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  sent_at TIMESTAMPTZ,                         -- Kada je poslano dobavljaču
  confirmed_at TIMESTAMPTZ,                    -- Kada je dobavljač potvrdio
  delivered_at TIMESTAMPTZ                     -- Kada je isporučeno
);

-- Indexi
CREATE INDEX IF NOT EXISTS idx_orders_order_id ON prod_maintenance_orders(order_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON prod_maintenance_orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_supplier ON prod_maintenance_orders(supplier);
CREATE INDEX IF NOT EXISTS idx_orders_created ON prod_maintenance_orders(created_at DESC);

-- RLS
ALTER TABLE prod_maintenance_orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all prod_maintenance_orders" ON prod_maintenance_orders;
CREATE POLICY "Allow all prod_maintenance_orders" ON prod_maintenance_orders FOR ALL USING (true);

-- Brojač za narudžbe
INSERT INTO prod_counters (counter_type, prefix, current_value, year)
VALUES ('MaintOrder', 'MO', 0, 2025)
ON CONFLICT (counter_type) DO UPDATE SET year = 2025;

-- ============================================
-- VIEW za statistiku narudžbi
-- ============================================
CREATE OR REPLACE VIEW v_maintenance_orders_stats AS
SELECT 
  COUNT(*) as total_orders,
  COUNT(*) FILTER (WHERE status = 'Kreirano') as pending,
  COUNT(*) FILTER (WHERE status = 'Poslano') as sent,
  COUNT(*) FILTER (WHERE status = 'Potvrđeno') as confirmed,
  COUNT(*) FILTER (WHERE status = 'Isporučeno') as delivered,
  COUNT(*) FILTER (WHERE status = 'Otkazano') as cancelled,
  COUNT(*) FILTER (WHERE priority = 'Hitan') as urgent,
  SUM(items_count) as total_items
FROM prod_maintenance_orders
WHERE created_at > NOW() - INTERVAL '90 days';

-- ============================================
-- Trigger za updated_at
-- ============================================
CREATE OR REPLACE FUNCTION update_maintenance_orders_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_maintenance_orders_updated ON prod_maintenance_orders;
CREATE TRIGGER trigger_maintenance_orders_updated
  BEFORE UPDATE ON prod_maintenance_orders
  FOR EACH ROW
  EXECUTE FUNCTION update_maintenance_orders_timestamp();

-- ============================================
-- Primjer test podataka
-- ============================================
/*
INSERT INTO prod_maintenance_orders (
  order_id, supplier, recipients, items_count, items_description, 
  items_json, status, priority, created_by
) VALUES (
  'MO-2025-0001',
  'NLI Dobavljač d.o.o.',
  ARRAY['nabava@nli.hr'],
  3,
  'TRK-0001 ×2, TRK-0005 ×1, TRK-0012 ×3',
  '[{"belt_code":"TRK-0001","quantity":2},{"belt_code":"TRK-0005","quantity":1},{"belt_code":"TRK-0012","quantity":3}]'::jsonb,
  'Kreirano',
  'Normalan',
  'Admin'
);
*/

-- Verifikacija
SELECT 'Tablica prod_maintenance_orders kreirana' as status;
