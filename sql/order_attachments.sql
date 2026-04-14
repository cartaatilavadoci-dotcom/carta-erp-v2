-- ============================================================
-- ORDER ATTACHMENTS (narudzbenice, test punjenja, itd.)
-- Datum: 2026-04-14
-- ============================================================
-- Dodaje privitke na narudžbe u Planiranje modul.
--
-- Use cases:
--   1. Narudžbenica (PDF/Excel) - original dokument od kupca, za
--      kontrolu je li kolega ispravno upisao narudžbu
--   2. Test punjenja (PDF) - rezultati testa, za pripremu RN-a s
--      eventualnim izmjenama
--   3. Ostalo - slike, napomene, specifikacije, dogovori
--
-- Priprema i za buduću AI integraciju: AI agent može dohvatiti
-- PDF i usporediti s parsiranom narudžbom u DB-u.
-- ============================================================

-- ----- Storage bucket (privatan, Supabase signed URL za read) -----
INSERT INTO storage.buckets (id, name, public)
VALUES ('order-attachments', 'order-attachments', false)
ON CONFLICT (id) DO NOTHING;

-- ----- Metadata tablica -----
CREATE TABLE IF NOT EXISTS prod_order_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES prod_orders(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('narudzbenica', 'test_punjenja', 'ostalo')),
  file_path TEXT NOT NULL,          -- puni path u bucketu (npr. "orders/<order_id>/<uuid>.pdf")
  file_name TEXT NOT NULL,          -- originalno ime koje je korisnik uploada-o
  file_size INTEGER,                -- bytes
  mime_type TEXT,
  note TEXT,                        -- opcionalna napomena ("v2", "izmjena kolor", ...)
  uploaded_by TEXT,                 -- ime korisnika
  uploaded_by_user_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_order_attach_order_id ON prod_order_attachments(order_id);
CREATE INDEX IF NOT EXISTS idx_order_attach_kind ON prod_order_attachments(kind);

COMMENT ON TABLE prod_order_attachments IS
  'Privici narudžbe: PDF narudžbenica, test punjenja, ostalo. Datoteke u storage.order-attachments bucket-u.';

-- ----- RLS -----
ALTER TABLE prod_order_attachments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for authenticated" ON prod_order_attachments;
CREATE POLICY "Allow all for authenticated" ON prod_order_attachments
  FOR ALL USING (true) WITH CHECK (true);

-- ----- Storage RLS (bucket je private, ali autentificirani imaju sve ovlasti) -----
DROP POLICY IF EXISTS "Anyone can upload to order-attachments" ON storage.objects;
CREATE POLICY "Anyone can upload to order-attachments" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'order-attachments');

DROP POLICY IF EXISTS "Anyone can read order-attachments" ON storage.objects;
CREATE POLICY "Anyone can read order-attachments" ON storage.objects
  FOR SELECT USING (bucket_id = 'order-attachments');

DROP POLICY IF EXISTS "Anyone can delete order-attachments" ON storage.objects;
CREATE POLICY "Anyone can delete order-attachments" ON storage.objects
  FOR DELETE USING (bucket_id = 'order-attachments');
