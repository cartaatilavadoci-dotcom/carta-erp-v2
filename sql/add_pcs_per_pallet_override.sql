-- Migracija: Dodaj pcs_per_pallet_override u prod_work_orders
-- Svrha: Omogućuje slagaču korekciju KOM/PALETA za specifični radni nalog
-- Kada je NULL, koristi se vrijednost iz prod_articles.pcs_per_pallet

ALTER TABLE prod_work_orders
ADD COLUMN IF NOT EXISTS pcs_per_pallet_override INTEGER;

COMMENT ON COLUMN prod_work_orders.pcs_per_pallet_override IS 'Override za KOM/PALETA - kada je postavljeno, koristi se umjesto artikl vrijednosti';
