-- ============================================================
-- C8-C10: TRACEABILITY LINKS (GOP↔POP↔Roll)
-- Datum: 2026-04-14
-- ============================================================
-- POZADINA:
-- Trenutno možemo trace GOP → consumed_rolls samo preko zajedničkog
-- work_order_id (94.8% pokrivenost). Ako jedan RN producira više
-- POP-ova i više GOP paleta, gubimo specifičnu vezu:
--   "Koja konkretna GOP paleta sadrži vrećice od koje POP role,
--    a ta POP rola je napravljena od kojih konkretnih rola papira?"
--
-- Za customer recall ili reklamacije — kritično.
--
-- C8: prod_gop_pop_link  — GOP paleta ↔ POP tuljci korišteni u njoj
-- C9: prod_pop_roll_link — POP tuljak ↔ role papira korištene
-- C10: v_full_traceability — denormalizirani view za upite
-- ============================================================


-- ============================================================
-- C8: prod_gop_pop_link
-- ============================================================
CREATE TABLE IF NOT EXISTS prod_gop_pop_link (
  gop_id UUID NOT NULL REFERENCES prod_inventory_gop(id) ON DELETE CASCADE,
  pop_id UUID NOT NULL REFERENCES prod_inventory_pop(id) ON DELETE RESTRICT,
  quantity_used INTEGER NOT NULL DEFAULT 0,  -- broj POP komada utrošenih u tu GOP paletu
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by TEXT,
  PRIMARY KEY (gop_id, pop_id)
);

COMMENT ON TABLE prod_gop_pop_link IS
  'Veza GOP paleta ↔ POP tuljci. Bottomer-slagač popunjava prilikom kreiranja palete. Za customer recall.';

CREATE INDEX IF NOT EXISTS idx_gop_pop_link_pop ON prod_gop_pop_link(pop_id);
CREATE INDEX IF NOT EXISTS idx_gop_pop_link_gop ON prod_gop_pop_link(gop_id);


-- ============================================================
-- C9: prod_pop_roll_link
-- ============================================================
CREATE TABLE IF NOT EXISTS prod_pop_roll_link (
  pop_id UUID NOT NULL REFERENCES prod_inventory_pop(id) ON DELETE CASCADE,
  consumed_roll_id UUID NOT NULL REFERENCES prod_inventory_consumed_rolls(id) ON DELETE RESTRICT,
  layer_number INTEGER,  -- 1-4, koji sloj papira (vanjski/srednji/unutarnji)
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (pop_id, consumed_roll_id)
);

COMMENT ON TABLE prod_pop_roll_link IS
  'Veza POP tuljak ↔ specifične role papira. Tuber-materijal popunjava na kraju smjene.';

CREATE INDEX IF NOT EXISTS idx_pop_roll_link_consumed ON prod_pop_roll_link(consumed_roll_id);
CREATE INDEX IF NOT EXISTS idx_pop_roll_link_pop ON prod_pop_roll_link(pop_id);


-- ============================================================
-- RLS - omogući kao i ostale tablice
-- ============================================================
ALTER TABLE prod_gop_pop_link ENABLE ROW LEVEL SECURITY;
ALTER TABLE prod_pop_roll_link ENABLE ROW LEVEL SECURITY;

-- Politike: dozvoli sve za autentificirane korisnike (uskladi s ostalim tablicama)
DROP POLICY IF EXISTS "Allow all for authenticated" ON prod_gop_pop_link;
CREATE POLICY "Allow all for authenticated" ON prod_gop_pop_link FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for authenticated" ON prod_pop_roll_link;
CREATE POLICY "Allow all for authenticated" ON prod_pop_roll_link FOR ALL USING (true) WITH CHECK (true);


-- ============================================================
-- C10: v_full_traceability — denormalizirani view za recall
-- ============================================================
-- Jedan red = jedna kombinacija (GOP paleta, POP tuljak, rola papira)
-- Daje kompletnu sljedivost od kupca do izvornog dobavljača papira.
-- Koristi se za:
--   - Customer recall (kupac prijavi defekt na paleti X)
--   - Quality investigation (problem s konkretnom rolom papira)
--   - Audit/compliance reports
-- ============================================================

DROP VIEW IF EXISTS v_full_traceability;
CREATE VIEW v_full_traceability AS
SELECT
  -- Izlaz prema kupcu
  g.id AS gop_id,
  g.pallet_number,
  g.customer_name,
  g.dispatch_id,
  g.dispatched_at,
  g.dispatch_status,

  -- Radni nalog
  g.work_order_id,
  g.work_order_number,
  g.order_number,
  g.article_code,
  g.article_name,
  g.production_line,
  g.operator_name,
  g.shift,
  g.created_at AS gop_created_at,
  g.quantity AS gop_quantity,

  -- POP tuljak (preko link tablice)
  p.id AS pop_id,
  p.pop_code,
  p.created_at AS pop_created_at,
  gpl.quantity_used AS pop_quantity_used_in_gop,

  -- Rola papira (preko consumed_rolls + link tablice)
  cr.id AS consumed_roll_entry_id,
  cr.source_table AS roll_source_table,
  cr.roll_code,
  cr.material_type,
  cr.width_cm,
  cr.grammage,
  cr.color,
  cr.manufacturer,
  cr.consumed_kg,
  cr.consumption_type,
  cr.shift_date AS material_consumption_date,
  prl.layer_number

FROM prod_inventory_gop g
LEFT JOIN prod_gop_pop_link gpl  ON gpl.gop_id = g.id
LEFT JOIN prod_inventory_pop p   ON p.id = gpl.pop_id
LEFT JOIN prod_pop_roll_link prl ON prl.pop_id = p.id
LEFT JOIN prod_inventory_consumed_rolls cr ON cr.id = prl.consumed_roll_id;

COMMENT ON VIEW v_full_traceability IS
  'Full chain traceability: GOP paleta → POP tuljak → rola papira. Za customer recall.';


-- ============================================================
-- HELPER RPC: trace_pallet — vraća sve podatke za jednu GOP paletu
-- ============================================================
CREATE OR REPLACE FUNCTION trace_pallet(p_pallet_number TEXT)
RETURNS TABLE (
  pallet_number VARCHAR,
  customer_name VARCHAR,
  dispatched_at TIMESTAMPTZ,
  work_order_number VARCHAR,
  article_name VARCHAR,
  pop_codes TEXT,
  roll_codes TEXT,
  manufacturers TEXT,
  layers TEXT
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    g.pallet_number,
    g.customer_name,
    g.dispatched_at,
    g.work_order_number,
    g.article_name,
    STRING_AGG(DISTINCT p.pop_code::text, ', ') AS pop_codes,
    STRING_AGG(DISTINCT cr.roll_code, ', ') AS roll_codes,
    STRING_AGG(DISTINCT cr.manufacturer, ', ') AS manufacturers,
    STRING_AGG(DISTINCT prl.layer_number::text, ', ') AS layers
  FROM prod_inventory_gop g
  LEFT JOIN prod_gop_pop_link gpl  ON gpl.gop_id = g.id
  LEFT JOIN prod_inventory_pop p   ON p.id = gpl.pop_id
  LEFT JOIN prod_pop_roll_link prl ON prl.pop_id = p.id
  LEFT JOIN prod_inventory_consumed_rolls cr ON cr.id = prl.consumed_roll_id
  WHERE g.pallet_number = p_pallet_number
  GROUP BY g.id, g.pallet_number, g.customer_name, g.dispatched_at,
           g.work_order_number, g.article_name;
$$;

COMMENT ON FUNCTION trace_pallet IS
  'Vrati kompletnu traceability za jednu GOP paletu (za reklamacije/recall).';


-- ============================================================
-- VERIFIKACIJA
-- ============================================================
SELECT 'prod_gop_pop_link' AS tablica, COUNT(*) AS rows FROM prod_gop_pop_link
UNION ALL
SELECT 'prod_pop_roll_link', COUNT(*) FROM prod_pop_roll_link
UNION ALL
SELECT 'v_full_traceability (sample)', COUNT(*) FROM v_full_traceability LIMIT 1;
