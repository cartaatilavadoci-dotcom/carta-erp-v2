-- ============================================
-- CARTA ERP - Kreiranje prod_inventory_wip tablice
-- Work In Progress (WIP) - poluproizvodi
-- ============================================

-- Ukloni tablicu ako postoji
DROP TABLE IF EXISTS prod_inventory_wip CASCADE;

-- Kreiraj tablicu
CREATE TABLE prod_inventory_wip (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Šifra WIP-a (jedinstvena)
    wip_code VARCHAR(50) NOT NULL UNIQUE,
    
    -- Veza s radnim nalogom
    work_order_id UUID REFERENCES prod_work_orders(id) ON DELETE SET NULL,
    work_order_number VARCHAR(50),
    order_number VARCHAR(50),
    
    -- Artikl info
    article_id UUID REFERENCES prod_articles(id) ON DELETE SET NULL,
    article_name VARCHAR(255),
    article_code VARCHAR(100),
    
    -- Kupac
    customer_name VARCHAR(255),
    
    -- Količine
    quantity INTEGER NOT NULL DEFAULT 0,           -- Ukupno proizvedeno
    quantity_in_stock INTEGER NOT NULL DEFAULT 0,  -- Trenutno na skladištu
    
    -- Status i linija
    status VARCHAR(50) DEFAULT 'Na skladištu',
    production_line VARCHAR(10),  -- 'WH' ili 'NLI'
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indeksi za brže pretrage
CREATE INDEX idx_wip_work_order_id ON prod_inventory_wip(work_order_id);
CREATE INDEX idx_wip_work_order_number ON prod_inventory_wip(work_order_number);
CREATE INDEX idx_wip_article_id ON prod_inventory_wip(article_id);
CREATE INDEX idx_wip_status ON prod_inventory_wip(status);
CREATE INDEX idx_wip_production_line ON prod_inventory_wip(production_line);
CREATE INDEX idx_wip_created_at ON prod_inventory_wip(created_at);

-- Trigger za updated_at
CREATE OR REPLACE FUNCTION update_wip_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_wip_updated_at
    BEFORE UPDATE ON prod_inventory_wip
    FOR EACH ROW
    EXECUTE FUNCTION update_wip_updated_at();

-- RLS (Row Level Security) - opciono
ALTER TABLE prod_inventory_wip ENABLE ROW LEVEL SECURITY;

-- Politika za čitanje - svi mogu čitati
CREATE POLICY "Allow read access" ON prod_inventory_wip
    FOR SELECT USING (true);

-- Politika za pisanje - svi mogu pisati (za anon key)
CREATE POLICY "Allow insert access" ON prod_inventory_wip
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow update access" ON prod_inventory_wip
    FOR UPDATE USING (true);

CREATE POLICY "Allow delete access" ON prod_inventory_wip
    FOR DELETE USING (true);

-- Komentar na tablicu
COMMENT ON TABLE prod_inventory_wip IS 'Work In Progress - poluproizvodi (POP) na skladištu';
COMMENT ON COLUMN prod_inventory_wip.wip_code IS 'Jedinstvena šifra WIP/POP-a (npr. POP-NLI-12345678)';
COMMENT ON COLUMN prod_inventory_wip.quantity IS 'Ukupna proizvedena količina';
COMMENT ON COLUMN prod_inventory_wip.quantity_in_stock IS 'Trenutna količina na skladištu (smanjuje se kad Bottomer troši)';

-- ============================================
-- VERIFIKACIJA
-- ============================================
SELECT 
    'prod_inventory_wip tablica kreirana!' AS status,
    COUNT(*) AS broj_kolona
FROM information_schema.columns 
WHERE table_name = 'prod_inventory_wip';
