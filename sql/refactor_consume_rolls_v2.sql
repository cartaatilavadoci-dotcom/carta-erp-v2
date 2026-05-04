-- =============================================================================
-- REFAKTOR SKIDANJA ROLA v2 — Tuber, Tisak, Rezač
-- =============================================================================
-- Glavni princip: Sljedivost je primarna; bilanca je sekundarna (po internal_id).
-- Save NIKAD ne pada zbog "rola nema dovoljno" ili "rola ne postoji" — operater
-- je autoritet, sustav loga discrepance i reconciles kasnije.
--
-- Sigurnost: sve operacije su atomske u jednoj transakciji unutar RPC-a.
-- Idempotency: idempotency_key sprječava duplo skidanje na retry/double-click.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- A) Idempotency kolone na work_orders (tisak, rezač)
-- -----------------------------------------------------------------------------
ALTER TABLE prod_work_orders_printing
  ADD COLUMN IF NOT EXISTS material_deducted BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS material_deducted_at TIMESTAMPTZ;

ALTER TABLE prod_work_orders_cutting
  ADD COLUMN IF NOT EXISTS material_deducted BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS material_deducted_at TIMESTAMPTZ;

-- -----------------------------------------------------------------------------
-- B) Idempotency key na consumed_rolls (UNIQUE)
-- -----------------------------------------------------------------------------
ALTER TABLE prod_inventory_consumed_rolls
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'uq_consumed_rolls_idempotency'
  ) THEN
    ALTER TABLE prod_inventory_consumed_rolls
      ADD CONSTRAINT uq_consumed_rolls_idempotency UNIQUE (idempotency_key);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_consumed_rolls_idem
  ON prod_inventory_consumed_rolls(idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- -----------------------------------------------------------------------------
-- C) verified flag na rolls (false = sustav kreirao iz operatorskog manualnog unosa)
-- -----------------------------------------------------------------------------
ALTER TABLE prod_inventory_rolls
  ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS created_by_consumption BOOLEAN DEFAULT false;

-- -----------------------------------------------------------------------------
-- D) Discrepancy log
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS prod_consumption_discrepancy_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_order_id UUID,
  work_order_number TEXT,
  machine TEXT NOT NULL,                  -- 'tuber' | 'tisak' | 'rezac'
  scanned_code TEXT NOT NULL,
  resolved_roll_id UUID,                  -- NULL ako roll nije pronađen
  resolved_source_table TEXT,             -- 'prod_inventory_rolls' | 'printed' | 'strips' | 'manual_entry'
  internal_id TEXT,
  reason TEXT NOT NULL,                   -- 'overdraft' | 'unknown_roll_new' | 'unknown_roll_existing'
                                          -- | 'null_initial_weight' | 'manual_entry' | 'legacy_overdraft'
  declared_kg NUMERIC(10,3),
  available_kg NUMERIC(10,3),
  delta_kg NUMERIC(10,3),
  layer_number INTEGER,
  operator_name TEXT,
  shift_date DATE,
  reviewed_at TIMESTAMPTZ,
  reviewed_by TEXT,
  resolution_note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_discrepancy_unreviewed
  ON prod_consumption_discrepancy_log(created_at DESC)
  WHERE reviewed_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_discrepancy_wo
  ON prod_consumption_discrepancy_log(work_order_id);

CREATE INDEX IF NOT EXISTS idx_discrepancy_reason_machine
  ON prod_consumption_discrepancy_log(reason, machine);

-- -----------------------------------------------------------------------------
-- E) Link tablice za sljedivost (printed, strips)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS prod_printed_roll_link (
  printed_roll_id UUID NOT NULL REFERENCES prod_inventory_printed(id) ON DELETE CASCADE,
  consumed_roll_id UUID NOT NULL REFERENCES prod_inventory_consumed_rolls(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (printed_roll_id, consumed_roll_id)
);

CREATE INDEX IF NOT EXISTS idx_printed_link_consumed ON prod_printed_roll_link(consumed_roll_id);

CREATE TABLE IF NOT EXISTS prod_strip_roll_link (
  strip_id UUID NOT NULL REFERENCES prod_inventory_strips(id) ON DELETE CASCADE,
  consumed_roll_id UUID NOT NULL REFERENCES prod_inventory_consumed_rolls(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (strip_id, consumed_roll_id)
);

CREATE INDEX IF NOT EXISTS idx_strip_link_consumed ON prod_strip_roll_link(consumed_roll_id);

-- -----------------------------------------------------------------------------
-- F) Glavna RPC: consume_rolls_for_work_order
-- -----------------------------------------------------------------------------
-- Input shape (JSONB):
-- {
--   "machine": "tuber|tisak|rezac",
--   "work_order_id": "<uuid optional>",
--   "work_order_number": "RN045/26",
--   "idempotency_key": "tuber:RN045/26:1730000000000",
--   "operator": "Marko",
--   "shift_date": "2026-04-29",
--   "shift_number": 1,
--   "production_line": "WH",
--   "pop_ids": ["<uuid>", ...],          -- tuber only
--   "printed_roll_id": "<uuid>",         -- tisak only
--   "strip_ids": ["<uuid>", ...],        -- rezac only
--   "rolls": [
--     {
--       "scanned_code": "B70-9123",
--       "consumed_kg": 12.5,
--       "layer_number": 1,
--       "client_row_id": "r0",
--       "is_new_roll": false,           -- ako rola ne postoji i operater kaže "nova"
--       "manual_initial_kg": null,       -- za is_new_roll=true
--       "manual_internal_id": null,      -- za is_new_roll=true
--       "manual_manufacturer": null      -- opcijski
--     }
--   ]
-- }
--
-- Returns JSONB:
-- { "status": "ok"|"no_op", "rows": [...], "discrepancies": N, "skipped": N }
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION consume_rolls_for_work_order(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_machine TEXT := lower(p_input->>'machine');
  v_wo_id UUID := NULLIF(p_input->>'work_order_id', '')::UUID;
  v_wo_number TEXT := p_input->>'work_order_number';
  v_idem_prefix TEXT := p_input->>'idempotency_key';
  v_operator TEXT := COALESCE(p_input->>'operator', 'System');
  v_shift_date DATE := COALESCE(NULLIF(p_input->>'shift_date','')::DATE, CURRENT_DATE);
  v_shift_number INT := NULLIF(p_input->>'shift_number','')::INT;
  v_prod_line TEXT := p_input->>'production_line';
  v_pop_ids UUID[];
  v_printed_id UUID := NULLIF(p_input->>'printed_roll_id', '')::UUID;
  v_strip_ids UUID[];
  v_roll JSONB;
  v_results JSONB := '[]'::JSONB;
  v_discrepancies INT := 0;
  v_skipped INT := 0;
  v_consumption_type TEXT;
BEGIN
  -- Validate machine
  IF v_machine NOT IN ('tuber','tisak','rezac') THEN
    RAISE EXCEPTION 'Invalid machine: %. Expected tuber|tisak|rezac', v_machine;
  END IF;

  -- Mapiranje machine → consumption_type za audit
  v_consumption_type := CASE v_machine
                          WHEN 'tuber' THEN 'Tuber'
                          WHEN 'tisak' THEN 'Tiskanje'
                          WHEN 'rezac' THEN 'Rezanje'
                        END;

  -- Parse arrays defensively
  IF jsonb_typeof(p_input->'pop_ids') = 'array' THEN
    SELECT array_agg((x)::UUID) INTO v_pop_ids
    FROM jsonb_array_elements_text(p_input->'pop_ids') x;
  END IF;

  IF jsonb_typeof(p_input->'strip_ids') = 'array' THEN
    SELECT array_agg((x)::UUID) INTO v_strip_ids
    FROM jsonb_array_elements_text(p_input->'strip_ids') x;
  END IF;

  -- Idempotency check #1 (tuber): ako su SVI POP-ovi već material_deducted=true → no-op
  IF v_machine = 'tuber' AND v_pop_ids IS NOT NULL AND array_length(v_pop_ids,1) > 0 THEN
    IF NOT EXISTS (
      SELECT 1 FROM prod_inventory_pop
      WHERE id = ANY(v_pop_ids) AND COALESCE(material_deducted,false) = false
    ) THEN
      RETURN jsonb_build_object(
        'status','no_op',
        'reason','already_deducted',
        'machine', v_machine,
        'pop_count', array_length(v_pop_ids,1)
      );
    END IF;
  END IF;

  -- Idempotency check #2 (tisak/rezač): provjera flaga na work_order_*
  IF v_machine = 'tisak' AND v_wo_number IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM prod_work_orders_printing
      WHERE wo_number = v_wo_number AND COALESCE(material_deducted,false) = true
    ) THEN
      RETURN jsonb_build_object('status','no_op','reason','already_deducted','machine','tisak');
    END IF;
  ELSIF v_machine = 'rezac' AND v_wo_number IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM prod_work_orders_cutting
      WHERE wo_number = v_wo_number AND COALESCE(material_deducted,false) = true
    ) THEN
      RETURN jsonb_build_object('status','no_op','reason','already_deducted','machine','rezac');
    END IF;
  END IF;

  -- Glavna petlja: za svaku rolu unesi consumed_rolls + UPDATE source + LINK
  FOR v_roll IN SELECT jsonb_array_elements(COALESCE(p_input->'rolls','[]'::JSONB))
  LOOP
    DECLARE
      v_scan TEXT := trim(v_roll->>'scanned_code');
      v_declared_kg NUMERIC := COALESCE((v_roll->>'consumed_kg')::NUMERIC, 0);
      v_layer INT := NULLIF(v_roll->>'layer_number','')::INT;
      v_client_row_id TEXT := COALESCE(v_roll->>'client_row_id','r');
      v_is_new BOOLEAN := COALESCE((v_roll->>'is_new_roll')::BOOLEAN, false);
      v_manual_initial NUMERIC := NULLIF(v_roll->>'manual_initial_kg','')::NUMERIC;
      v_manual_iid TEXT := NULLIF(v_roll->>'manual_internal_id','');
      v_manual_mfr TEXT := NULLIF(v_roll->>'manual_manufacturer','');
      v_source_table TEXT;
      v_source_id UUID;
      v_internal_id TEXT;
      v_initial NUMERIC;
      v_consumed_now NUMERIC;
      v_available NUMERIC;
      v_delta NUMERIC;
      v_consumed_id UUID;
      v_idem_key TEXT;
      v_color TEXT;
      v_grammage TEXT;
      v_width_cm NUMERIC;
      v_manufacturer TEXT;
      v_inserted BOOLEAN := false;
      v_discrepancy_reason TEXT;
    BEGIN
      -- skip prazne unose
      IF v_scan IS NULL OR v_scan = '' THEN
        v_skipped := v_skipped + 1;
        CONTINUE;
      END IF;

      v_idem_key := v_idem_prefix || ':' || v_client_row_id;

      -- 1) Pronađi source rolu (rolls → printed → strips)
      SELECT id, internal_id, initial_weight_kg, COALESCE(consumed_kg,0),
             color, grammage, width_cm, manufacturer
        INTO v_source_id, v_internal_id, v_initial, v_consumed_now,
             v_color, v_grammage, v_width_cm, v_manufacturer
        FROM prod_inventory_rolls WHERE roll_code = v_scan LIMIT 1;
      IF v_source_id IS NOT NULL THEN
        v_source_table := 'prod_inventory_rolls';
      ELSE
        SELECT id, NULL::TEXT, weight_kg, COALESCE(consumed_kg,0),
               color::TEXT, grammage, width_cm, NULL::TEXT
          INTO v_source_id, v_internal_id, v_initial, v_consumed_now,
               v_color, v_grammage, v_width_cm, v_manufacturer
          FROM prod_inventory_printed WHERE printed_roll_code = v_scan LIMIT 1;
        IF v_source_id IS NOT NULL THEN
          v_source_table := 'prod_inventory_printed';
        ELSE
          SELECT id, NULL::TEXT, weight_kg, COALESCE(consumed_kg,0),
                 color::TEXT, grammage, width_cm, NULL::TEXT
            INTO v_source_id, v_internal_id, v_initial, v_consumed_now,
                 v_color, v_grammage, v_width_cm, v_manufacturer
            FROM prod_inventory_strips WHERE strip_code = v_scan LIMIT 1;
          IF v_source_id IS NOT NULL THEN
            v_source_table := 'prod_inventory_strips';
          END IF;
        END IF;
      END IF;

      -- 2) Ako rola NIJE pronađena i operater kaže "nova rola" → kreiraj u skladištu
      IF v_source_id IS NULL AND v_is_new = true THEN
        INSERT INTO prod_inventory_rolls (
          roll_code, internal_id, manufacturer, initial_weight_kg, consumed_kg,
          status, entry_date, verified, created_by_consumption
        ) VALUES (
          v_scan,
          COALESCE(v_manual_iid, '?'),
          v_manual_mfr,
          v_manual_initial,
          0,
          'Na skladištu',
          v_shift_date,
          false,
          true
        )
        RETURNING id, initial_weight_kg, internal_id, manufacturer
          INTO v_source_id, v_initial, v_internal_id, v_manufacturer;
        v_source_table := 'prod_inventory_rolls';
        v_consumed_now := 0;

        -- log discrepancy reason='unknown_roll_new'
        INSERT INTO prod_consumption_discrepancy_log (
          work_order_id, work_order_number, machine, scanned_code,
          resolved_roll_id, resolved_source_table, internal_id, reason,
          declared_kg, available_kg, delta_kg, layer_number, operator_name, shift_date
        ) VALUES (
          v_wo_id, v_wo_number, v_machine, v_scan,
          v_source_id, v_source_table, v_internal_id, 'unknown_roll_new',
          v_declared_kg, COALESCE(v_manual_initial,0), 0, v_layer, v_operator, v_shift_date
        );
        v_discrepancies := v_discrepancies + 1;
      END IF;

      v_available := COALESCE(v_initial,0) - COALESCE(v_consumed_now,0);
      v_delta := v_available - v_declared_kg;

      -- 3) UVIJEK INSERT u consumed_rolls (sljedivost) — idempotency_key UNIQUE
      INSERT INTO prod_inventory_consumed_rolls (
        idempotency_key, source_roll_id, source_table, roll_code, internal_id,
        manufacturer, color, grammage, width_cm,
        initial_weight_kg, consumed_kg,
        work_order_id, work_order_number, layer_number,
        production_line, shift_date, shift_number, consumption_type,
        consumed_by, original_scanned_code, paper_type
      ) VALUES (
        v_idem_key, v_source_id,
        COALESCE(v_source_table, 'manual_entry'),
        v_scan, v_internal_id,
        v_manufacturer, v_color, v_grammage, v_width_cm,
        v_initial, v_declared_kg,
        v_wo_id, v_wo_number, v_layer,
        v_prod_line, v_shift_date, v_shift_number, v_consumption_type,
        v_operator, v_scan, NULL
      )
      ON CONFLICT (idempotency_key) DO NOTHING
      RETURNING id INTO v_consumed_id;

      v_inserted := (v_consumed_id IS NOT NULL);

      -- Ako je već postojao po idempotency_key, dohvati postojeći id (za eventualne linkove)
      IF v_consumed_id IS NULL THEN
        SELECT id INTO v_consumed_id
        FROM prod_inventory_consumed_rolls
        WHERE idempotency_key = v_idem_key
        LIMIT 1;
      END IF;

      -- 4) UPDATE consumed_kg na source roli — clamp da nikad ne prelazi initial_weight
      IF v_source_id IS NOT NULL AND v_inserted = true THEN
        IF v_source_table = 'prod_inventory_rolls' THEN
          UPDATE prod_inventory_rolls
            SET consumed_kg = LEAST(
                  COALESCE(consumed_kg,0) + v_declared_kg,
                  COALESCE(initial_weight_kg, COALESCE(consumed_kg,0) + v_declared_kg)
                ),
                status = CASE
                  WHEN COALESCE(initial_weight_kg, 0) > 0 AND
                       (COALESCE(consumed_kg,0) + v_declared_kg) >= initial_weight_kg
                    THEN 'Utrošeno'
                  ELSE 'Djelomično'
                END,
                updated_at = NOW()
            WHERE id = v_source_id;
        ELSIF v_source_table = 'prod_inventory_printed' THEN
          UPDATE prod_inventory_printed
            SET consumed_kg = LEAST(
                  COALESCE(consumed_kg,0) + v_declared_kg,
                  COALESCE(weight_kg, COALESCE(consumed_kg,0) + v_declared_kg)
                ),
                status = CASE
                  WHEN COALESCE(weight_kg, 0) > 0 AND
                       (COALESCE(consumed_kg,0) + v_declared_kg) >= weight_kg
                    THEN 'Utrošeno'
                  ELSE 'Djelomično'
                END
            WHERE id = v_source_id;
        ELSIF v_source_table = 'prod_inventory_strips' THEN
          UPDATE prod_inventory_strips
            SET consumed_kg = LEAST(
                  COALESCE(consumed_kg,0) + v_declared_kg,
                  COALESCE(weight_kg, COALESCE(consumed_kg,0) + v_declared_kg)
                ),
                status = CASE
                  WHEN COALESCE(weight_kg, 0) > 0 AND
                       (COALESCE(consumed_kg,0) + v_declared_kg) >= weight_kg
                    THEN 'Utrošeno'
                  ELSE 'Djelomično'
                END
            WHERE id = v_source_id;
        END IF;
      END IF;

      -- 5) Discrepancy logging (overdraft, null initial, unknown_existing)
      IF v_inserted = true THEN
        v_discrepancy_reason := NULL;
        IF v_source_id IS NULL THEN
          v_discrepancy_reason := 'unknown_roll_existing';
        ELSIF v_initial IS NULL THEN
          v_discrepancy_reason := 'null_initial_weight';
        ELSIF v_delta < -0.1 THEN
          v_discrepancy_reason := 'overdraft';
        END IF;

        IF v_discrepancy_reason IS NOT NULL THEN
          INSERT INTO prod_consumption_discrepancy_log (
            work_order_id, work_order_number, machine, scanned_code,
            resolved_roll_id, resolved_source_table, internal_id, reason,
            declared_kg, available_kg, delta_kg, layer_number, operator_name, shift_date
          ) VALUES (
            v_wo_id, v_wo_number, v_machine, v_scan,
            v_source_id, v_source_table, v_internal_id, v_discrepancy_reason,
            v_declared_kg, v_available, v_delta, v_layer, v_operator, v_shift_date
          );
          v_discrepancies := v_discrepancies + 1;
        END IF;
      END IF;

      -- 6) Link tablice (sljedivost) — UVIJEK ako imamo consumed_id
      IF v_consumed_id IS NOT NULL THEN
        IF v_machine = 'tuber' AND v_pop_ids IS NOT NULL THEN
          INSERT INTO prod_pop_roll_link (pop_id, consumed_roll_id, layer_number)
          SELECT pop_id, v_consumed_id, v_layer
          FROM unnest(v_pop_ids) AS t(pop_id)
          ON CONFLICT DO NOTHING;
        ELSIF v_machine = 'tisak' AND v_printed_id IS NOT NULL THEN
          INSERT INTO prod_printed_roll_link (printed_roll_id, consumed_roll_id)
          VALUES (v_printed_id, v_consumed_id)
          ON CONFLICT DO NOTHING;
        ELSIF v_machine = 'rezac' AND v_strip_ids IS NOT NULL THEN
          INSERT INTO prod_strip_roll_link (strip_id, consumed_roll_id)
          SELECT s_id, v_consumed_id
          FROM unnest(v_strip_ids) AS t(s_id)
          ON CONFLICT DO NOTHING;
        END IF;
      END IF;

      v_results := v_results || jsonb_build_object(
        'scanned_code', v_scan,
        'consumed_id', v_consumed_id,
        'source_id', v_source_id,
        'source_table', v_source_table,
        'declared_kg', v_declared_kg,
        'available_kg', v_available,
        'delta_kg', v_delta,
        'inserted', v_inserted,
        'discrepancy', v_discrepancy_reason
      );
    END;
  END LOOP;

  -- 7) Postavi flag-ove SAMO ako je sve gore prošlo (ako greška, RAISE EXCEPTION rollback-a)
  IF v_machine = 'tuber' AND v_pop_ids IS NOT NULL THEN
    UPDATE prod_inventory_pop
      SET material_deducted = true,
          updated_at = NOW()
      WHERE id = ANY(v_pop_ids);
  ELSIF v_machine = 'tisak' AND v_wo_number IS NOT NULL THEN
    UPDATE prod_work_orders_printing
      SET material_deducted = true,
          material_deducted_at = NOW(),
          updated_at = NOW()
      WHERE wo_number = v_wo_number;
  ELSIF v_machine = 'rezac' AND v_wo_number IS NOT NULL THEN
    UPDATE prod_work_orders_cutting
      SET material_deducted = true,
          material_deducted_at = NOW(),
          updated_at = NOW()
      WHERE wo_number = v_wo_number;
  END IF;

  RETURN jsonb_build_object(
    'status', 'ok',
    'machine', v_machine,
    'rows', v_results,
    'discrepancies', v_discrepancies,
    'skipped', v_skipped,
    'idempotency_key', v_idem_prefix
  );
END;
$$;

-- Grant execute (Supabase clients koriste authenticated role)
GRANT EXECUTE ON FUNCTION consume_rolls_for_work_order(JSONB) TO authenticated, anon, service_role;

-- -----------------------------------------------------------------------------
-- G) View: bilanca papira po internal_id
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_paper_balance_by_internal_id AS
SELECT
  internal_id,
  CASE WHEN length(internal_id) > 0 THEN substring(internal_id, 1, 1) ELSE '?' END AS color,
  COUNT(*) AS roll_count_total,
  COUNT(*) FILTER (WHERE status = 'Na skladištu' OR status = 'Djelomično') AS roll_count_active,
  ROUND(SUM(GREATEST(remaining_kg, 0))::numeric, 1) AS total_remaining_kg,
  ROUND(SUM(initial_weight_kg)::numeric, 1) AS total_initial_kg,
  ROUND(SUM(consumed_kg)::numeric, 1) AS total_consumed_kg,
  COUNT(*) FILTER (WHERE remaining_kg < 0) AS rolls_with_overdraft,
  COUNT(*) FILTER (WHERE initial_weight_kg IS NULL) AS rolls_with_null_initial,
  COUNT(*) FILTER (WHERE COALESCE(verified, true) = false) AS unverified_rolls,
  MAX(updated_at) AS last_updated
FROM prod_inventory_rolls
WHERE internal_id IS NOT NULL
GROUP BY internal_id
ORDER BY total_remaining_kg DESC;

-- -----------------------------------------------------------------------------
-- H) View: discrepancy aggregator za admin dashboard
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_consumption_discrepancies AS
SELECT
  reason,
  machine,
  COUNT(*) AS total_count,
  COUNT(*) FILTER (WHERE reviewed_at IS NULL) AS unreviewed_count,
  ROUND(SUM(ABS(COALESCE(delta_kg, 0)))::numeric, 1) AS total_abs_delta_kg,
  MIN(created_at) AS first_occurrence,
  MAX(created_at) AS last_occurrence
FROM prod_consumption_discrepancy_log
GROUP BY reason, machine
ORDER BY unreviewed_count DESC, total_count DESC;

-- -----------------------------------------------------------------------------
-- I) Feature flag-ovi u prod_settings (default OFF — uklj. tek kad smo spremni)
-- -----------------------------------------------------------------------------
INSERT INTO prod_settings (key, value, description)
VALUES
  ('roll_consumption_v2_tuber', 'false',
   'Feature flag: koristi novu RPC consume_rolls_for_work_order na tuberu. Default false.'),
  ('roll_consumption_v2_tisak', 'false',
   'Feature flag: koristi novu RPC consume_rolls_for_work_order na tisku. Default false.'),
  ('roll_consumption_v2_rezac', 'false',
   'Feature flag: koristi novu RPC consume_rolls_for_work_order na rezaču. Default false.')
ON CONFLICT (key) DO NOTHING;

COMMIT;

-- =============================================================================
-- VERIFIKACIJA (nakon primjene)
-- =============================================================================
-- 1) RPC postoji
--    SELECT proname FROM pg_proc WHERE proname = 'consume_rolls_for_work_order';
--
-- 2) Idempotency kolone postavljene
--    \d prod_work_orders_printing
--    \d prod_work_orders_cutting
--    \d prod_inventory_consumed_rolls
--
-- 3) Discrepancy log postoji i prazan
--    SELECT COUNT(*) FROM prod_consumption_discrepancy_log;
--
-- 4) Link tablice postoje
--    SELECT 'printed' AS t, COUNT(*) FROM prod_printed_roll_link
--    UNION ALL SELECT 'strip', COUNT(*) FROM prod_strip_roll_link;
--
-- 5) View-ovi rade
--    SELECT * FROM v_paper_balance_by_internal_id LIMIT 5;
--    SELECT * FROM v_consumption_discrepancies;
--
-- 6) Feature flag-ovi su 'false'
--    SELECT key, value FROM prod_settings WHERE key LIKE 'roll_consumption_v2%';
-- =============================================================================
