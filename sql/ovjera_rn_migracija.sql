-- ============================================
-- OVJERA RADNIH NALOGA - Migracija
-- CARTA ERP - Four-Eyes Principle
-- Izvrsiti u Supabase SQL Editor
-- ============================================

-- ============================================
-- 1. NOVE KOLONE U prod_work_orders
-- ============================================

-- 1.1 Status ovjere (Default 'Odobreno' da postojeci nalozi rade)
ALTER TABLE prod_work_orders
ADD COLUMN IF NOT EXISTS approval_status TEXT DEFAULT 'Odobreno';

-- 1.2 Tko je kreirao (UUID iz prod_users)
ALTER TABLE prod_work_orders
ADD COLUMN IF NOT EXISTS created_by_user_id UUID;

-- 1.3 Ime kreatora (za prikaz)
ALTER TABLE prod_work_orders
ADD COLUMN IF NOT EXISTS created_by_name TEXT;

-- 1.4 Tko je odobrio/odbio
ALTER TABLE prod_work_orders
ADD COLUMN IF NOT EXISTS approved_by_user_id UUID;

-- 1.5 Ime odobravatelja
ALTER TABLE prod_work_orders
ADD COLUMN IF NOT EXISTS approved_by_name TEXT;

-- 1.6 Vrijeme ovjere
ALTER TABLE prod_work_orders
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;

-- 1.7 Razlog odbijanja
ALTER TABLE prod_work_orders
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- ============================================
-- 2. CHECK CONSTRAINT
-- ============================================

-- Ukloni postojeci constraint ako postoji
ALTER TABLE prod_work_orders
DROP CONSTRAINT IF EXISTS chk_approval_status;

-- Dodaj novi constraint (koristi ASCII vrijednosti)
ALTER TABLE prod_work_orders
ADD CONSTRAINT chk_approval_status
CHECK (approval_status IN ('Ceka ovjeru', 'Odobreno', 'Odbijeno'));

-- ============================================
-- 3. INDEKSI ZA BRZO FILTRIRANJE
-- ============================================

CREATE INDEX IF NOT EXISTS idx_wo_approval_status
ON prod_work_orders(approval_status);

CREATE INDEX IF NOT EXISTS idx_wo_approval_pending
ON prod_work_orders(approval_status)
WHERE approval_status = 'Ceka ovjeru';

-- ============================================
-- 4. RETROAKTIVNO: SVI POSTOJECI NALOZI = ODOBRENO
-- ============================================

UPDATE prod_work_orders
SET approval_status = 'Odobreno'
WHERE approval_status IS NULL;

-- ============================================
-- 5. RPC FUNKCIJA: approve_work_order
-- ============================================

CREATE OR REPLACE FUNCTION approve_work_order(
  p_work_order_id UUID,
  p_approver_user_id UUID,
  p_approver_name TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_created_by UUID;
  v_current_status TEXT;
  v_wo_number TEXT;
BEGIN
  -- Dohvati podatke o nalogu
  SELECT created_by_user_id, approval_status, wo_number
  INTO v_created_by, v_current_status, v_wo_number
  FROM prod_work_orders
  WHERE id = p_work_order_id;

  -- Provjera: nalog postoji?
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Radni nalog nije pronadjen');
  END IF;

  -- Provjera: status mora biti 'Ceka ovjeru'
  IF v_current_status != 'Ceka ovjeru' THEN
    RETURN json_build_object('success', false, 'error', 'Nalog nije u statusu cekanja ovjere');
  END IF;

  -- Provjera: four-eyes - ista osoba NE MOZE odobriti
  IF v_created_by IS NOT NULL AND v_created_by = p_approver_user_id THEN
    RETURN json_build_object('success', false, 'error', 'Ne mozete odobriti nalog koji ste sami kreirali (four-eyes principle)');
  END IF;

  -- Odobri nalog
  UPDATE prod_work_orders
  SET approval_status = 'Odobreno',
      approved_by_user_id = p_approver_user_id,
      approved_by_name = p_approver_name,
      approved_at = NOW(),
      rejection_reason = NULL
  WHERE id = p_work_order_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Radni nalog ' || v_wo_number || ' je odobren'
  );
END;
$$;

-- Dozvole za RPC
GRANT EXECUTE ON FUNCTION approve_work_order(UUID, UUID, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION approve_work_order(UUID, UUID, TEXT) TO authenticated;

-- ============================================
-- 6. RPC FUNKCIJA: reject_work_order
-- ============================================

CREATE OR REPLACE FUNCTION reject_work_order(
  p_work_order_id UUID,
  p_rejector_user_id UUID,
  p_rejector_name TEXT,
  p_reason TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_status TEXT;
  v_wo_number TEXT;
BEGIN
  -- Dohvati podatke o nalogu
  SELECT approval_status, wo_number
  INTO v_current_status, v_wo_number
  FROM prod_work_orders
  WHERE id = p_work_order_id;

  -- Provjera: nalog postoji?
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Radni nalog nije pronadjen');
  END IF;

  -- Provjera: status mora biti 'Ceka ovjeru'
  IF v_current_status != 'Ceka ovjeru' THEN
    RETURN json_build_object('success', false, 'error', 'Nalog nije u statusu cekanja ovjere');
  END IF;

  -- Provjera: razlog je obavezan
  IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
    RETURN json_build_object('success', false, 'error', 'Razlog odbijanja je obavezan');
  END IF;

  -- Odbij nalog
  UPDATE prod_work_orders
  SET approval_status = 'Odbijeno',
      approved_by_user_id = p_rejector_user_id,
      approved_by_name = p_rejector_name,
      approved_at = NOW(),
      rejection_reason = p_reason
  WHERE id = p_work_order_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Radni nalog ' || v_wo_number || ' je odbijen'
  );
END;
$$;

-- Dozvole za RPC
GRANT EXECUTE ON FUNCTION reject_work_order(UUID, UUID, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION reject_work_order(UUID, UUID, TEXT, TEXT) TO authenticated;

-- ============================================
-- 7. RPC FUNKCIJA: resubmit_work_order
-- ============================================

CREATE OR REPLACE FUNCTION resubmit_work_order(
  p_work_order_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_status TEXT;
  v_wo_number TEXT;
BEGIN
  -- Dohvati podatke o nalogu
  SELECT approval_status, wo_number
  INTO v_current_status, v_wo_number
  FROM prod_work_orders
  WHERE id = p_work_order_id;

  -- Provjera: nalog postoji?
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Radni nalog nije pronadjen');
  END IF;

  -- Provjera: samo odbijeni nalozi se mogu ponovo poslati
  IF v_current_status != 'Odbijeno' THEN
    RETURN json_build_object('success', false, 'error', 'Samo odbijeni nalozi se mogu ponovo poslati na ovjeru');
  END IF;

  -- Ponovo posalji na ovjeru
  UPDATE prod_work_orders
  SET approval_status = 'Ceka ovjeru',
      approved_by_user_id = NULL,
      approved_by_name = NULL,
      approved_at = NULL,
      rejection_reason = NULL
  WHERE id = p_work_order_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Radni nalog ' || v_wo_number || ' je ponovo poslan na ovjeru'
  );
END;
$$;

-- Dozvole za RPC
GRANT EXECUTE ON FUNCTION resubmit_work_order(UUID) TO anon;
GRANT EXECUTE ON FUNCTION resubmit_work_order(UUID) TO authenticated;

-- ============================================
-- ZAVRSETAK MIGRACIJE
-- ============================================
-- Nakon izvrsenja provjerite:
-- 1. SELECT column_name FROM information_schema.columns WHERE table_name = 'prod_work_orders' AND column_name LIKE 'approv%';
-- 2. SELECT proname FROM pg_proc WHERE proname LIKE '%work_order';
-- 3. SELECT approval_status, COUNT(*) FROM prod_work_orders GROUP BY approval_status;
