-- ============================================================
-- TUBER FIFO PLACEHOLDER SYSTEM
-- Datum: 2026-04-14
-- ============================================================
-- Redizajn skidanja materijala na Tuber-u s FIFO pristupom.
--
-- SCENARIJ:
-- Operater skenira role koje je koristio. Sustav automatski skida
-- po FIFO-u. Ako skenira šifru koja NIJE u bazi (rezac/tisak još
-- nije unesli), sustav posudi kg iz najstarije role istog internal_id-a
-- i evidentira PLACEHOLDER. Kad se stvarna rola kasnije unese,
-- trigger vraća kg u source rolu i pripisuje ih stvarnoj.
--
-- VEZA: ovo ne dira ostale module (tisak/rezač). Samo osigurava da
-- Tuber može raditi i kad rola još nije registrirana.
-- ============================================================


-- ============================================================
-- 1. Placeholder tablica
-- ============================================================
CREATE TABLE IF NOT EXISTS prod_inventory_placeholder_consumption (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Što je operater skenirao
  scanned_code TEXT NOT NULL,
  internal_id TEXT NOT NULL,              -- iz artikla paper_sN_code
  layer_number INTEGER,

  -- Od koje smo role posudili (FIFO kandidat)
  placeholder_source_roll_id UUID REFERENCES prod_inventory_rolls(id) ON DELETE RESTRICT,
  consumed_kg NUMERIC(10,3) NOT NULL,

  -- Kontekst
  work_order_id UUID REFERENCES prod_work_orders(id) ON DELETE RESTRICT,
  work_order_number TEXT,
  operator TEXT,
  production_line TEXT,
  shift_date DATE,

  -- Resolve tracking
  resolved_at TIMESTAMPTZ,                -- NULL = čeka da stigne stvarna rola
  resolved_roll_id UUID REFERENCES prod_inventory_rolls(id),

  created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE prod_inventory_placeholder_consumption IS
  'FIFO placeholderi za Tuber: kad operater skenira šifru koja nije u bazi, sustav posudi iz FIFO role istog internal_id-a. Kad stvarna rola stigne, trigger resolve-a.';

CREATE INDEX IF NOT EXISTS idx_placeholder_scanned_code ON prod_inventory_placeholder_consumption(scanned_code) WHERE resolved_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_placeholder_wo ON prod_inventory_placeholder_consumption(work_order_id);
CREATE INDEX IF NOT EXISTS idx_placeholder_unresolved ON prod_inventory_placeholder_consumption(resolved_at) WHERE resolved_at IS NULL;

ALTER TABLE prod_inventory_placeholder_consumption ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for authenticated" ON prod_inventory_placeholder_consumption;
CREATE POLICY "Allow all for authenticated" ON prod_inventory_placeholder_consumption
  FOR ALL USING (true) WITH CHECK (true);


-- ============================================================
-- 2. Trigger koji resolve-a placeholdere pri INSERT-u nove role
-- ============================================================
CREATE OR REPLACE FUNCTION resolve_placeholders_on_roll_insert()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_placeholder RECORD;
  v_total_to_apply NUMERIC := 0;
BEGIN
  -- Za svaki unresolved placeholder s istim scanned_code kao nova rola
  FOR v_placeholder IN
    SELECT id, placeholder_source_roll_id, consumed_kg
    FROM prod_inventory_placeholder_consumption
    WHERE scanned_code = NEW.roll_code
      AND resolved_at IS NULL
      AND placeholder_source_roll_id IS NOT NULL
  LOOP
    -- 1. Vrati kg u izvornu FIFO rolu (smanji consumed_kg)
    UPDATE prod_inventory_rolls
    SET consumed_kg = GREATEST(0, COALESCE(consumed_kg, 0) - v_placeholder.consumed_kg)
    WHERE id = v_placeholder.placeholder_source_roll_id;

    -- 2. Zbroji kg koji se pripisuju NEW roli
    v_total_to_apply := v_total_to_apply + v_placeholder.consumed_kg;

    -- 3. Označi placeholder kao resolved
    UPDATE prod_inventory_placeholder_consumption
    SET resolved_at = NOW(),
        resolved_roll_id = NEW.id
    WHERE id = v_placeholder.id;

    RAISE NOTICE 'Placeholder resolved: % kg vraćeno iz % u novu rolu %',
      v_placeholder.consumed_kg, v_placeholder.placeholder_source_roll_id, NEW.id;
  END LOOP;

  -- Pripiši ukupni consumed_kg na novu rolu (jednim SET-om da se BEFORE trigger izvrši 1x)
  IF v_total_to_apply > 0 THEN
    NEW.consumed_kg := COALESCE(NEW.consumed_kg, 0) + v_total_to_apply;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_resolve_placeholder_on_roll_insert ON prod_inventory_rolls;
CREATE TRIGGER trg_resolve_placeholder_on_roll_insert
  BEFORE INSERT ON prod_inventory_rolls
  FOR EACH ROW
  EXECUTE FUNCTION resolve_placeholders_on_roll_insert();


-- ============================================================
-- 3. Helper RPC: pronađi FIFO kandidate za internal_id
-- ============================================================
CREATE OR REPLACE FUNCTION fifo_roll_candidates(
  p_internal_id TEXT,
  p_min_remaining NUMERIC DEFAULT 1
) RETURNS TABLE (
  id UUID,
  roll_code TEXT,
  internal_id TEXT,
  manufacturer TEXT,
  remaining_kg NUMERIC,
  initial_weight_kg NUMERIC,
  consumed_kg NUMERIC,
  entry_date DATE,
  created_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
  SELECT id, roll_code, internal_id, manufacturer,
         remaining_kg, initial_weight_kg, consumed_kg, entry_date, created_at
  FROM prod_inventory_rolls
  WHERE internal_id = p_internal_id
    AND status IN ('Na skladištu', 'Djelomično utrošeno', 'Djelomično')
    AND COALESCE(remaining_kg, 0) >= p_min_remaining
  ORDER BY COALESCE(entry_date, created_at::date) ASC, created_at ASC;
$$;


-- ============================================================
-- 4. Helper RPC: atomični conditional UPDATE za FIFO skidanje
-- ============================================================
-- Koristi se u JS-u: ako vrati 0 redaka promjene, druga sesija je skinula prije
-- nas → pokušaj sljedeću FIFO kandidat.
CREATE OR REPLACE FUNCTION atomic_consume_roll(
  p_roll_id UUID,
  p_amount NUMERIC
) RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  v_updated INTEGER;
BEGIN
  UPDATE prod_inventory_rolls
  SET consumed_kg = COALESCE(consumed_kg, 0) + p_amount
  WHERE id = p_roll_id
    AND COALESCE(remaining_kg, 0) >= p_amount;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated > 0;
END;
$$;


-- ============================================================
-- 5. Helper RPC: detektiraj ima li RN tisak
-- ============================================================
CREATE OR REPLACE FUNCTION wo_has_printing(p_wo_number TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM prod_work_orders_printing
    WHERE main_wo_number = p_wo_number
  );
$$;


-- ============================================================
-- 6. Helper RPC: FIFO kandidati iz printed rolla za RN
-- ============================================================
CREATE OR REPLACE FUNCTION fifo_printed_rolls_for_wo(
  p_wo_number TEXT
) RETURNS TABLE (
  id UUID,
  printed_roll_code TEXT,
  parent_roll_code TEXT,
  article_id TEXT,
  remaining_kg NUMERIC,
  weight_kg NUMERIC,
  consumed_kg NUMERIC,
  created_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
  SELECT id, printed_roll_code, parent_roll_code, article_id,
         remaining_kg, weight_kg, consumed_kg, created_at
  FROM prod_inventory_printed
  WHERE work_order_number = p_wo_number
    AND COALESCE(remaining_kg, 0) > 0
  ORDER BY COALESCE(entry_date, created_at::date) ASC, created_at ASC;
$$;


-- ============================================================
-- VERIFIKACIJA
-- ============================================================
SELECT 'prod_inventory_placeholder_consumption' AS obj, COUNT(*)::text AS info FROM prod_inventory_placeholder_consumption
UNION ALL SELECT 'resolve_placeholders_on_roll_insert', (SELECT COUNT(*)::text FROM pg_proc WHERE proname='resolve_placeholders_on_roll_insert')
UNION ALL SELECT 'fifo_roll_candidates', (SELECT COUNT(*)::text FROM pg_proc WHERE proname='fifo_roll_candidates')
UNION ALL SELECT 'atomic_consume_roll', (SELECT COUNT(*)::text FROM pg_proc WHERE proname='atomic_consume_roll')
UNION ALL SELECT 'wo_has_printing', (SELECT COUNT(*)::text FROM pg_proc WHERE proname='wo_has_printing')
UNION ALL SELECT 'fifo_printed_rolls_for_wo', (SELECT COUNT(*)::text FROM pg_proc WHERE proname='fifo_printed_rolls_for_wo');
