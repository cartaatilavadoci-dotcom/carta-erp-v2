-- ============================================================
-- CARTA ERP — ISO 9001 SCHEMA v1
-- ============================================================
-- Faza 1 sprint: Document Control + Nesukladnosti + CAPA + KPI + Mjerna oprema
-- Datum: 2026-05-02
--
-- Ova migracija kreira:
--   1) 19 iso_* tablica
--   2) RLS politike
--   3) Sequences i numbering helper funkcije
--   4) 2 trigger-a za auto-NC iz prod_inventory_rolls i prod_failure_reports
--   5) v_iso_pregled view za dashboard
--   6) ISO defaults u settings tablici
--   7) Storage bucket 'iso-documents'
--   8) Update existing prod_roles + nova rola 'koordinator-odrzavanja'
--
-- NAPOMENA o GENERATED kolonama: koristim ih za score (probability*severity) i total_score
-- (sukladno postojećoj konvenciji u CARTA-ERP-u — vidi CLAUDE.md Pravilo 21)
-- ============================================================


-- ============================================================
-- 1. STORAGE BUCKET
-- ============================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'iso-documents',
  'iso-documents',
  false,
  52428800, -- 50 MB
  ARRAY['application/pdf','application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.oasis.opendocument.text',
        'application/vnd.oasis.opendocument.spreadsheet',
        'image/png','image/jpeg','image/jpg','text/plain']
) ON CONFLICT (id) DO NOTHING;

-- Storage policies — authenticated korisnici mogu read/write
DROP POLICY IF EXISTS "iso_docs_read" ON storage.objects;
DROP POLICY IF EXISTS "iso_docs_insert" ON storage.objects;
DROP POLICY IF EXISTS "iso_docs_update" ON storage.objects;
DROP POLICY IF EXISTS "iso_docs_delete" ON storage.objects;

CREATE POLICY "iso_docs_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'iso-documents');
CREATE POLICY "iso_docs_insert" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'iso-documents');
CREATE POLICY "iso_docs_update" ON storage.objects FOR UPDATE
  USING (bucket_id = 'iso-documents');
CREATE POLICY "iso_docs_delete" ON storage.objects FOR DELETE
  USING (bucket_id = 'iso-documents');


-- ============================================================
-- 2. SEQUENCES za auto-numbering
-- ============================================================
CREATE SEQUENCE IF NOT EXISTS iso_nc_seq;
CREATE SEQUENCE IF NOT EXISTS iso_capa_seq;
CREATE SEQUENCE IF NOT EXISTS iso_audit_seq;
CREATE SEQUENCE IF NOT EXISTS iso_complaint_seq;
CREATE SEQUENCE IF NOT EXISTS iso_risk_seq;
CREATE SEQUENCE IF NOT EXISTS iso_objective_seq;


-- ============================================================
-- 3. iso_documents — Document Control master table
--    Pokriva: Politika kvalitete, Priručnik (PK), Procedure (PP),
--             Uputstva (UP), Obrasce (OB), Radne upute (RU)
-- ============================================================
CREATE TABLE IF NOT EXISTS iso_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE, -- 'OB-05', 'UP-04', 'PK-01', 'POL-01'
  title text NOT NULL,
  doc_type text NOT NULL, -- 'Politika','Prirucnik','Procedura','Uputstvo','Obrazac','Radna_uputa','Plan','Izvjesce','Drugo'
  category text, -- 'kvaliteta','sigurnost','okolis','administracija','proizvodnja','odrzavanje'
  current_version text, -- denormalized
  status text NOT NULL DEFAULT 'Draft', -- 'Draft','Review','Published','Superseded','Archived'
  owner_employee_id uuid REFERENCES employees(id) ON DELETE SET NULL,
  owner_role text, -- ako nema konkretnog vlasnika, npr. 'PUK','Uprava'
  classification text DEFAULT 'Interni', -- 'Interni','Javni','Povjerljivi'
  next_review_date date,
  review_interval_months integer DEFAULT 12,
  description text,
  legacy_filename text, -- za bulk import iz Windows foldera
  storage_folder text DEFAULT 'general',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  created_by uuid REFERENCES prod_users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_iso_documents_status ON iso_documents(status);
CREATE INDEX IF NOT EXISTS idx_iso_documents_review ON iso_documents(next_review_date);
CREATE INDEX IF NOT EXISTS idx_iso_documents_owner ON iso_documents(owner_employee_id);
CREATE INDEX IF NOT EXISTS idx_iso_documents_type ON iso_documents(doc_type, status);

COMMENT ON TABLE iso_documents IS 'ISO 9001 Document Control — sve politike, procedure, uputstva, obrasci.';


-- ============================================================
-- 4. iso_document_versions — version history s file URL-om
-- ============================================================
CREATE TABLE IF NOT EXISTS iso_document_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES iso_documents(id) ON DELETE CASCADE,
  version text NOT NULL, -- '1.0','1.1','2.0'
  file_path text, -- relativni put unutar 'iso-documents' bucketa
  file_size_bytes bigint,
  file_mime_type text,
  changelog text, -- "Što je promijenjeno u ovoj verziji"
  approved_by uuid REFERENCES prod_users(id) ON DELETE SET NULL,
  approved_at timestamptz,
  effective_from date,
  retired_at timestamptz,
  uploaded_at timestamptz NOT NULL DEFAULT now(),
  uploaded_by uuid REFERENCES prod_users(id) ON DELETE SET NULL,
  is_current boolean NOT NULL DEFAULT false,
  UNIQUE(document_id, version)
);
CREATE INDEX IF NOT EXISTS idx_iso_doc_versions_doc ON iso_document_versions(document_id, is_current);
CREATE INDEX IF NOT EXISTS idx_iso_doc_versions_current ON iso_document_versions(is_current) WHERE is_current = true;

COMMENT ON TABLE iso_document_versions IS 'Povijest verzija dokumenata. is_current=true je trenutno aktivna.';


-- ============================================================
-- 5. iso_document_acknowledgements — e-potpis "pročitao sam"
-- ============================================================
CREATE TABLE IF NOT EXISTS iso_document_acknowledgements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES iso_documents(id) ON DELETE CASCADE,
  version_id uuid NOT NULL REFERENCES iso_document_versions(id) ON DELETE CASCADE,
  employee_id uuid REFERENCES employees(id) ON DELETE SET NULL,
  user_id uuid REFERENCES prod_users(id) ON DELETE SET NULL,
  ack_at timestamptz NOT NULL DEFAULT now(),
  ip_address inet,
  notes text
);
CREATE INDEX IF NOT EXISTS idx_iso_doc_ack_doc ON iso_document_acknowledgements(document_id);
CREATE INDEX IF NOT EXISTS idx_iso_doc_ack_emp ON iso_document_acknowledgements(employee_id);


-- ============================================================
-- 6. iso_processes — OB_20 Procesi (Vodjenje, Nabava, Proizvodnja, ...)
-- ============================================================
CREATE TABLE IF NOT EXISTS iso_processes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE, -- '1.2','4','5','6','7','8','9','10','11'
  name text NOT NULL, -- 'Vođenje','Upravljanje kvalitetom','Nuđenje/Ugovaranje','Nabava'...
  description text,
  owner_employee_id uuid REFERENCES employees(id) ON DELETE SET NULL,
  owner_role text, -- 'Predsjednica uprave','PUK','Voditelj proizvodnje'
  inputs text,
  outputs text,
  resources text,
  measurement_frequency text, -- 'Mjesečno','Polugodišnje','Godišnje'
  measurement_method text,
  active boolean DEFAULT true,
  last_review_at date,
  next_review_at date,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);


-- ============================================================
-- 7. iso_quality_objectives — OB_06 Ciljevi (KPI + Projektni hibrid)
-- ============================================================
CREATE TABLE IF NOT EXISTS iso_quality_objectives (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  objective_number text, -- 'C-2026-001'
  year integer NOT NULL,
  objective_type text NOT NULL DEFAULT 'KPI', -- 'KPI' (mjerni s targetom) ili 'Projektni' (datum/status)
  name text NOT NULL,
  description text,
  process_id uuid REFERENCES iso_processes(id) ON DELETE SET NULL,
  -- za KPI tip:
  target_value numeric,
  target_unit text, -- '%','kom','EUR','sati','kg'
  target_direction text DEFAULT 'higher_better', -- 'higher_better','lower_better','target'
  measurement_frequency text DEFAULT 'monthly', -- 'daily','weekly','monthly','quarterly','yearly'
  kpi_query_name text, -- ime SQL view-a/funkcije, npr. 'kpi_isporuka_u_roku_pct(year)'
  -- za Projektni tip:
  responsible_role text,
  responsible_employee_id uuid REFERENCES employees(id) ON DELETE SET NULL,
  measures text, -- "Kupnja stroja, montaža..."
  deadline_date date,
  project_status text, -- 'Planirano','U_tijeku','Realizirano','Otkazano','Pomjereno'
  -- shared:
  active boolean DEFAULT true,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_iso_obj_year ON iso_quality_objectives(year, active);
CREATE INDEX IF NOT EXISTS idx_iso_obj_type ON iso_quality_objectives(objective_type);


-- ============================================================
-- 8. iso_quality_objective_results — KPI vrijednosti kroz vrijeme
-- ============================================================
CREATE TABLE IF NOT EXISTS iso_quality_objective_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  objective_id uuid NOT NULL REFERENCES iso_quality_objectives(id) ON DELETE CASCADE,
  period_start date NOT NULL,
  period_end date NOT NULL,
  measured_value numeric,
  achieved boolean,
  target_at_time numeric,
  notes text,
  computed_at timestamptz DEFAULT now(),
  computed_by text DEFAULT 'system',
  UNIQUE(objective_id, period_start, period_end)
);
CREATE INDEX IF NOT EXISTS idx_iso_obj_results_obj ON iso_quality_objective_results(objective_id, period_end DESC);


-- ============================================================
-- 9. iso_nonconformities — centralni log (zamjena OB_05 Excel-a)
-- ============================================================
CREATE TABLE IF NOT EXISTS iso_nonconformities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nc_number text NOT NULL UNIQUE, -- 'NC-2026-0001'
  occurred_at timestamptz NOT NULL DEFAULT now(),
  detected_at timestamptz NOT NULL DEFAULT now(),
  source_type text NOT NULL, -- 'rola_otpis','stroj_kvar','reklamacija_kupca','interni_audit','smjenski_skart','rucno','dobavljac'
  source_table text, -- za auto-generated: 'prod_inventory_rolls','prod_failure_reports','prod_shift_reports'
  source_id uuid, -- ID iz source tablice
  category text, -- 'repromaterijal','usluga','gotov_proizvod','u_proizvodnji','skladiste','administracija','odrzavanje'
  severity text DEFAULT 'minor', -- 'major','minor','observation'
  -- entity references
  supplier_name text,
  customer_id uuid REFERENCES prod_customers(id) ON DELETE SET NULL,
  customer_name text,
  work_order_id uuid REFERENCES prod_work_orders(id) ON DELETE SET NULL,
  work_order_number text,
  article_id text,
  article_name text,
  -- description
  description text NOT NULL,
  immediate_action text,
  root_cause text,
  -- workflow
  status text NOT NULL DEFAULT 'Otvoreno', -- 'Otvoreno','U_obradi','Cekanje','Zatvoreno','Otkazano'
  opened_by uuid REFERENCES prod_users(id) ON DELETE SET NULL,
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  closed_by uuid REFERENCES prod_users(id) ON DELETE SET NULL,
  -- cost tracking
  cost_estimated_eur numeric,
  cost_actual_eur numeric,
  -- attachments
  attachments jsonb DEFAULT '[]'::jsonb,
  notes text,
  -- auto-generated flag (čovjek mora reviewat)
  auto_generated boolean NOT NULL DEFAULT false,
  reviewed_by uuid REFERENCES prod_users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  -- metadata
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_iso_nc_status ON iso_nonconformities(status);
CREATE INDEX IF NOT EXISTS idx_iso_nc_source ON iso_nonconformities(source_type);
CREATE INDEX IF NOT EXISTS idx_iso_nc_supplier ON iso_nonconformities(supplier_name);
CREATE INDEX IF NOT EXISTS idx_iso_nc_customer ON iso_nonconformities(customer_id);
CREATE INDEX IF NOT EXISTS idx_iso_nc_occurred ON iso_nonconformities(occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_iso_nc_auto ON iso_nonconformities(auto_generated) WHERE auto_generated = true;

COMMENT ON TABLE iso_nonconformities IS 'Centralni log nesukladnosti. Auto-generated iz triggera (rola otpis, kvar) ili ručno unesen.';


-- ============================================================
-- 10. iso_capa — Corrective and Preventive Action workflow
-- ============================================================
CREATE TABLE IF NOT EXISTS iso_capa (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  capa_number text NOT NULL UNIQUE, -- 'CAPA-2026-0001'
  capa_type text NOT NULL DEFAULT 'korektivna', -- 'korektivna','preventivna'
  nc_id uuid REFERENCES iso_nonconformities(id) ON DELETE SET NULL,
  audit_finding_id uuid, -- FK dodaj kasnije nakon iso_audit_findings
  description text NOT NULL,
  root_cause_method text, -- '5-Why','Ishikawa','FMEA','Other'
  root_cause text,
  action_plan text NOT NULL,
  assigned_to_employee_id uuid REFERENCES employees(id) ON DELETE SET NULL,
  assigned_at timestamptz DEFAULT now(),
  due_date date NOT NULL,
  completed_at timestamptz,
  completed_by uuid REFERENCES prod_users(id) ON DELETE SET NULL,
  -- effectiveness verification gate (ISO 9001:2015 cl. 10.2)
  effectiveness_check_planned_date date,
  effectiveness_check_date date,
  effectiveness_verified boolean,
  effectiveness_verified_by uuid REFERENCES prod_users(id) ON DELETE SET NULL,
  effectiveness_notes text,
  -- workflow
  status text NOT NULL DEFAULT 'Otvoreno', -- 'Otvoreno','U_tijeku','Implementirano','Verificirano','Zatvoreno','Otkazano'
  opened_by uuid REFERENCES prod_users(id) ON DELETE SET NULL,
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  closed_by uuid REFERENCES prod_users(id) ON DELETE SET NULL,
  -- AI metadata
  ai_suggested_root_cause text,
  ai_suggested_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_iso_capa_status ON iso_capa(status);
CREATE INDEX IF NOT EXISTS idx_iso_capa_due ON iso_capa(due_date) WHERE status NOT IN ('Zatvoreno','Otkazano');
CREATE INDEX IF NOT EXISTS idx_iso_capa_nc ON iso_capa(nc_id);
CREATE INDEX IF NOT EXISTS idx_iso_capa_assigned ON iso_capa(assigned_to_employee_id);

COMMENT ON TABLE iso_capa IS 'CAPA workflow — gate ne dopusta status=Zatvoreno bez effectiveness_verified=true (UI-level check).';


-- ============================================================
-- 11. iso_risks — OB_18 Registar rizika
-- ============================================================
CREATE TABLE IF NOT EXISTS iso_risks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  risk_number text, -- 'R-2026-001'
  area text NOT NULL, -- 'repromaterijal','usluga_treci','gotov_proizvod','u_proizvodnji','skladiste','administracija','odrzavanje','dnevna_kontrola'
  risk_description text NOT NULL,
  probability integer NOT NULL CHECK (probability BETWEEN 1 AND 3),
  severity integer NOT NULL CHECK (severity BETWEEN 1 AND 3),
  score integer GENERATED ALWAYS AS (probability * severity) STORED,
  status text NOT NULL DEFAULT 'Aktivan', -- 'Aktivan','Pod_pracenjem','Mitigiran','Otkazan'
  owner_employee_id uuid REFERENCES employees(id) ON DELETE SET NULL,
  responsible_role text,
  mitigation_plan text,
  preventive_measures text,
  last_review_at date,
  next_review_date date,
  -- auto-link tracking
  linked_nc_count integer DEFAULT 0,
  linked_capa_count integer DEFAULT 0,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_iso_risks_area ON iso_risks(area);
CREATE INDEX IF NOT EXISTS idx_iso_risks_score ON iso_risks(score DESC);
CREATE INDEX IF NOT EXISTS idx_iso_risks_status ON iso_risks(status);


-- ============================================================
-- 12. iso_audits — OB_02/OB_03/OB_09 Internal audit module
-- ============================================================
CREATE TABLE IF NOT EXISTS iso_audits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_number text NOT NULL UNIQUE, -- 'AUD-2026-01'
  audit_type text NOT NULL DEFAULT 'interni', -- 'interni','eksterni','dobavljaca','prijave_iz_rizika'
  year integer NOT NULL,
  scope_processes uuid[], -- array od iso_processes ids
  scope_text text,
  planned_date date NOT NULL,
  executed_date date,
  status text NOT NULL DEFAULT 'Planiran', -- 'Planiran','U_tijeku','Provedeno','Izvjesce_izradeno','Zatvoren','Otkazan'
  lead_auditor_employee_id uuid REFERENCES employees(id) ON DELETE SET NULL,
  lead_auditor_external_name text, -- ako je vanjski (Krunoslav Matočec)
  auditees text[],
  external_consultant_present boolean DEFAULT false,
  external_consultant_name text,
  -- closure
  findings_summary text,
  total_findings integer DEFAULT 0,
  major_count integer DEFAULT 0,
  minor_count integer DEFAULT 0,
  observation_count integer DEFAULT 0,
  preporuka_count integer DEFAULT 0,
  report_path text, -- Storage path za PDF izvješće
  conclusion text,
  norm_compliant boolean,
  -- AI generated
  checklist_ai_generated boolean DEFAULT false,
  checklist_generated_at timestamptz,
  --
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_iso_audits_year ON iso_audits(year, status);
CREATE INDEX IF NOT EXISTS idx_iso_audits_date ON iso_audits(planned_date);


-- ============================================================
-- 13. iso_audit_checklist — pitanja iz checkliste (Gemini generated)
-- ============================================================
CREATE TABLE IF NOT EXISTS iso_audit_checklist (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid NOT NULL REFERENCES iso_audits(id) ON DELETE CASCADE,
  process_id uuid REFERENCES iso_processes(id) ON DELETE SET NULL,
  iso_clause text, -- '4.1','9.2','10.2'
  question_number integer,
  question text NOT NULL,
  expected_evidence text,
  answer text, -- 'DA','NE','N/A','DJELOMICNO'
  finding_type text, -- 'Sukladno','Nesukladnost_major','Nesukladnost_minor','Preporuka','Observation'
  finding_text text,
  evidence_attached jsonb DEFAULT '[]'::jsonb,
  ai_generated boolean DEFAULT false,
  ai_data_context jsonb, -- {nc_count: 23, capa_open: 5} — što je AI imao kao input
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_iso_checklist_audit ON iso_audit_checklist(audit_id);


-- ============================================================
-- 14. iso_audit_findings — formal nalazi (mogu otvoriti CAPA)
-- ============================================================
CREATE TABLE IF NOT EXISTS iso_audit_findings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid NOT NULL REFERENCES iso_audits(id) ON DELETE CASCADE,
  finding_number integer,
  iso_clause text,
  process_id uuid REFERENCES iso_processes(id) ON DELETE SET NULL,
  finding_type text NOT NULL, -- 'major','minor','observation','preporuka'
  description text NOT NULL,
  evidence text,
  capa_id uuid REFERENCES iso_capa(id) ON DELETE SET NULL,
  status text DEFAULT 'Otvoren', -- 'Otvoren','U_tijeku','Zatvoren'
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_iso_findings_audit ON iso_audit_findings(audit_id);
CREATE INDEX IF NOT EXISTS idx_iso_findings_status ON iso_audit_findings(status);

-- Sad možemo dodati FK iz iso_capa.audit_finding_id
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'iso_capa_audit_finding_fk'
  ) THEN
    ALTER TABLE iso_capa
      ADD CONSTRAINT iso_capa_audit_finding_fk
      FOREIGN KEY (audit_finding_id) REFERENCES iso_audit_findings(id) ON DELETE SET NULL;
  END IF;
END $$;


-- ============================================================
-- 15. iso_measuring_equipment — OB_14 Mjerna oprema (kalibracije)
-- ============================================================
CREATE TABLE IF NOT EXISTS iso_measuring_equipment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE, -- 'MJ-001'
  name text NOT NULL,
  description text,
  manufacturer text,
  model text,
  serial_number text,
  inventory_number text,
  location text,
  purchase_date date,
  -- kalibracija
  calibration_required boolean DEFAULT true,
  calibration_interval_months integer DEFAULT 12,
  last_calibration_date date,
  next_calibration_date date,
  calibration_certificate_path text, -- Storage path
  calibration_authority text, -- 'Ardenter d.o.o.'
  -- inspection (vatrogasni aparati, hidranti, posude pod tlakom)
  inspection_required boolean DEFAULT false,
  inspection_interval_months integer,
  last_inspection_date date,
  next_inspection_date date,
  inspection_certificate_path text,
  --
  responsible_employee_id uuid REFERENCES employees(id) ON DELETE SET NULL,
  status text DEFAULT 'Aktivan', -- 'Aktivan','U_kvaru','Povucen','Otpisan'
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_iso_equipment_calibration
  ON iso_measuring_equipment(next_calibration_date) WHERE status='Aktivan';
CREATE INDEX IF NOT EXISTS idx_iso_equipment_inspection
  ON iso_measuring_equipment(next_inspection_date) WHERE status='Aktivan';


-- ============================================================
-- 16. iso_supplier_evaluations — OB_10 auto-bodovanje
-- ============================================================
CREATE TABLE IF NOT EXISTS iso_supplier_evaluations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_name text NOT NULL,
  supplier_group text, -- 'dobavljac_sirovine','usluga_prijevoza','usluga_odrzavanja'
  year integer NOT NULL,
  -- auto-counted metrics:
  deliveries_count integer DEFAULT 0,
  complaints_count integer DEFAULT 0,
  late_deliveries_count integer DEFAULT 0,
  total_value_eur numeric,
  -- sustav predlozio (1-3):
  quality_score_auto integer CHECK (quality_score_auto BETWEEN 1 AND 3),
  time_score_auto integer CHECK (time_score_auto BETWEEN 1 AND 3),
  price_score_auto integer CHECK (price_score_auto BETWEEN 1 AND 3),
  -- finalna ocjena (PUK potvrdio):
  quality_score integer CHECK (quality_score BETWEEN 1 AND 3),
  time_score integer CHECK (time_score BETWEEN 1 AND 3),
  price_score integer CHECK (price_score BETWEEN 1 AND 3),
  total_score integer GENERATED ALWAYS AS (
    COALESCE(quality_score,0) + COALESCE(time_score,0) + COALESCE(price_score,0)
  ) STORED,
  classification text, -- 'A','B','C' ili 'zeleni','zuti','crveni'
  evaluator_employee_id uuid REFERENCES employees(id) ON DELETE SET NULL,
  signed_at timestamptz,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(supplier_name, year)
);


-- ============================================================
-- 17. iso_training_requirements + iso_employee_trainings — OB_07/08
-- ============================================================
CREATE TABLE IF NOT EXISTS iso_training_requirements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  description text,
  legal_reference text,
  applicable_positions text[],
  applicable_machine_types text[],
  validity_months integer DEFAULT 24,
  training_provider text,
  estimated_cost_eur numeric,
  active boolean DEFAULT true,
  notes text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS iso_employee_trainings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  training_requirement_id uuid REFERENCES iso_training_requirements(id) ON DELETE SET NULL,
  training_name text NOT NULL,
  completed_date date NOT NULL,
  valid_until date,
  trainer text,
  certificate_path text, -- Storage path
  certificate_number text,
  notes text,
  created_at timestamptz DEFAULT now(),
  created_by uuid REFERENCES prod_users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_iso_trainings_employee ON iso_employee_trainings(employee_id);
CREATE INDEX IF NOT EXISTS idx_iso_trainings_valid ON iso_employee_trainings(valid_until);


-- ============================================================
-- 18. iso_customer_complaints — reklamacije kupaca
-- ============================================================
CREATE TABLE IF NOT EXISTS iso_customer_complaints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_number text NOT NULL UNIQUE, -- 'REK-2026-001'
  complaint_date date NOT NULL,
  customer_id uuid REFERENCES prod_customers(id) ON DELETE SET NULL,
  customer_name text NOT NULL,
  contact_person text,
  contact_email text,
  -- kontekst
  work_order_number text,
  work_order_id uuid REFERENCES prod_work_orders(id) ON DELETE SET NULL,
  dispatch_number text,
  dispatch_id uuid REFERENCES prod_dispatch(id) ON DELETE SET NULL,
  article_id text,
  article_name text,
  delivery_date date,
  affected_quantity integer,
  -- opis
  description text NOT NULL,
  category text, -- 'kvaliteta','pucanje','kasnjenje','ostecenje','dimenzije','tisak','drugo'
  severity text DEFAULT 'minor',
  -- workflow
  status text NOT NULL DEFAULT 'Zaprimljena', -- 'Zaprimljena','U_obradi','Posjeta_planirana','Cekanje_kupca','Rijesena','Zatvorena','Otkazana'
  technical_visit_date date,
  resolution text,
  cost_estimated_eur numeric,
  cost_actual_eur numeric,
  -- linkage
  nc_id uuid REFERENCES iso_nonconformities(id) ON DELETE SET NULL,
  capa_id uuid REFERENCES iso_capa(id) ON DELETE SET NULL,
  attachments jsonb DEFAULT '[]'::jsonb,
  -- source
  source text DEFAULT 'rucno', -- 'rucno','email','telefon','drive_import'
  source_email_id text,
  --
  opened_by uuid REFERENCES prod_users(id) ON DELETE SET NULL,
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  closed_by uuid REFERENCES prod_users(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_iso_complaints_customer ON iso_customer_complaints(customer_id);
CREATE INDEX IF NOT EXISTS idx_iso_complaints_date ON iso_customer_complaints(complaint_date DESC);
CREATE INDEX IF NOT EXISTS idx_iso_complaints_status ON iso_customer_complaints(status);


-- ============================================================
-- 19. iso_management_reviews — OB_12 Ocjena uprave
-- ============================================================
CREATE TABLE IF NOT EXISTS iso_management_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_year integer NOT NULL UNIQUE,
  period_from date,
  period_to date,
  team_members jsonb, -- [{employee_id, role, name}]
  external_consultant_name text,
  -- structured inputs (ocjena 1/2/3/N + komentari po tocki)
  inputs jsonb, -- {a: {score: 3, notes: '...'}, b: {...}, c1: {...}, c2: {...}, c3: {...}, c4: {...}, c6: {...}, c7: {...}, d: {...}, e: {...}, f: {...}}
  outputs jsonb, -- akcijski plan + zaduzenja
  conclusions text,
  signed_by_management boolean DEFAULT false,
  signed_at timestamptz,
  signed_by uuid REFERENCES prod_users(id) ON DELETE SET NULL,
  report_path text,
  ai_draft_generated boolean DEFAULT false,
  ai_draft_generated_at timestamptz,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);


-- ============================================================
-- 20. iso_ai_outputs — Gemini cache + audit log
-- ============================================================
CREATE TABLE IF NOT EXISTS iso_ai_outputs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  feature text NOT NULL, -- 'audit_checklist','document_generator','rca','management_review','complaint_classify'
  prompt_hash text NOT NULL,
  prompt text NOT NULL,
  context_data jsonb,
  ai_provider text DEFAULT 'gemini',
  ai_model text,
  response text NOT NULL,
  tokens_used integer,
  duration_ms integer,
  used_in_table text,
  used_in_id uuid,
  user_id uuid REFERENCES prod_users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_iso_ai_hash ON iso_ai_outputs(prompt_hash);
CREATE INDEX IF NOT EXISTS idx_iso_ai_feature ON iso_ai_outputs(feature, created_at DESC);


-- ============================================================
-- RLS — enable + permissive policies (ko god se ulogira moze)
-- (konzistentno s ostalim tablicama u CARTA-ERP-u)
-- ============================================================
DO $$
DECLARE
  t text;
  iso_tables text[] := ARRAY[
    'iso_documents','iso_document_versions','iso_document_acknowledgements',
    'iso_processes','iso_quality_objectives','iso_quality_objective_results',
    'iso_nonconformities','iso_capa','iso_risks',
    'iso_audits','iso_audit_checklist','iso_audit_findings',
    'iso_measuring_equipment','iso_supplier_evaluations',
    'iso_training_requirements','iso_employee_trainings',
    'iso_customer_complaints','iso_management_reviews','iso_ai_outputs'
  ];
  pol_name text;
BEGIN
  FOREACH t IN ARRAY iso_tables LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    pol_name := t || '_all';
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', pol_name, t);
    EXECUTE format(
      'CREATE POLICY %I ON %I FOR ALL TO public USING (true) WITH CHECK (true)',
      pol_name, t
    );
  END LOOP;
END $$;


-- ============================================================
-- HELPER FUNCTIONS — auto-numbering
-- ============================================================
CREATE OR REPLACE FUNCTION iso_next_nc_number() RETURNS text AS $$
DECLARE
  yr integer := EXTRACT(YEAR FROM CURRENT_DATE);
  next_num integer;
BEGIN
  SELECT COALESCE(MAX((regexp_match(nc_number, '^NC-\d{4}-(\d+)$'))[1]::integer), 0) + 1
    INTO next_num
    FROM iso_nonconformities
    WHERE nc_number LIKE 'NC-' || yr || '-%';
  RETURN 'NC-' || yr || '-' || LPAD(next_num::text, 4, '0');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION iso_next_capa_number() RETURNS text AS $$
DECLARE
  yr integer := EXTRACT(YEAR FROM CURRENT_DATE);
  next_num integer;
BEGIN
  SELECT COALESCE(MAX((regexp_match(capa_number, '^CAPA-\d{4}-(\d+)$'))[1]::integer), 0) + 1
    INTO next_num
    FROM iso_capa
    WHERE capa_number LIKE 'CAPA-' || yr || '-%';
  RETURN 'CAPA-' || yr || '-' || LPAD(next_num::text, 4, '0');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION iso_next_audit_number() RETURNS text AS $$
DECLARE
  yr integer := EXTRACT(YEAR FROM CURRENT_DATE);
  next_num integer;
BEGIN
  SELECT COALESCE(MAX((regexp_match(audit_number, '^AUD-\d{4}-(\d+)$'))[1]::integer), 0) + 1
    INTO next_num
    FROM iso_audits
    WHERE audit_number LIKE 'AUD-' || yr || '-%';
  RETURN 'AUD-' || yr || '-' || LPAD(next_num::text, 2, '0');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION iso_next_complaint_number() RETURNS text AS $$
DECLARE
  yr integer := EXTRACT(YEAR FROM CURRENT_DATE);
  next_num integer;
BEGIN
  SELECT COALESCE(MAX((regexp_match(complaint_number, '^REK-\d{4}-(\d+)$'))[1]::integer), 0) + 1
    INTO next_num
    FROM iso_customer_complaints
    WHERE complaint_number LIKE 'REK-' || yr || '-%';
  RETURN 'REK-' || yr || '-' || LPAD(next_num::text, 3, '0');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION iso_next_risk_number() RETURNS text AS $$
DECLARE
  yr integer := EXTRACT(YEAR FROM CURRENT_DATE);
  next_num integer;
BEGIN
  SELECT COALESCE(MAX((regexp_match(risk_number, '^R-\d{4}-(\d+)$'))[1]::integer), 0) + 1
    INTO next_num
    FROM iso_risks
    WHERE risk_number LIKE 'R-' || yr || '-%';
  RETURN 'R-' || yr || '-' || LPAD(next_num::text, 3, '0');
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- TRIGGER: auto-NC kad je rola otpisana
-- ============================================================
CREATE OR REPLACE FUNCTION fn_iso_nc_from_roll_otpis()
RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'Otpisano' AND (OLD.status IS NULL OR OLD.status <> 'Otpisano') THEN
    INSERT INTO iso_nonconformities (
      nc_number, occurred_at, source_type, source_table, source_id,
      category, severity, supplier_name, description, status, auto_generated
    ) VALUES (
      iso_next_nc_number(),
      now(),
      'rola_otpis',
      'prod_inventory_rolls',
      NEW.id,
      'repromaterijal',
      CASE
        WHEN COALESCE(NEW.initial_weight_kg, 0) >= 500 THEN 'major'
        ELSE 'minor'
      END,
      NEW.manufacturer,
      'Rola ' || COALESCE(NEW.roll_code, '?') ||
        ' (' || COALESCE(NEW.manufacturer, '?') || ', ' ||
        COALESCE(NEW.initial_weight_kg::text, '?') || ' kg, ' ||
        COALESCE(NEW.paper_type, '?') || ') otpisana.' ||
        COALESCE(' Razlog: ' || NEW.notes, ''),
      'Otvoreno',
      true
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_iso_nc_from_roll_otpis ON prod_inventory_rolls;
CREATE TRIGGER trg_iso_nc_from_roll_otpis
  AFTER UPDATE OF status ON prod_inventory_rolls
  FOR EACH ROW EXECUTE FUNCTION fn_iso_nc_from_roll_otpis();


-- ============================================================
-- TRIGGER: auto-NC kad je prijavljen veci kvar (prod_failure_reports)
-- ============================================================
CREATE OR REPLACE FUNCTION fn_iso_nc_from_failure()
RETURNS trigger AS $$
BEGIN
  -- Samo prioritetni kvarovi ili dugi zastoji idu u NC log
  IF (NEW.priority = 'high' OR COALESCE(NEW.downtime_minutes, 0) >= 60) THEN
    INSERT INTO iso_nonconformities (
      nc_number, occurred_at, source_type, source_table, source_id,
      category, severity, description, status, auto_generated
    ) VALUES (
      iso_next_nc_number(),
      COALESCE(NEW.reported_at, now()),
      'stroj_kvar',
      'prod_failure_reports',
      NEW.id,
      'odrzavanje',
      CASE WHEN COALESCE(NEW.downtime_minutes, 0) >= 240 THEN 'major' ELSE 'minor' END,
      'Kvar stroja ' || COALESCE(NEW.machine_name, NEW.machine_code) ||
        ' (prijava ' || COALESCE(NEW.report_number, '?') || '): ' || NEW.description ||
        '. Trajanje zastoja: ' || COALESCE(NEW.downtime_minutes::text, '?') || ' min.',
      'Otvoreno',
      true
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_iso_nc_from_failure ON prod_failure_reports;
CREATE TRIGGER trg_iso_nc_from_failure
  AFTER INSERT ON prod_failure_reports
  FOR EACH ROW EXECUTE FUNCTION fn_iso_nc_from_failure();


-- ============================================================
-- VIEW: v_iso_pregled — dashboard semafori
-- ============================================================
CREATE OR REPLACE VIEW v_iso_pregled AS
SELECT
  (SELECT COUNT(*) FROM iso_nonconformities WHERE status='Otvoreno') AS otvoreni_nc,
  (SELECT COUNT(*) FROM iso_nonconformities
    WHERE status NOT IN ('Zatvoreno','Otkazano')
    AND severity='major') AS otvoreni_major,
  (SELECT COUNT(*) FROM iso_nonconformities
    WHERE status='Otvoreno' AND auto_generated=true AND reviewed_at IS NULL) AS auto_nc_za_review,
  (SELECT COUNT(*) FROM iso_capa
    WHERE status NOT IN ('Zatvoreno','Otkazano')
    AND due_date < CURRENT_DATE) AS overdue_capa,
  (SELECT COUNT(*) FROM iso_capa
    WHERE status NOT IN ('Zatvoreno','Otkazano')) AS otvoreni_capa,
  (SELECT COUNT(*) FROM iso_documents WHERE status='Published') AS aktivni_dokumenti,
  (SELECT COUNT(*) FROM iso_documents
    WHERE status='Published'
    AND next_review_date <= CURRENT_DATE + INTERVAL '30 days') AS dokumenti_za_review,
  (SELECT COUNT(*) FROM iso_measuring_equipment
    WHERE status='Aktivan'
    AND next_calibration_date <= CURRENT_DATE + INTERVAL '30 days') AS oprema_kalibracija_uskoro,
  (SELECT COUNT(*) FROM iso_measuring_equipment
    WHERE status='Aktivan'
    AND next_inspection_date <= CURRENT_DATE + INTERVAL '30 days') AS oprema_inspekcija_uskoro,
  (SELECT COUNT(*) FROM iso_employee_trainings
    WHERE valid_until <= CURRENT_DATE + INTERVAL '60 days'
    AND valid_until > CURRENT_DATE) AS osposobljavanja_isteci_60d,
  (SELECT COUNT(*) FROM iso_employee_trainings
    WHERE valid_until <= CURRENT_DATE) AS osposobljavanja_isteklo,
  (SELECT COUNT(*) FROM iso_audits
    WHERE status NOT IN ('Zatvoren','Otkazan')) AS aktivni_auditi,
  (SELECT COUNT(*) FROM iso_audits
    WHERE status='Planiran' AND planned_date <= CURRENT_DATE + INTERVAL '60 days') AS auditi_uskoro,
  (SELECT COUNT(*) FROM iso_customer_complaints
    WHERE status NOT IN ('Rijesena','Zatvorena','Otkazana')) AS otvorene_reklamacije,
  (SELECT COUNT(*) FROM iso_risks WHERE score >= 6 AND status='Aktivan') AS visoki_rizici,
  (SELECT text_value FROM settings WHERE key='iso_next_external_audit_date') AS next_external_audit;


-- ============================================================
-- ISO settings defaults
-- ============================================================
-- Text settings (value=0 jer je NOT NULL constraint)
INSERT INTO settings (key, value, text_value, category, description) VALUES
  ('iso_predsjednica_uprave_employee_id', 0, NULL, 'ISO_9001', 'Employee ID predsjednice uprave (potpisuje politiku, ocjenu uprave)'),
  ('iso_puk_employee_id', 0, NULL, 'ISO_9001', 'Employee ID Predstavnika Uprave za Kvalitetu (PUK) - operativno vodi sustav'),
  ('iso_voditelj_kontrolinga_employee_id', 0, NULL, 'ISO_9001', 'Employee ID voditelja kontrolinga'),
  ('iso_external_consultant_name', 0, 'Krunoslav Matočec', 'ISO_9001', 'Ime vanjskog ISO konzultanta'),
  ('iso_external_consultant_email', 0, NULL, 'ISO_9001', 'Email vanjskog konzultanta (rezervirano za buducu read-only rolu)'),
  ('iso_certifikator', 0, NULL, 'ISO_9001', 'Naziv certifikacijskog tijela (TUV NORD, Bureau Veritas...)'),
  ('iso_certifikat_broj', 0, NULL, 'ISO_9001', 'Broj ISO 9001 certifikata'),
  ('iso_certifikat_vrijedi_do', 0, NULL, 'ISO_9001', 'Datum isteka certifikata (YYYY-MM-DD)'),
  ('iso_next_external_audit_date', 0, '2026-09-15', 'ISO_9001', 'Datum sljedeceg eksternog nadzornog audita (YYYY-MM-DD)'),
  ('iso_politika_kvalitete_revision_date', 0, '2019-10-30', 'ISO_9001', 'Datum zadnje revizije Politike kvalitete')
ON CONFLICT (key) DO NOTHING;

-- Numeric settings
INSERT INTO settings (key, value, category, description) VALUES
  ('iso_skart_threshold_pct', 3.0, 'ISO_9001', 'Postotak skarta iznad kojeg se smjenski izvjestaj flag-uje kao NC kandidat'),
  ('iso_kvar_min_minutes', 60, 'ISO_9001', 'Minimalno trajanje kvara (min) za auto-NC iz prod_failure_reports'),
  ('iso_kvar_major_minutes', 240, 'ISO_9001', 'Trajanje kvara (min) iznad kojeg je severity=major'),
  ('iso_doc_review_default_months', 12, 'ISO_9001', 'Default frekvencija pregleda dokumenata (mjeseci)'),
  ('iso_capa_default_due_days', 30, 'ISO_9001', 'Default rok za izvrsenje CAPA (dana od otvaranja)'),
  ('iso_audit_alert_days_before', 60, 'ISO_9001', 'Koliko dana prije internog audita pocinju alerti')
ON CONFLICT (key) DO NOTHING;


-- ============================================================
-- DEFAULT iso_processes (iz OB_20 Carta dokumenta)
-- ============================================================
INSERT INTO iso_processes (code, name, owner_role, inputs, outputs, measurement_frequency, measurement_method) VALUES
  ('1.2', 'Vođenje', 'Predsjednica uprave',
    'Pregled poslovnih rezultata za prethodno razdoblje, Izvještaj o ocjeni uprave',
    'Ciljevi za poslovnu godinu', 'Mjesečno', 'Analiza poslovanja'),
  ('1.3', 'Upravljanje kvalitetom', 'PUK',
    'Ciljevi tvrtke, Zapisi o reklamacijama, Zapisi o provedenom internom auditu',
    'Zapis o ocjeni sustava, Ciljevi za plansko razdoblje, Analiza zadovoljstva kupaca',
    'Polugodišnje', 'Analiza ciljeva'),
  ('4', 'Nuđenje/Ugovaranje', 'Predsjednica uprave / Voditelj prodaje',
    'Upit kupca, Natječaj, Narudžba kupca',
    'Ponuda/Predračun, Ponudbena dokumentacija',
    'Polugodišnje', 'Analiza prolaznosti ponuda'),
  ('5', 'Nabava', 'Član uprave za nabavu, logistiku i proizvodnju',
    'Narudžbenica, Ugovor, Obavijest o dobivenom natječaju, Zalihe na skladištu, Potrebe',
    'Potvrda narudžbe, Potpisan ugovor, Nabavljeni repromaterijal',
    'Polugodišnje', 'Analiza kašnjenja i nesukladnosti'),
  ('6', 'Priprema proizvodnje', 'Voditelj proizvodnje',
    'Narudžbenica, Ugovor, Specifikacija kupca, nacrt, Otvoreni RN, uzorci',
    'Pripremljena oprema, strojevi, proizvodna traka, ulazni materijali',
    'Polugodišnje', 'Analiza isporuka u roku'),
  ('7', 'Proizvodnja', 'Voditelj proizvodnje',
    'Narudžbenica, Specifikacija kupca, Otvoreni RN, Softver',
    'Zatvoreni radni nalog, Otpremnica, Isporučena roba',
    'Godišnje', 'Analiza nesukladnosti od ukupnog broja narudžbi'),
  ('8', 'Kontroling i opći poslovi (HRM)', 'Back Office Manager',
    'Zakonodavni okvir, podaci i potvrde zaposlenih, ulazni računi',
    'Ugovori o radu, obračuni plaća, Financijski planovi i izvještaji, arhivirani dokumenti',
    'Polugodišnje', 'Analiza grešaka u kontrolingu'),
  ('9', 'Administracija', 'Radnici u administraciji',
    'Ulazno-izlazna pošta, Ulazni računi, primke, otpremnice, izlazni računi',
    'Distribuirana pošta, Plan obuke, Realizirana obuka, Zaposleni novi djelatnici',
    'Godišnje', 'Analiza ostvarenja plana obuke'),
  ('10', 'Skladištenje', 'Skladištar',
    'Otpremnice i ulazni računi, izdatnice i otpremnice sa skladišta',
    'Skladišne evidencije, otpremnice, izdatnice',
    'Godišnje', 'Analiza zastoja u proizvodnji uzrokovanih skladištem'),
  ('11', 'Održavanje', 'Voditelj proizvodnje',
    'Kvar na opremi, strojevima, alatu, Kvar na infrastrukturi',
    'Otklonjen kvar, Provedeno redovito održavanje',
    'Godišnje', 'Analiza sati zastoja zbog kvara')
ON CONFLICT (code) DO NOTHING;


-- ============================================================
-- DEFAULT iso_quality_objectives (KPI ciljevi za 2026 - autoizracun)
-- (Projektni ciljevi se rucno unose iz OB_06 - 27+ stavki)
-- ============================================================
INSERT INTO iso_quality_objectives
  (year, objective_type, name, description, target_value, target_unit, target_direction, measurement_frequency, kpi_query_name, active)
VALUES
  (2026, 'KPI', 'Postotak isporuka u roku',
    'Postotak otpremljenih narudžbi prije ili na ugovoreni rok isporuke',
    95.0, '%', 'higher_better', 'monthly', 'kpi_isporuka_u_roku_pct', true),
  (2026, 'KPI', 'Postotak nesukladnosti od narudžbi',
    'Broj reklamacija/nesukladnosti / ukupan broj narudžbi',
    1.0, '%', 'lower_better', 'monthly', 'kpi_nc_pct_od_narudzbi', true),
  (2026, 'KPI', 'Sati zastoja zbog kvara (% od fonda sati)',
    'Ukupno trajanje zastoja zbog kvara stroja / fond sati',
    2.0, '%', 'lower_better', 'monthly', 'kpi_zastoj_kvar_pct', true),
  (2026, 'KPI', 'Prolaznost ponuda',
    'Postotak prihvaćenih ponuda od ukupno poslanih',
    50.0, '%', 'higher_better', 'quarterly', 'kpi_prolaznost_ponuda_pct', true),
  (2026, 'KPI', 'Ostvarenje plana stručnog osposobljavanja',
    'Postotak provedenih treninga prema godišnjem planu',
    90.0, '%', 'higher_better', 'quarterly', 'kpi_osposobljavanje_pct', true),
  (2026, 'KPI', 'Postotak škarta',
    'Težina škarta / ukupno proizvedeno (kg)',
    1.0, '%', 'lower_better', 'monthly', 'kpi_skart_pct', true),
  (2026, 'KPI', 'OEE prosjek (NLI + WH)',
    'Prosječan OEE preko obje linije',
    70.0, '%', 'higher_better', 'monthly', 'kpi_oee_prosjek', true),
  (2026, 'KPI', 'Broj kašnjenja u nabavi',
    'Broj isporuka dobavljača koje su kasnile (subjektivno kašnjenje)',
    0, 'kom', 'lower_better', 'quarterly', 'kpi_kasnjenja_nabava', true),
  (2026, 'KPI', 'Broj otvorenih CAPA past due',
    'Broj CAPA koje su prošle due_date a nisu zatvorene',
    0, 'kom', 'lower_better', 'monthly', 'kpi_capa_overdue', true)
ON CONFLICT DO NOTHING;


-- ============================================================
-- ISO 9001 DOZVOLE — dodavanje u prod_roles
-- ============================================================
DO $$
DECLARE
  iso_perms_full text[] := ARRAY[
    'iso-pregled', 'iso-dokumenti', 'iso-nesukladnosti', 'iso-capa',
    'iso-ciljevi', 'iso-procesi', 'iso-rizici', 'iso-auditi',
    'iso-dobavljaci', 'iso-osposobljavanje', 'iso-mjerna-oprema',
    'iso-reklamacije', 'iso-ocjena-uprave'
  ];
  iso_perms_racunovodstvo text[] := ARRAY[
    'iso-pregled','iso-dokumenti','iso-ciljevi','iso-ocjena-uprave','iso-osposobljavanje'
  ];
  iso_perms_voditelj_odrzavanja text[] := ARRAY[
    'iso-pregled','iso-mjerna-oprema','iso-nesukladnosti','iso-capa','iso-rizici','iso-dokumenti'
  ];
  iso_perms_koordinator_proizvodnje text[] := ARRAY[
    'iso-pregled','iso-nesukladnosti','iso-capa','iso-procesi','iso-ciljevi',
    'iso-rizici','iso-reklamacije','iso-dokumenti','iso-mjerna-oprema'
  ];
  iso_perms_koordinator_odrzavanja text[] := ARRAY[
    'iso-pregled','iso-mjerna-oprema','iso-nesukladnosti','iso-capa','iso-rizici',
    'iso-dokumenti','iso-osposobljavanje'
  ];
  -- helper za dedup merge u JSONB array
  merged jsonb;
  rec record;
BEGIN
  -- admin: sve ISO dozvole
  FOR rec IN SELECT id, dozvole FROM prod_roles WHERE naziv = 'admin' LOOP
    SELECT jsonb_agg(DISTINCT v)
      INTO merged
      FROM (
        SELECT jsonb_array_elements_text(COALESCE(rec.dozvole, '[]'::jsonb))::text AS v
        UNION
        SELECT unnest(iso_perms_full)
      ) sub;
    UPDATE prod_roles SET dozvole = merged WHERE id = rec.id;
  END LOOP;

  -- uprava: sve ISO dozvole
  FOR rec IN SELECT id, dozvole FROM prod_roles WHERE naziv = 'uprava' LOOP
    SELECT jsonb_agg(DISTINCT v)
      INTO merged
      FROM (
        SELECT jsonb_array_elements_text(COALESCE(rec.dozvole, '[]'::jsonb))::text AS v
        UNION
        SELECT unnest(iso_perms_full)
      ) sub;
    UPDATE prod_roles SET dozvole = merged WHERE id = rec.id;
  END LOOP;

  -- racunovodstvo
  FOR rec IN SELECT id, dozvole FROM prod_roles WHERE naziv = 'racunovodstvo' LOOP
    SELECT jsonb_agg(DISTINCT v)
      INTO merged
      FROM (
        SELECT jsonb_array_elements_text(COALESCE(rec.dozvole, '[]'::jsonb))::text AS v
        UNION
        SELECT unnest(iso_perms_racunovodstvo)
      ) sub;
    UPDATE prod_roles SET dozvole = merged WHERE id = rec.id;
  END LOOP;

  -- voditelj-odrzavanja
  FOR rec IN SELECT id, dozvole FROM prod_roles WHERE naziv = 'voditelj-odrzavanja' LOOP
    SELECT jsonb_agg(DISTINCT v)
      INTO merged
      FROM (
        SELECT jsonb_array_elements_text(COALESCE(rec.dozvole, '[]'::jsonb))::text AS v
        UNION
        SELECT unnest(iso_perms_voditelj_odrzavanja)
      ) sub;
    UPDATE prod_roles SET dozvole = merged WHERE id = rec.id;
  END LOOP;

  -- koordinator-proizvodnje
  FOR rec IN SELECT id, dozvole FROM prod_roles WHERE naziv = 'koordinator-proizvodnje' LOOP
    SELECT jsonb_agg(DISTINCT v)
      INTO merged
      FROM (
        SELECT jsonb_array_elements_text(COALESCE(rec.dozvole, '[]'::jsonb))::text AS v
        UNION
        SELECT unnest(iso_perms_koordinator_proizvodnje)
      ) sub;
    UPDATE prod_roles SET dozvole = merged WHERE id = rec.id;
  END LOOP;

  -- koordinator-odrzavanja - kreiraj ako ne postoji, inace update
  IF NOT EXISTS (SELECT 1 FROM prod_roles WHERE naziv = 'koordinator-odrzavanja') THEN
    INSERT INTO prod_roles (naziv, opis, dozvole, aktivan)
    VALUES (
      'koordinator-odrzavanja',
      'Koordinator održavanja - održavanje + ISO moduli održavanja i kvalitete',
      to_jsonb(ARRAY['dashboard','maintenance','skladiste','oee'] || iso_perms_koordinator_odrzavanja),
      true
    );
  ELSE
    FOR rec IN SELECT id, dozvole FROM prod_roles WHERE naziv = 'koordinator-odrzavanja' LOOP
      SELECT jsonb_agg(DISTINCT v)
        INTO merged
        FROM (
          SELECT jsonb_array_elements_text(COALESCE(rec.dozvole, '[]'::jsonb))::text AS v
          UNION
          SELECT unnest(iso_perms_koordinator_odrzavanja)
        ) sub;
      UPDATE prod_roles SET dozvole = merged WHERE id = rec.id;
    END LOOP;
  END IF;
END $$;


-- ============================================================
-- KRAJ MIGRACIJE — provjera
-- ============================================================
DO $$
DECLARE
  table_count integer;
BEGIN
  SELECT COUNT(*) INTO table_count
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name LIKE 'iso\_%' ESCAPE '\';
  RAISE NOTICE 'ISO 9001 schema v1 instalirana. Broj iso_ tablica: %', table_count;
END $$;
