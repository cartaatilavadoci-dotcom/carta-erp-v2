-- ============================================
-- CARTA ERP - Kreiranje tablica za raspored proizvodnje
-- Pokreni ovaj SQL u Supabase SQL Editor
-- ============================================

-- 1. KREIRANJE TABLICE TIMOVA
CREATE TABLE IF NOT EXISTS prod_schedule_teams (
  id SERIAL PRIMARY KEY,
  postava_broj INTEGER NOT NULL,
  naziv_tima TEXT NOT NULL,
  stroj_tip TEXT NOT NULL,
  linija TEXT NOT NULL DEFAULT 'NLI',
  status TEXT NOT NULL DEFAULT 'Aktivan',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. KREIRANJE TABLICE ČLANOVA
CREATE TABLE IF NOT EXISTS prod_schedule_members (
  id SERIAL PRIMARY KEY,
  team_id INTEGER NOT NULL REFERENCES prod_schedule_teams(id) ON DELETE CASCADE,
  djelatnik_ime TEXT NOT NULL,
  employee_id UUID REFERENCES employees(id),
  aktivan BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. INDEXI
CREATE INDEX IF NOT EXISTS idx_pst_postava ON prod_schedule_teams(postava_broj);
CREATE INDEX IF NOT EXISTS idx_pst_linija ON prod_schedule_teams(linija);
CREATE INDEX IF NOT EXISTS idx_psm_team ON prod_schedule_members(team_id);

-- ============================================
-- POPUNJAVANJE TIMOVA (12 redaka)
-- ============================================
INSERT INTO prod_schedule_teams (id, postava_broj, naziv_tima, stroj_tip, linija, status) VALUES
  (1, 1, 'Postava 1', 'Bottomer', 'NLI', 'Aktivan'),
  (2, 1, 'Postava 1', 'Tuber', 'NLI', 'Aktivan'),
  (3, 2, 'Postava 2', 'Bottomer', 'NLI', 'Aktivan'),
  (4, 2, 'Postava 2', 'Tuber', 'NLI', 'Aktivan'),
  (5, 3, 'Postava 3', 'Bottomer', 'NLI', 'Aktivan'),
  (6, 3, 'Postava 3', 'Tuber', 'NLI', 'Aktivan'),
  (7, 4, 'Postava 4', 'Bottomer', 'WH', 'Aktivan'),
  (8, 4, 'Postava 4', 'Tuber', 'WH', 'Aktivan'),
  (9, 5, 'Postava 5', 'Bottomer', 'WH', 'Aktivan'),
  (10, 5, 'Postava 5', 'Tuber', 'WH', 'Aktivan'),
  (11, 6, 'Postava 6', 'Bottomer', 'NLI', 'Aktivan'),
  (12, 6, 'Postava 6', 'Tuber', 'NLI', 'Neaktivan');

-- Reset SERIAL sequence
SELECT setval('prod_schedule_teams_id_seq', 12);

-- ============================================
-- POPUNJAVANJE ČLANOVA (prema tvojim podacima)
-- ============================================

-- Postava 1 - Bottomer (team_id = 1)
INSERT INTO prod_schedule_members (team_id, djelatnik_ime) VALUES
  (1, 'SLAVKO VUGEC'),
  (1, 'BRUNO ŽIVKOVIĆ'),
  (1, 'DRAGANA POPOVIĆ'),
  (1, 'MILENA MILETIĆ'),
  (1, 'MIRTA ŠIPOŠ');

-- Postava 1 - Tuber (team_id = 2)
INSERT INTO prod_schedule_members (team_id, djelatnik_ime) VALUES
  (2, 'JOSIP LONČARIĆ'),
  (2, 'DANIJEL MRKŠIĆ');

-- Postava 2 - Bottomer (team_id = 3)
INSERT INTO prod_schedule_members (team_id, djelatnik_ime) VALUES
  (3, 'DINO MILJATOVIĆ'),
  (3, 'DRAGAN JERKOVIĆ'),
  (3, 'SLAĐANA POPOVIĆ'),
  (3, 'ALEKSANDRA MARIĆ'),
  (3, 'MIRJANA PETROVIĆ');

-- Postava 2 - Tuber (team_id = 4)
INSERT INTO prod_schedule_members (team_id, djelatnik_ime) VALUES
  (4, 'MATEJ BUDEŠ'),
  (4, 'MIHAEL ŽIVKOVIĆ');

-- Postava 3 - Bottomer (team_id = 5)
INSERT INTO prod_schedule_members (team_id, djelatnik_ime) VALUES
  (5, 'ZORAN KOVAČ'),
  (5, 'VEDRAN SCHRUDEL'),
  (5, 'EMANUELA KUJUNDŽIĆ'),
  (5, 'MICHELLE ANN ZUGOR'),
  (5, 'A. CVETKOVIĆ');

-- Postava 3 - Tuber (team_id = 6)
INSERT INTO prod_schedule_members (team_id, djelatnik_ime) VALUES
  (6, 'DRAGO POPOVIĆ'),
  (6, 'IVAN PARLOV');

-- Postava 4 - Bottomer WH (team_id = 7)
INSERT INTO prod_schedule_members (team_id, djelatnik_ime) VALUES
  (7, 'STJEPAN GRGURIĆ'),
  (7, 'BOJAN JAGER'),
  (7, 'DARIA ŠVAJHOFER'),
  (7, 'IVANA CICKAI');

-- Postava 4 - Tuber WH (team_id = 8)
INSERT INTO prod_schedule_members (team_id, djelatnik_ime) VALUES
  (8, 'LJUBICA MUSIĆ'),
  (8, 'BRANIMIR KOMIĆ');

-- Postava 5 - Bottomer WH (team_id = 9)
INSERT INTO prod_schedule_members (team_id, djelatnik_ime) VALUES
  (9, 'VEDRAN POPIĆ'),
  (9, 'DAMIR KAPETINIĆ'),
  (9, 'MIRJANA POPOVIĆ'),
  (9, 'ENA ŠMAHOLC');

-- Postava 5 - Tuber WH (team_id = 10)
INSERT INTO prod_schedule_members (team_id, djelatnik_ime) VALUES
  (10, 'HRVOJE ANDRAKOVIĆ'),
  (10, 'JOSIP ERVAČIĆ');

-- Postava 6 - Bottomer specijalna (team_id = 11)
INSERT INTO prod_schedule_members (team_id, djelatnik_ime) VALUES
  (11, 'BRUNO ŽIVKOVIĆ'),
  (11, 'BOJAN JAGER'),
  (11, 'ANITA CVETKOVIĆ'),
  (11, 'MIRTA ŠIPOŠ');

-- Postava 6 - Tuber (team_id = 12) - trenutno neaktivan, bez članova

-- ============================================
-- PROVJERA
-- ============================================
SELECT 'Timovi:' as info, COUNT(*) as broj FROM prod_schedule_teams
UNION ALL
SELECT 'Članovi:' as info, COUNT(*) as broj FROM prod_schedule_members;

-- Pregled svih članova po postavi
SELECT 
  t.postava_broj,
  t.naziv_tima,
  t.stroj_tip,
  t.linija,
  m.djelatnik_ime
FROM prod_schedule_teams t
LEFT JOIN prod_schedule_members m ON t.id = m.team_id
WHERE m.aktivan = true OR m.id IS NULL
ORDER BY t.postava_broj, t.stroj_tip, m.djelatnik_ime;

-- ============================================
-- TABLICA ZA SPREMLJENI RASPORED (opcijski)
-- ============================================
CREATE TABLE IF NOT EXISTS prod_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  datum DATE NOT NULL,
  smjena INTEGER NOT NULL CHECK (smjena BETWEEN 1 AND 3),
  postava_broj INTEGER NOT NULL,
  linija TEXT NOT NULL DEFAULT 'NLI',
  djelatnici JSONB,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES employees(id)
);

CREATE INDEX IF NOT EXISTS idx_prod_schedules_datum ON prod_schedules(datum);
CREATE INDEX IF NOT EXISTS idx_prod_schedules_linija ON prod_schedules(linija);

-- Unique constraint - jedan zapis po datumu/smjeni/liniji
CREATE UNIQUE INDEX IF NOT EXISTS idx_prod_schedules_unique 
  ON prod_schedules(datum, smjena, linija);
