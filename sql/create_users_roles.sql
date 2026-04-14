-- ============================================
-- CARTA ERP - Korisnici i uloge
-- ============================================

-- 1. KREIRANJE TABLICE KORISNIKA (ako ne postoji)
CREATE TABLE IF NOT EXISTS prod_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  ime TEXT NOT NULL,
  pin_code TEXT NOT NULL,
  uloga TEXT NOT NULL DEFAULT 'radnik',
  aktivan BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_login TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_prod_users_email ON prod_users(email);
CREATE INDEX IF NOT EXISTS idx_prod_users_pin ON prod_users(pin_code);

-- 2. KREIRANJE TABLICE ULOGA
CREATE TABLE IF NOT EXISTS prod_roles (
  id SERIAL PRIMARY KEY,
  naziv TEXT UNIQUE NOT NULL,
  opis TEXT,
  dozvole JSONB DEFAULT '[]',
  aktivan BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. UMETANJE ULOGA
INSERT INTO prod_roles (naziv, opis, dozvole) VALUES
  ('superadmin', 'Super Administrator - potpuni pristup', '["*"]'),
  ('admin', 'Administrator - sve osim postavki sustava', '["dashboard","place","produktivnost","izvjestaji","terminal","planiranje","artikli","skladiste","rezac","tisak","tuber-wh","tuber-nli","bottomer","pvnd","raspored-nli","raspored-wh","maintenance","admin"]'),
  ('racunovodstvo', 'Računovodstvo - plaće i izvještaji', '["dashboard","place","produktivnost","izvjestaji"]'),
  ('uprava', 'Uprava - pregled i izvještaji', '["dashboard","planiranje","artikli","pvnd","izvjestaji","raspored-nli","raspored-wh"]'),
  ('koordinator-proizvodnje', 'Koordinator proizvodnje', '["dashboard","planiranje","artikli","skladiste","raspored-nli","raspored-wh","pvnd"]'),
  ('voditelj-odrzavanja', 'Voditelj održavanja', '["dashboard","maintenance","skladiste"]'),
  ('tuber-nli', 'Operater Tuber NLI', '["dashboard","tuber-nli","terminal"]'),
  ('tuber-wh', 'Operater Tuber WH', '["dashboard","tuber-wh","terminal"]'),
  ('bottomer-nli', 'Operater Bottomer NLI', '["dashboard","bottomer","terminal"]'),
  ('bottomer-wh', 'Operater Bottomer WH', '["dashboard","bottomer","terminal"]'),
  ('rezac', 'Operater Rezač', '["dashboard","rezac","terminal"]'),
  ('skladiste', 'Skladištar', '["dashboard","skladiste","terminal"]'),
  ('tisak', 'Operater Tisak', '["dashboard","tisak","terminal"]')
ON CONFLICT (naziv) DO UPDATE SET 
  opis = EXCLUDED.opis,
  dozvole = EXCLUDED.dozvole;

-- 4. UMETANJE KORISNIKA (iz tvog screenshota)
INSERT INTO prod_users (email, ime, pin_code, uloga, aktivan) VALUES
  ('atila.vadoci@carta.hr', 'Atila', '1111', 'superadmin', TRUE),
  ('ivica.vajnberger@carta.hr', 'Ivica', '1111', 'admin', TRUE),
  ('vedrana.tomljanovic@carta.hr', 'Vedrana', '1111', 'admin', TRUE),
  ('sasa.davidovic@carta.hr', 'Sasa', '1111', 'admin', TRUE),
  ('avadoci@gmail.com', 'Atila', '1111', 'admin', TRUE),
  ('carta.oblak@gmail.com', 'Carta', '1111', 'admin', TRUE),
  ('bottomernli@gmail.com', 'BottomerNLI', '1111', 'bottomer-nli', TRUE),
  ('tisak.carta@gmail.com', 'Tisak', '5235', 'tisak', TRUE),
  ('carta.rezac@gmail.com', 'Rezac', '1111', 'rezac', TRUE),
  ('iva.ivkovic@carta.hr', 'Iva', '1111', 'admin', TRUE),
  ('milan.josic@carta.hr', 'Milan', '1111', 'admin', TRUE),
  ('bottomerwh@gmail.com', 'BottomerWH', '1111', 'bottomer-wh', TRUE)
ON CONFLICT (email) DO UPDATE SET
  ime = EXCLUDED.ime,
  pin_code = EXCLUDED.pin_code,
  uloga = EXCLUDED.uloga,
  aktivan = EXCLUDED.aktivan;

-- 5. PROVJERA
SELECT 'Korisnici:' as info, COUNT(*) as broj FROM prod_users WHERE aktivan = TRUE
UNION ALL
SELECT 'Uloge:' as info, COUNT(*) as broj FROM prod_roles WHERE aktivan = TRUE;

-- Pregled korisnika
SELECT email, ime, uloga, aktivan FROM prod_users ORDER BY uloga, ime;

-- Pregled uloga
SELECT naziv, opis FROM prod_roles WHERE aktivan = TRUE ORDER BY naziv;
