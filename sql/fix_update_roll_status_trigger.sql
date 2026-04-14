-- ============================================================
-- FIX: update_roll_status trigger - latentni bug
-- Datum: 2026-04-14
-- ============================================================
-- POZADINA:
-- update_roll_status_trigger je BEFORE UPDATE trigger na
-- prod_inventory_rolls. Funkcija je čitala NEW.remaining_kg,
-- ali remaining_kg je STORED GENERATED kolona koju Postgres
-- računa POSLIJE BEFORE triggera. Trigger je uvijek vidio
-- STARU vrijednost remaining_kg, pa je status uvijek završavao
-- u 'Na skladištu' (ELSE granu).
--
-- POSLJEDICA: Status nije bio sinkroniziran s consumed_kg.
-- Kad je migration backfill_consumed_kg_from_audit.sql ažurirao
-- consumed_kg za 575 rola, status je ostao 'Na skladištu'
-- iako je remaining_kg = 0.
--
-- FIX: Trigger sada manualno računa remaining iz
-- initial_weight_kg - consumed_kg, ne oslanja se na
-- NEW.remaining_kg.
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_roll_status()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_remaining numeric;
BEGIN
  -- GENERATED kolona se računa POSLIJE BEFORE triggera, pa moramo manualno
  v_remaining := COALESCE(NEW.initial_weight_kg, 0) - COALESCE(NEW.consumed_kg, 0);

  IF v_remaining <= 0 THEN
    NEW.status := 'Utrošena';
  ELSIF v_remaining < COALESCE(NEW.initial_weight_kg, 0) THEN
    NEW.status := 'Djelomično utrošeno';
  ELSE
    NEW.status := 'Na skladištu';
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$function$;

-- Touch-update svih rola da trigger preračuna status iz consumed_kg
UPDATE prod_inventory_rolls SET consumed_kg = consumed_kg WHERE consumed_kg IS NOT NULL;
