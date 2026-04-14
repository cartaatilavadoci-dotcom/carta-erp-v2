-- ============================================================
-- WORKFLOW QUICK WINS (A1 + A2 + A3)
-- Datum: 2026-04-14
-- ============================================================
-- A1: Auto-compute produced_quantity iz GOP-a
-- A2: Quantity variance flag (under/over production)
-- A3: Workflow gate-keeper u complete_bottomer_phase
-- ============================================================


-- ============================================================
-- A1 + A2: produced_quantity kolona + variance flag
-- ============================================================

-- Dodaj produced_quantity (komada) ako ne postoji
ALTER TABLE prod_work_orders
  ADD COLUMN IF NOT EXISTS produced_quantity INTEGER DEFAULT 0;

-- Dodaj variance flag (postotak proizvedenog vs planiranog)
-- GENERATED kolona - automatski izračunata
ALTER TABLE prod_work_orders
  ADD COLUMN IF NOT EXISTS produced_pct NUMERIC(5,1)
  GENERATED ALWAYS AS (
    CASE
      WHEN COALESCE(quantity, 0) = 0 THEN NULL
      ELSE ROUND((COALESCE(produced_quantity, 0) * 100.0 / quantity)::numeric, 1)
    END
  ) STORED;

-- Index za brže filtriranje under-produced naloga
CREATE INDEX IF NOT EXISTS idx_wo_produced_pct ON prod_work_orders(produced_pct)
  WHERE produced_pct IS NOT NULL;


-- ============================================================
-- TRIGGER: Auto-recalculate produced_quantity iz GOP-a
-- ============================================================

CREATE OR REPLACE FUNCTION sync_wo_produced_quantity()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_wo_ids UUID[];
BEGIN
  -- Sakupi sve WO ID-ove koje treba osvježiti
  IF TG_OP = 'INSERT' THEN
    v_wo_ids := ARRAY[NEW.work_order_id];
  ELSIF TG_OP = 'DELETE' THEN
    v_wo_ids := ARRAY[OLD.work_order_id];
  ELSIF TG_OP = 'UPDATE' THEN
    -- Ako je work_order_id promijenjen, osvježi oba RN-a
    IF NEW.work_order_id IS DISTINCT FROM OLD.work_order_id THEN
      v_wo_ids := ARRAY[NEW.work_order_id, OLD.work_order_id];
    ELSE
      v_wo_ids := ARRAY[NEW.work_order_id];
    END IF;
  END IF;

  -- Recompute produced_quantity za sve pogođene RN-ove
  UPDATE prod_work_orders wo
  SET produced_quantity = COALESCE((
    SELECT SUM(g.quantity)
    FROM prod_inventory_gop g
    WHERE g.work_order_id = wo.id
  ), 0)
  WHERE wo.id = ANY(v_wo_ids) AND wo.id IS NOT NULL;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_gop_sync_wo_produced ON prod_inventory_gop;
CREATE TRIGGER trg_gop_sync_wo_produced
  AFTER INSERT OR UPDATE OR DELETE ON prod_inventory_gop
  FOR EACH ROW EXECUTE FUNCTION sync_wo_produced_quantity();


-- ============================================================
-- BACKFILL: prepuni produced_quantity za sve postojeće RN-ove
-- ============================================================
UPDATE prod_work_orders wo
SET produced_quantity = COALESCE((
  SELECT SUM(g.quantity)
  FROM prod_inventory_gop g
  WHERE g.work_order_id = wo.id
), 0);


-- ============================================================
-- A3: Workflow gate-keeper u complete_bottomer_phase
-- ============================================================

CREATE OR REPLACE FUNCTION public.complete_bottomer_phase(p_work_order_id uuid, p_phase text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_voditelj_status TEXT;
  v_slagac_status TEXT;
  v_tuber_status TEXT;
  v_wo_status TEXT;
BEGIN
  -- GATE-KEEPER: Tuber mora biti završen prije završetka Bottomera
  SELECT tuber_status, status INTO v_tuber_status, v_wo_status
  FROM prod_work_orders WHERE id = p_work_order_id;

  IF v_wo_status IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Radni nalog ne postoji');
  END IF;

  IF v_tuber_status IS DISTINCT FROM 'Završeno' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Tuber faza nije završena - ne može se završiti Bottomer',
      'tuber_status', COALESCE(v_tuber_status, 'NULL')
    );
  END IF;

  -- Ažuriraj odgovarajući status
  IF p_phase = 'voditelj' THEN
    UPDATE prod_work_orders
    SET bottomer_voditelj_status = 'Završeno',
        bottomer_voditelj_completed_at = NOW()
    WHERE id = p_work_order_id;
  ELSIF p_phase = 'slagac' THEN
    UPDATE prod_work_orders
    SET bottomer_slagac_status = 'Završeno',
        bottomer_slagac_completed_at = NOW()
    WHERE id = p_work_order_id;
  ELSE
    RETURN json_build_object('success', false, 'error', 'Invalid phase');
  END IF;

  SELECT bottomer_voditelj_status, bottomer_slagac_status
  INTO v_voditelj_status, v_slagac_status
  FROM prod_work_orders WHERE id = p_work_order_id;

  -- Ako su OBA završena, završi cijeli nalog
  IF v_voditelj_status = 'Završeno' AND v_slagac_status = 'Završeno' THEN
    UPDATE prod_work_orders
    SET status = 'Završeno', completed_at = NOW()
    WHERE id = p_work_order_id;

    RETURN json_build_object(
      'success', true, 'fully_completed', true,
      'message', 'Nalog potpuno završen (voditelj + slagač)'
    );
  END IF;

  RETURN json_build_object(
    'success', true, 'fully_completed', false,
    'voditelj_status', v_voditelj_status,
    'slagac_status', v_slagac_status,
    'message', 'Faza ' || p_phase || ' završena, čeka se druga faza'
  );
END;
$function$;


-- ============================================================
-- VERIFIKACIJA
-- ============================================================
SELECT
  COUNT(*) AS ukupno_rn,
  COUNT(*) FILTER (WHERE produced_quantity > 0) AS s_proizvodnjom,
  COUNT(*) FILTER (WHERE produced_pct < 90 AND status='Završeno') AS pod_proizvedeni_zavrseni,
  COUNT(*) FILTER (WHERE produced_pct > 110 AND status='Završeno') AS nad_proizvedeni_zavrseni
FROM prod_work_orders
WHERE created_at > now() - interval '60 days';
