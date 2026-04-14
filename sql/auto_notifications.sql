-- ============================================================
-- AUTO NOTIFIKACIJE za ključne event-ove
-- Datum: 2026-04-14
-- ============================================================
-- Dodaje trigger funkcije koje auto-stvaraju notifikacije u
-- prod_notifications (koje surface-a bell dropdown iz 847652c).
--
-- Event-ovi:
--   1. RN odbijen  (approval_status → 'Odbijeno')
--   2. RN završen s pod-proizvodnjom (status → 'Završeno', produced_pct < 90)
-- ============================================================


-- ============================================================
-- Trigger 1: RN odbijen → notify kreator + uprava
-- ============================================================
CREATE OR REPLACE FUNCTION notify_on_wo_rejected()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.approval_status = 'Odbijeno'
     AND NEW.approval_status IS DISTINCT FROM OLD.approval_status THEN

    PERFORM create_notification(
      p_type := 'work_order_rejected',
      p_title := 'RN odbijen: ' || COALESCE(NEW.wo_number, '-'),
      p_message := 'Nalog za ' || COALESCE(NEW.customer_name, '-') || ' (' ||
                   COALESCE(NEW.article_name, '-') || ') je odbijen. ' ||
                   'Razlog: ' || COALESCE(NEW.rejection_reason, '(nije naveden)'),
      p_related_id := NEW.id,
      p_related_type := 'work_order',
      p_target_roles := ARRAY['uprava', 'koordinator-proizvodnje']::text[],
      p_created_by := COALESCE(NEW.approved_by_name, 'System')
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_wo_rejected_notify ON prod_work_orders;
CREATE TRIGGER trg_wo_rejected_notify
  AFTER UPDATE OF approval_status ON prod_work_orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_wo_rejected();


-- ============================================================
-- Trigger 2: RN završen s pod-proizvodnjom → alert
-- ============================================================
CREATE OR REPLACE FUNCTION notify_on_wo_under_produced()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_pct numeric;
BEGIN
  -- Fire samo kad status prelazi u 'Završeno'
  IF NEW.status = 'Završeno'
     AND NEW.status IS DISTINCT FROM OLD.status THEN

    -- produced_pct je GENERATED kolona, računa se automatski
    v_pct := NEW.produced_pct;

    IF v_pct IS NOT NULL AND v_pct < 90 THEN
      PERFORM create_notification(
        p_type := 'work_order_under_produced',
        p_title := '⚠️ Pod-proizvodnja: ' || COALESCE(NEW.wo_number, '-'),
        p_message := 'Proizvedeno ' || COALESCE(NEW.produced_quantity::text, '0') || '/' ||
                     COALESCE(NEW.quantity::text, '0') ||
                     ' kom (' || ROUND(v_pct, 1)::text || '%) za ' ||
                     COALESCE(NEW.customer_name, '-'),
        p_related_id := NEW.id,
        p_related_type := 'work_order',
        p_target_roles := ARRAY['uprava', 'koordinator-proizvodnje']::text[],
        p_created_by := 'System'
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_wo_under_produced_notify ON prod_work_orders;
CREATE TRIGGER trg_wo_under_produced_notify
  AFTER UPDATE OF status ON prod_work_orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_wo_under_produced();


-- ============================================================
-- VERIFIKACIJA
-- ============================================================
SELECT tgname, event_manipulation, action_timing
FROM information_schema.triggers
WHERE trigger_schema='public'
  AND event_object_table='prod_work_orders'
  AND tgname LIKE 'trg_wo_%notify%';
