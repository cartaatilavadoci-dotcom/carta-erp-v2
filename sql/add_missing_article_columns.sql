-- ============================================
-- CARTA ERP - Dodavanje nedostajućih kolona u prod_articles
-- ============================================

-- Kolona za količinu na paleti (koristi se u Bottomer modulima)
ALTER TABLE prod_articles
ADD COLUMN IF NOT EXISTS pallet_quantity INTEGER;

COMMENT ON COLUMN prod_articles.pallet_quantity IS 'Količina vreća na paleti (broj) - koristi se u Bottomer modulima';

-- Provjera da kolone za kodove boja postoje
DO $$
BEGIN
  -- top_color_1_code
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'prod_articles' AND column_name = 'top_color_1_code'
  ) THEN
    ALTER TABLE prod_articles ADD COLUMN top_color_1_code TEXT;
    COMMENT ON COLUMN prod_articles.top_color_1_code IS 'Kod boje gornji papir 1';
  END IF;

  -- top_color_2_code
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'prod_articles' AND column_name = 'top_color_2_code'
  ) THEN
    ALTER TABLE prod_articles ADD COLUMN top_color_2_code TEXT;
    COMMENT ON COLUMN prod_articles.top_color_2_code IS 'Kod boje gornji papir 2';
  END IF;

  -- bottom_color_1_code
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'prod_articles' AND column_name = 'bottom_color_1_code'
  ) THEN
    ALTER TABLE prod_articles ADD COLUMN bottom_color_1_code TEXT;
    COMMENT ON COLUMN prod_articles.bottom_color_1_code IS 'Kod boje donji papir 1';
  END IF;

  -- bottom_color_2_code
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'prod_articles' AND column_name = 'bottom_color_2_code'
  ) THEN
    ALTER TABLE prod_articles ADD COLUMN bottom_color_2_code TEXT;
    COMMENT ON COLUMN prod_articles.bottom_color_2_code IS 'Kod boje donji papir 2';
  END IF;
END
$$;

-- Migracija: Kopiraj pcs_per_pallet u pallet_quantity ako je moguće
UPDATE prod_articles
SET pallet_quantity = NULLIF(REGEXP_REPLACE(pcs_per_pallet, '[^0-9].*', ''), '')::INTEGER
WHERE pallet_quantity IS NULL
  AND pcs_per_pallet IS NOT NULL
  AND pcs_per_pallet ~ '^[0-9]+';

-- Provjera
SELECT 
  'prod_articles kolone' as info,
  COUNT(*) as total_articles,
  COUNT(pallet_quantity) as with_pallet_qty
FROM prod_articles;
