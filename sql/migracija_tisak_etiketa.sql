-- ============================================
-- CARTA ERP - Migracija: Tisak Etiketa
-- Datum: 2026-02-09
-- Opis: Dodaje podrsku za radne naloge tiska etiketa (dno vrece)
-- ============================================

-- 1. Kolona za razlikovanje tipa tiska (tijelo vs etiketa)
ALTER TABLE prod_work_orders_printing
  ADD COLUMN IF NOT EXISTS printing_type TEXT DEFAULT 'tijelo';

-- CHECK constraint za printing_type
ALTER TABLE prod_work_orders_printing
  ADD CONSTRAINT chk_printing_type CHECK (printing_type IN ('tijelo', 'etiketa'));

-- 2. Duljina jedne etikete u cm (rucni unos)
ALTER TABLE prod_work_orders_printing
  ADD COLUMN IF NOT EXISTS label_length NUMERIC(6,2);

-- 3. Broj etiketa po vreci (1 za OL ventil, 2 za ostale)
ALTER TABLE prod_work_orders_printing
  ADD COLUMN IF NOT EXISTS labels_per_bag INTEGER DEFAULT 1;

-- 4. Broj formi (parova) na kliseju (1-6)
ALTER TABLE prod_work_orders_printing
  ADD COLUMN IF NOT EXISTS label_forms_count INTEGER DEFAULT 1;

ALTER TABLE prod_work_orders_printing
  ADD CONSTRAINT chk_label_forms_count CHECK (label_forms_count BETWEEN 1 AND 6);

-- 5. PDF graficka priprema za etiketu (URL)
ALTER TABLE prod_work_orders_printing
  ADD COLUMN IF NOT EXISTS label_print_preparation_url TEXT;

-- 6. Indeks za brze filtriranje po tipu tiska
CREATE INDEX IF NOT EXISTS idx_printing_type ON prod_work_orders_printing(printing_type);

-- 7. Brojac za ETI prefix
INSERT INTO prod_counters (counter_type, prefix, current_value, year)
VALUES ('RN_Etiketa', 'ETI', 0, 2026)
ON CONFLICT (counter_type) DO UPDATE SET year = 2026;

-- Postojeci zapisi automatski dobivaju printing_type = 'tijelo' (DEFAULT)

-- ============================================
-- FORMULA ZA ETIKETE:
-- Sliv etikete = labels_per_bag x label_length (cm)
-- Metara = kolicina x sliv_etikete / 100 / label_forms_count
-- PotrebnoKg = (sirina_papira x gramatura x sliv_etikete x kolicina) / 10.000.000
-- ============================================
