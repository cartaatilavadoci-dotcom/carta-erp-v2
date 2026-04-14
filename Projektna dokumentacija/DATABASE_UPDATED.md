# CARTA ERP - Struktura Baze Podataka

## 📊 Pregled

- **Baza:** Supabase PostgreSQL
- **Ukupno tablica:** 70+
- **View-ova:** 15+
- **Najveće tablice:** prod_articles (119 kolona), prod_work_orders (48+ kolona), payroll (38)

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

#### prod_inventory_strips (15 kolona)
Rezane trake.

#### prod_inventory_printed (16 kolona)
Otisnute role.

#### prod_inventory_foil (11 kolona)
Folije.

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

*Zadnje ažuriranje: 11. Veljače 2026*
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
