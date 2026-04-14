-- ============================================
-- CARTA ERP - Punjenje prod_dropdown_values
-- TOČNE vrijednosti iz Dropdown_vrijednosti.xlsx
-- ============================================

-- Očisti postojeće (opcionalno)
-- DELETE FROM prod_dropdown_values WHERE category IN ('paper_color', 'cut_type', 'finger_hole', 'double_fold', 'valve_perforation', 'valve_type', 'perforation_type');

-- ============================================
-- BOJA VREĆE (paper_color)
-- ============================================
INSERT INTO prod_dropdown_values (category, value, sort_order, active) VALUES
('paper_color', 'S', 1, true),
('paper_color', 'B', 2, true)
ON CONFLICT (category, value) DO NOTHING;

-- ============================================
-- VRSTA REZA (cut_type)
-- ============================================
INSERT INTO prod_dropdown_values (category, value, sort_order, active) VALUES
('cut_type', 'Ravan', 1, true),
('cut_type', 'Smaknuti', 2, true)
ON CONFLICT (category, value) DO NOTHING;

-- ============================================
-- PRSTOHVAT (finger_hole)
-- ============================================
INSERT INTO prod_dropdown_values (category, value, sort_order, active) VALUES
('finger_hole', 'Da', 1, true),
('finger_hole', 'Ne', 2, true)
ON CONFLICT (category, value) DO NOTHING;

-- ============================================
-- DVOJNI PREKLOP (double_fold)
-- ============================================
INSERT INTO prod_dropdown_values (category, value, sort_order, active) VALUES
('double_fold', 'Da', 1, true),
('double_fold', 'Ne', 2, true)
ON CONFLICT (category, value) DO NOTHING;

-- ============================================
-- PERFORACIJA VENTILA (valve_perforation)
-- ============================================
INSERT INTO prod_dropdown_values (category, value, sort_order, active) VALUES
('valve_perforation', 'Jaka', 1, true),
('valve_perforation', 'Srednja', 2, true),
('valve_perforation', 'Slaba', 3, true),
('valve_perforation', 'Bez', 4, true)
ON CONFLICT (category, value) DO NOTHING;

-- ============================================
-- VRSTA VENTILA (valve_type)
-- ============================================
INSERT INTO prod_dropdown_values (category, value, sort_order, active) VALUES
('valve_type', 'VLR', 1, true),
('valve_type', 'VLRn', 2, true),
('valve_type', 'VLRp', 3, true),
('valve_type', 'VL', 4, true),
('valve_type', 'VL2', 5, true),
('valve_type', 'VL2n', 6, true),
('valve_type', 'IV', 7, true),
('valve_type', 'IVPE', 8, true),
('valve_type', 'OL', 9, true)
ON CONFLICT (category, value) DO NOTHING;

-- ============================================
-- VRSTA PERFORACIJE (perforation_type)
-- ============================================
INSERT INTO prod_dropdown_values (category, value, sort_order, active) VALUES
('perforation_type', '4x12', 1, true),
('perforation_type', '4x16', 2, true),
('perforation_type', '4x20', 3, true),
('perforation_type', '4x24', 4, true),
('perforation_type', '4x28', 5, true),
('perforation_type', '4x32', 6, true),
('perforation_type', '4x36', 7, true)
ON CONFLICT (category, value) DO NOTHING;

-- ============================================
-- POZICIJA VENTILA (valve_position)
-- ============================================
INSERT INTO prod_dropdown_values (category, value, sort_order, active) VALUES
('valve_position', 'A', 1, true),
('valve_position', 'B', 2, true),
('valve_position', 'C', 3, true),
('valve_position', 'D', 4, true)
ON CONFLICT (category, value) DO NOTHING;

-- ============================================
-- FOLIJA (has_foil)
-- ============================================
INSERT INTO prod_dropdown_values (category, value, sort_order, active) VALUES
('has_foil', 'DA', 1, true),
('has_foil', 'NE', 2, true)
ON CONFLICT (category, value) DO NOTHING;

-- ============================================
-- TIP BOTTOMERA (bottomer_type)
-- ============================================
INSERT INTO prod_dropdown_values (category, value, sort_order, active) VALUES
('bottomer_type', '5216', 1, true),
('bottomer_type', '2360', 2, true)
ON CONFLICT (category, value) DO NOTHING;

-- ============================================
-- PROIZVODNA LINIJA (production_line)
-- ============================================
INSERT INTO prod_dropdown_values (category, value, sort_order, active) VALUES
('production_line', 'NLI', 1, true),
('production_line', 'WH', 2, true)
ON CONFLICT (category, value) DO NOTHING;

-- ============================================
-- GRAMMAGE (gramatura)
-- ============================================
INSERT INTO prod_dropdown_values (category, value, sort_order, active) VALUES
('grammage', '60', 1, true),
('grammage', '70', 2, true),
('grammage', '80', 3, true),
('grammage', '90', 4, true),
('grammage', '100', 5, true),
('grammage', '110', 6, true),
('grammage', '120', 7, true),
('grammage', '130', 8, true),
('grammage', '140', 9, true),
('grammage', '150', 10, true)
ON CONFLICT (category, value) DO NOTHING;

-- ============================================
-- PROVJERA
-- ============================================
SELECT category, COUNT(*) as cnt, STRING_AGG(value, ', ' ORDER BY sort_order) as values
FROM prod_dropdown_values 
WHERE active = true
GROUP BY category 
ORDER BY category;
