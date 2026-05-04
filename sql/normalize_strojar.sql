-- ============================================================================
-- Normalizacija strojar imena u prod_shift_reports
-- ============================================================================
-- Razlog: 53 varijante za 18 stvarnih strojara — tipfeleri (Č/C, Š/S),
-- redoslijed (Marić Josip vs Josip Marić), prefiksi "-", "_", kombinirani
-- unosi pri zamjeni ("M. Kamenicki / V. Varga"), vrijeme oznake.
--
-- Plan:
--  1. Funkcija f_normalize_strojar(text) — vraća kanonsko ime ili NULL
--  2. Trigger BEFORE INSERT/UPDATE na prod_shift_reports.strojar
--  3. Backfill postojećih podataka
--
-- Logika funkcije:
--  - Strip leading "-" / "_"
--  - Split by "/" ili "," — uzmi prvog (kombinirani unos = primarni strojar)
--  - Ukloni vrijeme oznake (" 06:00-18:00", " (18-06)")
--  - Trim, collapse spaces
--  - ASCII-fold (Č→C, Š→S, Ž→Z) + uppercase za matching
--  - Lookup u alias mapping na kanonsko ime iz employees tablice
--  - Fallback: INITCAP (rijetki neviđeni unosi)
-- ============================================================================

CREATE OR REPLACE FUNCTION f_normalize_strojar(p_text TEXT) RETURNS TEXT AS $$
WITH s1 AS (
  SELECT REGEXP_REPLACE(COALESCE(p_text, ''), '^[-_]+\s*', '') AS x
), s2 AS (
  SELECT SPLIT_PART(SPLIT_PART(x, '/', 1), ',', 1) AS x FROM s1
), s3 AS (
  SELECT REGEXP_REPLACE(
    x, '\s*\(?\d{1,2}[:.]?\d{0,2}\s*[-–—]\s*\d{1,2}[:.]?\d{0,2}\)?', '', 'g'
  ) AS x FROM s2
), s4 AS (
  SELECT TRIM(REGEXP_REPLACE(x, '\s+', ' ', 'g')) AS x FROM s3
), s5 AS (
  SELECT x, UPPER(TRANSLATE(x, 'ČĆŠŽĐčćšžđ', 'CCSZDccszd')) AS xn FROM s4
)
SELECT CASE
  WHEN x IS NULL OR x IN ('', '-', '_', '?', '/') THEN NULL
  WHEN xn IN ('MARKO KAMENICKI', 'M. KAMENICKI', 'M.KAMENICKI', 'KAMENICKI MARKO', 'KAMENICKI M.', 'KAMENICKI M', 'KAMENICKI') THEN 'Marko Kamenicki'
  WHEN xn IN ('VALENTIN VARGA', 'V. VARGA', 'V.VARGA', 'V. VARG', 'V.VARG', 'VARGA VALENTIN', 'VARGA V.', 'VARGA V', 'VARGA') THEN 'Valentin Varga'
  WHEN xn IN ('ANDREJ MERKAS', 'MERKAS ANDREJ', 'A. MERKAS', 'A.MERKAS', 'MERKAS A.', 'MERKAS A', 'MERKAS') THEN 'Andrej Merkaš'
  WHEN xn IN ('VEDRAN POPIC', 'VEDRAN P', 'VEDRAN P.', 'V. POPIC', 'V.POPIC', 'POPIC VEDRAN', 'POPIC V.', 'POPIC V', 'POPIC') THEN 'Vedran Popić'
  WHEN xn IN ('DRAGO POPOVIC', 'D. POPOVIC', 'D.POPOVIC', 'POPOVIC DRAGO', 'POPOVIC D.', 'POPOVIC D') THEN 'Drago Popović'
  WHEN xn IN ('HRVOJE ANDRAKOVIC', 'ANDRAKOVIC', 'H. ANDRAKOVIC', 'H.ANDRAKOVIC', 'ANDRAKOVIC HRVOJE', 'ANDRAKOVIC H.', 'ANDRAKOVIC H') THEN 'Hrvoje Andraković'
  WHEN xn IN ('STJEPAN GRGURIC', 'GRGURIC', 'GRGURIC STJEPAN', 'S. GRGURIC', 'S.GRGURIC', 'GRGURIC S.', 'GRGURIC S') THEN 'Stjepan Grgurić'
  WHEN xn IN ('ZORAN KOVAC', 'KOVAC ZORAN', 'Z. KOVAC', 'Z.KOVAC', 'KOVAC Z.', 'KOVAC Z', 'KOVAC') THEN 'Zoran Kovač'
  WHEN xn IN ('DOMINIK VIDINOVIC', 'VIDINOVIC DOMINIK', 'D. VIDINOVIC', 'D.VIDINOVIC', 'VIDINOVIC D.', 'VIDINOVIC D', 'VIDINOVIC') THEN 'Dominik Vidinović'
  WHEN xn IN ('MATEJ GALUNIC', 'GALUNIC MATEJ', 'M. GALUNIC', 'M.GALUNIC', 'GALUNIC M.', 'GALUNIC M', 'GALUNIC') THEN 'Matej Galunić'
  WHEN xn IN ('MATEJ BUDES', 'BUDES MATEJ', 'M. BUDES', 'M.BUDES', 'BUDES M.', 'BUDES M', 'BUDES') THEN 'Matej Budeš'
  WHEN xn IN ('ZORAN KUKIC', 'KUKIC ZORAN', 'Z. KUKIC', 'Z.KUKIC', 'KUKIC Z.', 'KUKIC Z', 'KUKIC') THEN 'Zoran Kukić'
  WHEN xn IN ('JOSIP LONCARIC', 'LONCARIC JOSIP', 'J. LONCARIC', 'J.LONCARIC', 'LONCARIC J.', 'LONCARIC J', 'LONCARIC') THEN 'Josip Lončarić'
  WHEN xn IN ('JOSIP MARIC', 'MARIC JOSIP', 'J. MARIC', 'J.MARIC', 'MARIC J.', 'MARIC J') THEN 'Josip Marić'
  WHEN xn IN ('SLAVKO VUGEC', 'VUGEC SLAVKO', 'S. VUGEC', 'S.VUGEC', 'VUGEC S.', 'VUGEC S', 'VUGEC') THEN 'Slavko Vugec'
  WHEN xn IN ('LJUBICA MUSIC', 'MUSIC LJUBICA', 'L. MUSIC', 'L.MUSIC', 'MUSIC L.', 'MUSIC L', 'MUSIC') THEN 'Ljubica Musić'
  WHEN xn IN ('DINO MILJATOVIC', 'MILJATOVIC DINO', 'D. MILJATOVIC', 'D.MILJATOVIC', 'MILJATOVIC D.', 'MILJATOVIC D') THEN 'Dino Miljatović'
  WHEN xn IN ('DRAGANA MIODANIC', 'MIODANIC DRAGANA', 'D. MIODANIC', 'MIODANIC D.', 'MIODANIC D') THEN 'Dragana Miodanić'
  WHEN xn IN ('BRANIMIR KOMIC', 'KOMIC BRANIMIR', 'B. KOMIC', 'B.KOMIC', 'KOMIC B.', 'KOMIC B', 'KOMIC') THEN 'Branimir Komić'
  WHEN xn IN ('BRUNO ZIVKOVIC', 'ZIVKOVIC BRUNO', 'B. ZIVKOVIC', 'ZIVKOVIC B.') THEN 'Bruno Živković'
  WHEN xn IN ('DAMIR KAPETINIC', 'KAPETINIC DAMIR', 'D. KAPETINIC', 'KAPETINIC D.') THEN 'Damir Kapetinić'
  WHEN xn IN ('DANIJEL MRKSIC', 'MRKSIC DANIJEL', 'D. MRKSIC', 'MRKSIC D.') THEN 'Danijel Mrkšić'
  WHEN xn IN ('DRAGAN JERKOVIC', 'JERKOVIC DRAGAN', 'D. JERKOVIC', 'JERKOVIC D.') THEN 'Dragan Jerković'
  WHEN xn IN ('JOSIP ERVACIC', 'ERVACIC JOSIP', 'J. ERVACIC', 'ERVACIC J.') THEN 'Josip Ervačić'
  WHEN xn IN ('IVAN PARLOV', 'PARLOV IVAN', 'I. PARLOV', 'PARLOV I.') THEN 'Ivan Parlov'
  WHEN xn IN ('IVAN SCHRODEL', 'SCHRODEL IVAN', 'I. SCHRODEL', 'SCHRODEL I.') THEN 'Ivan Schrödel'
  WHEN xn IN ('MIHAEL ZIVKOVIC', 'ZIVKOVIC MIHAEL', 'M. ZIVKOVIC', 'ZIVKOVIC M.') THEN 'Mihael Živković'
  WHEN xn IN ('RADOS RABRENOVIC', 'RABRENOVIC RADOS', 'R. RABRENOVIC', 'RABRENOVIC R.') THEN 'Radoš Rabrenović'
  ELSE INITCAP(LOWER(x))
END
FROM s5;
$$ LANGUAGE SQL IMMUTABLE;

COMMENT ON FUNCTION f_normalize_strojar IS
  'Normalizira strojar input: trim leading -, split kombinirane na "/" ili "," (uzmi prvog), ukloni vrijeme oznake, ASCII-fold za matching, mapping na kanonsko ime iz employees tablice.';

-- ============================================================================
-- Trigger: auto-normalizacija na svaki INSERT/UPDATE
-- ============================================================================
CREATE OR REPLACE FUNCTION f_trg_normalize_strojar() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.strojar IS NOT NULL THEN
    NEW.strojar := f_normalize_strojar(NEW.strojar);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_normalize_strojar ON prod_shift_reports;
CREATE TRIGGER trg_normalize_strojar
  BEFORE INSERT OR UPDATE OF strojar ON prod_shift_reports
  FOR EACH ROW
  EXECUTE FUNCTION f_trg_normalize_strojar();

COMMENT ON TRIGGER trg_normalize_strojar ON prod_shift_reports IS
  'Auto-normalizacija strojar imena pri svakom upisu (sprečava duplikate od typo-a, kombiniranih unosa, varijacija).';

-- ============================================================================
-- Backfill (jednom)
-- ============================================================================
-- UPDATE prod_shift_reports SET strojar = f_normalize_strojar(strojar)
-- WHERE strojar IS DISTINCT FROM f_normalize_strojar(strojar);
