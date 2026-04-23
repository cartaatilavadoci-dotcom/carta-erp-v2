# CARTA-ERP - AI Razvojni Vodič

> **Verzija:** 1.4 | **Zadnje ažuriranje:** 14. Travnja 2026 (sesija 2)

---

## 📖 Uvod

**CARTA-ERP** je specijaliziran ERP sistem za upravljanje proizvodnjom papirnatih vrećica. Ovaj dokument služi kao **single source of truth** za AI asistente (Claude, GPT, Copilot) koji razvijaju ili održavaju ovaj sistem.

### Verzija

- **Aplikacija:** v2.0.0
- **Datum:** 14. Travnja 2026
- **Proizvodni pogon:** 2 linije (NLI i W&H), 3 smjene

### Svrha ovog dokumenta

- ✅ Brzo razumijevanje projekta i tehnologija
- ✅ Kritični koncepti (proizvodni datum, smjene, ESP32 sinkronizacija)
- ✅ 23 zlatnih pravila razvoja koja MORAJU biti poštovana
- ✅ Česti zadaci i how-to primjeri
- ✅ Kritični bugovi i poznati problemi

### Ko bi trebao čitati ovaj dokument?

- AI asistenti koji razvijaju nove module
- AI asistenti koji otklanjaju bugove
- AI asistenti koji ažuriraju postojeću funkcionalnost
- AI asistenti koji odgovaraju na pitanja o sustavu

---

## 📁 Struktura Projekta

```
carta-erp/
├── index.html                    - SPA shell (7KB)
├── CLAUDE.md                     - AI razvojni vodič (ovaj dokument)
├── css/
│   └── styles.css                - Globalni stilovi (30KB)
├── js/                           - Core JavaScript (12 datoteka)
│   ├── config.js                 - Konfiguracija, role, navigacija
│   ├── supabase-client.js        - Supabase inicijalizacija i CRUD helperi
│   ├── supabase-helpers.js       - SAFE wrapperi (SB.*) s error handlingom ⭐
│   ├── auth.js                   - Autentikacija i sesije
│   ├── router.js                 - SPA hash-based routing
│   ├── utils.js                  - Proizvodni datum, smjene, helperi
│   ├── mobile.js                 - Mobile UI responsivnost
│   ├── scanner.js                - Barcode/QR skeniranje
│   ├── zamjene-postave.js        - Upravljanje postavama (GLOBALNI objekt!)
│   ├── esp32_tuber_integration.js - ESP32 brojač integracija
│   ├── ovjera-rn.js              - Logika verifikacije RN-ova
│   └── carta-ai-widget.js        - AI chat widget
├── views/
│   ├── login.html                - Prijava
│   ├── dashboard.html            - Glavni pregled (75KB)
│   ├── hr/                       - 7 HR modula
│   │   ├── djelatnici.html       - Upravljanje zaposlenicima (34KB)
│   │   ├── place.html            - Obračun plaća (48KB)
│   │   ├── produktivnost.html    - HR produktivnost (41KB)
│   │   ├── obracun.html          - Obračuni (52KB)
│   │   ├── izvjestaji.html       - Izvještaji (STUB)
│   │   ├── terminal.html         - Terminal (STUB)
│   │   └── raspored-hr.html      - Raspored (STUB)
│   ├── proizvodnja/              - 23 proizvodna modula
│   │   ├── planiranje.html       - Planiranje proizvodnje (232KB) ⭐
│   │   ├── artikli.html          - Artikli i kupci (135KB)
│   │   ├── tuber.html            - Tuber proizvodnja (211KB)
│   │   ├── tuber-materijal.html  - Materijal evidencija (88KB, interni)
│   │   ├── bottomer-voditelj.html - Bottomer stroj (196KB)
│   │   ├── bottomer-slagac.html  - Bottomer slaganje (233KB)
│   │   ├── slagac-pomocnik.html  - Slagač pomoćnik (43KB, interni)
│   │   ├── tisak.html            - Tisak (201KB)
│   │   ├── rezac.html            - Rezač (108KB)
│   │   ├── skladiste.html        - Skladište (142KB)
│   │   ├── otpreme.html          - Otpreme (119KB)
│   │   ├── pvnd.html             - Proizvodnja neto dnevna (78KB)
│   │   ├── oee.html              - OEE dashboard (24KB)
│   │   ├── maintenance.html      - Održavanje (75KB)
│   │   ├── kuhinja.html          - Kuhinja ljepila (56KB)
│   │   ├── produktivnost-strojara.html - Produktivnost strojara (32KB)
│   │   ├── raspored-nli.html     - Raspored NLI linije (30KB)
│   │   ├── raspored-wh.html      - Raspored W&H linije (45KB)
│   │   ├── raspored-tisak.html   - Raspored tiska (40KB)
│   │   └── videonadzor.html      - Video nadzor (18KB)
│   ├── upravljanje/
│   │   ├── ovjera-rn.html        - Ovjera radnih naloga (17KB)
│   │   └── ovjera-rn.js          - Ovjera logika (36KB)
│   └── admin/
│       ├── admin.html            - Upravljanje korisnicima (13KB)
│       └── postavke.html         - Postavke sustava (74KB, superadmin)
├── sql/                          - 18 SQL migracijskih skripti
└── Projektna dokumentacija/      - Dokumentacija + ESP32 firmware
```

**Napomena:** Svi moduli imaju CSS i JS INLINE u HTML datoteci. Nema build sustava - čisti vanilla JS.

---

## 💻 Tehnološki Stack

### Frontend
- **JavaScript:** Vanilla ES6+ (bez framework-a!)
- **HTML5 + CSS3:** Responzivni dizajn, mobile-first
- **SPA Router:** Hash-based (#view-name), klijentska navigacija
- **PWA:** Mogućnost instalacije kao mobilna aplikacija

### Backend
- **Supabase:** PostgreSQL cloud baza
- **Real-time:** Supabase Realtime subscriptions
- **RLS:** Row-Level Security politike
- **RPC:** PostgreSQL funkcije za poslovnu logiku

### Biblioteke
- **jsPDF + autoTable:** PDF generiranje i izvoz
- **html5-qrcode:** Barcode/QR code skeniranje
- **Supabase JS Client:** Komunikacija s bazom

### Integracije
- **ESP32 IoT:** Brojači na Tuber/Bottomer strojevima
- **IP Kamere:** RTSP/MJPEG proxy na 192.168.1.199:3001
- **CARTA AI Widget:** Chat asistent na 192.168.1.199:3002
- **Barcode skeneri:** Warehouse management

---

## 🔄 Proizvodni Workflow ⭐ KLJUČNO

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CARTA PROIZVODNI WORKFLOW                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Narudžba → Planiranje → Rezač → Tisak → Tuber → Bottomer → GOP → Otprema   │
│     │           │          │       │        │        │        │       │     │
│     ▼           ▼          ▼       ▼        ▼        ▼        ▼       ▼     │
│  prod_     prod_work_   Strips  Printed   POP      GOP    Palete  Otprem-   │
│  orders    orders       (trake) (otisnuto)(tuljci)(vrećice)       ljeno     │
│                            │       │        │        │                      │
│                            ▼       ▼        ▼        ▼                      │
│                         prod_    prod_    prod_    prod_                    │
│                         inventory inventory inventory inventory             │
│                         _strips  _printed _pop     _gop                     │
│                                                                              │
│  SVAKI KORAK GENERIRA INVENTAR ZA SLJEDEĆI!                                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Detaljni workflow po fazama

| Faza | Ulaz | Izlaz | Tablica inventara |
|------|------|-------|-------------------|
| **Rezač** | Role papira | Trake (strips) | prod_inventory_strips |
| **Tisak** | Trake / Role | Otisnute role | prod_inventory_printed |
| **Tuber** | Trake + Otisnuto + Folija | POP (tuljci) | prod_inventory_pop |
| **Bottomer** | POP (tuljci) | GOP (vrećice) | prod_inventory_gop |
| **Otprema** | GOP palete | Otpremljeno | prod_inventory_gop.status |

---

## 🔥 Kritični Koncepti (OBAVEZNO PROČITATI)

### 1. Proizvodni Datum ⭐ NAJVAŽNIJE

```
PROIZVODNI DAN počinje u 06:00, NE u ponoć!

┌──────────────────────────────────────────────────┐
│  Kalendarski dan: 20.01.2026                     │
│  ────────────────────────────────────────────────│
│  00:00-05:59 → Proizvodni dan: 19.01. (Smjena 3) │
│  06:00-23:59 → Proizvodni dan: 20.01. (Smjene 1-2-3) │
└──────────────────────────────────────────────────┘

Primjer:
- Unos u 02:00 ujutro 20.01. → proizvodni dan 19.01., smjena 3
- Unos u 06:24 ujutro 20.01. → proizvodni dan 20.01., smjena 1
```

**Funkcije iz [js/utils.js](js/utils.js):**
```javascript
getProductionDate()              // → '2026-01-20'
getYesterdayProductionDate()     // → '2026-01-19'
getCurrentShiftNumber()          // → 1, 2 ili 3
getProductionDateFromTimestamp(ts)
getProductionDayStartISO(dateStr)  // '2026-01-20T06:00:00'
getProductionDayEndISO(dateStr)    // '2026-01-21T05:59:59'
```

### 2. Tri Smjene

```
1. smjena: 06:00 - 14:00 (shift_number = 1)
2. smjena: 14:00 - 22:00 (shift_number = 2)
3. smjena: 22:00 - 06:00 (shift_number = 3) ← PRELAZI DAN!
```

### 3. Dvije Proizvodne Linije

| Linija | Boja teme | CSS klasa | Machine kodovi |
|--------|-----------|-----------|----------------|
| **W&H** | Zelena (#2e7d32) | `body.linija-wh` | WH-1, WH-B1 |
| **NLI** | Narančasta (#e65100) | `body.linija-nli` | NLI-1, NLI-2 |

### 4. GENERATED Kolone ⚠️ KRITIČNO

**3 GENERATED kolone u sustavu - NE ažurirati ručno!**

```sql
-- 1. prod_orders.quantity_remaining
Formula: quantity_ordered - quantity_produced
❌ NE radi: .update({ quantity_remaining: 100 })
✅ Ažuriraj: quantity_ordered ili quantity_produced

-- 2. prod_inventory_rolls.remaining_kg ⭐ NOVO
Formula: initial_weight_kg - consumed_kg
❌ NE radi: .update({ remaining_kg: 500 }) ni .insert({ remaining_kg: 500 })
✅ Ažuriraj: consumed_kg (sustav automatski računa remaining_kg)

-- 3. prod_inventory_pop.quantity_available
Formula: quantity_in_stock - COALESCE(quantity_reserved, 0)
❌ NE radi: .update({ quantity_available: 100 })
✅ Ažuriraj: quantity_in_stock ili quantity_reserved
```

### 5. ZamjenePostave Globalni Objekt ⚠️

```javascript
// PROBLEM: ZamjenePostave.data dijele SVI moduli!
// Ako korisnik otvori Bottomer → Tuber, podaci mogu biti krivi!

// ❌ POGREŠNO
if (ZamjenePostave.data.clanovi.length > 0) { ... }

// ✅ ISPRAVNO
if (window.tuberTrenutnaSmjenaData.djelatnici.length > 0) { ... }
```

### 6. ESP32 Sinkronizacija ⚠️ KRITIČNO

```
ESP32 heartbeat (svakih 30s):
→ Poziva get_active_work_order(machine_code)
→ Ako tubes==syncedCount && buffer==0:
  → tubes = serverCount (PREPIŠE LOKALNI COUNT!)

⚠️ OPASNOST:
Ako serverCount=0 (pogrešan reset):
→ ESP32 gubi count → IZGUBLJENO 1000+ KOMADA!

✅ ZAŠTITA:
UVIJEK provjeri get_counter_status PRIJE start_machine_counter!
```

---

## 📊 Status Vrijednosti ⭐ REFERENCA

| Tablica | Kolona | Moguće vrijednosti |
|---------|--------|-------------------|
| **prod_orders** | status | `Aktivno`, `Završeno`, `Otkazano` |
| **prod_work_orders** | status | `Planiran`, `U tijeku`, `Završeno`, `Pauziran` |
| **prod_work_orders** | tuber_status | `Aktivan`, `Završeno`, `Pauzirano` |
| **prod_work_orders** | bottomer_voditelj_status | `Aktivan`, `Završeno`, `Pauzirano` |
| **prod_work_orders** | bottomer_slagac_status | `Aktivan`, `Završeno`, `Pauzirano` |
| **prod_shift_log** | status | `Aktivno`, `Završeno` |
| **prod_inventory_rolls** | status | `Na skladištu`, `Djelomično`, `Utrošeno`, `Otpisano` |
| **prod_inventory_pop** | status | `Na skladištu`, `Utrošeno` |
| **prod_inventory_gop** | status | `Na skladištu`, `U pripremi`, `Otpremljeno` |

---

## ⚡ 23 Zlatna Pravila Razvoja

### Pravilo 1: Baza prije koda
```
❌ Pretpostaviti da kolona postoji
✅ Provjeriti strukturu tablice prije pisanja koda
```

### Pravilo 2: Postavke su centralne
```
Tablica: prod_settings (key-value) - proizvodne postavke
Tablica: settings - opće postavke
```

### Pravilo 3: Limit uvijek eksplicitan
```javascript
// ❌ NIKAD
const { data } = await supabase.from('tablica').select('*');

// ✅ UVIJEK
const { data } = await supabase.from('tablica').select('*').limit(10000);
```

### Pravilo 4: UUID za reference
```javascript
// ❌ Shared values (može biti duplicirano)
.eq('work_order_number', 'WO-2025-001')

// ✅ UUID (uvijek jedinstveno)
.eq('work_order_id', 'a1b2c3d4-e5f6-...')
```

### Pravilo 5: Encoding = UTF-8
```
Problem: Upload mehanizmi mogu kvariti encoding
Simptom: mojibake znakovi umjesto č, ć, š, ž, đ
Rješenje: Direktni upload ili sed fix
```

### Pravilo 6: Mobile first
```css
/* Fontovi: 11-12px za mobile */
/* Padding: 50% manje */
/* Touch targets: min 44px */
```

### Pravilo 7: Linija = tema
```
WH: Zelena (#2e7d32) - body.linija-wh
NLI: Narančasta (#e65100) - body.linija-nli
```

### Pravilo 8: Smjena persistira
```
LocalStorage: tuber_linija, tuber_aktivniRN_{LINIJA}
Baza: prod_shift_log.status = 'Aktivno'
```

### Pravilo 9: Funkcije po modulu
```javascript
// Prefix funkcije prema modulu
tuberLoadData()
tuberPokreniSmjenu()
rezacPrikaziRole()
esp32Init()
```

### Pravilo 10: Nove stranice = sidebar + role
```
1. Dodaj u config.js NAV_ITEMS
2. Dodaj u DEFAULT_ROLES
3. Dodaj u router.js viewPath mapping
4. Dodaj u prod_roles (baza)
```

### Pravilo 11: Putanje u viewovima - apsolutne od roota
```html
<!-- ✅ ISPRAVNO (apsolutno od roota) -->
<link rel="stylesheet" href="views/proizvodnja/tuber.css">
```

### Pravilo 12: Moduli - sve inline
```
Svi moduli imaju CSS i JS INLINE u HTML datoteci.
```

### Pravilo 13: Proizvodni datum i timezone ⭐ KRITIČNO
```javascript
// ❌ NIKAD
const today = new Date().toISOString().split('T')[0];

// ✅ UVIJEK
const productionDate = getProductionDate();
```

### Pravilo 14: NE IZOSTAVLJAJ I NE RADI PO SVOM ⭐ KRITIČNO
```
1. NE IZOSTAVLJAJ NIŠTA
   - Ako korisnik ne kaže da nešto treba maknuti, NE MICAJ

2. NE RADI PO SVOM
   - Ako nisi siguran što korisnik želi, PITAJ
```

### Pravilo 15: Interni moduli nasljeđuju pristup
```javascript
// Interni moduli nemaju stavku u sidebaru
// Nasljeđuju pristup od parent modula

// router.js
const interniModuli = {
  'tuber-materijal': 'tuber',
  'slagac-pomocnik': 'bottomer-slagac'
};
```

### Pravilo 16: ESP32 brojač - ne resetiraj postojeći ⭐ KRITIČNO
```javascript
// PRIJE pokretanja naloga UVIJEK provjeri:
const status = await initSupabase().rpc('get_counter_status', { p_machine_code: machineCode });

// Ako postoji aktivan za ISTI nalog → NE DIRAJ
if (status.active && status.work_order_id === workOrderId) {
  console.log('Brojač već aktivan, koristim postojeći');
  return;
}

// Ako NEMA aktivnog → pokreni novi
await initSupabase().rpc('start_machine_counter', {...});
```

### Pravilo 17: ZamjenePostave je GLOBALNI objekt ⚠️
```javascript
// ZamjenePostave.data dijele SVI moduli!
// Ako korisnik navigira Bottomer → Tuber, podaci mogu biti krivi!

// ✅ RJEŠENJE: Koristi modul-specifične varijable
window.tuberTrenutnaSmjenaData  // Za Tuber
// Ili provjeri stroj_tip i liniju
if (ZamjenePostave.data.stroj_tip === 'Tuber' && 
    ZamjenePostave.data.linija === window.LINIJA)
```

### Pravilo 18: Material tracking - deducted flag
```javascript
// Prije skidanja materijala provjeri:
const pop = await getPOP(popId);
if (pop.material_deducted) {
  console.log('Materijal već skinut za ovaj POP');
  return;
}

// Nakon skidanja postavi flag:
await updatePOP(popId, { material_deducted: true });
```

### Pravilo 19: Bottomer ima DVA statusa
```javascript
// Voditelj i Slagač rade NEOVISNO!
// Koristi odvojene statuse:
bottomer_voditelj_status  // Za upravljanje strojem
bottomer_slagac_status    // Za slaganje paleta

// Za završetak koristi RPC:
await initSupabase().rpc('complete_bottomer_phase', {
  p_work_order_id: woId,
  p_phase: 'voditelj'  // ili 'slagac'
});
```

### Pravilo 20: Jedan aktivni nalog po stroju
```javascript
// PRIJE pokretanja novog naloga provjeri:
const aktivni = await getAktivniNalog(machineCode);
if (aktivni) {
  showMessage('Već postoji aktivan nalog: ' + aktivni.wo_number, 'error');
  return;
}
```

### Pravilo 21: remaining_kg je GENERATED (prod_inventory_rolls) ⭐ NOVO
```javascript
// remaining_kg = initial_weight_kg - consumed_kg
// NE MOŽE se direktno upisati ili ažurirati!

// ❌ GREŠKA
.insert({ roll_code: 'X', initial_weight_kg: 500, remaining_kg: 500 })
.update({ remaining_kg: novaTezina })

// ✅ ISPRAVNO - ažuriraj consumed_kg
const noviConsumedKg = initialWeight - novaTezina;
.update({ consumed_kg: noviConsumedKg, status: noviStatus })
```

### Pravilo 22: Counter sync - bidirekcijsko ažuriranje ⭐ NOVO
```javascript
// Sinkronizacija brojača u planiranju dozvoljava SMANJIVANJE!
// Koristite nakon brisanja RN-ova za vraćanje brojača na stvarni max.

// Logika:
const newValue = maxFound;  // NE Math.max(currentValue, maxFound)!
const needsUpdate = newValue !== currentValue;  // !== umjesto >
```

### Pravilo 24: Koristi SB.* helpere za nove Supabase pozive ⭐ NOVO
```javascript
// js/supabase-helpers.js (window.SB) je centralizirani wrapper koji:
// - Baca iznimku ako Supabase vrati error (NIKAD silent fail!)
// - Loguje grešku u console s prefiksom ❌ i imenom tablice
// - Pokazuje toast korisniku (osim ako { silent: true })
// - Vraća .data direktno
// - UPDATE/DELETE ZAHTIJEVAJU filter (sigurnosna mjera)

// ❌ STARO (silent fail rizik)
const { data, error } = await initSupabase().from('prod_inventory_rolls')
  .update({ consumed_kg: 100 }).eq('id', rollId);
// (mnogi moduli ne provjeravaju error - bug iz cc96144 commita)

// ✅ NOVO
await SB.update('prod_inventory_rolls', { consumed_kg: 100 }, { id: rollId });

// SVE METODE: SB.select, SB.insert, SB.update, SB.upsert, SB.delete, SB.rpc, SB.count
// Vidi js/supabase-helpers.js za primjere.
// Postojeći moduli postupno migriraju - novi kod MORA koristiti SB.*
```

### Pravilo 23: Tipovi radnih naloga i brojača ⭐ NOVO
```
prod_counters sadrži tipove brojača:
| Tip           | Prefix | Tablica                    | Pattern         |
|---------------|--------|----------------------------|-----------------|
| Narudžba      | N      | prod_orders                | N{br}/{god}     |
| RN_Glavni     | RN     | prod_work_orders           | RN{br}/{god}    |
| RN_Tisak      | TIS    | prod_work_orders_printing  | TIS{br}/{god}   |
| RN_Rezanje    | REZ    | prod_work_orders_cutting   | REZ{br}/{god}   |
| RN_Etiketa    | ETI    | -                          | ETI{br}/{god}   |
| Kvar          | KV     | -                          | KV{br}/{god}    |
| MaintOrder    | MO     | -                          | MO{br}/{god}    |
```

---

## 🛡️ Kritični Bugovi - PAZI!

### BUG: ESP32 resetira count pri pokretanju ⭐ RIJEŠENO 26.01.

```
Simptom: Operater pokrene nalog, ESP32 izgubi 1000+ komada
Uzrok: start_machine_counter UVIJEK radi UPSERT s count=0
       ESP32 heartbeat dohvati serverCount=0 → tubes=0!
Rješenje: UVIJEK provjeri get_counter_status PRIJE start_machine_counter

Vidi: Pravilo 16
```

### BUG: Tuber izvještaj prikazuje Bottomer postavu ⭐ RIJEŠENO 26.01.

```
Simptom: U Tuber izvještaju prikazuje se Bottomer postava
Uzrok: ZamjenePostave je GLOBALNI objekt, dijele ga svi moduli
Rješenje: Koristi window.tuberTrenutnaSmjenaData (modul-specifična varijabla)

Vidi: Pravilo 17
```

### BUG: Duplo skidanje materijala ⭐ RIJEŠENO 25.01.

```
Simptom: Materijal se skida više puta za isti POP
Uzrok: Nedostaje tracking je li materijal već skinut
Rješenje: Nova kolona material_deducted u prod_inventory_pop

Vidi: Pravilo 18
```

### BUG: Bottomer Slagač ne vidi nalog nakon završetka Voditelja ⭐ RIJEŠENO 25.01.

```
Simptom: Voditelj završi nalog → status='Završeno' → Slagač ne može spremiti paletu
Uzrok: Jedan zajednički status za cijeli nalog
Rješenje: Odvojeni statusi (bottomer_voditelj_status, bottomer_slagac_status)

Vidi: complete_bottomer_phase RPC funkcija
```

---

## 🎛️ Moduli & Njihove Specifičnosti

### Tuber modul ([tuber.html](views/proizvodnja/tuber.html)) ⭐

- **Veličina:** 211KB (~5,758 linija koda)
- **Svrha:** Glavni modul za Tuber proizvodnju
- **Povezan sa:** [tuber-materijal.html](views/proizvodnja/tuber-materijal.html) (interni modul)
- **Funkcije:** `tuber*` prefix
- **Smjenski izvještaj:**
  - Kolone 1-3: Iz proizvodnje (prod_shift_details)
  - Kolone 4-11: Ručni unos (prod_shift_reports)
  - Nazivi: "Čekanje tiska", "Čekanje bottomera"
- **Postava:** Koristi `window.tuberTrenutnaSmjenaData` (NE ZamjenePostave!)
- **ESP32:** NLI-1 (192.168.1.175), WH-1 (192.168.1.176)

### Tuber-Materijal modul ([tuber-materijal.html](views/proizvodnja/tuber-materijal.html)) ⭐

- **Tip:** Interni modul (nasljeđuje pristup od 'tuber')
- **Svrha:** Evidencija materijala pri završetku naloga/smjene
- **Workflow:**
  1. Operater završi nalog/smjenu u tuber.html
  2. Sustav otvara tuber-materijal modul
  3. Operater skenira korištene role
  4. Sustav računa skidanje po formuli
  5. Sprema u prod_inventory_consumed_rolls
  6. Ažurira material_deducted = true
- **Billerud transformacije:** 3 načina pretraživanja barkoda
- **Formula:** (POP × širina × gramatura × REZ) / 10.000.000

### Bottomer-Voditelj modul ([bottomer-voditelj.html](views/proizvodnja/bottomer-voditelj.html)) ⭐

- **Veličina:** 196KB
- **Svrha:** Upravljanje Bottomer strojem
- **Smjenski izvještaj:**
  - Kolone 1-3: Iz proizvodnje
  - Kolone 4-11: Ručni unos
  - Nazivi: "Čekanje tuljke", "Čekanje"
- **Odvojeni statusi:** `bottomer_voditelj_status` (neovisno od slagača)
- **ESP32:** NLI-2 (192.168.1.229), WH-B1 (TBD)

### Bottomer-Slagač modul ([bottomer-slagac.html](views/proizvodnja/bottomer-slagac.html))

- **Veličina:** 233KB (~6,400 linija koda)
- **Svrha:** Slaganje paleta i spremanje GOP-a
- **Odvojeni statusi:** `bottomer_slagac_status` (neovisno od voditelja)
- **Provjera:** Aktivan nalog prije pokretanja
- **pcs_per_pallet_override:** Omogućuje override kom/paleta za specifični radni nalog (NULL = koristi artikl vrijednost)

### Planiranje modul ([planiranje.html](views/proizvodnja/planiranje.html)) ⭐

- **Veličina:** 232KB
- **Svrha:** Planiranje proizvodnje, generiranje RN-ova
- **Funkcionalnosti:**
  - Kreiranje narudžbi i radnih naloga (RN)
  - 3 tipa RN: Glavni (RN), Tisak (TIS), Rezanje (REZ)
  - Sort order narudžbi (↑↓ strelice, sort_order kolona)
  - Završavanje/pauziranje/brisanje RN-ova
  - Ovjera RN (encoding UTF-8)
  - Sinkronizacija brojača (bidirekcijska - gore I dolje)
- **Brojači:** prod_counters tablica, prod_reserved_numbers
- **Counter sync:** Skenira max broj u bazi, dozvoljava smanjivanje nakon brisanja RN

### Rezač modul ([rezac.html](views/proizvodnja/rezac.html))

- **Veličina:** 108KB
- **Svrha:** Rezanje rola papira na trake
- **Funkcionalnosti:**
  - Skeniranje/pretraga rola
  - Override težine role (⚖️ korekcija) za ispravak grešaka
  - Filter po šifri role
  - DB scan za role s remaining_kg=0 (nevidljive u tablici)
- **VAŽNO:** remaining_kg je GENERATED kolona - ažuriraj samo consumed_kg!

### Tisak modul ([tisak.html](views/proizvodnja/tisak.html))

- **Veličina:** 201KB
- **Svrha:** Upravljanje tiskom
- **Funkcionalnosti:**
  - Rad s prod_work_orders_printing
  - Etikete i tisak nalozi
  - Smjenski izvještaji

### PVND modul ([pvnd.html](views/proizvodnja/pvnd.html))

- **Veličina:** 78KB
- **Svrha:** Proizvodnja vrećica - neto dnevna
- **Funkcionalnosti:**
  - Mjesečni i godišnji pregled po linijama (NLI/WH)
  - Per-line metrike: sati rada, količina, kom/h, broj RN, kom/RN
  - Izvor podataka: prod_shift_details (vrsta_unosa='GOP')
  - Sati rada: (unique datum-smjena kombinacije) × 8h

### Skladište ([skladiste.html](views/proizvodnja/skladiste.html))

- **Veličina:** 142KB
- **Svrha:** Upravljanje inventarom
- **Inventar:**
  - Role papira (prod_inventory_rolls)
  - Trake (prod_inventory_strips)
  - Otisnute role (prod_inventory_printed)
  - Folije (prod_inventory_foil)
- **Palete:** cover_quantity, cover_reserved, cover_available

### Slagač-Pomoćnik ([slagac-pomocnik.html](views/proizvodnja/slagac-pomocnik.html))

- **Tip:** Interni modul (nasljeđuje pristup od 'bottomer-slagac')
- **Svrha:** Pomoćne funkcije za slaganje paleta

### Maintenance modul ([maintenance.html](views/proizvodnja/maintenance.html))

- **Veličina:** 75KB
- **Svrha:** Evidencija kvarova i održavanja strojeva
- **Brojači:** Kvar, MaintOrder, Maintenance (prod_counters)

### Kuhinja modul ([kuhinja.html](views/proizvodnja/kuhinja.html))

- **Veličina:** 56KB
- **Svrha:** Upravljanje ljepilom (glue kitchen)

### Ovjera RN modul ([ovjera-rn.html](views/upravljanje/ovjera-rn.html))

- **Veličina:** 17KB + [ovjera-rn.js](js/ovjera-rn.js) (36KB)
- **Svrha:** Verifikacija radnih naloga

### Dashboard modul ([dashboard.html](views/dashboard.html))

- **Veličina:** 75KB (~1,650 linija)
- **Svrha:** Glavni pregled sustava
- **Funkcionalnosti:**
  - KPI kartice (kupci, artikli, aktivni strojevi, narudžbe)
  - Live kamera s ulaza
  - Dnevna/jučerašnja proizvodnja po linijama (NLI vs WH)
  - Status inventara rola papira
  - Aktivni radni nalozi s vizualnim praćenjem statusa

### Artikli modul ([artikli.html](views/proizvodnja/artikli.html)) ⭐

- **Veličina:** 135KB (~3,422 linija)
- **Svrha:** Upravljanje artiklima i kupcima
- **Funkcionalnosti:**
  - Dva taba: Kupci i Artikli
  - Geografsko filtriranje kupaca (HR/regionalni vs međunarodni)
  - AI-powered "wizard" za auto-detekciju specifikacija artikala
  - Tablice: prod_articles (119 kolona), prod_customers

### Otpreme modul ([otpreme.html](views/proizvodnja/otpreme.html))

- **Veličina:** 119KB (~3,290 linija)
- **Svrha:** Upravljanje otpremama
- **Funkcionalnosti:**
  - Gantt kalendar otprema
  - KPI kartice (čekaju/otpremljene narudžbe)
  - Praćenje statusa otpreme
  - Integracija s skladištem (prod_dispatch, prod_dispatch_items, prod_dispatch_pallets)

### OEE modul ([oee.html](views/proizvodnja/oee.html))

- **Veličina:** 24KB (~948 linija)
- **Svrha:** Overall Equipment Effectiveness dashboard
- **Funkcionalnosti:**
  - OEE gauge + komponente (availability, performance, quality)
  - Filteri po vremenu i stroju
  - Vizualizacija u gauge-style grafikonima

### Produktivnost Strojara modul ([produktivnost-strojara.html](views/proizvodnja/produktivnost-strojara.html))

- **Veličina:** 32KB (~1,166 linija)
- **Svrha:** Ranking produktivnosti operatera
- **Funkcionalnosti:**
  - Filtriranje po datumu i operateru
  - Praćenje bonus postotaka
  - Komparativna analitika po smjenama i timovima

### Raspored NLI modul ([raspored-nli.html](views/proizvodnja/raspored-nli.html))

- **Veličina:** 30KB (~976 linija)
- **Svrha:** Raspored smjena za NLI proizvodnu liniju
- **Funkcionalnosti:**
  - Dodjela smjena po datumu
  - 6 profila smjena s bojama
  - Dodjela zaposlenika po smjeni

### Raspored WH modul ([raspored-wh.html](views/proizvodnja/raspored-wh.html))

- **Veličina:** 45KB (~1,588 linija)
- **Svrha:** Raspored smjena za W&H proizvodnu liniju
- **Funkcionalnosti:**
  - View/Edit tabovi (javni i admin pristup)
  - Subotnji rad scheduling
  - Administrativne override mogućnosti

### Raspored Tisak modul ([raspored-tisak.html](views/proizvodnja/raspored-tisak.html))

- **Veličina:** 40KB (~1,343 linija)
- **Svrha:** Raspored smjena za odjel tiska
- **Funkcionalnosti:**
  - Fleksibilni obrasci smjena (3×8h ili 2×12h)
  - View/Edit tabovi s admin kontrolama

### Videonadzor modul ([videonadzor.html](views/proizvodnja/videonadzor.html))

- **Veličina:** 18KB
- **Svrha:** Prikaz IP kamera u browseru
- **Proxy:** RTSP → MJPEG konverzija na 192.168.1.199:3001

---

## 👤 HR & Place Moduli

### Djelatnici modul ([djelatnici.html](views/hr/djelatnici.html))

- **Veličina:** 34KB (~947 linija)
- **Svrha:** Registar zaposlenika
- **Funkcionalnosti:**
  - KPI kartice (ukupno, aktivni, neaktivni, prosječna plaća)
  - Pretraga/filtriranje po imenu, timu, poziciji, statusu
  - Modal za dodavanje/uređivanje (tabovi: osnovni podaci, radni raspored, plaća, ugovor)

### Place modul ([place.html](views/hr/place.html))

- **Veličina:** 48KB (~1,285 linija)
- **Svrha:** Obračun plaća
- **Funkcionalnosti:**
  - Tri taba: unos sati (koeficijenti za redovni/prekovremeni/noćni/blagdanski rad), obračun plaća, pregled po timovima
  - Kopiranje podataka prethodnog mjeseca
  - Bulk obrada plaća

### Produktivnost HR modul ([produktivnost.html](views/hr/produktivnost.html))

- **Veličina:** 41KB (~1,158 linija)
- **Svrha:** HR praćenje produktivnosti
- **Funkcionalnosti:**
  - Filteri: mjesec/godina/linija/stroj/tim
  - KPI kartice za prosječne bonuse (operateri vs voditelji) i postotak škarta
  - Dodavanje/izvoz podataka produktivnosti

### Obračun modul ([obracun.html](views/hr/obracun.html))

- **Veličina:** 52KB (~1,820 linija)
- **Svrha:** Kompletni obračun plaća
- **Funkcionalnosti:**
  - Odabir perioda obračuna
  - Komponente plaće, odbici, porezni izračuni
  - Isplatni listići i distribucija plaća
  - Multi-tab sučelje za različite workflow-ove

### HR Stub moduli (U razvoju)

- **Izvještaji** ([izvjestaji.html](views/hr/izvjestaji.html)) - Placeholder
- **Terminal** ([terminal.html](views/hr/terminal.html)) - Placeholder
- **Raspored HR** ([raspored-hr.html](views/hr/raspored-hr.html)) - Placeholder

---

## ⚙️ Admin Moduli

### Admin modul ([admin.html](views/admin/admin.html))

- **Veličina:** 13KB (~431 linija)
- **Svrha:** Upravljanje korisnicima sustava
- **Funkcionalnosti:**
  - Kreiranje/uređivanje zaposlenika i korisničkih računa
  - Statistika korisnika (aktivni/neaktivni)
  - Dodjela rola (superadmin/admin/user)
  - Pretraga i bulk akcije

### Postavke modul ([postavke.html](views/admin/postavke.html))

- **Veličina:** 74KB (~2,136 linija)
- **Svrha:** Postavke sustava (samo superadmin!)
- **Funkcionalnosti:**
  - Upravljanje rolama i dozvolama
  - Konfiguracija email predložaka
  - Sistemske postavke (fond sati, minimalna plaća)
  - Audit logging
  - Konfiguracija kompanija i linija

---

## 🤖 CARTA AI Widget

### Konfiguracija

```javascript
// js/carta-ai-widget.js (16KB, ~483 linija)
// Server: http://192.168.1.199:3002/api
```

### Opis

- **Svrha:** AI chat asistent integriran u CARTA ERP
- **Server:** Dijeli host s camera proxy serverom (192.168.1.199)
- **Port:** 3002 (camera proxy na 3001)
- **Funkcionalnosti:**
  - Floating Action Button (FAB) za otvaranje chata
  - Fixed chat panel s poviješću poruka
  - Integracija s pending roll stanjem
  - AI-powered decision support unutar aplikacije

---

## 🤖 ESP32 & OEE Sistem

### Machine Kodovi & IP Adrese

| Stroj | Machine Code | IP Adresa | Modul |
|-------|--------------|-----------|-------|
| NLI Tuber | NLI-1 | 192.168.1.175 | tuber.html |
| NLI Bottomer | NLI-2 | 192.168.1.229 | bottomer-voditelj.html |
| WH Tuber | WH-1 | 192.168.1.176 | tuber.html |
| WH Bottomer | WH-B1 | TBD | bottomer-voditelj.html |

### Firmware Verzije

```
v4.5: Baseline (kompenzacija 3→6)
v5.0: OEE logging (blocking - problematično)
v5.1: Non-blocking (NTP ovisnost - problematično)
v5.2: NTP-optional, uvijek šalje evente
v5.3: Batch logging svakih 500 kom
v5.4: DualCore Polling - Core 1 dedicated counting (1ms poll, zero loss),
      Core 0 handles HTTP/OLED/WiFi. Thread-safe volatile varijable.
      (TRENUTNA VERZIJA) ⭐
```

### ESP32 Sinkronizacija - OPASNOST! ⚠️

```
┌─────────────────────────────────────────────────────────┐
│             ESP32 HEARTBEAT (svakih 30s)                 │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  1. ESP32 poziva get_active_work_order(machine_code)     │
│  2. Dohvati serverCount iz baze                          │
│  3. Ako tubes==syncedCount && offlineBuffer==0:          │
│     → tubes = serverCount (PREPIŠE LOKALNI COUNT!)       │
│                                                          │
│  ⚠️ OPASNOST:                                           │
│  Ako je serverCount=0 (pogrešan start_machine_counter):  │
│  → ESP32 postavlja tubes=0                               │
│  → IZGUBLJENI KOMADI (1000+)!                            │
│                                                          │
│  ✅ ZAŠTITA:                                            │
│  tuber.html MORA provjeriti get_counter_status           │
│  PRIJE start_machine_counter!                            │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### OEE Tablice

- **prod_machine_counter_sync** - Sync log svakih 500 kom (dijagram brzine)
- **prod_machine_events** - STOP/START eventi s trajanjem
- **prod_downtime_categories** - 7 kategorija zastoja:
  - PREST (Preštelavanje - planirano)
  - CISCENJE (Čišćenje - planirano)
  - KVAR (Kvar stroja)
  - RVS (Radni nalog / materijal)
  - MATERIJAL (Čekanje materijala)
  - MIKRO (Mikro zastoji <5 min)
  - NEOP (Neopravdano)
- **prod_shift_statistics** - Dnevni agregati (cron job u 06:15)

---

## 📹 Video Nadzor

### Konfiguracija

```javascript
// config.js
CONFIG.CAMERA_PROXY_URL = 'http://192.168.1.199:3001'
```

### Proxy Server

- **Lokacija:** Server na 192.168.1.199
- **Port:** 3001
- **Svrha:** RTSP → MJPEG konverzija za prikaz u browseru
- **Modul:** [videonadzor.html](views/upravljanje/videonadzor.html)

### Napomena

Ako se kamere ne prikazuju, provjeri:
1. Je li proxy server pokrenut
2. Je li IP adresa ispravna u CONFIG.CAMERA_PROXY_URL
3. Mrežna povezanost između klijenta i proxy servera

---

## 👥 Role & Dozvole

| Uloga | Pristup |
|-------|---------|
| `superadmin` | Sve stranice + postavke |
| `admin` | Sve osim postavki |
| `koordinator-proizvodnje` | Planiranje, ovjera-rn, artikli, skladište, otpreme, OEE, produktivnost-strojara, rasporedi, pvnd, videonadzor |
| `uprava` | Dashboard, planiranje, ovjera-rn, artikli, pvnd, otpreme, izvještaji, OEE, produktivnost-strojara, rasporedi, videonadzor |
| `tuber-wh` / `tuber-nli` | Tuber (+ tuber-materijal), terminal |
| `bottomer-wh` / `bottomer-nli` | Bottomer moduli, terminal |
| `rezac` | Rezač, terminal |
| `skladiste` | Skladište, terminal |
| `tisak` | Tisak, raspored-tisak, terminal |
| `racunovodstvo` | HR i place |
| `voditelj-odrzavanja` | Maintenance, skladište |

---

## 📊 Smjenski Izvještaji - Struktura ⭐

### Struktura Kolona

```
KOLONE 1-3 (iz proizvodnje - UVIJEK svježi podaci):
1. Br. Naloga     - RN broj iz prod_shift_details
2. Opis           - Naziv artikla
3. Količina (kom) - Suma proizvedenih komada u smjeni

KOLONE 4-11 (ručni unos - sprema se u bazu):
4. Škart (kg)
5. Preštel.       - Vrijeme preštelavanja (h)
6. Rad            - Vrijeme rada (h)
7. Kvar           - Vrijeme kvara (h)
8. Čekanje tiska/tuljke - Čekanje (h)
9. Rad van stroja - Rad van stroja (h)
10. Čekanje bottomera/ostalo - Čekanje (h)
11. Čišćenje      - Vrijeme čišćenja (h)
```

### Workflow

```
1. Otvori izvještaj → dohvati RN-ove iz prod_shift_details
2. Provjeri prod_shift_reports za spremljeni izvještaj
3. Generiraj tablicu:
   - Kolone 1-3: UVIJEK iz proizvodnje (svježi podaci)
   - Kolone 4-11: iz spremljenog izvještaja AKO POSTOJI
4. Operater unosi/mijenja ručne unose
5. Spremi → UPSERT u prod_shift_reports (report_data: JSONB)
6. Osvježi → kolone 1-3 se osvježe, kolone 4-11 ostaju
```

### Vizualni Indikatori

- **Zelena pozadina (#e8f5e9)** = Podaci iz trenutne proizvodnje
- **Plava pozadina (#e3f2fd)** = Podaci učitani iz spremljenog izvještaja

---

## 📖 Reference - Dodatna Dokumentacija

Za detaljnije informacije, pogledaj:

- **[SCHEMA_UPDATED.md](Projektna dokumentacija/SCHEMA_UPDATED.md)** - Arhitektura aplikacije, smjenski izvještaji, formula za skidanje papira, transformacije barkoda
- **[RULES_UPDATED.md](Projektna dokumentacija/RULES_UPDATED.md)** - 20 pravila i konvencija razvoja, riješeni bugovi, changelog
- **[DATABASE_UPDATED.md](Projektna dokumentacija/DATABASE_UPDATED.md)** - Struktura baze podataka, RPC funkcije, ESP32 tablice
- **[OVJERA_RN_SPECIFIKACIJA.md](Projektna dokumentacija/OVJERA_RN_SPECIFIKACIJA.md)** - Specifikacija verifikacije radnih naloga
- **[ESP32_Brojac_v5_4_DualCore](Projektna dokumentacija/ESP32_Brojac_v5_4_DualCore/)** - Arduino firmware v5.4 za ESP32 brojače

---

## 📅 Changelog & Najnovija Ažuriranja

### 14. Travnja 2026 - Sesija 2 finale: Tuber FIFO sustav ⭐

**Novi opcijski FIFO flow za Tuber (beta, toggle mode):**
- ⭐ **Operater samo skenira šifre rola** — sustav automatski FIFO skida po `internal_id` iz artikla (`paper_sN_code`)
- ⭐ **Folija (prefix F) se preskače** (user uputstvo)
- ⭐ **Sloj 1 + RN s tiskom** → FIFO iz `prod_inventory_printed` (wo_has_printing RPC)
- ⭐ **Nepoznate šifre → placeholder** (posudba iz FIFO role istog internal_id-a). Kad stvarna rola kasnije dođe kroz rezač/tisak/skladište, trigger `trg_resolve_placeholder_on_roll_insert` vraća kg i pripisuje stvarnoj roli
- ⭐ **Toggle na vrhu tuber-materijal.html** — default OFF (stari UI radi), ON (novi FIFO UI)
- ⭐ **DB:** `prod_inventory_placeholder_consumption` + 5 RPC funkcija (`fifo_roll_candidates`, `atomic_consume_roll`, `wo_has_printing`, `fifo_printed_rolls_for_wo`, resolve function)
- ⭐ **JS library:** `js/tuber-fifo.js` — `TuberFifo.computePlan()` + `TuberFifo.executePlan()`
- **Backward compatible:** postojeći produkcijski flow nije dirnut, može se vratiti isključivanjem toggle-a

### 14. Travnja 2026 - Sesija 2 (v1.4) ⭐ VELIKA SESIJA (27 commitova)

**Dashboard nadogradnje (sve aktivno):**
- ⭐ **🔴 Live brojači strojeva** - realtime subscription na prod_machine_counters, po karta kartici NLI/WH Tuber/Bottomer, live dot + progress bar + zadnji pulse
- ⭐ **⚡ OEE widget** - sažetak po liniji+stroju iz v_oee_dashboard, zadnjih 30 dana, obojene OEE brojke (≥70 zeleno, ≥50 narančasto, <50 crveno)
- ⭐ **⚠️ Pod-proizvedeni nalozi widget** - lista RN-ova s produced_pct < 90% u zadnjih 30 dana
- ⭐ **📊 Progress bar u Aktivnim RN** - proizvedeno / planirano + obojena crta
- ⭐ **🔍 Sljedivost palete/RN** - pretraga po RN broju (full overview) ili paleti (trace), modal s kupac→GOP→POP→Roll→proizvođač
- ⭐ **🖨️ Tisak enrichment u traceability** - otisnute role pokazuju Tisak RN + izvornu papirnu rolu + proizvođača
- ⭐ **🔔 Bell notifikacije** - badge s brojem nepročitanih, dropdown sa klik-navigacijom

**Planiranje nadogradnje:**
- ⭐ **📎 Privici narudžbe** - PDF/Excel upload za narudžbenice, test punjenja, ostalo
  - Storage bucket 'order-attachments' + prod_order_attachments tablica
  - Badge na 📎 gumbu + banner u editOrder modalu
  - Za quality control (double-check narudžbe) i AI agent pripremu
- ⭐ **FK RESTRICT soft-delete fallback** - kad RN ima POP/GOP/evidenciju, ponudi "Otkazano" umjesto hard delete

**Realtime (WebSocket subscriptions):**
- ⭐ **prod_notifications realtime** - bell se update-a u <1s bez polling-a (60s polling je fallback)
- ⭐ **prod_machine_counters realtime** - live brojači se auto-refreshaju dok ESP32 šalje pulse

**Workflow & Infrastructure:**
- ⭐ **Supabase MCP integracija** - direktan pristup bazi za analizu i migracije
- ⭐ **SB.* safe wrapper** (js/supabase-helpers.js) - centraliziran error handling za sve Supabase pozive (novo Pravilo #24)
- ⭐ **SB.rpc migracija kompletna** - svih 9 RPC poziva u 3 modula (ovjera-rn × 2, otpreme)
- ⭐ **Notifikacijski sustav UI** - bell icon + dropdown u sidebaru, surface-a prod_notifications

**Kritični popravci:**
- 🐛 **FIX: GENERATED column silent fail** u tuber-materijal.html - 4 UPDATE-a pisala remaining_kg na 5 inventory tablica, Postgres odbijao, lažni success log
- 📊 **Backfill 557 rola** (~389 t papira) iz audit trail-a
- 🐛 **FIX: update_roll_status trigger** - čitao STALE vrijednost GENERATED kolone u BEFORE trigger-u
- 🐛 **RECONCILE: OTP-2026-0004** - prekinut confirmDispatch, 172,100 kom zavedeno kao neotpremljeno

**Database - nove strukture:**
- ⭐ **FK constraints** na core production lanac (POP/GOP/consumed_rolls → work_orders) s ON DELETE RESTRICT
- ⭐ **prod_gop_pop_link** - veza GOP paleta ↔ POP tuljci (bottomer-slagac popunjava)
- ⭐ **prod_pop_roll_link** - veza POP ↔ role papira (tuber-materijal popunjava)
- ⭐ **v_full_traceability** view + **trace_pallet(pallet_number)** RPC za customer recall
- ⭐ **produced_quantity** kolona (auto-sync iz GOP-a preko triggera)
- ⭐ **produced_pct** GENERATED kolona - postotak proizvodnje vs planirano
- ⭐ **5 novih triggera:** trg_gop_sync_wo_produced, trg_gop_dispatch_status_sync, trg_wo_rejected_notify, trg_wo_under_produced_notify, (popravljen update_roll_status)

**Frontend:**
- ⭐ **Dashboard progress bar** na aktivnim RN-ovima + **pod-proizvedeni widget**
- ⭐ **Sljedivost search** - po RN broju ili paleti, drill-down do pojedinačne palete
- ⭐ **Bell notifikacije** - lista nepročitanih, auto-navigate na klik
- ⭐ **FK RESTRICT soft-delete fallback** u planiranje - "ponudi otkazati umjesto brisati"

**RPC/Code refactoring:**
- ⭐ **SB.rpc migracija** - svih 9 RPC poziva u 3 modula (ovjera-rn × 2, otpreme)
- ⭐ **dispatch_pallets workflow** - auto-sync status trigger spriječava inkonzistentnost
- ⭐ **Bottomer gate-keeper** - complete_bottomer_phase sad provjerava tuber_status

**Git & Deployment:**
- ⭐ **Repozitorij migriran** na cartaatilavadoci-dotcom/carta-erp-v2 (public)
- ⭐ **GitHub Pages** omogućen
- ⭐ **22 commita** pushana u ovoj sesiji

### 14. Travnja 2026

- ⭐ **CLAUDE.md v1.3** - Kompletno ažuriranje dokumentacije
- ⭐ **Ispravljena verzija aplikacije:** v2.1.0 → v2.0.0 (prema config.js)
- ⭐ **Ispravljen Camera Proxy IP:** 192.168.1.125 → 192.168.1.199
- ⭐ **Dodana struktura projekta** - kompletni pregled datoteka i direktorija
- ⭐ **19 nedostajućih modula dokumentirano:**
  - Dashboard, Artikli, Otpreme, OEE, Produktivnost Strojara
  - Raspored NLI, Raspored WH, Raspored Tisak, Videonadzor
  - Djelatnici, Place, Produktivnost HR, Obračun (+ 3 HR stub modula)
  - Admin, Postavke
- ⭐ **Nova sekcija: HR & Place Moduli** - cijeli HR sustav dokumentiran
- ⭐ **Nova sekcija: Admin Moduli** - admin i postavke dokumentirani
- ⭐ **Nova sekcija: CARTA AI Widget** - chat asistent (192.168.1.199:3002)
- ⭐ **ESP32 firmware v5.4 DualCore** dokumentiran (Core 1 dedicated counting)
- ⭐ **pcs_per_pallet_override** dokumentiran u Bottomer-Slagač modulu
- ⭐ **Ažurirane veličine datoteka** za module koji su rasli od veljače
- ⭐ **Ažurirane role** prema config.js (koordinator, uprava)
- ⭐ **GitHub repozitorij inicijaliziran** - verzioniranje i backup

### 11. Veljače 2026

- ⭐ **CLAUDE.md v1.2** - Kompletno ažuriranje dokumentacije
- ⭐ **remaining_kg GENERATED kolona** dokumentirana (prod_inventory_rolls)
- ⭐ **Rezac modul:** Override težine role (⚖️), filter šifra role, DB scan
- ⭐ **PVND modul:** Per-line metrike (sati rada, kom/h, broj RN, kom/RN)
- ⭐ **Planiranje:** Sort order narudžbi (↑↓ strelice), bidirekcijski counter sync
- ⭐ **Nova pravila #21-23:** remaining_kg GENERATED, counter sync, tipovi brojača
- ⭐ **Nedostajući moduli dokumentirani:** Planiranje, Rezač, Tisak, PVND, Maintenance, Kuhinja, Ovjera RN
- ⭐ **Interni moduli ažurirani:** slagac-pomocnik → bottomer-slagac

### 01. Veljače 2026

- ⭐ **CLAUDE.md v1.1** - Dodani workflow, status vrijednosti, camera proxy
- ⭐ **Formula za skidanje papira** dokumentirana: (POP × širina × gramatura × REZ) / 10.000.000
- ⭐ **Workflow skidanja materijala** sa material_deducted flag-om
- ⭐ **Transformacije barkoda** (Billerud rotacija, pozicije 2-10)
- ⭐ **Detekcija tipa materijala** po prefixu (T-, R-, F, S, B)
- ⭐ **Nova pravila #18-20** dodana

### 26. Siječanj 2026

- ⭐ **BUG-027 riješen:** Hardkodirana linija u izvještaju → dinamički iz window.LINIJA
- ⭐ **BUG-026 riješen:** Tuber izvještaj prikazuje krivu postavu → koristi window.tuberTrenutnaSmjenaData
- ⭐ **BUG-025 riješen:** ESP32 resetira count → dodana provjera get_counter_status
- ⭐ **Smjenski izvještaji:** kolone 1-3 iz proizvodnje, 4-11 ručni unos
- ⭐ **ESP32 sinkronizacija** dokumentirana opasnost od resetiranja
- ⭐ **Pravilo #17 dodano:** ZamjenePostave je globalni objekt

### 25. Siječanj 2026

- ⭐ **BUG-022 riješen:** Odvojeni Bottomer statusi (voditelj/slagač)
- ⭐ **BUG-021 riješen:** Duplo skidanje materijala (material_deducted kolona)
- ⭐ **RPC funkcije:** complete_bottomer_phase, reactivate_bottomer_phase
- ⭐ **prod_work_orders** proširen na 48+ kolona

### 24. Siječanj 2026

- ⭐ **Tuber-Materijal modul** dodan (interni modul)
- ⭐ **Tablica prod_inventory_consumed_rolls** dodana
- ⭐ **ESP32 firmware v5.3** (batch logging svakih 500 kom)

---

**Verzija dokumenta:** 1.4
**Zadnje ažuriranje:** 14. Travnja 2026 (sesija 2)
**Autor:** AI Assistant (Claude)

---

💡 **Savjet:** Prije pisanja koda, UVIJEK prvo pročitaj **20 Zlatnih Pravila Razvoja** i **Kritični Bugovi** sekcije!
