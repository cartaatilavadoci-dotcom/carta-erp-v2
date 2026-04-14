-- ============================================
-- CARTA ERP - Evidencija Smjena
-- ============================================

-- 1. GLAVNA TABLICA SMJENA
-- ============================================
DROP TABLE IF EXISTS prod_shift_details CASCADE;
DROP TABLE IF EXISTS prod_shift_log CASCADE;

CREATE TABLE prod_shift_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifikator smjene (SM-YYYYMMDD-LINIJA-SMJENA)
    shift_id VARCHAR(30) NOT NULL UNIQUE,
    
    -- Kada i koja smjena
    datum DATE NOT NULL,
    smjena INTEGER NOT NULL CHECK (smjena BETWEEN 1 AND 3),
    linija VARCHAR(10) NOT NULL,  -- 'NLI' ili 'WH'
    stroj_tip VARCHAR(20) NOT NULL,  -- 'Tuber' ili 'Bottomer'
    
    -- Postava
    postava_broj INTEGER,
    postava_naziv VARCHAR(50),
    djelatnici JSONB,  -- Lista djelatnika u smjeni
    
    -- Vrijeme
    vrijeme_pocetka TIMESTAMPTZ,
    vrijeme_zavrsetka TIMESTAMPTZ,
    
    -- Status
    status VARCHAR(20) DEFAULT 'U tijeku',
    
    -- Agregirane statistike (ažurira se na kraju smjene)
    broj_paleta INTEGER DEFAULT 0,
    ukupno_proizvedeno INTEGER DEFAULT 0,
    ukupno_skart INTEGER DEFAULT 0,
    
    -- Napomena
    napomena TEXT,
    zakljucio VARCHAR(100),
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Unique constraint
    UNIQUE(datum, smjena, linija, stroj_tip)
);

-- 2. DETALJI SMJENE (svaki unos POP/GOP)
-- ============================================
CREATE TABLE prod_shift_details (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Veza na smjenu
    shift_log_id UUID REFERENCES prod_shift_log(id) ON DELETE CASCADE,
    shift_id VARCHAR(30) NOT NULL,  -- Denormalizirano za lakše querije
    
    -- Datum i smjena (denormalizirano)
    datum DATE NOT NULL,
    smjena INTEGER NOT NULL,
    linija VARCHAR(10) NOT NULL,
    stroj_tip VARCHAR(20) NOT NULL,
    postava_naziv VARCHAR(50),
    
    -- Radni nalog
    work_order_id UUID,
    work_order_number VARCHAR(50),
    order_number VARCHAR(50),
    
    -- Artikl
    article_name VARCHAR(255),
    article_code VARCHAR(100),
    customer_name VARCHAR(255),
    
    -- Proizvodnja
    vrsta_unosa VARCHAR(20) NOT NULL,  -- 'POP' ili 'GOP' ili 'Paleta'
    referenca VARCHAR(50),  -- pop_code ili pallet_number
    kolicina INTEGER NOT NULL DEFAULT 0,
    skart INTEGER DEFAULT 0,
    
    -- Vrijeme i operater
    vrijeme_unosa TIMESTAMPTZ DEFAULT NOW(),
    operater VARCHAR(100),
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. INDEKSI
-- ============================================
CREATE INDEX idx_shift_log_datum ON prod_shift_log(datum);
CREATE INDEX idx_shift_log_linija ON prod_shift_log(linija);
CREATE INDEX idx_shift_log_stroj ON prod_shift_log(stroj_tip);
CREATE INDEX idx_shift_log_status ON prod_shift_log(status);
CREATE INDEX idx_shift_log_shift_id ON prod_shift_log(shift_id);
CREATE INDEX idx_shift_log_datum_linija ON prod_shift_log(datum, linija, stroj_tip);

CREATE INDEX idx_shift_details_shift_id ON prod_shift_details(shift_id);
CREATE INDEX idx_shift_details_shift_log_id ON prod_shift_details(shift_log_id);
CREATE INDEX idx_shift_details_datum ON prod_shift_details(datum);
CREATE INDEX idx_shift_details_wo ON prod_shift_details(work_order_number);

-- 4. RLS POLITIKE
-- ============================================
ALTER TABLE prod_shift_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE prod_shift_details ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all shift_log" ON prod_shift_log FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all shift_details" ON prod_shift_details FOR ALL USING (true) WITH CHECK (true);

-- 5. TRIGGER ZA updated_at
-- ============================================
CREATE OR REPLACE FUNCTION update_shift_log_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_shift_log_updated
    BEFORE UPDATE ON prod_shift_log
    FOR EACH ROW
    EXECUTE FUNCTION update_shift_log_updated_at();

-- 6. KOMENTARI
-- ============================================
COMMENT ON TABLE prod_shift_log IS 'Evidencija smjena - glavna tablica';
COMMENT ON TABLE prod_shift_details IS 'Detalji proizvodnje po smjeni - svaki unos POP/GOP';
COMMENT ON COLUMN prod_shift_log.shift_id IS 'Format: SM-YYYYMMDD-LINIJA-STROJ-SMJENA';
COMMENT ON COLUMN prod_shift_details.vrsta_unosa IS 'POP za Tuber, GOP/Paleta za Bottomer';

-- 7. PROVJERA
-- ============================================
SELECT 'prod_shift_log' AS tablica, COUNT(*) AS kolona FROM information_schema.columns WHERE table_name = 'prod_shift_log'
UNION ALL
SELECT 'prod_shift_details', COUNT(*) FROM information_schema.columns WHERE table_name = 'prod_shift_details';
