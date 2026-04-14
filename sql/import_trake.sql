-- ============================================
-- IMPORT TRAKA IZ EXCEL DATOTEKE
-- Generirano automatski
-- ============================================

-- Prvo očisti postojeće test podatke
DELETE FROM prod_maintenance_belts WHERE belt_code LIKE 'TR-%';

-- Import traka
INSERT INTO prod_maintenance_belts (
  belt_code, 
  category, 
  position, 
  type, 
  description,
  width_mm, 
  length_mm, 
  thickness_mm, 
  min_stock, 
  quantity_in_stock, 
  price_eur, 
  supplier,
  compatible_machines
) VALUES
  ('TRK-0001', 'Plosnato remenje', 'S-press (pegla)', 'SL-F2200', 'SL-F2200 (1,4T X 180WX2500L)', 180.0, 2500.0, 1.4, 2, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0002', 'Plosnato remenje', 'S-press (pegla)', 'SL-F2200', 'SL-F2200 (1,4T X 180WX2880L)', 180.0, 2880.0, 1.4, 2, 3, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0003', 'Plosnato remenje', 'S-press (pegla)', 'SL-F2200', 'SL-F2200 (1,4T X 180WX4690L)', 180.0, 4690.0, 1.4, 2, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0004', 'Plosnato remenje', 'S-press (pegla)', 'SL-F2200', 'SL-F2200 (1,4T X 180WX5435L)', 180.0, 5435.0, 1.4, 2, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0005', 'Plosnato remenje', 'S-press (pegla)', 'SL-F2200', 'SL-F2200 (1,4T X 180WX5580L)', 180.0, 5580.0, 1.4, 2, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0006', 'Plosnato remenje', 'S-press (pegla)', 'SL-F2200', 'SL-F2200 (1,4T X 180WX5660L)', 180.0, 5660.0, 1.4, 2, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0007', 'Plosnato remenje', 'S-press (pegla)', 'SL-F2200', 'SL-F2200 (1,4T X 180WX6405L)', 180.0, 6405.0, 1.4, 2, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0008', 'Plosnato remenje', 'S-press (pegla)', 'SL-F2200', 'SL-F2200 (1,4T X 180WX5990L)', 180.0, 5990.0, 1.4, 2, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0009', 'Plosnato remenje', 'S-press (pegla)', 'SL-F2200', 'SL-F2200 (1,4T X 180WX10230L)', 180.0, 10230.0, 1.4, 2, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0010', 'Plosnato remenje', 'S-press (pegla)', 'SL-F2200', 'SL-F2200 (1,4T X 180WX11660L)', 180.0, 11660.0, 1.4, 2, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0011', 'Plosnato remenje', 'S-press (pegla)', 'SL-F2200', 'SL-F2200 (1,4T X 180WX1015L)', 180.0, 1015.0, 1.4, 2, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0012', 'Plosnato remenje', 'S-press (pegla)', '0,7T x 160W x 2920L', '0,7T x 160W x 2920L', 160.0, 2920.0, 0.7, 2, 3, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0013', 'Plosnato remenje', 'S-press (pegla)', '0,7T x 200W x 2560L', '0,7T x 200W x 2560L', 200.0, 2560.0, 0.7, 2, 2, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0014', 'Plosnato remenje', 'S-press (pegla)', 'KO 2M0309 S24', 'KO 2M0309 S24 BLACK + V10 x 6', 10.0, 6.0, NULL, 1, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0015', 'Remenje', 'MC-120 iza noža', '20 PE2', '20 PE2 š=40 x d=565 - 2.0 t x 40 w x 565 L', 40.0, 565.0, 2.0, 2, 1, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0016', 'Remenje', 'MC-120 iza noža', '20 PE2', '20 PE2 š=40 x d=745 - 2.0 t x 40 w x 745 L', 40.0, 745.0, 2.0, 2, 1, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0017', 'Remenje', 'MC-120 iza noža', '20 PE2', '20 PE2 š=40 x d=1445 - 2.0 t x 40 w x 1445 L', 40.0, 1445.0, 2.0, 2, 2, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0018', 'Remenje', 'MC-120 iza noža', '20 PE2', '20 PE2 š=40 x d=1645 - 2.0 t x 40 w x 1645 L', 40.0, 1645.0, 2.0, 2, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0019', 'Remenje za vođenje ventila', 'Ventil aparat', 'KP 2M1523 S18', 'KP 2M1523 S18 35x5960 BPF', 35.0, 5960.0, NULL, 1, 1, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0020', 'Remenje za vođenje ventila', 'Ventil aparat', 'KP 2M1523 S18', 'KP 2M1523 S18 35x3090 BPF', 35.0, 3090.0, NULL, 1, 3, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0021', 'Remenje vuče', 'Samar - vuča dna', '10 EPZ', '10 EPZ 65x2920', 65.0, 2920.0, NULL, 4, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0022', 'Zupčasto remenje', 'Odmicanje ventil aparata', 'T10-690', 'T10-690 Š=15mm', 15.0, 690.0, NULL, 2, 6, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0023', 'Zupčasto remenje', 'Prstohvat ventil aparata', 'T10-880', 'T10-880 Š=15mm', 15.0, 880.0, NULL, 2, 6, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0024', 'Remenje vuče', 'Vuča', 'Remenje vuče', '30x12140x6', 30.0, 12140.0, 6.0, 4, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0025', 'Remenje vuče', 'Vuča', 'Remenje vuče', '30x14850x6', 30.0, 14850.0, 6.0, 4, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0026', 'Remenje vuče', 'Vuča', 'Remenje vuče', '30x8600', 30.0, 8600.0, NULL, 4, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0027', 'Zupčasto remenje', 'Etiketa', 'T10-120Z', 'T10-120Z 17x1200', 17.0, 1200.0, NULL, 2, 9, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0028', 'Zupčasto remenje', 'Etiketa', 'T10-120Z', 'T10-120Z 15x1200', 15.0, 1200.0, NULL, 2, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0029', 'Zupčasto remenje', 'Etiketa', 'T10-380Z', 'T10-380Z 25x3800', 25.0, 3800.0, NULL, 1, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0030', 'Zupčasto remenje', 'Etiketa', 'T10-343Z', 'T10-343Z 25x3430', 25.0, 3430.0, NULL, 1, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0031', 'Zupčasto remenje', 'Odmicanje etikete', 'T10-63Z', 'T10-63Z 25x630', 25.0, 630.0, NULL, 2, 10, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0032', 'Zupčasto remenje', 'Valjci na otvaranju', 'T10-120Z', 'T10-120Z 25x1200', 25.0, 1200.0, NULL, 2, 7, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0033', 'Remenje', 'Ulagač', 'Remenje ulagača', '35x1240x1', 35.0, 1240.0, 1.0, 10, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0034', 'Remenje', 'AM2140 Izlaz', 'KO 2M0230 S34', 'KO 2M0230 S34 š= 70 mm x d= 1 710 mm', 70.0, 1710.0, NULL, 2, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0035', 'Remenje', 'AM2140 Izlaz', 'KO 2M0230 S34', '4 KO 2M 0230 S34 š= 70 mm x d= 1 400 mm', 70.0, 1400.0, NULL, 2, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0036', 'Remenje', 'AD2360 Dvojni', '10 EPZ', '10 EPZ š= 80 mm x d= 1910 mm', 80.0, 1910.0, NULL, 2, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0037', 'Remenje', 'AD2360 Dvojni', '10 EPZ', '10 EPZ š= 60 mm x d= 1580 mm', 60.0, 1580.0, NULL, 2, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0038', 'Remenje vuče', 'AD2360 Vuča', 'Remenje vuče', 'd=6790 mm', NULL, 6790.0, NULL, 6, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0039', 'Remenje vuče', 'AD2360 Vuča', 'Remenje vuče', 'd=6250 mm', NULL, 6250.0, NULL, 4, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0040', 'Remenje vuče', 'AD2360 Vuča', 'Remenje vuče', 'd=2480 mm', NULL, 2480.0, NULL, 4, 0, NULL, 'NLI', ARRAY['NLI-BOT-01']),
  ('TRK-0041', 'Remenje vuče', 'AD2360 Vuča', 'Remenje vuče', 'd=1920 mm', NULL, 1920.0, NULL, 4, 0, NULL, 'NLI', ARRAY['NLI-BOT-01'])
;

-- Verifikacija
SELECT 
  COUNT(*) as total_belts,
  COUNT(DISTINCT category) as categories,
  SUM(CASE WHEN quantity_in_stock = 0 THEN 1 ELSE 0 END) as out_of_stock,
  SUM(CASE WHEN quantity_in_stock <= min_stock AND quantity_in_stock > 0 THEN 1 ELSE 0 END) as low_stock
FROM prod_maintenance_belts;
