# CARTA ERP - Struktura Baze Podataka

## 📊 Pregled

> **Zadnja analiza:** 14. travnja 2026. (direktna Supabase introspekcija)

- **Baza:** Supabase PostgreSQL
- **Ukupno tablica:** 77 (public schema)
- **View-ova:** 19
- **RPC funkcija:** 48 (uključujući triggere)
- **GENERATED kolone:** 7
- **Sve tablice imaju RLS enabled**
- **Najveće tablice po broju kolona:**
  - `prod_articles` (121)
  - `prod_work_orders` (44)
  - `prod_work_orders_cutting` (42)
  - `prod_work_orders_printing` (40)
  - `prod_orders` (40)
  - `payroll` (38)
  - `prod_inventory_consumed_rolls` (36)
  - `prod_shift_statistics` (34)

---

## 🗃️ Tablice po domenama

### 1. ARTIKLI I NARUDŽBE (Core Production)

#### prod_articles (119 kolona)
Glavni katalog proizvoda - svaka vrećica/proizvod.

#### prod_orders (37 kolona) ⭐ AŽURIRANO 11.02.2026
Narudžbe kupaca.
```
- id, order_number, customer_id, article_id
- item_number (INT) - redni broj stavke
- quantity_ordered, quantity_produced
- quantity_remaining (GENERATED!) - automatski
- sort_order (INTEGER DEFAULT 0) ⭐ NOVO - ručno sortiranje narudžbi
- status, priority, delivery_deadline

⚠️ KRITIČNO: quantity_remaining je GENERATED kolona!
```

#### prod_customers (14 kolona)
Kupci.

### 2. RADNI NALOZI

#### prod_work_orders (48+ kolona) ⭐ AŽURIRANO 25.01.2026
Glavni radni nalozi.
```
Ključne kolone:
- id (UUID, PK)
- wo_number, wo_type
- article_id, article_name, article_code
- customer_id, customer_name
- quantity, produced_quantity
- status: 'Planiran' | 'U tijeku' | 'Završeno' | 'Pauzirano'
- production_line: 'WH' | 'NLI'
- tuber_status: 'Aktivan' | 'Završeno' | 'Pauzirano' ⭐ ZA ESP32!
- created_at, completed_at

NOVE KOLONE - Bottomer odvojeni statusi ⭐ NOVO:
- bottomer_voditelj_status: 'Aktivan' | 'Završeno' | 'Pauzirano'
- bottomer_slagac_status: 'Aktivan' | 'Završeno' | 'Pauzirano'
- bottomer_voditelj_completed_at: TIMESTAMPTZ
- bottomer_slagac_completed_at: TIMESTAMPTZ
- pcs_per_pallet_override: INTEGER (NULL = koristi artikl vrijednost) ⭐ NOVO
```

#### prod_work_orders_cutting (42 kolona)
Nalozi za rezanje.

#### prod_work_orders_printing (33 kolona)
Nalozi za tisak.

### 3. SMJENE I PROIZVODNJA

#### prod_shift_log (19 kolona)
Dnevnik smjena.

#### prod_shift_details (22 kolona)
Detalji proizvodnje po smjeni. **KLJUČNA TABLICA za PVND modul!**

#### prod_shift_substitutions (12 kolona)
Zamjene članova postave.

#### prod_shift_reports ⭐ KORISTI SE ZA TUBER IZVJEŠTAJE
Smjenski izvještaji s JSON podacima.
```
Ključne kolone:
- id (UUID, PK)
- production_line: 'WH' | 'NLI'
- machine_type: 'Tuber' | 'Bottomer' | etc.
- shift_date: DATE
- shift_number: INTEGER (1, 2, 3)
- report_data: JSONB (svi podaci izvještaja)
- strojar: TEXT
- pomocnici: TEXT
- napomena: TEXT
- created_at, updated_at
```

### 4. SKLADIŠTE (Inventory)

#### prod_inventory_rolls (18 kolona) ⭐ AŽURIRANO 11.02.2026
Role papira.
```
⚠️ KRITIČNO: remaining_kg je GENERATED kolona!
Formula: initial_weight_kg - consumed_kg
❌ NE radi: .insert({ remaining_kg: 500 }) ni .update({ remaining_kg: 100 })
✅ Samo ažuriraj: consumed_kg (sustav automatski računa remaining_kg)
```

#### prod_inventory_strips (15 kolona) ⚠️ GENERATED KOLONA
Rezane trake.
```
⚠️ remaining_kg je GENERATED kolona!
Formula: weight_kg - consumed_kg
```

#### prod_inventory_printed (16 kolona) ⚠️ GENERATED KOLONA
Otisnute role.
```
⚠️ remaining_kg je GENERATED kolona!
Formula: weight_kg - consumed_kg
```

#### prod_inventory_foil (11 kolona) ⚠️ GENERATED KOLONA
Folije.
```
⚠️ remaining_kg je GENERATED kolona!
Formula: weight_kg - consumed_kg
```

#### prod_inventory_pop (20 kolona) ⭐ AŽURIRANO 01.02.2026
POP - poluproizvodi (tuljci).
```
Ključne kolone:
- id (UUID, PK)
- pop_code (VARCHAR)
- work_order_id, work_order_number
- article_id, article_name
- quantity, quantity_in_stock
- quantity_reserved (INTEGER) ⭐ NOVO 01.02.2026 - rezervirano od Bottomer-a
- quantity_available (INTEGER GENERATED) ⭐ NOVO 01.02.2026 - dostupno (in_stock - reserved)
- status (VARCHAR) - 'Na skladištu', 'Utrošeno', etc.
- production_line (VARCHAR) - 'WH' ili 'NLI'
- material_deducted (BOOLEAN) ⭐ - je li materijal skinut sa stanja
- created_at, updated_at

⚠️ KRITIČNO: quantity_available je GENERATED kolona!
Formula: quantity_in_stock - COALESCE(quantity_reserved, 0)
❌ NE radi: .update({ quantity_available: 100 })
✅ Samo ažuriraj: quantity_in_stock ili quantity_reserved
```

#### prod_inventory_gop (17 kolona)
GOP - gotovi proizvodi (vrećice).

#### prod_inventory_pallets
Prazne palete i poklopci.
```
- id (UUID, PK)
- dimension (TEXT)
- quantity (INTEGER) - količina paleta
- min_stock (INTEGER)
- cover_quantity (INTEGER) - fizičko stanje poklopaca
- cover_reserved (INTEGER) - rezervirani poklopci
- cover_min_stock (INTEGER)
- created_at, updated_at
```

---

## 🧻 Evidencija Potrošnje Materijala

### prod_inventory_consumed_rolls
Evidencija svakog skidanja materijala sa stanja (Tuber → tuber-materijal modul).

```sql
CREATE TABLE prod_inventory_consumed_rolls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Izvorni materijal
  source_roll_id UUID,              -- ID role u izvornoj tablici
  roll_code TEXT,                   -- Šifra materijala
  source_table TEXT,                -- 'prod_inventory_rolls', 'prod_inventory_strips', etc.
  material_type TEXT,               -- 'rolls', 'strips', 'printed', 'foil'
  
  -- Dimenzije
  width_cm NUMERIC(10,2),           -- Širina materijala
  grammage INTEGER,                 -- Gramatura (g/m²)
  
  -- Količine
  consumed_kg NUMERIC(10,3),        -- Potrošeno (kg)
  remaining_kg NUMERIC(10,3),       -- Ostatak na roli (kg)
  
  -- Kontekst proizvodnje
  work_order_id UUID,               -- Radni nalog
  work_order_number TEXT,           -- Broj RN
  article_name TEXT,                -- Naziv artikla
  layer_number INTEGER,             -- Sloj (1-4)
  pop_quantity INTEGER,             -- Proizvedeno POP-a
  
  -- Vrijeme i lokacija
  production_line TEXT,             -- 'WH' ili 'NLI'
  shift_date DATE,                  -- Proizvodni datum
  consumption_type TEXT,            -- 'full' (potpuno) ili 'partial' (djelomično)
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 📮 ESP32 i OEE Tablice ⭐ AŽURIRANO 26.01.2026

### prod_machine_counters ⭐ KRITIČNA TABLICA
Glavni brojač za svaki stroj. **Koristi se za sinkronizaciju ESP32 ↔ Web app!**

```sql
Ključne kolone:
- machine_code (TEXT, PK ili UNIQUE) - 'NLI-1', 'WH-1', etc.
- count (INTEGER) - trenutni broj komada
- work_order_id (UUID) - aktivni radni nalog
- work_order_number (TEXT) - broj aktivnog naloga
- target_quantity (INTEGER) - cilj za nalog
- is_active (BOOLEAN) - je li brojač aktivan
- last_sync_at (TIMESTAMPTZ) - zadnji sync
- device_id (TEXT) - ESP32 device ID
- started_at (TIMESTAMPTZ) - kada je brojač pokrenut
```

### Tko piše u prod_machine_counters?

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     PISANJE U prod_machine_counters                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ESP32 (increment_machine_counter RPC):                                     │
│  ───────────────────────────────────────                                    │
│  - Svakih 500 komada kad stroj stane                                        │
│  - SAMO DODAJE na postojeći count (count += p_increment)                    │
│  - NE resetira count!                                                       │
│                                                                             │
│  tuber.html (start_machine_counter RPC):                                    │
│  ─────────────────────────────────────────                                  │
│  - Pri pokretanju NOVOG naloga                                              │
│  - UPSERT: ako postoji → RESETIRA count na 0!                               │
│  - ⚠️ OPASNO ako se pozove za aktivni nalog!                                │
│                                                                             │
│  tuber.html (stop_machine_counter RPC):                                     │
│  ────────────────────────────────────────                                   │
│  - Pri završetku naloga                                                     │
│  - Postavlja is_active = false                                              │
│  - NE briše count (ostaje za evidenciju)                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### prod_machine_counter_sync
Sync log - zapis svakih 500 komada za OEE analizu brzine.
```
- machine_code, work_order_id
- count_at_sync (500, 1000, 1500...)
- production_date, shift_number
- created_at
```

### prod_machine_events
STOP/START eventi za OEE analizu zastoja.
```
- machine_code, work_order_id
- event_type: 'STOP' | 'START'
- count_at_event
- duration_seconds (za START event)
- created_at
```

### prod_downtime_categories
Kategorije zastoja za OEE (7 kategorija).

### prod_shift_statistics
Dnevni agregati za OEE (cron job u 06:15).

---

## ⚙️ RPC Funkcije

### Za ESP32

#### increment_machine_counter
```sql
SELECT * FROM increment_machine_counter(
  p_machine_code := 'NLI-1',
  p_device_id := 'ABC123',
  p_increment := 500
);
-- Vraća: { success, count, work_order_id, work_order_number, target }

-- ⚠️ VAŽNO: Ova funkcija DODAJE na count, NE resetira!
```

#### get_counter_status ⭐ KORISTI SE U tuber.html
```sql
SELECT * FROM get_counter_status(p_machine_code := 'NLI-1');
-- Vraća: { active, count, target_quantity, work_order_number, work_order_id, ... }

-- ⭐ tuber.html MORA provjeriti ovu funkciju PRIJE start_machine_counter!
```

#### get_active_work_order ⭐ KORISTI ESP32 HEARTBEAT
```sql
SELECT * FROM get_active_work_order(p_machine_code := 'NLI-1');
-- Vraća: { active, work_order_id, work_order_number, count, target }

-- ⚠️ ESP32 koristi ovo za sinkronizaciju:
-- Ako tubes==syncedCount && buffer==0 → tubes = serverCount
-- Ako je serverCount=0 (pogrešan reset), ESP32 gubi count!
```

#### start_machine_counter ⭐ OPREZ!
```sql
SELECT * FROM start_machine_counter(
  p_machine_code := 'NLI-1',
  p_work_order_id := 'uuid',
  p_work_order_number := 'RN025/26',
  p_target_quantity := 80000
);

-- ⚠️ KRITIČNO: Ova funkcija radi UPSERT s count=0!
-- Ako se pozove za postojeći nalog, RESETIRA count!
-- tuber.html MORA provjeriti get_counter_status PRIJE poziva!
```

#### stop_machine_counter
```sql
SELECT * FROM stop_machine_counter(
  p_machine_code := 'NLI-1',
  p_final_count := 12345
);
```

### Za Bottomer module ⭐ NOVO 25.01.2026

#### complete_bottomer_phase
Završava bottomer fazu (voditelj ili slagač). Automatski završava nalog kad OBA završe.
```sql
SELECT * FROM complete_bottomer_phase(
  p_work_order_id := 'uuid-naloga',
  p_phase := 'voditelj'  -- ili 'slagac'
);

-- Vraća:
-- { success: true, fully_completed: false, voditelj_status: 'Završeno', slagac_status: 'Aktivan', message: '...' }
-- ili ako su oba završena:
-- { success: true, fully_completed: true, message: 'Nalog potpuno završen (voditelj + slagač)' }
```

#### reactivate_bottomer_phase
Reaktivira bottomer fazu ako je potrebno poništiti završetak.
```sql
SELECT * FROM reactivate_bottomer_phase(
  p_work_order_id := 'uuid-naloga',
  p_phase := 'slagac'  -- ili 'voditelj'
);

-- Vraća: { success: true, message: 'Faza slagac reaktivirana' }
```

---

## ⚠️ KRITIČNE Napomene

### 1. GENERATED kolone - NE AŽURIRATI! ⭐ AŽURIRANO 11.02.2026
```
3 GENERATED kolone u sustavu:

1. prod_orders.quantity_remaining = quantity_ordered - quantity_produced
   ❌ .update({ quantity_remaining: 100 })
   ✅ Ažuriraj: quantity_ordered ili quantity_produced

2. prod_inventory_rolls.remaining_kg = initial_weight_kg - consumed_kg ⭐ NOVO
   ❌ .insert({ remaining_kg: 500 }) ili .update({ remaining_kg: 100 })
   ✅ Ažuriraj: consumed_kg

3. prod_inventory_pop.quantity_available = quantity_in_stock - COALESCE(quantity_reserved, 0)
   ❌ .update({ quantity_available: 100 })
   ✅ Ažuriraj: quantity_in_stock ili quantity_reserved
```

### 2. Mjerne jedinice
```
SVE DIMENZIJE U BAZI SU U CENTIMETRIMA (cm)!
• tube_length: cm -> /100 za metre
• gramatura: g/m² -> /1000 za kg/m²
```

### 3. Row limits
```javascript
// Supabase default vraća max 1000 redova - UVIJEK postavi limit!
const { data } = await supabase.from('tablica').select('*').limit(10000);
```

### 4. Status vrijednosti
```
Narudžbe: Aktivno, Završeno, Otkazano
Radni nalozi: Planiran, U tijeku, Završeno, Pauziran
Tuber status: Aktivan, Završeno, Pauzirano ⭐ ZA ESP32!
Bottomer statusi: Aktivan, Završeno, Pauzirano ⭐ NOVO
Smjene: Aktivno, Završeno
Inventar: Na skladištu, Djelomično, Utrošeno, Otpisano
GOP palete: Na skladištu, Otpremljeno, U pripremi
```

### 5. Proizvodni datum vs Kalendarski datum
```
KRITIČNO: Proizvodni dan traje od 06:00 do 06:00!

Smjene:
- 1. smjena: 06:00 - 14:00
- 2. smjena: 14:00 - 22:00
- 3. smjena: 22:00 - 06:00 (prelazi u sljedeći kalendarski dan!)

Primjer:
- Unos u 02:00 ujutro 20.01. → proizvodni dan 19.01., smjena 3
```

### 6. ESP32 sinkronizacija ⭐ NOVO 26.01.2026
```
KRITIČNO: ESP32 heartbeat može resetirati lokalni count!

ESP32 logika (svakih 30s kad stroj stoji):
1. Poziva get_active_work_order()
2. Dobije serverCount iz baze
3. Ako tubes==syncedCount && offlineBuffer==0:
   → tubes = serverCount

⚠️ Ako je serverCount=0 (zbog pogrešnog start_machine_counter poziva):
   → ESP32 postavlja tubes=0
   → IZGUBLJENI KOMADI!

✅ tuber.html MORA provjeriti get_counter_status PRIJE start_machine_counter
```

---

## 🆕 SQL Skripte - 26. Siječanj 2026

### Ispravna logika za pokretanje naloga ⭐ NOVO
```javascript
// tuber.html - tuberZapocni()

// 1. PRVO provjeri postoji li aktivni brojač
var statusResult = await initSupabase()
  .rpc('get_counter_status', { p_machine_code: machineCode });

// 2. Ako postoji za ISTI nalog → NE DIRAJ
if (currentCounter.active && currentCounter.work_order_id === id) {
  console.log('Brojač već aktivan, koristi postojeći count');
  return; // NE pozivaj start_machine_counter!
}

// 3. Ako NEMA aktivnog → pokreni novi
if (!currentCounter.active) {
  await initSupabase().rpc('start_machine_counter', {...});
}
```

---

## 🆕 SQL Skripte - 25. Siječanj 2026

### Odvojeni Bottomer statusi ⭐ NOVO
```sql
-- 1. Dodaj nove kolone za bottomer statuse
ALTER TABLE prod_work_orders 
ADD COLUMN IF NOT EXISTS bottomer_voditelj_status TEXT DEFAULT 'Aktivan',
ADD COLUMN IF NOT EXISTS bottomer_slagac_status TEXT DEFAULT 'Aktivan',
ADD COLUMN IF NOT EXISTS bottomer_voditelj_completed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS bottomer_slagac_completed_at TIMESTAMPTZ;

-- 2. CHECK constraints
ALTER TABLE prod_work_orders
ADD CONSTRAINT chk_bottomer_voditelj_status 
CHECK (bottomer_voditelj_status IN ('Aktivan', 'Završeno', 'Pauzirano') OR bottomer_voditelj_status IS NULL);

ALTER TABLE prod_work_orders
ADD CONSTRAINT chk_bottomer_slagac_status 
CHECK (bottomer_slagac_status IN ('Aktivan', 'Završeno', 'Pauzirano') OR bottomer_slagac_status IS NULL);

-- 3. Ažuriraj postojeće završene naloge
UPDATE prod_work_orders 
SET bottomer_voditelj_status = 'Završeno',
    bottomer_slagac_status = 'Završeno'
WHERE status = 'Završeno';

-- 4. Indeksi
CREATE INDEX IF NOT EXISTS idx_work_orders_bottomer_voditelj_status 
ON prod_work_orders(bottomer_voditelj_status) 
WHERE bottomer_voditelj_status IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_work_orders_bottomer_slagac_status 
ON prod_work_orders(bottomer_slagac_status) 
WHERE bottomer_slagac_status IS NOT NULL;
```

### RPC funkcija complete_bottomer_phase ⭐ NOVO
```sql
CREATE OR REPLACE FUNCTION complete_bottomer_phase(
  p_work_order_id UUID,
  p_phase TEXT  -- 'voditelj' ili 'slagac'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_voditelj_status TEXT;
  v_slagac_status TEXT;
BEGIN
  -- Ažuriraj odgovarajući status
  IF p_phase = 'voditelj' THEN
    UPDATE prod_work_orders 
    SET bottomer_voditelj_status = 'Završeno',
        bottomer_voditelj_completed_at = NOW()
    WHERE id = p_work_order_id;
  ELSIF p_phase = 'slagac' THEN
    UPDATE prod_work_orders 
    SET bottomer_slagac_status = 'Završeno',
        bottomer_slagac_completed_at = NOW()
    WHERE id = p_work_order_id;
  ELSE
    RETURN json_build_object('success', false, 'error', 'Invalid phase');
  END IF;
  
  -- Dohvati trenutne statuse
  SELECT bottomer_voditelj_status, bottomer_slagac_status
  INTO v_voditelj_status, v_slagac_status
  FROM prod_work_orders
  WHERE id = p_work_order_id;
  
  -- Ako su OBA završena, završi cijeli nalog
  IF v_voditelj_status = 'Završeno' AND v_slagac_status = 'Završeno' THEN
    UPDATE prod_work_orders 
    SET status = 'Završeno',
        completed_at = NOW()
    WHERE id = p_work_order_id;
    
    RETURN json_build_object(
      'success', true, 
      'fully_completed', true,
      'message', 'Nalog potpuno završen (voditelj + slagač)'
    );
  END IF;
  
  RETURN json_build_object(
    'success', true, 
    'fully_completed', false,
    'voditelj_status', v_voditelj_status,
    'slagac_status', v_slagac_status,
    'message', 'Faza ' || p_phase || ' završena, čeka se druga faza'
  );
END;
$$;

-- Dozvole
GRANT EXECUTE ON FUNCTION complete_bottomer_phase(UUID, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION complete_bottomer_phase(UUID, TEXT) TO authenticated;
```

### RPC funkcija reactivate_bottomer_phase ⭐ NOVO
```sql
CREATE OR REPLACE FUNCTION reactivate_bottomer_phase(
  p_work_order_id UUID,
  p_phase TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_phase = 'voditelj' THEN
    UPDATE prod_work_orders 
    SET bottomer_voditelj_status = 'Aktivan',
        bottomer_voditelj_completed_at = NULL,
        status = CASE WHEN status = 'Završeno' THEN 'U tijeku' ELSE status END,
        completed_at = CASE WHEN status = 'Završeno' THEN NULL ELSE completed_at END
    WHERE id = p_work_order_id;
  ELSIF p_phase = 'slagac' THEN
    UPDATE prod_work_orders 
    SET bottomer_slagac_status = 'Aktivan',
        bottomer_slagac_completed_at = NULL,
        status = CASE WHEN status = 'Završeno' THEN 'U tijeku' ELSE status END,
        completed_at = CASE WHEN status = 'Završeno' THEN NULL ELSE completed_at END
    WHERE id = p_work_order_id;
  ELSE
    RETURN json_build_object('success', false, 'error', 'Invalid phase');
  END IF;
  
  RETURN json_build_object('success', true, 'message', 'Faza ' || p_phase || ' reaktivirana');
END;
$$;

-- Dozvole
GRANT EXECUTE ON FUNCTION reactivate_bottomer_phase(UUID, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION reactivate_bottomer_phase(UUID, TEXT) TO authenticated;
```

### Nova kolona material_deducted u prod_inventory_pop
```sql
ALTER TABLE prod_inventory_pop 
ADD COLUMN IF NOT EXISTS material_deducted BOOLEAN DEFAULT false;

UPDATE prod_inventory_pop SET material_deducted = true;

CREATE INDEX IF NOT EXISTS idx_pop_material_deducted 
ON prod_inventory_pop(material_deducted);

CREATE INDEX IF NOT EXISTS idx_pop_wo_deducted
ON prod_inventory_pop(work_order_id, material_deducted);
```

### Rezervacije POP-a ⭐ NOVO 01.02.2026

Sistem automatskog upravljanja rezervacijama POP-a između Bottomer-a i Tuber-a.

```sql
-- Dodaj kolone za rezervacije
ALTER TABLE prod_inventory_pop
ADD COLUMN IF NOT EXISTS quantity_reserved INTEGER DEFAULT 0;

ALTER TABLE prod_inventory_pop
ADD COLUMN IF NOT EXISTS quantity_available INTEGER
GENERATED ALWAYS AS (quantity_in_stock - COALESCE(quantity_reserved, 0)) STORED;

-- Komentari
COMMENT ON COLUMN prod_inventory_pop.quantity_reserved IS
'Količina rezervirana od strane Bottomer-a dok POP još nije fizički na skladištu';

COMMENT ON COLUMN prod_inventory_pop.quantity_available IS
'Dostupna količina za potrošnju (in_stock - reserved). GENERATED kolona - ne ažurirati ručno!';

-- Indeksi
CREATE INDEX IF NOT EXISTS idx_pop_reserved
ON prod_inventory_pop(work_order_number)
WHERE quantity_reserved > 0;

CREATE INDEX IF NOT EXISTS idx_pop_wo_status_reserved
ON prod_inventory_pop(work_order_number, status, quantity_reserved);

CREATE INDEX IF NOT EXISTS idx_pop_available
ON prod_inventory_pop(quantity_available)
WHERE quantity_available > 0;
```

**Workflow:**
```
1. Bottomer-slagač treba POP koji još nije na skladištu
   → REZERVIRA količinu (quantity_reserved += X)
   → Prikazuje upozorenje operateru

2. Tuber dodaje novi POP
   → Automatski provjerava ima li rezervacija
   → Skida rezervacije (FIFO)
   → Ažurira quantity_in_stock na novom POP-u
   → Obavještava operatera

3. Rezultat: Točno stanje zaliha, nema "duhova"
```

**Implementirane funkcije:**
- `bottomer-slagac.html::skiniPOPSaStanja()` - rezervira ako nema dovoljno
- `tuber.html::tuberSkiniRezervacije()` - automatski skida rezervacije

---

---

## 🔢 Brojači i Rezervirani Brojevi ⭐ NOVO 11.02.2026

### prod_counters
Sekvencijalni brojači za generiranje jedinstvenih brojeva.
```
- id (UUID, PK)
- counter_type (TEXT) - tip brojača (jedinstven po godini)
- current_value (INTEGER) - trenutna vrijednost
- year (INTEGER) - godina
- prefix (TEXT) - prefix za generiranje broja
- updated_at (TIMESTAMPTZ)

Tipovi brojača:
| counter_type | prefix | Tablica                    | Pattern       |
|-------------|--------|----------------------------|---------------|
| Narudžba    | N      | prod_orders                | N{br}/{god}   |
| RN_Glavni   | RN     | prod_work_orders           | RN{br}/{god}  |
| RN_Tisak    | TIS    | prod_work_orders_printing  | TIS{br}/{god} |
| RN_Rezanje  | REZ    | prod_work_orders_cutting   | REZ{br}/{god} |
| RN_Etiketa  | ETI    | -                          | ETI{br}/{god} |
| Kvar        | KV     | -                          | KV{br}/{god}  |
| MaintOrder  | MO     | -                          | MO{br}/{god}  |
| Maintenance | MAINT  | -                          | MAINT{br}     |
| GOP         | GOP    | -                          | GOP{br}       |
| POP         | POP    | -                          | POP{br}       |
| Paleta      | PAL    | -                          | PAL{br}       |
```

### prod_reserved_numbers
Rezervirani brojevi (sprečava duplikate pri konkurentnom kreiranju).
```
- id (UUID, PK)
- counter_type (TEXT) - tip brojača
- reserved_number (INTEGER) - rezervirani broj
- reserved_at (TIMESTAMPTZ) - kada je rezerviran
- used (BOOLEAN) - je li broj iskorišten
- used_at (TIMESTAMPTZ) - kada je iskorišten
```

### Sinkronizacija brojača (planiranje.html)
```
Bidirekcijsko ažuriranje - dozvoljava i SMANJIVANJE!

Workflow:
1. Skenira sve tablice → pronađe max broj po tipu
2. Usporedi s current_value u prod_counters
3. Ako se razlikuju → ponudi ažuriranje
4. Primjena → UPDATE current_value na max pronađen

⚠️ VAŽNO: Nakon brisanja RN-a, pokrenite sync
za vraćanje brojača na stvarni max iz baze!
```

---

## 📋 Kompletan popis tablica (77) ⭐ AŽURIRANO 14.04.2026

Dobiven direktnom introspekcijom Supabase baze. Svi podaci RLS enabled.

### Core Production (15)
`prod_articles` (121 kol, 807 redaka) | `prod_customers` (144) | `prod_orders` (40 kol, 209) | `prod_work_orders` (44 kol, 191) | `prod_work_orders_cutting` (42 kol, 111) | `prod_work_orders_printing` (40 kol, 135) | `prod_shift_log` (201) | `prod_shift_details` (3378) | `prod_shift_substitutions` (367) | `prod_shift_reports` (760) | `prod_shift_notes` (0) | `prod_shift_statistics` (0) | `prod_bag_controls` (747) | `prod_tape_usage` (7712) | `prod_production_plans` (48)

### Inventory (10)
`prod_inventory_rolls` (2056) | `prod_inventory_strips` (884) | `prod_inventory_printed` (393) | `prod_inventory_foil` (71) | `prod_inventory_pop` (479) | `prod_inventory_gop` (3473) | `prod_inventory_pallets` (8) | `prod_inventory_consumed_rolls` (1443) | `prod_pop_consumption` (41) | `prod_palletization_patterns` (5)

### ESP32 / OEE / Machines (7)
`prod_machines` (7) | `prod_machine_counters` (15) | `prod_machine_counter_sync` (56) | `prod_machine_events` (1108) | `prod_downtime_categories` (7) | `prod_failure_reports` (24) | `prod_counters` (11)

### Dispatch (4)
`prod_dispatch` (11) | `prod_dispatch_items` (7) | `prod_dispatch_pallets` (209) | `prod_dispatch_returns` (0)

### Maintenance (6)
`prod_maintenance` (1) | `prod_maintenance_orders` (5) | `prod_maintenance_belts` (41) | `prod_maintenance_dropdowns` (7) | `prod_spare_parts` (0) | `prod_belts` (41)

### HR & Payroll (14)
`employees` (62) | `teams` (18) | `team_members` (43) | `shifts` (4) | `time_entries` (4) | `holidays` (28) | `rotation_patterns` (15) | `hour_types` (13) | `tax_brackets` (2) | `contribution_rates` (4) | `payroll` (38 kol, 176) | `productivity` (30) | `productivity_bonus_rules` (2) | `bonuses` (105) | `monthly_hours` (24) | `work_hours` (0)

### Scheduling (3)
`prod_schedules` (834) | `prod_schedule_teams` (16) | `prod_schedule_members` (43)

### Auth & Config (8)
`prod_users` (19) | `prod_roles` (16) | `prod_settings` (0) | `settings` (70) | `prod_email_settings` (7) | `prod_email_recipients` (1) | `prod_dropdown_values` (38) | `prod_helper_values` (45)

### Ostalo (10)
`companies` (1) | `prod_paper_codes` (1585) | `prod_notifications` (7) | `prod_article_notes` (19) | `prod_order_comments` (0) | `prod_deletion_log` (0) | `prod_reserved_numbers` (0) | `app_counters` (6)

---

## 🔢 Sve GENERATED kolone (7) ⭐ AŽURIRANO 14.04.2026

| Tablica | Kolona | Formula |
|---------|--------|---------|
| `prod_orders` | `quantity_remaining` | `quantity_ordered - quantity_produced` |
| `prod_inventory_rolls` | `remaining_kg` | `initial_weight_kg - consumed_kg` |
| `prod_inventory_strips` | `remaining_kg` | `weight_kg - consumed_kg` |
| `prod_inventory_printed` | `remaining_kg` | `weight_kg - consumed_kg` |
| `prod_inventory_foil` | `remaining_kg` | `weight_kg - consumed_kg` |
| `prod_inventory_pop` | `quantity_available` | `quantity_in_stock - COALESCE(quantity_reserved, 0)` |
| `prod_maintenance` | `total_cost` | `(parts_cost + material_cost) + labor_cost` |

**⚠️ Nijednu od ovih kolona NE MOŽETE direktno upisati ili ažurirati!** Ažurirajte izvorne kolone.

---

## 🔧 Kompletan popis RPC funkcija (48) ⭐ AŽURIRANO 14.04.2026

### Work Order Approval
- `approve_work_order(p_work_order_id, p_approver_user_id, p_approver_name)` → json
- `reject_work_order(p_work_order_id, p_rejector_user_id, p_rejector_name, p_reason)` → json
- `resubmit_work_order(p_work_order_id)` → json

### Machine Counter (ESP32) ⭐ KRITIČNO
- `get_counter_status(p_machine_code)` → json
- `get_active_work_order(p_machine_code)` → json
- `start_machine_counter(p_machine_code, p_work_order_id, p_work_order_number, p_target_quantity)` → json
- `stop_machine_counter(p_machine_code, p_final_count)` → json
- `reset_machine_counter(p_machine_code)` → json
- `increment_machine_counter(p_machine_code, p_device_id, p_increment)` → json

### Tuber / Bottomer Status
- `complete_tuber_for_work_order(p_work_order_id)` → json ⭐ NOVO
- `reactivate_tuber_for_work_order(p_work_order_id)` → json
- `complete_bottomer_phase(p_work_order_id, p_phase)` → json
- `reactivate_bottomer_phase(p_work_order_id, p_phase)` → json

### OEE / Statistics
- `aggregate_shift_statistics(p_date)` → integer
- `calculate_speed_from_syncs(p_machine_code, p_production_date, p_shift_number)` → TABLE ⭐ NOVO
- `get_oee_target_speed(p_machine_type)` → integer ⭐ NOVO
- `cleanup_old_esp32_data(p_days)` → TABLE
- `daily_esp32_processing()` → text

### Dispatch
- `get_available_pallets_for_dispatch(p_order_number, p_article_code)` → TABLE
- `dispatch_pallets(p_dispatch_id, p_pallet_ids, p_user_name)` → jsonb
- `return_pallet(p_dispatch_id, p_gop_id, p_quantity, p_reason, p_notes, p_user_name)` → jsonb
- `get_order_dispatch_stats(p_order_number)` → jsonb

### POP Consumption
- `fn_auto_consume_pop()` → trigger
- `fn_manual_consume_pop(p_consumption_id, p_operator_name)` → jsonb

### ID Generatori
- `generate_next_number(p_counter_type)` → text
- `generate_shift_id(p_date, p_line, p_shift)` → text
- `generate_shift_detail_id()` → text
- `generate_maintenance_order_id()` → text
- `set_shift_detail_id()` → trigger

### Ostalo
- `check_user_access(p_email, p_page)` → boolean
- `calculate_palletization_pattern(p_bag_width, p_bag_length, p_pallet_type)` → text
- `get_palletization_pattern(p_pattern_code)` → json
- `create_notification(p_type, p_title, p_message, ...)` → uuid
- `get_unread_shift_notes(p_production_line, p_machine_type, p_days_back)` → TABLE

### Triggeri (15 - interni)
`update_updated_at_column`, `update_shift_log_updated_at`, `update_shift_reports_updated_at`, `update_shift_totals`, `update_pallet_status`, `update_roll_status`, `update_machine_counter_timestamp`, `update_consumed_rolls_timestamp`, `update_consumed_rolls_updated_at`, `update_maintenance_costs`, `update_maintenance_orders_timestamp`, `update_prod_plans_updated_at`, `update_spare_parts_stock`, `update_work_hours_timestamp`

---

## 👁️ Svi view-ovi (19) ⭐ AŽURIRANO 14.04.2026

### Operativni
- `v_active_orders` - Aktivne narudžbe s progressom
- `v_work_orders_overview` - Pregled svih RN-ova
- `v_articles_with_notes` - Artikli s pridruženim napomenama
- `v_inventory_rolls_summary` - Sažetak stanja rola papira
- `v_machine_counters` - Trenutno stanje brojača strojeva

### Dispatch
- `v_dispatch_summary` - Sažetak otprema
- `v_orders_dispatch_status` - Status otpreme po narudžbama

### OEE
- `v_oee_dashboard` - Glavni OEE dashboard
- `v_oee_daily_summary` - Dnevni OEE pregled
- `v_oee_monthly` - Mjesečni OEE
- `v_oee_operator_ranking` - Ranking operatera po OEE
- `v_oee_settings` - OEE konfiguracija
- `v_shift_reports_oee` - Smjenski izvještaji s OEE metrikama

### Maintenance
- `v_machines_maintenance_status` - Status održavanja strojeva
- `v_maintenance_costs_by_machine` - Troškovi održavanja po stroju
- `v_maintenance_orders_stats` - Statistika maintenance naloga
- `v_parts_low_stock` - Upozorenje za rezervne dijelove

### HR & Statistika
- `v_payroll_details` - Detalji plaća
- `v_monthly_line_stats` - Mjesečna statistika po linijama

---

## 🆕 Nove tablice identificirane 14.04.2026

Tablice koje nisu dokumentirane u prethodnim verzijama:

| Tablica | Kolone | Redovi | Svrha |
|---------|--------|--------|-------|
| `prod_notifications` | - | 7 | Sistem notifikacija (za `create_notification` RPC) |
| `prod_palletization_patterns` | - | 5 | Uzorci slaganja na palete (za `calculate_palletization_pattern`) |
| `prod_maintenance_dropdowns` | - | 7 | Dropdown vrijednosti za maintenance modul |
| `prod_helper_values` | - | 45 | Helper/konfiguracijske vrijednosti |
| `prod_belts` | - | 41 | Remeni (dupliranje s `prod_maintenance_belts`?) |
| `app_counters` | - | 6 | Aplikacijski brojači (app-level) |
| `prod_pop_consumption` | 20 | 41 | Rješava race condition Bottomer traži POP prije Tuber |
| `prod_dispatch_items` | - | 7 | Stavke otpreme |
| `prod_dispatch_pallets` | - | 209 | Palete po otpremi |
| `prod_dispatch_returns` | - | 0 | Povrati otpremljenih paleta |
| `prod_order_comments` | - | 0 | Komentari na narudžbe |

---

*Zadnje ažuriranje: 14. Travnja 2026 (sesija 2)*

### 14.04.2026 - Sesija 2 (workflow + traceability + FK) ⭐

**Nove tablice:**
- `prod_gop_pop_link` (gop_id, pop_id, quantity_used, created_by, created_at) - PK(gop_id,pop_id)
  - FK gop_id → prod_inventory_gop ON DELETE CASCADE
  - FK pop_id → prod_inventory_pop ON DELETE RESTRICT
  - Popunjava bottomer-slagac.skiniPOPSaStanja kad je proslijeđen gopId
- `prod_pop_roll_link` (pop_id, consumed_roll_id, layer_number, created_at) - PK(pop_id,consumed_roll_id)
  - FK pop_id → prod_inventory_pop ON DELETE CASCADE
  - FK consumed_roll_id → prod_inventory_consumed_rolls ON DELETE RESTRICT
  - Popunjava tuber-materijal.spremiSkidanje nakon evidencije potrošnje

**Nove kolone u prod_work_orders:**
- `produced_quantity INTEGER DEFAULT 0` - auto-sync iz GOP-a preko trigger-a
- `produced_pct NUMERIC(5,1) GENERATED ALWAYS AS` (quantity > 0: produced_quantity * 100.0 / quantity, else NULL)

**Novi FK constraints (RESTRICT - spriječava brisanje RN-a s produkcijom):**
- `prod_inventory_pop.work_order_id` → `prod_work_orders(id)`
- `prod_inventory_gop.work_order_id` → `prod_work_orders(id)`
- `prod_inventory_consumed_rolls.work_order_id` → `prod_work_orders(id)`

**Novi triggeri (5):**
- `trg_gop_sync_wo_produced` (AFTER INS/UPD/DEL na prod_inventory_gop) - sync produced_quantity u parent RN
- `trg_gop_dispatch_status_sync` (BEFORE UPDATE prod_inventory_gop WHEN dispatch_status changed) - auto-sync status i dispatched_at
- `trg_wo_rejected_notify` (AFTER UPDATE OF approval_status) - auto create_notification
- `trg_wo_under_produced_notify` (AFTER UPDATE OF status) - notification ako Završeno + produced_pct < 90
- `update_roll_status_trigger` (POPRAVLJEN) - funkcija sad računa remaining manualno umjesto čitanja GENERATED kolone

**Novi view + RPC:**
- `v_full_traceability` - denormalizirani view: GOP → POP → consumed_roll
- `trace_pallet(pallet_number TEXT)` RPC - agregirani trace za customer recall

**Update complete_bottomer_phase RPC:**
- Sad provjerava `tuber_status = 'Završeno'` prije dopuštanja završetka Bottomera
- Vraća `{success: false, error: 'Tuber faza nije završena'}` ako nije

**Ukupno tablica:** 79 (prije 77)
**Ukupno triggera:** ~21 (prije 16)
**Ukupno view-ova:** 20 (prije 19)
**Ukupno RPC funkcija:** 49 (prije 48)

---

### 14.04.2026 (direktna Supabase introspekcija)
- ⭐ **Ukupan broj tablica:** 77 (prije "70+")
- ⭐ **Ukupan broj view-ova:** 19 (prije "15+")
- ⭐ **Ukupan broj RPC funkcija:** 48 (dokumentirano 33 + 15 trigger funkcija)
- ⭐ **GENERATED kolone povećane na 7** (prije 3) - dodane: `strips.remaining_kg`, `printed.remaining_kg`, `foil.remaining_kg`, `maintenance.total_cost`
- ⭐ **prod_articles:** 121 kolona (prije 119)
- ⭐ **prod_work_orders:** 44 kolone (prije 48+)
- ⭐ **Nove tablice dokumentirane:** prod_notifications, prod_palletization_patterns, prod_maintenance_dropdowns, prod_helper_values, prod_belts, app_counters, prod_pop_consumption
- ⭐ **Nove RPC funkcije:** complete_tuber_for_work_order, calculate_speed_from_syncs, get_oee_target_speed, fn_auto_consume_pop, fn_manual_consume_pop, get_palletization_pattern, check_user_access, create_notification, get_unread_shift_notes
- ⭐ **Svi view-ovi kategorizirani:** Operativni, Dispatch, OEE, Maintenance, HR

### 11.02.2026
- ⭐ Dodane tablice prod_counters i prod_reserved_numbers
- ⭐ remaining_kg dokumentirana kao GENERATED kolona (prod_inventory_rolls)
- ⭐ sort_order kolona dodana u prod_orders
- ⭐ Ažurirana sekcija GENERATED kolone (3 ukupno)
- ⭐ Dodan sistem rezervacija POP-a (quantity_reserved, quantity_available)
- ⭐ Automatsko skidanje rezervacija pri dodavanju novog POP-a (tuber → bottomer)
- ⭐ SQL skripta za dodavanje kolona rezervacija u prod_inventory_pop
- ⭐ Dokumentirana ESP32 sinkronizacija i opasnost od resetiranja count-a
- ⭐ Dodano upozorenje o start_machine_counter UPSERT ponašanju
- ⭐ Dokumentirana ispravna logika za tuberZapocni()
- Dodane kolone bottomer_voditelj_status i bottomer_slagac_status u prod_work_orders
- Dodane RPC funkcije complete_bottomer_phase i reactivate_bottomer_phase
- Dodana kolona material_deducted u prod_inventory_pop
- Dodana tablica prod_inventory_consumed_rolls
- Dodane OEE tablice i RPC funkcije za ESP32
