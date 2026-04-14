# CARTA ERP - Shema Aplikacije (Dodatak 01.02.2026)

## 📋 Smjenski izvještaji - Tuber i Bottomer ⭐ AŽURIRANO

### Struktura kolona izvještaja

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SMJENSKI IZVJEŠTAJ - STRUKTURA KOLONA                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  KOLONE 1-3 (iz proizvodnje - UVIJEK svježi podaci):                        │
│  ─────────────────────────────────────────────────                          │
│  1. Br. Naloga    - RN broj iz prod_shift_details                           │
│  2. Opis          - Naziv artikla                                           │
│  3. Količina (kom)- Suma proizvedenih komada u smjeni                       │
│                                                                             │
│  KOLONE 4-11 (ručni unos - sprema se u bazu):                               │
│  ────────────────────────────────────────────                               │
│  4. Škart (kg)                                                              │
│  5. Preštel.      - Vrijeme preštelavanja (h)                               │
│  6. Rad           - Vrijeme rada (h)                                        │
│  7. Kvar          - Vrijeme kvara (h)                                       │
│  8. Čekanje tiska*    - Čekanje na tisak (h) [Tuber]                        │
│     Čekanje tuljke*   - Čekanje na tuljke (h) [Bottomer]                    │
│  9. Rad van stroja    - Rad van stroja (h)                                  │
│ 10. Čekanje bottomera* - Čekanje na bottomer (h) [Tuber]                    │
│     Čekanje*          - Ostalo čekanje (h) [Bottomer]                       │
│ 11. Čišćenje      - Vrijeme čišćenja (h)                                    │
│                                                                             │
│  * Nazivi kolona se razlikuju između Tuber i Bottomer modula                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Logika učitavanja i spremanja

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WORKFLOW SMJENSKOG IZVJEŠTAJA                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. OTVARANJE IZVJEŠTAJA (generirajTuberIzvjestaj / generirajIzvjestaj)     │
│     │                                                                       │
│     ├─► Dohvati proizvodne podatke iz prod_shift_details                    │
│     │   (grupirano po work_order_number)                                    │
│     │                                                                       │
│     ├─► Provjeri postoji li spremljeni izvještaj u prod_shift_reports       │
│     │   .eq('production_line', LINIJA)                                      │
│     │   .eq('machine_type', 'Tuber' ili 'Bottomer')                         │
│     │   .eq('shift_date', danas)                                            │
│     │   .eq('shift_number', smjena)                                         │
│     │                                                                       │
│     └─► Generiraj tablicu:                                                  │
│         - Kolone 1-3: UVIJEK iz proizvodnje                                 │
│         - Kolone 4-11: iz spremljenog izvještaja AKO POSTOJI                │
│                                                                             │
│  2. SPREMANJE (spremiTuberIzvjestaj / spremiIzvjestaj)                      │
│     │                                                                       │
│     ├─► Prikupi sve podatke iz forme                                        │
│     │                                                                       │
│     ├─► Provjeri postoji li zapis za tu smjenu                              │
│     │   └─► DA: UPDATE postojećeg zapisa                                    │
│     │   └─► NE: INSERT novog zapisa                                         │
│     │                                                                       │
│     └─► Spremi u prod_shift_reports                                         │
│                                                                             │
│  3. OSVJEŽAVANJE (klik na "Osvježi")                                        │
│     │                                                                       │
│     └─► Ponovno učitaj - kolone 1-3 se osvježe iz proizvodnje,              │
│         kolone 4-11 ostaju iz spremljenog izvještaja                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Vizualni indikatori

```
Zelena pozadina (#e8f5e9) = Podaci iz trenutne proizvodnje
Plava pozadina (#e3f2fd)  = Podaci učitani iz spremljenog izvještaja
```

---

## ⚠️ ZamjenePostave - GLOBALNI OBJEKT ⭐ NOVO

### Problem

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ZAMJENEPOSTAVE - GLOBALNI OBJEKT                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ZamjenePostave je definiran u zamjene-postave.js i DIJELE GA SVI MODULI!   │
│                                                                             │
│  ZamjenePostave.data sadrži:                                                │
│  ─────────────────────────                                                  │
│  {                                                                          │
│    postava_broj: 3,                                                         │
│    linija: 'NLI',          // ← Može biti WH ili NLI                        │
│    stroj_tip: 'Bottomer',  // ← Može biti Tuber ili Bottomer                │
│    smjena: 2,                                                               │
│    clanovi: [...],                                                          │
│    zamjene: [...]                                                           │
│  }                                                                          │
│                                                                             │
│  ⚠️ PROBLEM:                                                                │
│  Ako korisnik otvori Bottomer stranicu, pa se vrati na Tuber,               │
│  ZamjenePostave.data još uvijek sadrži Bottomer podatke!                    │
│                                                                             │
│  ❌ KRIVO (originalni kod):                                                 │
│  if (ZamjenePostave.data.clanovi.length > 0) {                              │
│    // Koristi članove - ALI TO MOGU BITI BOTTOMER ČLANOVI!                  │
│  }                                                                          │
│                                                                             │
│  ✅ ISPRAVNO:                                                               │
│  // Opcija 1: Koristi modul-specifičnu varijablu                            │
│  if (window.tuberTrenutnaSmjenaData.djelatnici.length > 0) {                │
│    // Koristi Tuber djelatnike                                              │
│  }                                                                          │
│                                                                             │
│  // Opcija 2: Provjeri stroj_tip i liniju                                   │
│  if (ZamjenePostave.data.stroj_tip === 'Tuber' &&                           │
│      ZamjenePostave.data.linija === window.LINIJA) {                        │
│    // Sigurno su Tuber podaci                                               │
│  }                                                                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Modul-specifične varijable

| Modul | Varijabla | Sadržaj |
|-------|-----------|---------|
| tuber.html | `window.tuberTrenutnaSmjenaData` | `{ postava_broj, djelatnici: [...] }` |
| bottomer-voditelj.html | Direktni dohvat iz baze | N/A |

---

## 📊 Ažurirani moduli (26.01.2026)

### tuber.html
```
Promjene:
1. Nazivi kolona u izvještaju:
   - "Čekanje tuljke" → "Čekanje tiska"
   - "Čekanje" → "Čekanje bottomera"
   - Dodani <br> prelomi za duže nazive

2. Dinamička linija u izvještaju:
   - Dodano id="izvjestajLinija"
   - Postavlja se iz window.LINIJA

3. Dohvat postave u izvještaju:
   - Koristi SAMO window.tuberTrenutnaSmjenaData
   - Uklonjena ovisnost o ZamjenePostave

4. Logika učitavanja:
   - Kolone 1-3: UVIJEK iz proizvodnje
   - Kolone 4-11: Iz spremljenog izvještaja
```

### bottomer-voditelj.html
```
Promjene:
1. Logika učitavanja izvještaja:
   - Kolone 1-3 (Br. Naloga, Opis, Proizvedena količina): UVIJEK iz proizvodnje
   - Kolone 4-11: Iz spremljenog izvještaja

2. Dodano machine_type='Bottomer' u filtere za prod_shift_reports
```

---

## 📐 Formula za skidanje papira sa stanja ⭐ NOVO 01.02.2026

### Glavna formula

```javascript
const skidanje = (pop * sirina * gramatura * rez) / 10000000;
```

### Varijable

| Varijabla | Značenje | Mjerna jedinica | Izvor |
|-----------|----------|-----------------|-------|
| **pop** | Broj proizvedenih tuljaka | komada | Ručni unos operatera |
| **sirina** | Širina papira | cm | Iz artikla (`paper_s1_width`, ...) |
| **gramatura** | Gramatura papira | g/m² | Iz artikla (`paper_s1_grammage`, ...) |
| **rez** | Duljina reza (tuljka) | cm | Izračunava se iz dimenzija artikla |

### Izračun REZ vrijednosti

```javascript
if (valveType === 'OL') {
  // OL ventil: dužina + pola dna + 2 cm
  rez = bag_length + (bag_bottom / 2) + 2;
} else {
  // Ostali tipovi: dužina + dno + 4 cm
  rez = bag_length + bag_bottom + 4;
}
```

### Matematička raščlamba

```
Djelitelj 10.000.000 proizlazi iz:
- 10.000 = pretvorba cm² → m²
- 1.000 = pretvorba g → kg

Masa [kg] = (POP × širina[cm] × gramatura[g/m²] × rez[cm]) / 10.000.000
```

### Primjer izračuna

```
POP = 5.000 tuljaka
Širina = 72 cm
Gramatura = 70 g/m²
REZ = 67 cm

skidanje = (5.000 × 72 × 70 × 67) / 10.000.000
         = 1.688.400.000 / 10.000.000
         = 168,84 kg
```

---

## 🔄 Workflow skidanja materijala sa stanja ⭐ NOVO 01.02.2026

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     WORKFLOW SKIDANJA MATERIJALA                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. PROIZVODNJA POP-a (tuberDodajProizvodnju)                               │
│     ├─► Operater unosi količinu proizvedenih tuljaka                        │
│     ├─► Sprema se u prod_inventory_pop                                      │
│     ├─► material_deducted = false (default)                                 │
│     └─► ⚠️ MATERIJAL SE NE SKIDA AUTOMATSKI!                                │
│                                                                             │
│  2. ZAVRŠETAK SMJENE ili NALOGA                                             │
│     ├─► Operater klikne "Završi smjenu" ili "Završi nalog"                  │
│     ├─► Sustav dohvati sve POP-ove gdje material_deducted = false           │
│     └─► Otvara se tuber-materijal modul                                     │
│                                                                             │
│  3. EVIDENCIJA MATERIJALA (tuber-materijal modul)                           │
│     ├─► Operater skenira/odabire role korištene za proizvodnju              │
│     ├─► Sustav izračunava skidanje po formuli                               │
│     └─► Operater potvrđuje                                                  │
│                                                                             │
│  4. SKIDANJE SA STANJA (spremiSkidanje)                                     │
│     ├─► Za svaki sloj (1-4):                                                │
│     │   ├─► Izračunaj: (POP × širina × gramatura × REZ) / 10.000.000        │
│     │   ├─► UPDATE inventar: consumed_kg += skidanje                        │
│     │   ├─► Ako remaining_kg < 20: status = 'Utrošeno'                      │
│     │   └─► INSERT u prod_inventory_consumed_rolls (evidencija)             │
│     └─► UPDATE prod_inventory_pop: material_deducted = true                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Tablice uključene u proces

| Redoslijed | Tablica | Operacija | Svrha |
|------------|---------|-----------|-------|
| 1 | `prod_inventory_pop` | INSERT | Sprema proizvedene tuljke |
| 2 | `prod_inventory_pop` | SELECT | Dohvaća POP-ove za skidanje |
| 3 | `prod_inventory_rolls/strips/printed/foil` | SELECT | Dohvaća trenutno stanje |
| 4 | `prod_inventory_rolls/strips/printed/foil` | UPDATE | Ažurira consumed_kg, status |
| 5 | `prod_inventory_consumed_rolls` | INSERT | Evidencija potrošnje (audit) |
| 6 | `prod_inventory_pop` | UPDATE | Označava material_deducted = true |

---

## 🔍 Skeniranje šifre materijala ⭐ NOVO 01.02.2026

### Workflow skeniranja

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     SKENIRANJE ŠIFRE MATERIJALA                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. UNOS ŠIFRE                                                              │
│     └─► Operater skenira barkod ili ručno upiše šifru                       │
│                                                                             │
│  2. TRAŽENJE U BAZI (pronadiMaterijal)                                      │
│     ├─► Korak 1: Probaj ORIGINALNI barkod                                   │
│     │   └─► Ako pronađeno → GOTOVO ✅                                       │
│     │                                                                       │
│     ├─► Korak 2: TRANSFORMACIJA 1 (Billerud rotacija)                       │
│     │   └─► Prebaci zadnja 2 znaka naprijed + skrati za 2                   │
│     │   └─► Ako pronađeno → GOTOVO ✅                                       │
│     │                                                                       │
│     └─► Korak 3: TRANSFORMACIJA 2 (pozicije 2-10)                           │
│         └─► Izvuci znakove 2-10 iz barkoda                                  │
│         └─► Ako pronađeno → GOTOVO ✅                                       │
│                                                                             │
│  3. DETEKCIJA TIPA (detektirajTipMaterijala)                                │
│     ├─► T- ili TIS → prod_inventory_printed (otiskane role)                 │
│     ├─► R- → prod_inventory_strips (izrezane trake)                         │
│     ├─► F → prod_inventory_foil (folija)                                    │
│     ├─► S ili B → prod_inventory_strips (trake)                             │
│     └─► Ostalo → prod_inventory_rolls (sirove role)                         │
│                                                                             │
│  4. ODABIR SLOJA (popup)                                                    │
│     ├─► Operater odabire sloj (S1, S2, S3, S4)                              │
│     ├─► Označava je li rola POTPUNO POTROŠENA                               │
│     └─► Potvrda → Dodaj u listu skeniranih materijala                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Transformacije barkoda

#### Transformacija 1: Billerud rotacija
```javascript
// Prebaci zadnja 2 znaka naprijed, zatim skrati za 2
var temp = barkod.slice(-2) + barkod.slice(0, -2);
var transform1 = temp.slice(0, -2);

// Primjer: "1234567890" → "9012345678" → "90123456"
```

#### Transformacija 2: Pozicije 2-10
```javascript
// Izvuci znakove na pozicijama 2-10 (0-indexed: 1-9)
var transform2 = barkod.substring(1, 10);

// Primjer: "A123456789XYZ" → "123456789"
```

### Detekcija tipa materijala po prefixu

| Prefix | Tablica | Tip | Opis |
|--------|---------|-----|------|
| `T-` | `prod_inventory_printed` | printed | Otiskana rola |
| `TIS` | `prod_inventory_printed` | printed | Otiskana rola (legacy) |
| `R-` | `prod_inventory_strips` | strips | Izrezana traka |
| `F` | `prod_inventory_foil` | foil | Folija |
| `S` ili `B` | `prod_inventory_strips` | strips | Traka |
| *ostalo* | `prod_inventory_rolls` | rolls | Sirova rola (default) |

---

## 🏭 Tuber-Materijal v2 - Smart Material Deduction ⭐ AŽURIRANO 05.02.2026

### Glavne značajke

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TUBER-MATERIJAL v2 - ZNAČAJKE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. AUTOMATSKI DOHVAT MATERIJALA                                            │
│     ├─► Traži u prod_inventory_consumed_rolls po article_id                 │
│     ├─► Fallback na article_name ako nema article_id                        │
│     └─► Fallback na work_order_number ako nema artikla                      │
│                                                                             │
│  2. 4 SLOJA PAPIRA (S1-S4)                                                  │
│     ├─► Automatski učitava paper_s1_code do paper_s4_code iz artikla        │
│     ├─► Svaki sloj ima: šifra, širina, gramatura                            │
│     └─► Više materijala po sloju (npr. 2 role za S1)                        │
│                                                                             │
│  3. DODATNI SLOJEVI (dodatniSlojevi[])                                      │
│     ├─► Za situacije kad treba više materijala od 4 sloja                   │
│     ├─► Dinamički dodavanje (npr. S2b za drugu vrstu papira)                │
│     └─► Ručni unos materijala koji nije u sustavu                           │
│                                                                             │
│  4. FILTERI I PROŠIRENJE                                                    │
│     ├─► Filter po proizvođaču/dobavljaču (Billerud, Mondi, itd.)            │
│     ├─► Proširenje širine: točna, +5cm, +10cm, sve                          │
│     └─► Drugi tip papira: SE↔KR, SE↔PR, itd.                                │
│                                                                             │
│  5. OZNAČAVANJE POTROŠNJE                                                   │
│     ├─► Checkbox "Potpuno potrošena" za svaki materijal                     │
│     ├─► Označene role → status='Utrošeno', remaining_kg=0                   │
│     └─► Neoznačene → djelomično skidanje, ostatak na roli                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Kontekst (materijalKontekst)

```javascript
var materijalKontekst = {
  tip: 'nalog',           // 'nalog' ili 'smjena'
  linija: 'NLI',          // 'NLI' ili 'WH'
  workOrderId: 'uuid',    // ID radnog naloga
  workOrderNumber: 'RN001/26',
  orderNumber: 'N-001/26', // Broj narudžbe
  articleId: 'uuid',       // ID artikla
  articleName: 'Naziv',
  articleData: {...},      // Cijeli objekt artikla
  proizvedenoPOP: 5000,    // Broj proizvedenih tuljaka
  rez: 67.5,              // Izračunata duljina reza (cm)
  popIds: [...]           // ID-ovi POP-ova za označavanje
};
```

### Struktura slojeva

```javascript
var slojevi = {
  1: { paperCode: 'B70-72-SE', sirina: 72, gramatura: 70, materijali: [], autoLoaded: false },
  2: { paperCode: 'S80-72-KR', sirina: 72, gramatura: 80, materijali: [], autoLoaded: false },
  3: { paperCode: null, sirina: null, gramatura: null, materijali: [], autoLoaded: false },
  4: { paperCode: null, sirina: null, gramatura: null, materijali: [], autoLoaded: false }
};

// Svaki materijal u materijali[] ima strukturu:
{
  id: 'uuid',
  sifra: 'B70-72-SE-12345',
  tip: 'roll',           // 'roll', 'strip', 'printed', 'foil'
  tablica: 'prod_inventory_rolls',
  sirina: 72,
  gramatura: 70,
  preostalo: 150.5,      // kg na roli
  potpunoPotrosena: false,  // checkbox stanje
  manualEntry: false     // true za ručno unesene
}
```

### Logika spremanja (spremiSkidanje)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    LOGIKA SPREMANJA SKIDANJA                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ZA SVAKI SLOJ:                                                             │
│  │                                                                          │
│  ├─► Izračunaj POTREBNO: (POP × širina × gramatura × REZ) / 10.000.000     │
│  ├─► Izračunaj DODANO: suma svih preostalo kg                               │
│  ├─► Izračunaj OZNAČENO: suma preostalo kg gdje potpunoPotrosena=true       │
│  │                                                                          │
│  ├─► Ako ima OZNAČENIH:                                                     │
│  │   └─► ostatak = označeno - potrebno                                      │
│  ├─► Ako NEMA OZNAČENIH:                                                    │
│  │   └─► ostatak = dodano - potrebno                                        │
│  │                                                                          │
│  └─► ZA SVAKI MATERIJAL:                                                    │
│      │                                                                      │
│      ├─► Ako OZNAČEN (potpunoPotrosena=true):                               │
│      │   ├─► UPDATE: status='Utrošeno', remaining_kg=0                      │
│      │   └─► INSERT evidencija: consumption_type='full'                     │
│      │                                                                      │
│      └─► Ako NEOZNAČEN i prima ostatak:                                     │
│          ├─► potrošeno = preostalo - ostatak                                │
│          ├─► UPDATE: remaining_kg=ostatak, consumed_kg=potrošeno            │
│          ├─► status = ostatak<20 ? 'Utrošeno' : 'Djelomično'                │
│          └─► INSERT evidencija: consumption_type='partial'                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Tablica prod_inventory_consumed_rolls

| Kolona | Tip | Opis |
|--------|-----|------|
| source_roll_id | UUID | ID izvorne role |
| roll_code | TEXT | Šifra role |
| source_table | TEXT | Izvorna tablica (rolls/strips/printed/foil/manual_entry) |
| material_type | TEXT | Tip materijala |
| width_cm | NUMERIC | Širina u cm |
| grammage | NUMERIC | Gramatura g/m² |
| consumed_kg | NUMERIC | Potrošeno kg |
| remaining_kg | NUMERIC | Ostatak kg |
| work_order_id | UUID | ID radnog naloga |
| work_order_number | TEXT | Broj radnog naloga |
| article_name | TEXT | Naziv artikla |
| layer_number | INT | Broj sloja (1-4) |
| pop_quantity | INT | Broj POP-ova |
| production_line | TEXT | Linija (NLI/WH) |
| shift_date | DATE | Proizvodni datum |
| consumption_type | TEXT | 'full' ili 'partial' |

### Filtriranje materijala po tipu papira

```javascript
// Tipovi papira (sufiks u šifri)
var sviTipovi = ['SE', 'KR', 'PR', 'HP', 'HD', 'MG', 'MF', 'NS', 'NL'];

// Parsiranje šifre: B70-72-SE
var paperCode = 'B70-72-SE';
var parts = paperCode.split('-');
var paperPrefix = parts[0];      // 'B70'
var paperWidth = parts[1];       // '72'
var paperSuffix = parts[2];      // 'SE'

// Filtriranje dostupnih materijala
// Ako "Drugi tip" uključen → prikaži sve tipove osim trenutnog
// Ako "Drugi tip" isključen → prikaži samo materijale s istim sufiksom
```

---

---

## ⚖️ Rezač - Override težine role ⭐ NOVO 11.02.2026

### Problem
Ako je u prošlosti krivo skinuta količina sa role, remaining_kg ne odgovara stvarnosti.
Operater treba mogućnost ručne korekcije.

### Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    REZAČ - OVERRIDE TEŽINE ROLE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. PRISTUP                                                                 │
│     ├─► Iz tablice rola: ⚖️ gumb za svaku rolu                             │
│     └─► Iz workflow-a: ⚖️ Korekcija gumb nakon skeniranja/unosa            │
│                                                                             │
│  2. MODAL                                                                   │
│     ├─► Prikazuje: šifra, početna težina, potrošeno, preostalo             │
│     ├─► Unos nove težine (kg)                                               │
│     └─► Razlog korekcije (opcionalno)                                       │
│                                                                             │
│  3. SPREMANJE                                                               │
│     ├─► noviConsumedKg = initial_weight_kg - novaTezina                     │
│     ├─► UPDATE consumed_kg (NE remaining_kg - GENERATED!)                   │
│     ├─► status = novaTezina < 20 ? 'Utrošeno' : 'Djelomično'               │
│     └─► Ako rola u workflow-u → ažurira prikaz                              │
│                                                                             │
│  ⚠️ VAŽNO: remaining_kg je GENERATED kolona!                                │
│  Formula: initial_weight_kg - consumed_kg                                   │
│  NIKAD ne ažurirati remaining_kg direktno!                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 PVND - Metrike produktivnosti ⭐ NOVO 11.02.2026

### Metrike po liniji (NLI / WH)

| Metrika | Formula | Opis |
|---------|---------|------|
| **Sati rada** | unique(datum-smjena) × 8h | Svaka aktivna smjena = 8h |
| **Količina** | SUM(quantity) | Iz prod_shift_details (vrsta_unosa='GOP') |
| **kom/h** | količina / sati_rada | Produktivnost po satu |
| **Broj RN** | COUNT(DISTINCT wo_number) | Jedinstveni radni nalozi |
| **kom/RN** | količina / broj_rn | Produktivnost po nalogu |

### Izračun sati rada

```javascript
// Pristup: broji unique (datum + smjena) kombinacije iz sirovih podataka
const nliShiftSet = new Set();  // 'YYYY-MM-DD-1', 'YYYY-MM-DD-2', ...
const nliDaySet = new Set();    // Dani bez smjena (fallback)

monthGop.forEach(g => {
  const day = g.datum;
  const smjena = g.smjena || 0;
  if (smjena) nliShiftSet.add(`${day}-${smjena}`);
  else nliDaySet.add(day);
});

// Fallback: dani bez smjena koji nemaju poznate smjene
let nliExtraDays = 0;
nliDaySet.forEach(d => {
  if (![...nliShiftSet].some(s => s.startsWith(d + '-'))) nliExtraDays++;
});

const nliSatiRada = (nliShiftSet.size + nliExtraDays) * 8;
```

---

## 🔄 Sinkronizacija brojača - Bidirekcijska ⭐ NOVO 11.02.2026

### Staro ponašanje
```javascript
// Samo POVEĆAVANJE - ne dozvoljava smanjivanje
const newValue = Math.max(currentValue, maxFound);
const needsUpdate = newValue > currentValue;
```

### Novo ponašanje
```javascript
// BIDIREKCIJSKO - dozvoljava i smanjivanje (npr. nakon brisanja RN)
const newValue = maxFound;
const needsUpdate = newValue !== currentValue;
const isDecrease = newValue < currentValue;
```

### Vizualni indikatori
- **⚠️ Potrebno ažurirati** (narančasto) - brojač treba povećati
- **🔻 Smanjiti** (crveno) - brojač treba smanjiti (nakon brisanja RN)
- **✅ OK** (zeleno) - brojač je sinkroniziran

---

## 📋 Sortiranje narudžbi ⭐ NOVO 11.02.2026

### sort_order kolona u prod_orders
```sql
ALTER TABLE prod_orders ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0;
```

### Logika sortiranja
```javascript
// Primarni sort: sort_order (0 = na kraj)
const sortA = a.sort_order || 99999;
const sortB = b.sort_order || 99999;
if (sortA !== sortB) return sortA - sortB;

// Sekundarni sort: prioritet pa datum
```

### moveOrder() funkcija
1. Filtrira narudžbe iste linije
2. Sortira po sort_order
3. Ako oba imaju sort_order=0 → renumberira sve
4. Swap sort_order između susjednih stavki

---

*Zadnje ažuriranje: 11. Veljače 2026*
- ⭐ Dokumentirana formula za skidanje papira sa stanja
- ⭐ Dokumentiran workflow skidanja materijala
- ⭐ Dokumentirane transformacije barkoda pri skeniranju
- ⭐ Dokumentirana detekcija tipa materijala po prefixu
- ⭐ Dokumentiran tuber-materijal v2 (Smart Material Deduction)
- ⭐ Rezač override težine role (remaining_kg GENERATED!)
- ⭐ PVND per-line metrike produktivnosti
- ⭐ Bidirekcijska sinkronizacija brojača
- ⭐ Sortiranje narudžbi (sort_order kolona)
