-- ============================================
-- CARTA ERP - Work Hours Table
-- Verzija 2.0 - Prilagođeno postojećoj bazi
-- ============================================

-- 1. WORK_HOURS - Tablica za unos sati
-- Napomena: sati se mogu unositi direktno u payroll.hours_breakdown
-- Ova tablica je za buduću integraciju s praćenjem RV
CREATE TABLE IF NOT EXISTS work_hours (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id),
  employee_id UUID NOT NULL REFERENCES employees(id),
  year INTEGER NOT NULL,
  month INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
  
  -- Sati po tipovima (JSON za fleksibilnost)
  hours_breakdown JSONB DEFAULT '{}',
  
  -- Prijevoz
  transport_days INTEGER DEFAULT 0,
  transport_amount DECIMAL(10,2) DEFAULT 0,
  
  -- Napomena
  notes TEXT,
  
  -- Status
  status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'confirmed', 'processed')),
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID,
  
  -- Unique constraint - jedan zapis po djelatniku/mjesecu
  UNIQUE(employee_id, year, month)
);

-- Indeksi
CREATE INDEX IF NOT EXISTS idx_work_hours_employee ON work_hours(employee_id);
CREATE INDEX IF NOT EXISTS idx_work_hours_period ON work_hours(year, month);
CREATE INDEX IF NOT EXISTS idx_work_hours_status ON work_hours(status);

-- 2. Dodaj kolone u payroll ako ne postoje
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'payroll' AND column_name = 'sick_leave_hours') THEN
    ALTER TABLE payroll ADD COLUMN sick_leave_hours DECIMAL(10,2) DEFAULT 0;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'payroll' AND column_name = 'transport_reduction') THEN
    ALTER TABLE payroll ADD COLUMN transport_reduction DECIMAL(10,2) DEFAULT 0;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'payroll' AND column_name = 'bonus_reduction') THEN
    ALTER TABLE payroll ADD COLUMN bonus_reduction DECIMAL(10,2) DEFAULT 0;
  END IF;
END $$;

-- 3. Trigger za updated_at
CREATE OR REPLACE FUNCTION update_work_hours_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS work_hours_updated ON work_hours;
CREATE TRIGGER work_hours_updated
  BEFORE UPDATE ON work_hours
  FOR EACH ROW
  EXECUTE FUNCTION update_work_hours_timestamp();

-- 4. View za pregled plaća s podacima o djelatnicima
CREATE OR REPLACE VIEW v_payroll_details AS
SELECT 
  p.*,
  e.first_name,
  e.last_name,
  e.first_name || ' ' || e.last_name AS full_name,
  e.position AS job_title,
  e.coefficient,
  e.average_net_salary,
  e.tax_rate_override,
  e.children_count,
  e.transport_allowance AS emp_transport,
  e.team_name,
  e.surtax_rate AS emp_surtax_rate
FROM payroll p
JOIN employees e ON p.employee_id = e.id;

COMMENT ON TABLE work_hours IS 'Unos radnih sati - za buduću integraciju s praćenjem RV';
COMMENT ON VIEW v_payroll_details IS 'Payroll s podacima o djelatnicima';
