-- ============================================================
-- CARTA ERP - Analiza strukture baze podataka
-- Datum: 2026-04-02
-- Svrha: Pregled svih tablica, kolona, RPC funkcija, viewova
-- ============================================================
-- NAPOMENA: Pokreni svaki upit ZASEBNO u Supabase SQL Editoru
-- i kopiraj rezultate nazad
-- ============================================================


-- ============================================================
-- 1. SVE TABLICE - popis s brojem kolona i procijenjenim redovima
-- ============================================================
SELECT
  t.table_name,
  COUNT(c.column_name) AS broj_kolona,
  pg_stat.n_live_tup AS procijenjeni_redovi,
  obj_description((t.table_schema || '.' || t.table_name)::regclass) AS komentar
FROM information_schema.tables t
JOIN information_schema.columns c
  ON c.table_schema = t.table_schema AND c.table_name = t.table_name
LEFT JOIN pg_stat_user_tables pg_stat
  ON pg_stat.relname = t.table_name
WHERE t.table_schema = 'public'
  AND t.table_type = 'BASE TABLE'
GROUP BY t.table_name, pg_stat.n_live_tup, t.table_schema
ORDER BY t.table_name;


-- ============================================================
-- 2. SVE KOLONE - detalji po tablici (tipovi, defaulti, nullable)
-- ============================================================
SELECT
  c.table_name,
  c.ordinal_position AS rbr,
  c.column_name,
  c.data_type,
  c.udt_name,
  c.character_maximum_length,
  c.numeric_precision,
  c.is_nullable,
  c.column_default,
  c.is_generated,
  c.generation_expression
FROM information_schema.columns c
JOIN information_schema.tables t
  ON t.table_schema = c.table_schema AND t.table_name = c.table_name
WHERE c.table_schema = 'public'
  AND t.table_type = 'BASE TABLE'
ORDER BY c.table_name, c.ordinal_position;


-- ============================================================
-- 3. GENERATED KOLONE - sve automatski izračunate kolone
-- ============================================================
SELECT
  c.table_name,
  c.column_name,
  c.is_generated,
  c.generation_expression,
  c.data_type
FROM information_schema.columns c
JOIN information_schema.tables t
  ON t.table_schema = c.table_schema AND t.table_name = c.table_name
WHERE c.table_schema = 'public'
  AND t.table_type = 'BASE TABLE'
  AND (c.is_generated = 'ALWAYS' OR c.generation_expression IS NOT NULL)
ORDER BY c.table_name, c.column_name;


-- ============================================================
-- 4. PRIMARY KEYS i UNIQUE CONSTRAINTS
-- ============================================================
SELECT
  tc.table_name,
  tc.constraint_name,
  tc.constraint_type,
  STRING_AGG(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) AS kolone
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON kcu.constraint_name = tc.constraint_name
  AND kcu.table_schema = tc.table_schema
WHERE tc.table_schema = 'public'
  AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
GROUP BY tc.table_name, tc.constraint_name, tc.constraint_type
ORDER BY tc.table_name, tc.constraint_type;


-- ============================================================
-- 5. FOREIGN KEYS - sve veze između tablica
-- ============================================================
SELECT
  tc.table_name AS tablica,
  kcu.column_name AS kolona,
  ccu.table_name AS referencira_tablicu,
  ccu.column_name AS referencira_kolonu,
  tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.table_schema = 'public'
  AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name, kcu.column_name;


-- ============================================================
-- 6. CHECK CONSTRAINTS - validacijska pravila
-- ============================================================
SELECT
  tc.table_name,
  tc.constraint_name,
  cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc
  ON cc.constraint_name = tc.constraint_name
  AND cc.constraint_schema = tc.table_schema
WHERE tc.table_schema = 'public'
  AND tc.constraint_type = 'CHECK'
  AND tc.constraint_name NOT LIKE '%_not_null'
ORDER BY tc.table_name, tc.constraint_name;


-- ============================================================
-- 7. INDEKSI - svi indeksi na tablicama
-- ============================================================
SELECT
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;


-- ============================================================
-- 8. VIEWS - svi pogledi
-- ============================================================
SELECT
  table_name AS view_name,
  view_definition
FROM information_schema.views
WHERE table_schema = 'public'
ORDER BY table_name;


-- ============================================================
-- 9. RPC FUNKCIJE - sve custom PostgreSQL funkcije
-- ============================================================
SELECT
  p.proname AS naziv_funkcije,
  pg_get_function_arguments(p.oid) AS argumenti,
  pg_get_function_result(p.oid) AS povratni_tip,
  CASE p.prokind
    WHEN 'f' THEN 'function'
    WHEN 'p' THEN 'procedure'
  END AS tip,
  p.prosecdef AS security_definer,
  l.lanname AS jezik,
  pg_get_functiondef(p.oid) AS definicija
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
JOIN pg_language l ON p.prolang = l.oid
WHERE n.nspname = 'public'
  AND p.proname NOT LIKE 'pg_%'
ORDER BY p.proname;


-- ============================================================
-- 10. TRIGGERI - svi triggeri na tablicama
-- ============================================================
SELECT
  event_object_table AS tablica,
  trigger_name,
  event_manipulation AS event,
  action_timing AS timing,
  action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;


-- ============================================================
-- 11. RLS POLITIKE - Row Level Security
-- ============================================================
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual AS using_expression,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;


-- ============================================================
-- 12. ENUMI - custom tipovi podataka
-- ============================================================
SELECT
  t.typname AS enum_name,
  STRING_AGG(e.enumlabel, ', ' ORDER BY e.enumsortorder) AS vrijednosti
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
JOIN pg_namespace n ON t.typnamespace = n.oid
WHERE n.nspname = 'public'
GROUP BY t.typname
ORDER BY t.typname;


-- ============================================================
-- 13. TABLICE BEZ PRIMARY KEY-a (potencijalni problem)
-- ============================================================
SELECT t.table_name
FROM information_schema.tables t
WHERE t.table_schema = 'public'
  AND t.table_type = 'BASE TABLE'
  AND t.table_name NOT IN (
    SELECT tc.table_name
    FROM information_schema.table_constraints tc
    WHERE tc.table_schema = 'public'
      AND tc.constraint_type = 'PRIMARY KEY'
  )
ORDER BY t.table_name;


-- ============================================================
-- 14. VELIČINE TABLICA - prostor na disku
-- ============================================================
SELECT
  relname AS tablica,
  pg_size_pretty(pg_total_relation_size(relid)) AS ukupna_velicina,
  pg_size_pretty(pg_relation_size(relid)) AS velicina_podataka,
  pg_size_pretty(pg_indexes_size(relid)) AS velicina_indeksa,
  n_live_tup AS zivi_redovi,
  n_dead_tup AS mrtvi_redovi,
  last_vacuum,
  last_autovacuum
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(relid) DESC;


-- ============================================================
-- 15. NOVE TABLICE OD 11.02.2026 (zadnji dokumentirani update)
-- Tablice kreirane nakon zadnjeg ažuriranja dokumentacije
-- ============================================================
-- Napomena: pg_class.relfilenode se mijenja pri ALTER,
-- pa koristimo oid za procjenu starosti
SELECT
  c.relname AS tablica,
  c.relkind,
  c.reltuples::bigint AS procijenjeni_redovi,
  pg_size_pretty(pg_total_relation_size(c.oid)) AS velicina
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'v')  -- r=tablica, v=view
ORDER BY c.relname;


-- ============================================================
-- 16. SUPABASE REALTIME - koje tablice imaju realtime enabled
-- ============================================================
SELECT * FROM supabase_realtime.subscription
LIMIT 50;
-- Ako gornji ne radi, probaj:
-- SELECT * FROM realtime.subscription LIMIT 50;


-- ============================================================
-- 17. STORAGE BUCKETS - Supabase storage
-- ============================================================
SELECT id, name, public, created_at, updated_at
FROM storage.buckets
ORDER BY name;
