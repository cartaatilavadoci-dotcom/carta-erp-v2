-- ============================================================
-- DISPATCH: Reconcile OTP-2026-0004 + preventivni trigger
-- Datum: 2026-04-14
-- ============================================================
-- POZADINA:
-- Dispatch OTP-2026-0004 (Gebi, 20.01.2026) imao je 43 GOP palete
-- označene s dispatch_status='dispatched' ali:
--   - GOP.status ostao 'Na skladištu' (trebao bi biti 'Otpremljeno')
--   - dispatched_at=NULL
--   - Parent prod_dispatch.status ostao 'Pripremljeno'
--
-- Uzrok: vjerojatno prekinut confirmDispatch RPC poziv (network fail
-- nakon što je prvi UPDATE prošao, prije završetka).
--
-- Posljedica: PVND/Dashboard query koji filtriraju status='Otpremljeno'
-- NE vide 172,100 kom otpremljenih vreća → metrike prikazuju manje.
-- ============================================================


-- ============================================================
-- KORAK 1: Reconcile OTP-2026-0004 (već primijenjeno)
-- ============================================================

-- UPDATE prod_inventory_gop
-- SET status = 'Otpremljeno',
--     dispatched_at = '2026-01-20 13:36:24.788921+00'
-- WHERE dispatch_id = (SELECT id FROM prod_dispatch WHERE dispatch_number='OTP-2026-0004')
--   AND dispatch_status = 'dispatched';
--
-- UPDATE prod_dispatch
-- SET status = 'Otpremljeno',
--     dispatched_at = '2026-01-20 13:36:24.788921+00',
--     dispatched_by = COALESCE(dispatched_by, 'System (retroactive reconcile 2026-04-14)'),
--     total_quantity = 172100,
--     total_pallets = 43
-- WHERE dispatch_number = 'OTP-2026-0004';


-- ============================================================
-- KORAK 2: Preventivni trigger - auto-sync status
-- ============================================================
-- Ako itko (frontend, ad-hoc SQL, future bugs) postavi
-- dispatch_status='dispatched' na GOP paletu, trigger auto-sync-a:
--   - status → 'Otpremljeno'
--   - dispatched_at → NOW() (ako nije već postavljen)
-- Sprečava ponavljanje OTP-2026-0004 scenarija.
-- ============================================================

CREATE OR REPLACE FUNCTION sync_gop_dispatch_status()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Kad dispatch_status postane 'dispatched', osiguraj da su
  -- glavni status i dispatched_at u skladu
  IF NEW.dispatch_status = 'dispatched'
     AND NEW.dispatch_status IS DISTINCT FROM OLD.dispatch_status THEN
    IF NEW.status IS DISTINCT FROM 'Otpremljeno' THEN
      NEW.status := 'Otpremljeno';
    END IF;
    IF NEW.dispatched_at IS NULL THEN
      NEW.dispatched_at := NOW();
    END IF;
  END IF;

  -- Obratno: ako se dispatch_status vrati na 'available' (rollback),
  -- vrati status u 'Na skladištu'
  IF NEW.dispatch_status = 'available'
     AND OLD.dispatch_status = 'dispatched' THEN
    IF NEW.status = 'Otpremljeno' THEN
      NEW.status := 'Na skladištu';
    END IF;
    NEW.dispatched_at := NULL;
    NEW.dispatch_id := NULL;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_gop_dispatch_status_sync ON prod_inventory_gop;
CREATE TRIGGER trg_gop_dispatch_status_sync
  BEFORE UPDATE ON prod_inventory_gop
  FOR EACH ROW
  WHEN (NEW.dispatch_status IS DISTINCT FROM OLD.dispatch_status)
  EXECUTE FUNCTION sync_gop_dispatch_status();


-- ============================================================
-- VERIFIKACIJA
-- ============================================================
SELECT
  status,
  dispatch_status,
  COUNT(*) AS broj
FROM prod_inventory_gop
GROUP BY status, dispatch_status
ORDER BY broj DESC;
