# OVJERA RADNIH NALOGA - Implementacijska specifikacija

## Sažetak
Implementirati "four-eyes principle" za radne naloge - prije puštanja u proizvodnju, RN mora biti ovjeren od drugog admin/superadmin korisnika. Osoba koja je kreirala RN NE MOŽE isti odobriti.

---

## 1. SQL MIGRACIJA (izvršiti u Supabase SQL Editoru)

### 1.1 Nove kolone u prod_work_orders

```sql
-- ============================================
-- OVJERA RADNIH NALOGA - Migracija
-- ============================================

-- 1. Status ovjere
ALTER TABLE prod_work_orders 
ADD COLUMN IF NOT EXISTS approval_status TEXT DEFAULT 'Odobreno';
-- Default je 'Odobreno' da postojeći nalozi rade normalno

-- 2. Tko je kreirao (user_id iz prod_users)
ALTER TABLE prod_work_orders 
ADD COLUMN IF NOT EXISTS created_by_user_id UUID;

-- 3. Ime kreatora (za prikaz)
ALTER TABLE prod_work_orders 
ADD COLUMN IF NOT EXISTS created_by_name TEXT;

-- 4. Tko je odobrio
ALTER TABLE prod_work_orders 
ADD COLUMN IF NOT EXISTS approved_by_user_id UUID;

-- 5. Ime odobravatelja
ALTER TABLE prod_work_orders 
ADD COLUMN IF NOT EXISTS approved_by_name TEXT;

-- 6. Vrijeme ovjere
ALTER TABLE prod_work_orders 
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;

-- 7. Razlog odbijanja (ako je odbijeno)
ALTER TABLE prod_work_orders 
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- CHECK constraint
ALTER TABLE prod_work_orders 
ADD CONSTRAINT chk_approval_status
CHECK (approval_status IN ('Čeka ovjeru', 'Odobreno', 'Odbijeno'));

-- Index za brzo filtriranje
CREATE INDEX IF NOT EXISTS idx_wo_approval_status 
ON prod_work_orders(approval_status);

CREATE INDEX IF NOT EXISTS idx_wo_approval_pending 
ON prod_work_orders(approval_status) 
WHERE approval_status = 'Čeka ovjeru';

-- Retroaktivno: svi postojeći nalozi = Odobreno
UPDATE prod_work_orders 
SET approval_status = 'Odobreno' 
WHERE approval_status IS NULL;
```

### 1.2 RPC funkcija za odobravanje

```sql
-- ============================================
-- RPC: approve_work_order
-- ============================================
CREATE OR REPLACE FUNCTION approve_work_order(
  p_work_order_id UUID,
  p_approver_user_id UUID,
  p_approver_name TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_created_by UUID;
  v_current_status TEXT;
BEGIN
  -- Dohvati podatke o nalogu
  SELECT created_by_user_id, approval_status
  INTO v_created_by, v_current_status
  FROM prod_work_orders
  WHERE id = p_work_order_id;

  -- Provjera: nalog postoji?
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Radni nalog nije pronađen');
  END IF;

  -- Provjera: status mora biti 'Čeka ovjeru'
  IF v_current_status != 'Čeka ovjeru' THEN
    RETURN json_build_object('success', false, 'error', 'Nalog nije u statusu čekanja ovjere');
  END IF;

  -- Provjera: four-eyes - ista osoba NE MOŽE odobriti
  IF v_created_by IS NOT NULL AND v_created_by = p_approver_user_id THEN
    RETURN json_build_object('success', false, 'error', 'Ne možete odobriti nalog koji ste sami kreirali');
  END IF;

  -- Odobri
  UPDATE prod_work_orders
  SET approval_status = 'Odobreno',
      approved_by_user_id = p_approver_user_id,
      approved_by_name = p_approver_name,
      approved_at = NOW()
  WHERE id = p_work_order_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Radni nalog odobren'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION approve_work_order(UUID, UUID, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION approve_work_order(UUID, UUID, TEXT) TO authenticated;
```

### 1.3 RPC funkcija za odbijanje

```sql
-- ============================================
-- RPC: reject_work_order
-- ============================================
CREATE OR REPLACE FUNCTION reject_work_order(
  p_work_order_id UUID,
  p_rejector_user_id UUID,
  p_rejector_name TEXT,
  p_reason TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_status TEXT;
BEGIN
  SELECT approval_status INTO v_current_status
  FROM prod_work_orders WHERE id = p_work_order_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Radni nalog nije pronađen');
  END IF;

  IF v_current_status != 'Čeka ovjeru' THEN
    RETURN json_build_object('success', false, 'error', 'Nalog nije u statusu čekanja ovjere');
  END IF;

  UPDATE prod_work_orders
  SET approval_status = 'Odbijeno',
      approved_by_user_id = p_rejector_user_id,
      approved_by_name = p_rejector_name,
      approved_at = NOW(),
      rejection_reason = p_reason
  WHERE id = p_work_order_id;

  RETURN json_build_object('success', true, 'message', 'Radni nalog odbijen');
END;
$$;

GRANT EXECUTE ON FUNCTION reject_work_order(UUID, UUID, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION reject_work_order(UUID, UUID, TEXT, TEXT) TO authenticated;
```

### 1.4 RPC za ponovno slanje na ovjeru (nakon odbijanja)

```sql
-- ============================================
-- RPC: resubmit_work_order
-- ============================================
CREATE OR REPLACE FUNCTION resubmit_work_order(
  p_work_order_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_status TEXT;
BEGIN
  SELECT approval_status INTO v_current_status
  FROM prod_work_orders WHERE id = p_work_order_id;

  IF v_current_status != 'Odbijeno' THEN
    RETURN json_build_object('success', false, 'error', 'Samo odbijeni nalozi se mogu ponovo poslati');
  END IF;

  UPDATE prod_work_orders
  SET approval_status = 'Čeka ovjeru',
      approved_by_user_id = NULL,
      approved_by_name = NULL,
      approved_at = NULL,
      rejection_reason = NULL
  WHERE id = p_work_order_id;

  RETURN json_build_object('success', true, 'message', 'Nalog ponovo poslan na ovjeru');
END;
$$;

GRANT EXECUTE ON FUNCTION resubmit_work_order(UUID) TO anon;
GRANT EXECUTE ON FUNCTION resubmit_work_order(UUID) TO authenticated;
```

---

## 2. IZMJENE U POSTOJEĆIM DATOTEKAMA

### 2.1 config.js - Dodaj u NAV_ITEMS

Dodati novu stavku u sekciju 'Upravljanje' (PRIJE 'postavke'):
```javascript
{ id: 'ovjera-rn', icon: '✅', label: 'Ovjera RN', section: 'Upravljanje' },
```

### 2.2 config.js - Dodaj u DEFAULT_ROLES

Dodati 'ovjera-rn' SAMO u uloge admin i superadmin:
```javascript
'superadmin': ['*'],  // već ima sve
'admin': [...postojeće..., 'ovjera-rn'],
```

### 2.3 router.js - Dodaj view path mapping

```javascript
'ovjera-rn': 'views/upravljanje/ovjera-rn.html'
```

### 2.4 planiranje.html - Izmjene pri kreiranju RN-a

Kad se kreira novi radni nalog, MORA se postaviti:
```javascript
// Pri insertu novog radnog naloga dodaj:
created_by_user_id: Auth.getUser().id,   // UUID iz prod_users
created_by_name: Auth.getUser().name,     // Ime korisnika
approval_status: 'Čeka ovjeru'            // ← KLJUČNA PROMJENA
```

**PAZI:** Postojeća kolona `created_by` (TEXT) ostaje za backward compatibility. 
Nove kolone `created_by_user_id` i `created_by_name` su za ovjeru.

### 2.5 Proizvodni moduli - Filtriranje odobrenih naloga

U svim modulima koji prikazuju radne naloge za proizvodnju (tuber, bottomer, itd.), 
dodati filter:
```javascript
.eq('approval_status', 'Odobreno')
```

Moduli koji trebaju ovu izmjenu:
- tuber.html (dohvat naloga za pokretanje)
- bottomer-voditelj.html
- bottomer-slagac.html
- bottomer-wh.html
- bottomer-nli.html
- planiranje.html (vizualni prikaz statusa ovjere u listi)

### 2.6 prod_roles - Ažurirati u bazi

```sql
-- Dodaj 'ovjera-rn' u dozvole za admin ulogu
UPDATE prod_roles 
SET dozvole = jsonb_set(
  dozvole::jsonb, 
  '{0}', 
  -- dodaj 'ovjera-rn' u postojeći array
  -- ILI ručno ažuriraj JSON string dozvola u bazi
)
WHERE naziv = 'admin';
```
**NAPOMENA:** Bolje ručno dodati 'ovjera-rn' u JSON dozvola kroz Supabase dashboard jer je format TEXT s JSON-om.

---

## 3. NOVA STRANICA: views/upravljanje/ovjera-rn.html

### 3.1 Layout stranice

```
┌─────────────────────────────────────────────────────────────────────────┐
│  ✅ Ovjera radnih naloga                              [Filter ▼] [🔄] │
├───────────────────────────┬─────────────────────────────────────────────┤
│                           │                                             │
│  LISTA RN-ova             │  DETALJI ODABRANOG RN-a                     │
│  (lijevi panel)           │  (desni panel)                              │
│                           │                                             │
│  ┌───────────────────┐    │  ┌─────────────────────────────────────┐    │
│  │ 🟡 RN045/26       │    │  │ INFORMACIJE O NALOGU               │    │
│  │ Patent CO         │    │  │ Broj: RN045/26                      │    │
│  │ 50.000 kom        │    │  │ Narudžba: N012/26                   │    │
│  │ WH | 05.02.2026   │    │  │ Kupac: Patent CO                    │    │
│  │ Kreirao: Ana P.   │    │  │ Količina: 50.000 kom                │    │
│  ├───────────────────┤    │  │ Linija: WH                          │    │
│  │ 🟡 RN046/26       │    │  │ Kreirao: Ana Petrović               │    │
│  │ Heidelberg        │    │  │ Datum: 05.02.2026 08:23             │    │
│  │ 80.000 kom        │    │  └─────────────────────────────────────┘    │
│  │ NLI | 05.02.2026  │    │                                             │
│  │ Kreirao: Marko T. │    │  ┌─────────────────────────────────────┐    │
│  ├───────────────────┤    │  │ SPECIFIKACIJA ARTIKLA               │    │
│  │ 🟢 RN044/26       │    │  │                                     │    │
│  │ Odobreno ✅        │    │  │  ┌─────┐                            │    │
│  │ Patent CO         │    │  │  │     │ Širina: 47 cm              │    │
│  │ Odobrio: Atila V. │    │  │  │VREĆ.│ Visina: 83 cm              │    │
│  ├───────────────────┤    │  │  │     │ Dno: 14 cm                 │    │
│  │ 🔴 RN043/26       │    │  │  └─────┘ Ventil: OL                 │    │
│  │ Odbijeno ❌        │    │  │                                     │    │
│  │ Razlog: ...       │    │  │  Papir S1: S70-86-SE (70g, 86cm)    │    │
│  └───────────────────┘    │  │  Papir S2: S70-86-SE (70g, 86cm)    │    │
│                           │  │  Slojeva: 2                          │    │
│  Filter:                  │  │  Tip reza: ravan                     │    │
│  [Čeka] [Odobreno]       │  │  Duljina tuljka: 63.25 cm            │    │
│  [Odbijeno] [Sve]        │  │  Boja vreće: S (smeđa)               │    │
│                           │  │  Tisak: 4 boje                       │    │
│                           │  │  Pakiranje: 15 kom/paket             │    │
│                           │  │  Paleta: 5000 kom | 120x120          │    │
│                           │  └─────────────────────────────────────┘    │
│                           │                                             │
│                           │  ┌─────────────────────────────────────┐    │
│                           │  │ GRAFIČKA PRIPREMA (PDF)              │    │
│                           │  │                                     │    │
│                           │  │  ┌─────────────────────────────┐    │    │
│                           │  │  │                             │    │    │
│                           │  │  │   Google Drive PDF iframe   │    │    │
│                           │  │  │   (print_preparation_url)   │    │    │
│                           │  │  │                             │    │    │
│                           │  │  └─────────────────────────────┘    │    │
│                           │  │  [Otvori u novom tabu ↗]            │    │
│                           │  └─────────────────────────────────────┘    │
│                           │                                             │
│                           │  ┌─────────────────────────────────────┐    │
│                           │  │ OVJERA                               │    │
│                           │  │                                     │    │
│                           │  │  Kreirao: Ana Petrović               │    │
│                           │  │  Datum kreiranja: 05.02.2026 08:23  │    │
│                           │  │                                     │    │
│                           │  │  [✅ ODOBRI]    [❌ ODBIJ]          │    │
│                           │  │                                     │    │
│                           │  │  Komentar (obavezan za odbijanje):   │    │
│                           │  │  ┌───────────────────────────────┐  │    │
│                           │  │  │                               │  │    │
│                           │  │  └───────────────────────────────┘  │    │
│                           │  └─────────────────────────────────────┘    │
│                           │                                             │
│                           │  ┌─────────────────────────────────────┐    │
│                           │  │ POVIJEST OVJERE                      │    │
│                           │  │ • Kreiran: Ana P. - 05.02. 08:23    │    │
│                           │  │ • Odobren: Atila V. - 05.02. 09:15  │    │
│                           │  └─────────────────────────────────────┘    │
│                           │                                             │
├───────────────────────────┴─────────────────────────────────────────────┤
│  Čeka ovjeru: 2  |  Odobreno danas: 3  |  Odbijeno: 1                  │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Specifikacija artikla - Grafički prikaz

Prikazati SVG vizualizaciju vrećice s dimenzijama:
- Pravokutnik koji predstavlja vrećicu (bag_width × bag_length)
- Dno označeno (bag_bottom)
- Ventil označen (bag_valve, valve_type)
- Slojevi papira vizualno (S1, S2, S3, S4) s bojama
- Boja vrećice (bag_color)

### 3.3 Podaci za prikaz iz prod_articles

Kad korisnik odabere RN, dohvatiti puni artikl iz prod_articles po article_id:

**Dimenzije vrećice:**
- bag_width, bag_length, bag_bottom, bag_valve
- valve_type, valve_position
- tube_length, cut_type, finger_hole

**Papir po slojevima (S1-S4):**
- paper_s1_code, paper_s1_width, paper_s1_grammage
- paper_s2_code, paper_s2_width, paper_s2_grammage
- paper_s3_code, paper_s3_width, paper_s3_grammage
- paper_s4_code, paper_s4_width, paper_s4_grammage

**Ventil:**
- valve_s1_paper_code, valve_s1_width, valve_s1_grammage, valve_s1_length
- valve_s2_paper_code, valve_s2_width, valve_s2_grammage, valve_s2_length

**Dno i vrh:**
- top_paper_code, top_width, top_grammage, top_length
- bottom_paper_code, bottom_width, bottom_grammage, bottom_length
- top_double_overlap, bottom_double_overlap

**Folija:**
- foil_code, foil_width, foil_microns, foil_type

**Tisak:**
- colors_count, print_colors_count
- print_color_1 ... print_color_6
- cliche_thickness, duplofan_thickness

**Pakiranje:**
- pcs_per_package, pcs_per_pallet, pallet_type, packaging_type

**Perforacije:**
- perforation_s1, perforation_s2, perforation_s3, perforation_s4
- perforation_valve, perforation_valve_type

**PDF grafička priprema:**
- print_preparation_url (Google Drive /preview URL → <iframe>)

### 3.4 Stilovi

Slijediti CARTA ERP konvencije:
- Sve CSS INLINE u HTML datoteci
- Sav JS INLINE u HTML datoteci
- Mobile-first responsive
- Badge boje:
  - Čeka ovjeru: #FFF3E0 pozadina, #E65100 tekst (narančasto)
  - Odobreno: #E8F5E9 pozadina, #2E7D32 tekst (zeleno)
  - Odbijeno: #FFEBEE pozadina, #C62828 tekst (crveno)

### 3.5 Funkcionalnosti

1. **Učitavanje liste RN-ova**
   - Default filter: 'Čeka ovjeru'
   - Sortiranje: najnoviji prvi
   - Badge za svaki status
   - Prikaz broja RN-ova po statusu u footeru

2. **Odabir RN-a → prikaz detalja**
   - Dohvati RN iz prod_work_orders
   - Dohvati artikl iz prod_articles po article_id
   - Prikaži SVG vizualizaciju vrećice
   - Prikaži PDF iframe (print_preparation_url)
   - Prikaži info o kreatoru

3. **Odobravanje**
   - Pozovi RPC approve_work_order
   - Four-eyes provjera: ako je current user = creator → blokiraj + poruka
   - Nakon odobravanja osvježi listu

4. **Odbijanje**
   - Obavezno polje za razlog
   - Pozovi RPC reject_work_order
   - Nakon odbijanja osvježi listu

5. **Badge counter u sidebaru** (opcionalno, ali preporučeno)
   - Prikazati broj naloga koji čekaju ovjeru kraj "Ovjera RN" u navigaciji
   - Npr: "✅ Ovjera RN (3)"

---

## 4. GOOGLE DRIVE PDF EMBED

PDF-ovi su na Google Drive s /preview URL-ovima. Embed ovako:

```html
<iframe 
  src="https://drive.google.com/file/d/XXXXXX/preview" 
  width="100%" 
  height="500px"
  style="border: 1px solid #ddd; border-radius: 8px;"
  allow="autoplay">
</iframe>
```

Ako artikl NEMA print_preparation_url, prikazati placeholder:
```html
<div style="padding: 40px; text-align: center; color: #999; background: #f5f5f5; border-radius: 8px;">
  📄 Grafička priprema nije učitana za ovaj artikl
</div>
```

---

## 5. KONTROLNA LISTA

### Prije deployanja provjeriti:
- [ ] SQL migracija izvršena (sve kolone, RPC funkcije, indeksi)
- [ ] config.js: 'ovjera-rn' dodan u NAV_ITEMS i DEFAULT_ROLES
- [ ] router.js: path mapping za ovjera-rn
- [ ] prod_roles tablica: 'ovjera-rn' dodano u admin dozvole
- [ ] planiranje.html: kreiranje RN-a postavlja created_by_user_id, created_by_name, approval_status='Čeka ovjeru'
- [ ] Proizvodni moduli: filtrirani na approval_status='Odobreno'
- [ ] ovjera-rn.html: kreiran i testiran
- [ ] Four-eyes provjera radi (ista osoba ne može odobriti)
- [ ] PDF embed radi za artikle s print_preparation_url
- [ ] Mobile responsive testiran
- [ ] Svi postojeći nalozi imaju approval_status='Odobreno'

### Redoslijed implementacije:
1. **Prvo:** SQL migracija u Supabase
2. **Drugo:** Izmjene u config.js, router.js
3. **Treće:** Nova stranica ovjera-rn.html
4. **Četvrto:** Izmjene u planiranje.html (kreiranje RN-a)
5. **Peto:** Izmjene u proizvodnim modulima (filter)
6. **Zadnje:** Testiranje cijelog workflow-a

---

## 6. PODACI IZ BAZE ZA KONTEKST

### Postojeće kolone prod_work_orders (36 kolona):
```
id, wo_number, wo_type, order_number, customer_name, article_name,
article_id, article_code, quantity, status, production_line,
created_at, started_at, completed_at, valve_type, bag_width,
bag_length, bag_bottom, specs, operator, notes, created_by,
updated_at, planned_start_date, planned_start_shift,
planned_duration_shifts, machine, sort_order, produced_kg,
tuber_status, tuber_completed_at, bottomer_voditelj_status,
bottomer_slagac_status, bottomer_voditelj_completed_at,
bottomer_slagac_completed_at, paper_suffix_override
```

### Trenutni statusi RN-ova:
- Završeno: 44
- Planiran: 6
- U tijeku: 5
- NAPOMENA: created_by je prazan za sve postojeće naloge

### prod_articles ima 119 kolona (778 artikala)
- 240 artikala ima print_preparation_url (Google Drive /preview linkovi)
- Kolone detaljno popisane u sekciji 3.3

### Supabase URL:
```
https://gusudzydgofdcywmvwbh.supabase.co
```

### Autentikacija:
```javascript
// Trenutni korisnik se dobije ovako:
const user = Auth.getUser();
// user.id = UUID iz prod_users
// user.name = ime korisnika
// user.role = 'admin' | 'superadmin' | ...

// Provjera prava:
Auth.isAdmin() // true za admin i superadmin
```

---

## 7. SAŽETAK PROMJENA PO DATOTEKAMA

| Datoteka | Promjena |
|----------|----------|
| **BAZA (SQL)** | Nove kolone, 3 RPC funkcije, indeksi |
| **config.js** | NAV_ITEMS + DEFAULT_ROLES |
| **router.js** | View path mapping |
| **prod_roles (baza)** | Dodati 'ovjera-rn' u admin dozvole |
| **planiranje.html** | Pri kreiranju RN: approval_status, created_by_* |
| **tuber.html** | Filter: .eq('approval_status', 'Odobreno') |
| **bottomer-voditelj.html** | Filter: .eq('approval_status', 'Odobreno') |
| **bottomer-slagac.html** | Filter: .eq('approval_status', 'Odobreno') |
| **bottomer-wh.html** | Filter: .eq('approval_status', 'Odobreno') |
| **bottomer-nli.html** | Filter: .eq('approval_status', 'Odobreno') |
| **NOVA: ovjera-rn.html** | Kompletna nova stranica |
