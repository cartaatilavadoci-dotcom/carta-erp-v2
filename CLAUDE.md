# CARTA-ERP - AI Razvojni Vodič

> **Verzija:** 2.0 | **Zadnje ažuriranje:** 5. Svibnja 2026 (sesija 10 — Theme migration Faza 3+4: audit script proširen s `--migrate-colors`, automatska zamjena 1694 inline hex boja u 40 view fajlova, gradient guard. Ostaje Faza 5 — cross-theme verification + Chart.js theme-aware boje)

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
- ✅ 26 zlatnih pravila razvoja koja MORAJU biti poštovana
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

## ⚡ 26 Zlatnih Pravila Razvoja

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

### Pravilo 25: Ne pisati inline `<svg>` tagove u view fragmentima ⭐ KRITIČNO

**Problem:** VSCode Live Server (Ritwick Dey ekstenzija) ima regex
`/(<\/body>|<\/svg>)/i` i ubacuje WebSocket auto-reload `<script>`
**ispred svakog `</svg>` taga**. Pošto su svi view-ovi HTML fragmenti
(bez `</body>`), Live Server pada na fallback i injektira u SVAKI SVG.
Dashboard s 30 ikona = 30 injekcija = razbijen DOM. Browser baca:

```
Uncaught SyntaxError: Failed to execute 'replaceChild' on 'Node':
Invalid or unexpected token
  at router.js:162 (ili gdje god script bude inserted)
```

**Symptom:** stranica učita HTML, ali router-ov script tag ne izvršava,
podaci ne dolaze (KPI ostaju "-"), funkcije nedefinirane. Node/jsdom
parsiraju fajl ispravno → debug težak.

**❌ POGREŠNO:**
```html
<svg xmlns="..." viewBox="..."><path d="..."/></svg>
```
```js
return '<svg ...>' + ... + '</svg>';   // SVG kao JS string
```

**✅ ISPRAVNO:** URL-encoded SVG kao CSS background:
```css
.dash-icon-users {
  background-image: url("data:image/svg+xml;utf8,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' ...%3E...%3C/svg%3E");
  width: 24px; height: 24px;
}
```
```html
<span class="dash-icon dash-icon-users"></span>
```

Ključ: zamijeni `<` s `%3C`, `>` s `%3E`, `/` s `%2F` u data URL-u.
Live Server-ov regex ne matcha URL-encoded sadržaj jer literal `</svg>`
ne postoji u source-u.

**Alternative:** CSS-only ikone (border/transform), Unicode dingbats
(⚙ ⚠ ✓ ◉), eksterni `<img src="/icons/x.svg">`, `createElementNS` DOM API.

**Vidi:** [views/dashboard.html](views/dashboard.html) `.dash-icon-*` klase
(17 ikona) + memory `feedback_no_svg_in_js_strings.md`.

**Debug:** Browser DevTools → Network → klik view.html → Response tab.
Ako vidiš `<!-- Code injected by live-server -->\n<script>...</script>`
unutar HTML strukture (ne na kraju), problem je Live Server.

### Pravilo 26: Centralizirani SVG icon sustav ⭐ NOVO (sesija 5)

**Što:** Sve nove ikone u CARTA-ERP-u koriste **CSS mask-image klase iz [css/icons.css](css/icons.css)**, NE emoji-je.

**Why:**
- Profesionalni izgled ERP-a (emojiji izgledaju ležerno)
- Konzistentnost (Lucide stroke=2 svuda)
- Boja se prilagođava kontekstu (sidebar hover/active automatski)
- Skalabilnost (xs/sm/md/lg/xl size klase)
- Ne ovisi o OS emoji renderu (svaki OS ih različito prikazuje)

**Kako koristiti:**

```html
<!-- Default 20px -->
<span class="svg-icon svg-icon-shield-check"></span>

<!-- Velicinske varijante -->
<span class="svg-icon svg-icon-alert-triangle svg-icon-lg"></span> <!-- 32px -->
<span class="svg-icon svg-icon-target svg-icon-sm"></span>          <!-- 16px -->

<!-- Custom boja (slijedi text color) -->
<span class="svg-icon svg-icon-bot" style="color:#7e57c2"></span>

<!-- Inline custom velicina -->
<span class="svg-icon svg-icon-x" style="width:14px;height:14px"></span>
```

**Pristup pod haubom:**
- `mask-image` + `background-color: currentColor` → ikona automatski prati text color (bez per-state JS)
- URL-encoded SVG (Pravilo 25 — Live Server bug zaobilaznica)
- Generirano iz Python skripte: ikone se NE pišu ručno

**Dodavanje nove ikone (workflow):**

```bash
# 1) Otvori scripts/generate_icons_css.py i dodaj u ICONS dict:
#    'moja-ikona': "<path d='...'/><circle cx='12' cy='12' r='3'/>",
#    (Lucide-style — viewBox 0 0 24, stroke='black', stroke-width=2)
# 2) Pokreni:
python scripts/generate_icons_css.py
# 3) Output: 55 ikona generirano u css/icons.css
# 4) Koristi: <span class="svg-icon svg-icon-moja-ikona"></span>
```

**Sidebar (config.js) konvencija:**

```js
// ❌ STARO (legacy emoji)
{ id: 'dashboard', icon: '📊', label: 'Pregled' }

// ✅ NOVO (icon name)
{ id: 'dashboard', icon: 'dashboard', label: 'Pregled' }
```

`buildSidebar()` u [js/utils.js](js/utils.js) detektira regex `/^[a-z][a-z0-9-]*$/` —
ako je icon ime ima samo lowercase + crtice, render ide u svg-icon span;
inače fallback na text (backward-compat za emoji).

**Status sidebar-a:** sve 40 NAV_ITEMS prešlo na semantic names u sesiji 5.

**Status modula:** [views/iso/iso-pregled.html](views/iso/iso-pregled.html) ⭐ sve emoji
zamijenjene SVG-ovima. Ostali moduli (dashboard, maintenance, tuber, bottomer...)
i dalje koriste emoji za status pillove i tab labele — migracija po potrebi.

**Vidi:** [css/icons.css](css/icons.css) (55 ikona),
[scripts/generate_icons_css.py](scripts/generate_icons_css.py) (generator),
memory `feedback_svg_icon_system.md`.

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

### 3-4. Svibnja 2026 - Sesija 9: UI redizajn dark glass blue + multi-theme arhitektura ⭐⭐⭐⭐ (mega sesija)

> **Najveći UI rad u povijesti projekta.** Cijeli ERP prebačen iz light theme (`#366092` plava + bijele kartice) u **dark glass blue** stil (inspiriran erp-dashboard.html referencom). Nakon brojnih iteracija + frustracije zbog patch-by-patch pristupa, na kraju implementirana **prava multi-theme arhitektura** s 3 teme prebacivima preko Postavke → Izgled tab.

**Konačno stanje:**
- 3 teme: **Dark Glass Blue** (default), **Light** (klasični svijetli), **Sage Mid Green** (sive-zelena wellness/eco)
- Theme switcher u **Postavke → 🎨 Izgled tab** (3 vizualne kartice s mockup preview)
- localStorage perzistencija (`carta_theme` key)
- Boot script u index.html (inline, prije CSS load) — **no FOUC**
- `<html data-theme="dark|light|sage">` mehanizam

**Foundation (Faze 1+2):**

1. **CSS variable arhitektura** ([css/styles.css](css/styles.css), 5069 linija — 1094 braces):
   - **Layer 1 — Theme tokens** (`--t-*`): ~80 varijabli definiraju paletu po temi
     - `--t-bg-page`, `--t-bg-card`, `--t-bg-input`, `--t-bg-modal`, `--t-bg-thead`, `--t-bg-row-hover`
     - `--t-primary`, `--t-text-hi/mid/lo`
     - `--t-success/warning/danger/info` + `*-bg` varijante
     - `--t-glass-bg/-border/-border-strong/-blur`
     - `--t-shadow/-shadow-lg/-glow-primary`
     - `--t-remap-warning-bg/-info-bg/-success-bg/-danger-bg/-grey-bg/-text` (za inline-style overrideove)
     - `--t-gradient-info/-warning/-success/-danger/-purple` (za card-header banneri)
     - `--t-pvnd-row-wh-bg/-hover`, `--t-pvnd-row-nli-bg/-hover` (PVND specijal — žuti/zeleni redovi)
     - `--t-postava-1..6` + `--t-postava-text` (raspored color identity)
     - `--t-logo-filter` (CSS filter chain za Carta PNG → theme primary boja)
     - `--t-color-scheme` (browser native form controls)
   - **Layer 2 — Component aliases** (`--primary`, `--bg-card`, `--text-hi`, `--success`, itd.) → svi referenciraju `--t-*` tokene. **Postojeća pravila u styles.css ostaju netaknuta** — automatski mijenjaju vrijednosti per-theme.
   - **3 theme blocka** definirani na vrhu styles.css: `[data-theme="dark"], :root` (default), `[data-theme="light"]`, `[data-theme="sage"]`
2. **Boot script** [index.html](index.html#L9-L40):
   ```javascript
   (function() {
     var allowed = ['dark', 'light', 'sage'];
     var t = localStorage.getItem('carta_theme');
     if (allowed.indexOf(t) === -1) t = 'dark';
     document.documentElement.setAttribute('data-theme', t);
   })();
   window.setTheme = function(name) {...};  // applyer + localStorage save
   window.getTheme = function() {...};
   ```
3. **Theme switcher UI** [views/admin/postavke.html](views/admin/postavke.html):
   - Novi 9. tab "🎨 Izgled" (uz Postavke / Uloge / Korisnici / Email / OEE / Plan produktivnosti / ISO 9001)
   - 3 `theme-card` s mini mockup preview (sidebar + main + cards + pillovi po temi)
   - `applyThemeFromPicker()` + `refreshThemePickerSelection()` JS handleri
   - Klik na karticu → odmah primjeni + spremi + toast confirmation

**Per-modul refactor (18+ modula očišćeno):**

⭐ **Modul-by-modul cleanup**: stripirao duplikate base klasa (`.btn`, `.card`, `.modal`, `.form-control`, `.tab-btn`, smjenski izvještaj, napomene, raspored stilove) iz view fragmenata da global styles.css preuzme. Slijedeći moduli su prošli refactor (svaki s `.bak` backupom):

| Modul | Što je strip-ano |
|---|---|
| `views/proizvodnja/bottomer-voditelj.html` | `.card/.modal/.btn/.form-control/.izvjestaj-*` duplikati |
| `views/proizvodnja/bottomer-slagac.html` | `.btn/.card/table/.izvjestaj-*` duplikati |
| `views/proizvodnja/otpreme.html` | `.modal/.form-control` duplikati |
| `views/proizvodnja/tisak.html` | `.notes-section/.note-card/.izvjestaj-*` (~150 linija) |
| `views/proizvodnja/tuber.html` | `.izvjestaj-*` duplikati |
| `views/proizvodnja/raspored-nli.html` | sve raspored klase (~230 linija) |
| `views/proizvodnja/raspored-wh.html` | sve raspored klase (~415 linija) |
| `views/proizvodnja/raspored-tisak.html` | sve raspored klase (~325 linija) |
| `views/hr/obracun.html` | `.tab-btn/.btn/.modal` duplikati |
| `views/hr/djelatnici.html` | `.tab-btn` duplikati |

⭐ **Audit script**: [scripts/audit_view_styles.py](scripts/audit_view_styles.py) — Python skripta koja sken-a sve `<style>` blokove u view fragmentima, identificira duplikate **86 base klasa** (Buttons, Cards, Modals, Forms, Tabs, Badges, itd.) i strip-a ih.
- Tri moda: `--audit` (dry-run), `--apply` (stvarno briše + .bak backup), `--report-only` (lista preostalih module-spec klasa)
- Već uklonjeno **36 duplikata** iz raznih view-ova
- **Plan**: proširiti za `--migrate-colors` mode s `HEX_TO_VAR_MAP` da automatski zamijeni hex vrijednosti u inline stilovima sa `var(...)` pozivima

⭐ **Dashboard** [views/dashboard.html](views/dashboard.html):
- Surgical rewrite: stripirano staro light-theme `<style>` block (~400 linija light theme overrides)
- Dash-icon URL-encoded SVG-ovi prebačeni s tamnog `%232c3e50` stroke-a na svijetlo plavi `%236aacee`
- Attribute-selector overrides za 50+ inline `style="background:#fafafa/#f5f5f5/#fff3e0"` itd.

⭐ **Login screen** [views/login.html](views/login.html):
- Kompletni redizajn: Carta logo (CSS filter chain za blue tint), dark glass tabovi (PIN/Admin segmented), dark inputi
- Naslijedi temu kroz `<html data-theme>` (login screen koristi istu temu kao app)
- Inline `<svg>` zamijenjeni s `.svg-icon` klasama (Pravilo 25 — Live Server bug zaobilaznica)

⭐ **Sidebar mini-collapsed mode** [css/styles.css](css/styles.css):
- Default: 56px (samo ikone)
- Hover na sidebar: expand do 220px (labeli klize unutra, sekcije se pojavljuju)
- Smooth transition 0.22s
- Mobile-mode override: full hidden + slide-in drawer

⭐ **Top header** [index.html](index.html):
- Carta logo (PNG s `--t-logo-filter` per-theme, automatski mijenja boju)
- Centarski naslov stranice (auto-update kroz `hashchange` event)
- Right side: notification bell, lozinka, odjava, user avatar (inicijali iz `Auth.getUser().name`)

⭐ **Modal layout fix**:
- `.modal-content` flex column → header sticky na vrhu, body scrolla, **actions sticky na dnu** (nikad više "ne mogu doći do gumba")
- Defense-in-depth: svi descendantsi `.modal-content` (p, div, span, td, h1-h6, label, small, strong) imaju eksplicitno light text
- `<select><option>` dropdown OS-default bijeli/crni → forsiran dark `#07142e`

**Module-specific theme-aware komponente:**

⭐ **PVND specijal** ([views/proizvodnja/pvnd.html](views/proizvodnja/pvnd.html) `.row-wh/.row-nli`):
- W&H redovi: žuti tint (per-theme: dark `#2a2210`, light `#fffde7`, sage `#3d3a25`)
- NLI redovi: zeleni tint (per-theme: dark `#112820`, light `#e8f5e9`, sage `#2d3d33`)
- Hover pojača boju + akcent slijeva (border-left + box-shadow inset)
- KPI kartice color-coded varijante (`.kpi-card.nli` orange, `.wh` green, `.total` blue, `.plan` purple) — restored nakon što ih je generic kpi-card override "potonuo"

⭐ **Smjenski izvještaj print template** (`.izvjestaj-print/-table/-input-*`):
- Print mode `@media print` ostaje papir-bijel u svim temama (za fizički print)
- Screen view: dark glass cells, theme-aware boje
- "PROIZVEDENA KOLIČINA" orange akcent (semantic za "glavni input") preko `var(--remap-warning-bg)`

⭐ **Rasporedi (NLI/WH/Tisak)** sa **postava color tokens**:
- 6 boja postava (P1-P6) preko `--postava-1..6` tokena per-theme
- NLI koristi P1-P6, WH koristi P1-P5, Tisak koristi T1-T3 (mapirano isti tokeni)
- `.subota-row` (žuti tint), `.nedjelja-row` (crveni), `.today-row` (plavi outline), `.slobodni-cell` (gray), `.neradna-cell` (crveni) — sve preko `--remap-*-bg` tokena
- Week badges (.week-a/b/c) koriste postava-1/2/3 boje za rotaciju
- Edit section, subote section, info-box, rotacija-info, satnica-info — sve theme-aware

⭐ **Ovjera RN** (.ovjera-* klase):
- Cijeli desni detalji panel (bila bijela površina) → dark glass
- Card title gradient banneri (info/spec/pdf/approval/history) → muted glass
- Spec section (Pakiranje, dimenzije, slojevi papira) → dark glass + light text
- Result boxes (ODOBRENO/ODBIJENO history) → semantic glass
- Action buttons (Odobri/Odbij/Resubmit) — semantic gradient gumbi

⭐ **ISO moduli (svih 13)** s shared `.iso-*` class system:
- `.iso-module-card` (dashboard kartice) — glass card s left border u semantic boji
- `.iso-alert-warning/success/danger` (callouts) — muted glass
- `.iso-pill-major/minor/observation/status-*` — semantic pillovi
- `.iso-table` thead/tr/td — dark glass
- `.iso-source-*` (NC source badges) — color-coded ikonice (rola purple, stroj orange, audit blue, itd.)
- `.iso-countdown-badge.ok/warn/danger` (audit countdown semafor)

⭐ **Postavke modul** s 9 tabova (Postavke / Uloge / Korisnici / Email / Email Primatelji / OEE / Plan produktivnosti / ISO 9001 / **Izgled**):
- `.settings-tabs/-tab/-tab.active` — glass plavi tab strip
- `.setting-item` (mini-card po settingu) — glass
- `.roles-table/-table` — dark glass headers s plavim accentom
- `.perm-badge` permission pillovi
- `.btn-edit/delete/test` action buttons
- `.email-info-box` warning banner
- `.test-result.success/error` — semantic glass

**Sidebar nav-item text contrast** bumpan: `var(--text-mid)` (78% bijelo umjesto 65%) — Atila konkretno tražio "slova se loše vide". Plus `.user-name`, `.user-role` u footer-u brighter.

**Carta logo theme-aware filter chain:**
```css
[data-theme="dark"]  --t-logo-filter: ... → blue #6aacee
[data-theme="light"] --t-logo-filter: ... → dark blue #1976d2
[data-theme="sage"]  --t-logo-filter: ... → sage green tone
```
Generirano kroz https://codepen.io/sosuke/pen/Pjoqqp pattern (brightness(0) saturate(100%) → invert/sepia/saturate/hue-rotate). Logo PNG je originalno zelen, filter chain ga preliva u theme primary.

**Animacije + transitions:**
- `transition: background-color 0.30s, color 0.30s` na body (smooth theme switch)
- Sidebar hover expand: 0.22s ease
- Modal flex layout: header sticky / body scroll / footer sticky
- Top header: 0.30s background transition

---

**Plan dokumenta**: [`C:\Users\Atila\.claude\plans\joj-da-smo-odmah-goofy-sparkle.md`](C:\Users\Atila\.claude\plans\joj-da-smo-odmah-goofy-sparkle.md) — kompletna theme switching arhitektura s 5 faza + sub-task za rasporede. **Status na kraju sesije 9:**

| Faza | Što | Status |
|---|---|---|
| 1a | Layer 1+2 variable arhitektura + 3 theme blocka | ✅ Done |
| 1b | Refactor hardkodiranih rgba u styles.css (33 najčešće zamjene + sidebar text + 3 logo lokacije) | ✅ Done |
| 1c | Outliers cleanup (tisak notes/pregled, smjenski izvještaj 3 modula, ovjera-rn detalji, rasporedi 3) | ✅ Done |
| 2a | Boot script u index.html | ✅ Done |
| 2b | Izgled tab u Postavkama (3 theme cards + applyTheme) | ✅ Done |
| **3** | Extend audit_view_styles.py s --migrate-colors (HEX_TO_VAR_MAP) | ⏳ **Sljedeća sesija** |
| **4** | Mass migration svih 47 view-ova kroz extended audit script | ⏳ **Sljedeća sesija** |
| **5** | Cross-theme verification + outlier fixing (dashboard 542 inline stilova, charts theme-aware boje, login background gradient) | ⏳ **Sljedeća sesija** |

**Sljedeća sesija — što treba napraviti:**

1. **Faza 3** (~30 min): proširiti `scripts/audit_view_styles.py` s novim `--migrate-colors` modom. Dodati `HEX_TO_VAR_MAP` dict (~50 entries) koji mapira najčešće hex kodove (#fff8e1 → `var(--remap-warning-bg)`, itd.). Parser proširit da čita inline `style="..."` atribute u HTML body-u (ne samo `<style>` blokove). Output: report unmapped boja per file.

2. **Faza 4** (~1-2 sesije): pokrenuti `python scripts/audit_view_styles.py --migrate-colors --apply` na svih 47 view-ova. Generira `migration_report.txt`. Manual fix outlier-a za rare hex bez mappinga.

3. **Faza 5**: cross-theme verification — proći kroz dashboard / planiranje / PVND / ovjera-rn / ISO pregled / HR place / postavke u svim 3 teme. Dashboard.html (542 inline stilova) je najveći risk — može trebati surgical fixes.

4. **Charts theme-aware**: Chart.js u dashboardu trenutno koristi hardkodirane boje. Treba čitati `getComputedStyle(document.documentElement).getPropertyValue('--primary')` da automatski adapta na temu.

5. **Outliers koje znamo:**
   - Login background gradient (potencijalno hardkodiran)
   - ISO klimatske ikone (možda imaju specifične boje koje trebaju per-theme)
   - OEE gauge boje (Chart.js + custom donut)
   - Print mode (`@media print`) verify da ostaje papir-bijel u svim temama

**Quick wins pripremljeni:**
- ✅ Foundation radi savršeno (3 teme se prebacuju instant, no FOUC, perzistira)
- ✅ Sidebar / top header / modali / forme / tablice / izvještaji rade u sve 3 teme
- ✅ Rasporedi su demo da theme-aware semantic identity radi (P1-P6 plave/narandžaste/zelene/roze/ljubičaste/amber u svim temama)
- ⚠️ Postoji **outliers** u modulima koje nisu prošli individual refactor (npr. dashboard inline stilovi) — vidjive samo u Light/Sage temama, Dark izgleda OK svuda

**Promjene u ostalim datotekama (sumarno):**
- `css/styles.css` — narastao s 1643 → **5069 linija** (1094 braces, balansiran). Dodano: 3-layer variable system, 3 theme blocks, ~330 linija raspored override, ~150 linija postavke override, ~100 linija ovjera-rn override, ~80 linija PVND, sve novo theme-aware
- `index.html` — boot script (32 linije) + Carta logo s `var(--t-logo-filter)` + Chart.js CDN dodan (za buduće dashboard refactor)
- `views/admin/postavke.html` — Izgled tab + theme picker UI + applyThemeFromPicker handler + ~110 linija nova CSS za `.theme-card/-card-preview/-card-body/-card-check`

**Kritički bugovi popravljeni u sesiji:**
- 🐛 **TR background show-through** — globalno `table tr:hover td { background: var(--bg-table-row-hover) }` overridealo `.row-wh:hover { background: amber }` jer TD bg pobjeđuje TR bg show-through. Fix: bg ide direktno na TD (`.row-wh:hover td { background: amber !important }`).
- 🐛 **Logo magenta umjesto plav** — `hue-rotate(180deg)` zarotirao zelenu (98°) na 278° = magenta. Fix: color-to-hex filter chain (brightness(0) → invert+sepia+saturate) garantira tačnu boju.
- 🐛 **Modal actions/footer cut off** — dodano `display: flex; flex-direction: column` na `.modal-content`, body s `flex: 1; overflow: auto`, footer s `flex-shrink: 0` (uvijek vidljiv).
- 🐛 **Mobile-side-menu drawer always visible** — `mobile.js` stvara DOM ali stari CSS imao `display: none`, novi CSS nije imao → drawer bio vidljiv kao normal block. Fix: dodano `.mobile-side-menu { display: none }` + `.active { display: block }` u novi CSS.
- 🐛 **Tab buttons washed out** — `.main-tabs/.month-tabs` u PVND-u su WHITE KONTEJNERI koji wrap-aju tabove. Fix: container bg → glass dark. Plus generic `.kpi-card` override potonuo `.kpi-card.nli/.wh/.total/.plan` color-coded varijante — fix: dodatno specifična pravila s !important.

**Metoda rada (lessons learned):**
- ✅ **Audit script** za batch strip duplikata (efikasno kad su patterni jasni)
- ✅ **`.bak` backup** prije svakog destruktivnog edit-a
- ❌ **Patch-by-patch ručno editiranje** ne skalira — user je s pravom rekao "iscrpno je"
- ✅ **Modul-by-modul refactor** s STRIP duplikata + GLOBAL pravila u centralnom CSS-u — pravi arhitektonski pristup
- ✅ **CSS varijable kao theme tokens** od početka — najveća lekcija. User je rekao "joj da smo odmah napravili kako treba davno bi bilo gotovo" — zato je sad theme switching pravilno podržan i sve buduće promjene su trivijalne

---

### 3. Svibnja 2026 - Sesija 8: Audit Sprint Mode + Bell ISO alerts + sprint roadmap ⭐⭐

> Quality-of-life sprint poslije završetka 13/13 ISO modula. Dvije nove core funkcionalnosti i strateški roadmap za Sprint A/B/C.

**Audit Sprint Mode (na ISO Pregledu):**
- ⭐ Auto-banner se pojavljuje kad je `iso_next_external_audit_date` ≤90 dana
- ⭐ Modal s 12 stavki checklist-a: provjerava sve kritične audit pretpostavke (auto-NC pregledan, CAPA past due, dokumenti vlasnici, kalibracije, dobavljači bodovani, KPI mjerenja, interni audit odrađen, ocjena uprave potpisana, politika v2.0 aktivna, reklamacije evidentirane)
- ⭐ Per-stavka: status (✓/⚠️/✗) + count + direct link na modul
- ⭐ Sortirano po prioritetu (kritično → warning → ok)
- ⭐ Sumarna kartica + zaključak ("spreman za audit" ili "X kritičnih riješi")

**Bell notifikacije za ISO (5 tipova):**
- ⭐ DB trigger `fn_iso_notify_auto_nc` — pri kreiranju auto-NC (rola otpis ili kvar) automatski kreira bell notifikaciju za PUK/koordinatore (real-time kroz Supabase realtime)
- ⭐ DB funkcija `iso_generate_alerts()` — provjeri 5 tipova s cooldown-om:
  - CAPA past due (24h cooldown)
  - Kalibracije ≤7d (24h)
  - Eksterni audit ≤30d (24h)
  - Dokumenti review ≤7d (7d)
  - Auto-NC nepregledan >3d (48h)
- ⭐ JS hook `Notifications.maybeGenerateIsoAlerts()` poziva funkciju 1× po 6h po sesiji (localStorage timestamp)
- ⭐ Routing: klik na bell stavku otvara odgovarajući ISO modul (NC → nesukladnosti, CAPA → capa, kalibracija → mjerna-oprema...)
- ⭐ 6 novih ikona u `_iconForType()` map (🤖 ⏰ 📏 🛡️ 📑)

**Atilini odgovori na strateška pitanja (ova sesija):**
1. **Gemini deploy:** Atila će pribaviti API key + deploy Cloudflare proxy danas/sutra. Sprint A AI ekspanzija ide nakon toga.
2. **Domena:** Nema (B4 anketa zadovoljstva čeka).
3. **Supabase plan:** Pro (pg_cron dostupan — B5 može).
4. **ZNR modul:** Nakon završetka ISO. **Atila želi sve sprint-e A/B/C odmah** bez obzira na audit.

**Roadmap zaključen (Sprint A/B/C):**

- **Sprint A — AI ekspanzija** (5 podsprintova): A1 mgmt review komentari, A2 5-Why CAPA, A3 doc generator, A4 reklamacija klasifikacija, A5 policy chat widget
- **Sprint B — Quality of Life** (6 podsprintova): B1 backfill osposobljavanja iz PDF, B2 backfill reklamacija s Drive, B3 PDF traceability export, B4 anketa zadovoljstva (čeka domenu), B5 pg_cron za KPI, B6 mobile QR scanner
- **Sprint C — Šira poboljšanja** (4 podsprinta): C1 ZNR/HACCP modul (3-4 sesije, najveće), C2 CARTA AI Widget proširenje, C3 ESG report generator, C4 multi-tenant priprema (post-audit, kandidat za standalone SaaS)

---

### 3. Svibnja 2026 - Sesija 7: ISO 9001 Faza 3 — KOMPLETIRANO (Auditi + Reklamacije + Ocjena uprave + Gemini AI) ⭐⭐⭐

> **Faza 3 sprint — 3 zadnja ISO modula + Cloudflare AI proxy. SVIH 13/13 ISO MODULA SAD GOTOVO.** Pripremno je sve da Cartin sustav prođe rujanski eksterni audit s puno boljim ocjenama nego prošlih godina (auditor neće više imati istih 3 P-finding-a iz 2022-2025).

**Novi UI moduli (3 zadnja):**

- ⭐ **[views/iso/iso-auditi.html](views/iso/iso-auditi.html)** — OB_02/03/09 audit modul:
  - Year switcher + 4 KPI (ukupno, planirani, provedeni, otvoreni nalazi)
  - Tablica auditi za godinu s tipovima (interni/eksterni/dobavljača)
  - Modal: scope_processes multi-select (checkbox grid), audit team, vanjski konzultant flag
  - Detail panel s 3 sekcije: meta + AI banner + checklist + nalazi
  - **AI Checklist Generator** — gumb poziva `/api/iso/gemini` proxy, šalje real-time kontekst (nc_total, capa_open, documents_published, scope), spremaaj 15-20 pitanja u `iso_audit_checklist`
  - "Dodaj nalaz" inline (prompt) — major/minor/observation/preporuka, automatski incrementira finding_number
  - "Otvori CAPA" deep-link iz finding-a
- ⭐ **[views/iso/iso-reklamacije.html](views/iso/iso-reklamacije.html)** — workflow modul reklamacija kupaca:
  - 4 KPI (otvorene, major, nove 7d, zatvorene 30d)
  - Filteri: status, severity, kupac (lookup iz prod_customers)
  - Modal s svim poljima (kupac picker ILI ručni unos, RN/dispatch, kategorija, severity, technical_visit_date, cost tracking, resolution)
  - **"Auto-otvori NC" checkbox** — pri spremanju reklamacije auto-kreira nesukladnost u `iso_nonconformities` i poveže nc_id back-reference
  - **"Import iz Drive" gumb** — pre-popunjava modal s podacima iz postojeće Moravacem reklamacije s Cartine Google Drive (Atila samo treba potvrdit i spremit)
- ⭐ **[views/iso/iso-ocjena-uprave.html](views/iso/iso-ocjena-uprave.html)** — godišnji OB_12 obrazac:
  - Year switcher (2023-2027)
  - Per-godina struktura: tim za ocjenu (auto-popunjava se iz ISO postavki — Branka/Kristina/Vedrana/Krunoslav), 11 inputa po Cartinom OB_12 template-u (a, b, c1-c7, d, e, f)
  - Svaki input: 4 score dugmeta (1=loše/2=djelomično/3=potpuno/N=nije primjenjivo) + textarea s autosave (debounce 600ms)
  - Vizualna boja border-left-a po score-u (crveno/žuto/zeleno/sivo)
  - Score summary bar (avg, broj 1-2-3-N) + "Pre-popuni iz baze" gumb (agregira NC count, CAPA count, audit findings, KPI achieved, suppliers A/C class, complaints — i automatski popunjava komentare gdje su prazni)
  - **"Potpiši i objavi" gumb** (samo za Predsjednicu uprave) — postavlja signed_by_management, signed_at, signed_by → ocjena postaje formalan dokument za audit
  - "Obriši ocjenu" za poništenje (s confirm)

**Cloudflare Pages Function — Gemini AI proxy (Pravilo: AI proof-of-value):**

- ⭐ **[scripts/gemini-proxy/functions/api/iso/gemini.js](scripts/gemini-proxy/functions/api/iso/gemini.js)** — kompletan proxy s 4 feature-a:
  - `audit_checklist` — generira 15-20 pitanja po ISO klauzulama 4-10 s real-time brojkama
  - `doc_generator` — draft procedure/uputstva u HR jeziku
  - `rca` — 5-Why root cause analysis za NC
  - `mgmt_review` — komentari za sve 11 sekcija OB_12
- ⭐ **Cache + audit log u `iso_ai_outputs`** — SHA-256 prompt hash, ponovljen poziv vraća cached response (0 tokena)
- ⭐ **CORS handling** za browser pozive
- ⭐ **Format normalizacija** — JSON output (osim doc_generator koji vraća plain text)
- ⭐ **[scripts/gemini-proxy/README.md](scripts/gemini-proxy/README.md)** — kompletne setup upute (Wrangler CLI ili GitHub Pages integracija + env vars), demo plan za upravu, troubleshooting
- ⭐ Free tier (Gemini 2.5 Flash, 15 req/min, 1500 req/dan) — više nego dovoljno za ISO use case
- ⭐ **Strategija "AI proof-of-value first"** (memory): Atila prvo dokazuje ROI s besplatnim alatom, pa nakon 3-6 mjeseci traži uprava odobrenje za plaćeni AI

**Document Control proširenja:**

- ⭐ **Edit metapodataka modal** za postojeće dokumente — gumb pencil ⏐ pored eye/upload akcija u tablici
  - Reuse postojeći docModal s mode='editmeta:UUID'
  - Dynamically sakriva version+file polja (samo metapodaci)
  - Polja: code, title, doc_type, category, owner_employee_id, classification, review_interval_months, status, description
  - Riješava problem da bulk import 36 dokumenata nije imao vlasnike — sad PUK može jedan po jedan dodijeliti vlasnike

**Verifikacija u DB nakon Faze 3:**
- 19 iso_ tablica ✅
- 37 dokumenata u Document Control ✅
- 14 NC + 16 rizika ✅
- 0 CAPA / 0 audita / 0 reklamacija / 0 ocjena uprave (Atila treba kreirati prve podatke)
- 5 KPI rezultata za travanj 2026 ✅
- Cloudflare proxy spreman za deploy (Atila treba: pribaviti Gemini key + deploy preko Wrangler ili GitHub)

**Stanje napretka prema rujanskom auditu — KOMPLETIRANO:**

| Modul | Status | Audit must-have (clause) |
|---|---|---|
| Document Control | ✅ Faza 1 | 7.5.1-3 |
| Nesukladnosti (NC log) | ✅ Faza 1 | 10.2.1 |
| CAPA workflow | ✅ Faza 2 | 10.2.2 (effectiveness) |
| Ciljevi kvalitete | ✅ Faza 1 | 6.2 |
| Procesi (OB_20) | ✅ Faza 2 | 4.4 |
| Rizici (incl. climate) | ✅ Faza 2 | 6.1 |
| Dobavljači (auto) | ✅ Faza 2 | 8.4 |
| Mjerna oprema | ✅ Faza 1 | 7.1.5 |
| Osposobljavanja | ✅ Faza 2 | 7.2 |
| Reklamacije kupaca | ✅ Faza 3 | 9.1.2 |
| Interni auditi + AI | ✅ Faza 3 | 9.2 |
| Ocjena uprave | ✅ Faza 3 | 9.3 |
| ISO Pregled | ✅ Faza 1 | (interno) |

**13/13 modula tehnički gotovo. Sad je na Atili da popuni stvarne podatke.**

**Što ostaje za pred audit (administracije, ne razvoj):**
1. **Postavi PUK** u Postavke → ISO 9001 (Kristina Čubela / Ivica Vajnberger)
2. **Kreiraj prvi interni audit** za 2026 (rok: 2 mjeseca prije eksternog = lipanj/srpanj 2026)
3. **Pokreni AI checklist generator** (zahtijeva Cloudflare deploy + Gemini key — vidi scripts/gemini-proxy/README.md)
4. **Dodijeli vlasnike** dokumentima (37 ih treba review)
5. **Bodi dobavljače za 2026** (8 dobavljača s auto-prijedlozima)
6. **Unesi prvu reklamaciju** (Moravacem) preko "Import iz Drive" gumba
7. **Backfill osposobljavanja** iz `ISO 9001/2025/Osposobljavanje*.pdf` PDF-ova
8. **Zatraži Branku da potpiše Politiku kvalitete v2.0** (draft u Projektna dokumentacija/)
9. **Generiraj Ocjenu uprave 2026** kroz modul + "Pre-popuni iz baze" gumb + Branka potpiše

**Quick wins planirani za Fazu 4 (NAKON audita):**
- pg_cron schedule za nightly KPI recompute (kad MCP omogući extension management)
- Backfill historical reklamacija s Drive-a (pretraga foldera "Reklamacije i izvješća")
- Slijed dokumentacije završenog projekta — PDF export za customer recall
- Audit Sprint Mode wizard — UI koji kaže "imaš 30d do audita, evo što fali"
- AI integracija u CAPA modul (5-Why button)
- Mobile QR scanner za dokumente (auditor scaniranje na terenu)

---

### 3. Svibnja 2026 - Sesija 6: ISO 9001 Faza 2 (CAPA + Rizici + Dobavljači + Procesi + Osposobljavanja) ⭐⭐⭐

> Faza 2 sprint — 5 dodatnih ISO modula gotovih, 16 rizika seedanih (uključujući 4 klimatska iz politike drafta), auto-bodovanje dobavljača iz proizvodnih podataka, manual KPI recompute gumb. **9/13 ISO modula gotovo, 4 placeholderi (auditi, reklamacije, ocjena-uprave + interna 1).**

**Novi UI moduli (5):**

- ⭐ **[views/iso/iso-capa.html](views/iso/iso-capa.html)** — CAPA workflow modul:
  - 4 KPI kartice (u procesu, past due, čeka effectiveness, zatvoreno 30d)
  - Filteri: status, tip (korektivna/preventivna), izvršitelj
  - Modal: full add/edit, povezivanje s NC (lookup dropdown), root cause method (5-Why/Ishikawa/FMEA)
  - **Workflow gate**: status='Zatvoreno' BLOKIRAN bez `effectiveness_verified=true` (frontend + DB validacija)
  - Detail panel s **5-step progress bar** (Otvoreno → U tijeku → Implementirano → Verificirano → Zatvoreno)
  - Quick action gumbi za prelaz između stanja, "Provjeri djelotvornost" prompt
  - Deep-link iz NC modula: `#iso-capa?prefill_nc=UUID` automatski otvara modal s pre-popunjenim podacima
- ⭐ **[views/iso/iso-rizici.html](views/iso/iso-rizici.html)** — OB_18 Registar rizika:
  - 4 KPI (ukupno, veliki ≥6, srednji 3-5, mali 1-2)
  - **Vizualna 3×3 risk matrix** s brojevima rizika u svakoj ćeliji (legenda obojena po kategorijama)
  - Filteri: područje (9 područja uključujući "Klimatski"), status, score
  - Modal s prob×severity dropdownom + auto-izračun score-a u realtime
  - Auto-color score-a (zeleno/žuto/crveno) prema prag-u
  - **Seedano 16 rizika**: 12 iz OB_18 (repromaterijal, usluge trećih, gotovi proizvodi, u proizvodnji × 2, skladiste × 2, administracija, održavanje × 2, dnevna kontrola) + **4 klimatska** (otežana dostava papira, povećani trošak energije, ESG zahtjevi kupaca, EU PPWR regulativa) — **prvi cartin Climate Risk Assessment**
- ⭐ **[views/iso/iso-dobavljaci.html](views/iso/iso-dobavljaci.html)** — OB_10 auto-bodovanje (rješava 4-godišnju auditor preporuku!):
  - Year switcher (2023–2027)
  - 4 KPI: aktivni, A klasa (8-9), B klasa (5-7), C klasa (1-4)
  - Tablica s metrikom (isporuke, reklamacije, kašnjenja, ukupno kg) + auto-predlozenim ocjenama
  - Modal s 1-3 dropdownima po dimenziji (kvaliteta/rok/cijena), auto-recalc total + klasifikacija u realtime
  - Visual hint koja je auto-vrijednost vs PUK ocjena
  - "Potpiši i spremi" workflow s timestampom
- ⭐ **[views/iso/iso-procesi.html](views/iso/iso-procesi.html)** — OB_20 pregled u **card grid layoutu**:
  - Svaki proces: kod, naziv, vlasnik (uloga + employee), ulazi, izlazi, frekvencija, metoda mjerenja
  - **Live KPI panel po procesu**: pokazuje povezane KPI ciljeve s ✓/✗ statusom
  - Add/Edit modal s svim metapodacima
  - Inactive procesi grayscale (opacity 0.55)
- ⭐ **[views/iso/iso-osposobljavanje.html](views/iso/iso-osposobljavanje.html)** — Training matrix s 2 taba:
  - **Tab 1 — Evidencija osposobljavanja**: tablica per zaposlenik, validity badge (zeleno/žuto/crveno), filteri (zaposlenik, status validity)
  - **Tab 2 — Plan / zahtjevi**: definicija što sve zaposlenici moraju imati prema poziciji/stroju
  - Modal evidencije auto-popunjava polja iz odabranog requirementa (naziv, trener, valid_until iz validity_months × completed_date)
  - Sortiranje po isteku (najkraće prvi, auditor friendly)

**DB izmjene:**

- ⭐ **PL/pgSQL `iso_supplier_metrics(year)` RPC** — agregira broj isporuka, reklamacija, ukupne težine i auto-predlaže 1-3 score po dimenziji iz `prod_inventory_rolls` + `iso_nonconformities`
- ⭐ **Seed 16 rizika** s tekstom iz Cartinog OB_18 + climate risks
- ⭐ **3 SQL title fix** (OB-07, KV-SMJENA, POL-01) za bolje prikazivanje u Document Control

**Bug fixes:**

- ⭐ **Nesukladnosti detail "Otvori CAPA"** više nije disabled — sad otvara CAPA modul s prefill iz NC (deep link kroz `?prefill_nc=UUID`)
- ⭐ **Bulk import skripta `import_iso_2025.py`** — popravljena 2 regex bug-a:
  - UP regex hvatao "UP-0" iz "UP_02UPUTSTVO..." (lookahead bila pogrešno postavljena) → sad `(?=[\s_-]|$)` hvata samo varijantna slova ako iza njih ima separator
  - OSP suffix bio "OSP-OSPOSOBLJAVANJE-XX" (redundantno) → sad skip set uklanja "osposobljavanje"/"uvjerenje" iz tokena pa rezultat je "OSP-PODRUCJA-ZASTITE", "OSP-ARKS", "OSP-RAD-STROJU" itd.

**KPI engine extension:**

- ⭐ **Manual KPI recompute gumb** na iso-pregled.html — poziva `iso_recompute_kpis()` RPC (umjesto čekanja nightly cron-a koji još nije aktiviran)

**Verifikacija u DB:**
- 19 iso_ tablica ✅
- **37 dokumenata** importirano u Document Control (uključujući POL-01 koji je Atila ručno uploadao + 36 iz bulk import-a)
- **14 NC** + 0 CAPA još (Atila treba kreirat prvi)
- **16 rizika** (12 OB_18 + 4 klimatska) ✅
- **0 dobavljačkih evaluacija** (Atila treba prvi put potpisati ocjene za 2026)
- **10 procesa** seedano ✅
- **9 KPI ciljeva**, 5 popunjenih za travanj 2026 ✅
- **0 osposobljavanja** (Atila treba unijeti — ima dobre PDF-ove iz `ISO 9001/2025/Osposobljavanje*.pdf`)

**Što ostaje za sljedeću sesiju (Faza 3 — pred audit):**
- iso/auditi.html + AI checklist generator (PRVI Gemini AI use case za demo upravi)
- iso/reklamacije.html + Gmail integracija (postoji već 1 Moravacem reklamacija na Drive-u)
- iso/ocjena-uprave.html — godišnji izvještaj (kasnije s AI draftom)
- Edit metapodataka modal za dokumente (vlasnik, status, klasifikacija)
- pg_cron schedule za nightly KPI recompute (kad MCP omogući extension management)
- Backfill osposobljavanja iz `ISO 9001/2025/Osposobljavanje_*.pdf` PDF-ova

**Stanje napretka prema rujanskom auditu:**

| Modul | Status | Audit must-have |
|---|---|---|
| Document Control | ✅ Faza 1 | DA — clauses 7.5.1-3 |
| Nesukladnosti (NC log) | ✅ Faza 1 | DA — clause 10.2.1 |
| CAPA workflow | ✅ Faza 2 | DA — clause 10.2.2 (effectiveness verification) |
| Ciljevi kvalitete | ✅ Faza 1 | DA — clause 6.2 |
| Procesi | ✅ Faza 2 | DA — clause 4.4 |
| Rizici | ✅ Faza 2 (incl. climate) | DA — clause 6.1 |
| Dobavljači | ✅ Faza 2 | DA — clause 8.4 (4-godišnja preporuka!) |
| Mjerna oprema | ✅ Faza 1 | DA — clause 7.1.5 |
| Osposobljavanja | ✅ Faza 2 | DA — clause 7.2 |
| Reklamacije kupaca | ⏳ Faza 3 | DA — clause 9.1.2 |
| Interni auditi | ⏳ Faza 3 | DA — clause 9.2 (mora biti odrađen prije eksternog!) |
| Ocjena uprave | ⏳ Faza 3 | DA — clause 9.3 |
| ISO Pregled | ✅ Faza 1 | NE (interno za nas) |

**9/13 modula spremno, 3 ostaju za Fazu 3 (auditi/reklamacije/ocjena-uprave) + administracije za Atilu da unese stvarne podatke.**

---

### 2. Svibnja 2026 - Sesija 5: ISO 9001 Faza 1 (start) + SVG icon sustav ⭐⭐⭐

> Sesija s dva paralelna toka rada: **ISO 9001 modul** se počinje graditi prema 4-mjesečnom roku (eksterni audit rujan 2026), i **SVG icon sustav** zamijenio emojije u sidebaru i prvom ISO view-u.

**Strateški kontekst:**
- Cartin sljedeći eksterni nadzorni audit certifikatora je u **rujnu 2026** (~4 mjeseca rok)
- Plan: Faze 1–3 ISO modula moraju biti gotove prije rujna (Document Control, Nesukladnosti, CAPA, KPI, Auditi, Rizici, Dobavljači, Osposobljavanja, Mjerna oprema, Reklamacije)
- Faza 4 (Ocjena uprave AI draft, traceability PDF) i Faza 5 (14001) idu nakon audita
- Pravilo "subsidized R&D" iz master konteksta — Carta plaća, output validira realnim use case-om, kasnije mogući SaaS

**ISO 9001 — DB layer (3 migracije primijenjene na produkciju):**
- ⭐ **`iso_schema_v1.sql` (~1100 linija):** 19 `iso_*` tablica
  - Document Control: `iso_documents`, `iso_document_versions`, `iso_document_acknowledgements`
  - Procesi i ciljevi: `iso_processes` (OB_20), `iso_quality_objectives` (OB_06 — KPI + projektni hibrid), `iso_quality_objective_results`
  - Nesukladnosti i CAPA: `iso_nonconformities` (OB_05 zamjena), `iso_capa` (s effectiveness gate-om — ISO 9001:2015 cl. 10.2)
  - Rizici: `iso_risks` (OB_18) s GENERATED kolonom `score = probability * severity`
  - Auditi: `iso_audits` (OB_02/03/09), `iso_audit_checklist`, `iso_audit_findings`
  - Mjerna oprema: `iso_measuring_equipment` (OB_14) — kalibracije + inspekcije
  - Dobavljači: `iso_supplier_evaluations` (OB_10 auto-bodovanje)
  - Osposobljavanja: `iso_training_requirements` + `iso_employee_trainings` (OB_07/08)
  - Reklamacije kupaca: `iso_customer_complaints` (workflow zaprimanja → tehničkog posjeta → rezolucije)
  - Ocjena uprave: `iso_management_reviews` (OB_12)
  - AI cache: `iso_ai_outputs` (Gemini prompt hash + audit log)
- ⭐ **2 trigger-a na postojeće tablice (auto-NC iz proizvodnje):**
  - `trg_iso_nc_from_roll_otpis` na `prod_inventory_rolls` (UPDATE OF status='Otpisano') — auto-NC s severity=major ako rola ≥500kg
  - `trg_iso_nc_from_failure` na `prod_failure_reports` (INSERT) — auto-NC ako priority=high ili downtime ≥60min, severity=major ako ≥240min
- ⭐ **5 helper funkcija za auto-numbering:** `iso_next_nc_number()`, `iso_next_capa_number()`, `iso_next_audit_number()`, `iso_next_complaint_number()`, `iso_next_risk_number()` (format `NC-2026-0001`, `CAPA-2026-0001` itd.)
- ⭐ **`v_iso_pregled` view** — 16 KPI-eva za dashboard (otvoreni NC, overdue CAPA, dokumenti za review, kalibracije uskoro, osposobljavanja isteci, reklamacije, visoki rizici, sljedeci audit countdown)
- ⭐ **Storage bucket `iso-documents`** (50 MB limit, PDF/DOCX/XLSX/slike) + 4 RLS policies
- ⭐ **Seed:** 10 procesa iz OB_20 (Vođenje, Upravljanje kvalitetom, Nuđenje, Nabava, Priprema, Proizvodnja, Kontroling, Administracija, Skladištenje, Održavanje), 9 KPI ciljeva za 2026 (isporuka u roku 95%, % nesukladnosti <1%, OEE prosjek 70%, % škarta <1%, prolaznost ponuda 50%, osposobljavanje 90%, sati zastoja zbog kvara <2%, kašnjenja u nabavi 0, CAPA past due 0)
- ⭐ **16 ISO settings** u `settings` tablici (PUK ID, certifikator, datum sljedećeg audita = 2026-09-15, pragovi škarta i kvarova, default rok CAPA, frekvencija pregleda dokumenata)
- ⭐ **Update prod_roles:** 5 postojećih rola (admin, uprava, racunovodstvo, voditelj-odrzavanja, koordinator-proizvodnje) dobile ISO dozvole + nova rola **`koordinator-odrzavanja`**

**ISO 9001 — UI layer:**
- ⭐ **Novi sidebar item "ISO 9001"** s 13 podstranica (config.js NAV_ITEMS proširen)
- ⭐ **router.js** — viewPath mapping `iso-*` → `views/iso/{viewId}.html`
- ⭐ **[views/iso/iso-pregled.html](views/iso/iso-pregled.html)** — kompletni dashboard:
  - 6 KPI status kartica (otvoreni NC, CAPA past due, dokumenti za review, kalibracije, osposobljavanja, reklamacije)
  - Auto-NC alert (prikazuje koliko auto-generiranih NC čeka pregled)
  - 12 modul-card brzog pristupa s live brojkama
  - Tablica posljednjih 10 nesukladnosti s source badges
  - Tablica KPI ciljeva 2026 (target vs zadnja vrijednost)
  - External audit countdown (semafor: zeleno/žuto/crveno po blizini)
- 12 ISO modula (dokumenti, nesukladnosti, capa, ciljevi, procesi, rizici, auditi, dobavljaci, osposobljavanje, mjerna-oprema, reklamacije, ocjena-uprave) — placeholderi 404 zasad, idu sljedećim sprintovima

**SVG icon sustav (cross-cutting promjena):**
- ⭐ **Pravilo 26 dodano** — sve nove ikone idu kroz `css/icons.css` mask-image klase, NE emojije
- ⭐ **`scripts/generate_icons_css.py`** (NOVO) — Python generator s 55 Lucide-style ikona (single source of truth)
- ⭐ **`css/icons.css`** (NOVO) — 55 ikona kao `mask-image` + `background-color: currentColor` → ikona slijedi text color (sidebar hover/active rade automatski)
- ⭐ **URL-encoded SVG** (Pravilo 25 ispoštovano — Live Server ne lomi script tag)
- ⭐ **5 size klasa:** `svg-icon-xs/sm/md/lg/xl` (14/16/24/32/48px), default 20px
- ⭐ **App-specific overridei** za `.nav-icon.svg-icon` (22px), `.menu-icon.svg-icon`, `.status-card-icon .svg-icon` (36px), `.sidebar-logo .svg-icon` (32px)
- ⭐ **Status-card bojanje** — `.status-card.warning .svg-icon { color: var(--warning) }` itd.
- ⭐ **config.js NAV_ITEMS** — sve 40 stavki migrirano: `icon: '📊'` → `icon: 'dashboard'` (semantic name)
- ⭐ **utils.js `buildSidebar()`** — regex `/^[a-z][a-z0-9-]*$/` detect → svg span; backward-compat za emoji (kad bi se vraćalo)
- ⭐ **mobile.js** — isto detect za burger menu i bottom nav
- ⭐ **index.html** — favicon zamijenjen s SVG warehouse ikonom (umjesto emoji 🏭)

**Workflow za dodavanje nove ikone:**

```bash
# 1) U scripts/generate_icons_css.py dodaj u ICONS dict
# 2) python scripts/generate_icons_css.py
# 3) Koristi u HTML: <span class="svg-icon svg-icon-NAME"></span>
```

**Pristup po rolama (config.js + prod_roles synced):**
- **superadmin/admin/uprava** → svih 13 ISO modula
- **racunovodstvo** → pregled, dokumenti, ciljevi, ocjena-uprave, osposobljavanje
- **voditelj-odrzavanja / koordinator-odrzavanja** → pregled, mjerna-oprema, nesukladnosti, capa, rizici, dokumenti
- **koordinator-proizvodnje** → pregled, nesukladnosti, capa, procesi, ciljevi, rizici, reklamacije, dokumenti, mjerna-oprema

**Pripremno za AI integraciju (NIJE još aktivirano):**
- `iso_ai_outputs` tablica spremna za Gemini cache (prompt_hash + response + token usage)
- Plan: Cloudflare Pages Function `/api/iso/gemini` (free tier) — pattern kao DemoSongsBalkan Replicate proxy
- AI use cases planirani: Audit Checklist generator, Document drafter, Root Cause helper, Management Review draft

**Što slijedi (Faza 1 nastavak — sljedeća sesija):**
- `iso/dokumenti.html` — Document Control modul s versioningom + e-potpis + QR
- `iso/nesukladnosti.html` — centralni NC log s detail view i CAPA gumbom
- `iso/ciljevi.html` — KPI + projektni ciljevi
- `iso/mjerna-oprema.html` — kalibracijski registar
- `admin/postavke.html` — ISO sekcija (PUK config dropdown)
- `scripts/import_iso_2025.py` — bulk import 2025/ foldera kao v1.0 dokumente
- Backfill historical NC iz `prod_inventory_rolls` (Otpisano) + `prod_failure_reports` (≥60min)
- Edge function `iso-recompute-kpis` (cron 06:30) za automatski KPI izračun

**Migracije u sql/ (sve apply-ane preko Supabase MCP):**
- `iso_schema_v1.sql` (sva DDL — tablice, RLS, indeksi)
- (in-MCP only) `iso_9001_functions_triggers_seeds` — funkcije, triggeri, view, settings, processi, ciljevi
- (in-MCP only) `iso_9001_prod_roles_update` — dozvole + nova rola

**Verifikacija u DB:**
- 19 iso_ tablica ✅
- 10 procesa, 9 KPI ciljeva, 16 ISO settings ✅
- 6 rola s ISO dozvolama (admin, uprava, racunovodstvo, voditelj-odrzavanja, koordinator-proizvodnje, koordinator-odrzavanja) ✅
- 2 trigger-a aktivna ✅
- v_iso_pregled view ✅
- Storage bucket iso-documents ✅

**Bug riješen u sesiji:**
- Sidebar prikazivao text ime ikone ("shield-check") umjesto SVG renderera. Uzrok: Live Server cache-irao stari `js/utils.js` koji još nije imao SVG detect granu. Riješeno re-applyom Edit-a + hard refresh (Ctrl+F5).

**Faza 1 nastavak (isti dan, 4 dodatna ISO modula + KPI engine + bulk import + Politika 2026 draft):**

- ⭐ **[views/iso/iso-dokumenti.html](views/iso/iso-dokumenti.html)** — Document Control modul (~700 lin):
  - Lista s 4 KPI kartice (ukupno, Published, Draft, za review 30d)
  - Filteri: tip, status, kategorija, search
  - Modal za novi dokument (8-poljska metadata) + nova verzija (smart bump 1.0→1.1)
  - Upload u Supabase Storage bucket `iso-documents` (path: `{slug}/v{version}/{filename}`)
  - Detail panel: meta, povijest verzija (current highlighted), changelog, download via signed URL (60s)
  - E-potpis "Označi pročitano" za aktivnu verziju
- ⭐ **[views/iso/iso-nesukladnosti.html](views/iso/iso-nesukladnosti.html)** — centralni NC log:
  - 4 KPI (otvoreni, major, auto čeka pregled, zatvoreni 30d)
  - Filteri: status, severity, source_type, auto-only
  - Source pillovi s SVG ikonama (file-text, wrench, mail-warning, search...)
  - Add/Edit modal koristi RPC `iso_next_nc_number()` za auto-numbering
  - Detail panel: opis, immediate action, root cause, auto-generated trag, "Označi pregledano" za auto-NC
  - "Brzo zatvori" gumb (s confirm), "Otvori CAPA" placeholder za sljedeći sprint
- ⭐ **[views/iso/iso-mjerna-oprema.html](views/iso/iso-mjerna-oprema.html)** — OB_14 kalibracijski registar:
  - 4 KPI (ukupno, kalibracije ≤30d, istekle, inspekcije ≤30d)
  - Filteri: status, "kad ističe" (overdue/30d/90d/ok)
  - Modal s dvije sekcije: Kalibracija (interval, last, next auto-calc, autoritet) + Inspekcija (vatrogasni aparati, posude pod tlakom, hidranti)
  - Auto-compute next_date kad se promijeni last+interval
  - "Brza recalibration" gumb — dohvati interval, pomakni next datum
  - Posebne due-date boje (overdue=crveno, 30d=narančasto, 90d=žuto, ok=zeleno)
- ⭐ **[views/iso/iso-ciljevi.html](views/iso/iso-ciljevi.html)** — OB_06 KPI + projektni:
  - Year switcher (2023–2027 tabovi)
  - 4 KPI (ukupno, KPI zadovoljava N/M, projektni u tijeku, projektni realizirano)
  - **Dvije zasebne tablice**: KPI ciljevi (target vs zadnja vrijednost + sparkline trend) i Projektni ciljevi (mjere, rok, status)
  - Modal s prebacivanjem KPI/Projektni (showya/sakriva polja po tipu)
  - "Dodaj ručno mjerenje" za KPI (postavi rezultat + auto-achieved kalkulacija)
  - "Brzo ažuriraj status" za projektne (prompt s opcijama)
  - **"Kopiraj projektne ciljeve iz prošle godine"** — kritično za audit (auditor godinama pita zašto ciljevi nisu ažurirani)

**ISO postavke u admin/postavke.html:**
- ⭐ Novi tab **"🛡️ ISO 9001"** s 3 sekcije:
  - **Tim** (5 fields): Predsjednica uprave, PUK, Voditelj kontrolinga (employee dropdowns), Vanjski konzultant ime + email
  - **Certifikat** (5 fields): Certifikator, broj, vrijedi do, sljedeći eksterni audit, datum revizije politike
  - **Pragovi** (6 numerika): % škarta, min/major minute kvara, default mjeseci pregleda dokumenata, default rok CAPA, dani prije audit alerta
- ⭐ `ucitajIsoPostavke()` + `spremiIsoPostavke()` JS funkcije (iz `settings` tablice gdje category='ISO_9001')

**KPI engine — `iso_recompute_kpis(year, month)` PL/pgSQL funkcija:**
- ⭐ Hardcoded mapping `kpi_query_name` → SQL za 9 KPI-eva:
  - `kpi_isporuka_u_roku_pct` — JOIN prod_dispatch + prod_orders.delivery_deadline
  - `kpi_nc_pct_od_narudzbi` — count NC reklamacija / count narudzbi
  - `kpi_zastoj_kvar_pct` — sum prod_failure_reports.downtime_minutes / fond sati
  - `kpi_skart_pct` — sum prod_shift_details.skart / sum kolicina (FIX: shema koristi `datum` ne `production_date`)
  - `kpi_oee_prosjek` — fallback na v_oee_dashboard (ako postoji)
  - `kpi_capa_overdue` — count CAPA past due
  - `kpi_osposobljavanje_pct` — provedeno / total requirements
  - `kpi_kasnjenja_nabava` / `kpi_prolaznost_ponuda_pct` — placeholderi za buduće (vraćaju NULL/0)
- ⭐ UPSERT u `iso_quality_objective_results` (idempotentno po objective_id+period)
- ⭐ Auto-izračun `achieved` po `target_direction` (higher_better/lower_better/target ±5%)
- ⭐ **Verifikacija:** travanj 2026 — 5 KPI-eva popunjeno (sve zadovoljavaju target za sad)
- ⭐ Pokreće se ručno (UI gumb planiran za sljedeći sprint), pg_cron schedule kasnije

**Backfill historical NC + bug fix:**
- ⭐ **BUG OTKRIVEN:** trigger `fn_iso_nc_from_failure` čekao engleske `priority='high'` ali Cartin `prod_failure_reports.priority` koristi **hrvatske vrijednosti** ('Kritičan', 'Visok', 'Normalan', 'Nizak'). Trigger nikad nije okidao za stvarne kvarove!
- ⭐ Fix migracija: trigger sad prepoznaje `IN ('Visok', 'Kritičan', 'high', 'critical')` (oboje za buduću kompatibilnost), severity=major samo za 'Kritičan' ili dt≥240min
- ⭐ Auto-status mapping: ako je kvar 'Riješen', NC se odmah postavlja kao 'Zatvoreno' + reviewed_at
- ⭐ **14 historical NC backfill-ano** iz prod_failure_reports (priority Visok+Kritičan, sve od prosinca 2025) — KPI dashboard sad prikazuje stvarne brojke

**Bulk import skripta — `scripts/import_iso_2025.py`:**
- ⭐ Skenira Windows folder (`ISO 9001/2025/` default) i prepoznaje tip dokumenta po prefiksu filename-a
- ⭐ **Pattern matching** za: OB_*, UP_*, PK_*, RU_*, UR_*, Politika kvalitete, Procjena rizika, Popis mjera, Plan održavanja/podmazivanja/poslova, Kontrola vreća, Dnevnik rada, Anketa zadovoljstva, Zbrinjavanje otpada, Osposobljavanja, Opis radnih mjesta, Imenovanje
- ⭐ Auto-generira ISO šifru (npr. `OB-05`, `UP-04`, `PK-01`, `POL-01`, `PR-ZNR`...)
- ⭐ Idempotent (skip ako već postoji isti `code`), `--dry-run` za pregled
- ⭐ Insert u `iso_documents` + `iso_document_versions` (v1.0) + upload u Storage bucket
- ⭐ Service-role key support za bypass RLS
- ⭐ **Pokretanje:** `pip install supabase` → `python scripts/import_iso_2025.py`

**Politika kvalitete 2026 — DRAFT:**
- ⭐ **[Projektna dokumentacija/Politika kvalitete 2026 — DRAFT.md](Projektna dokumentacija/Politika kvalitete 2026 — DRAFT.md)** — proširena verzija postojeće politike iz 30.10.2019.
- ⭐ Nove obveze sukladne ISO 9001:2026 DIS:
  - **Climate change** integriran u kontekst organizacije (sirovinski lanac, energija, ESG)
  - **Quality culture i etičko ponašanje** — eksplicitno spomenuto, uključujući obvezu točnog izvještavanja (bez retroaktivnog "namještanja" pred audit)
  - **Posvećenost Uprave** — 5 točaka koje audit traži (resursi, svijest, godišnja Ocjena uprave, podaci-driven odluke, sigurno radno okruženje)
  - **Ekološki otisak** — nova alineja
- ⭐ Workflow uputa: pregled → Branka Hitner odobrava → konvertiraj DOCX → upload kroz iso-dokumenti modul kao verzija 2.0 → e-potpis svih zaposlenika
- ⭐ Bonus: prijedlog dodavanja "Klimatski rizici" kategorije u OB_18 Registar rizika

**Verifikacija u DB nakon Faze 1 nastavka:**
- 19 iso_ tablica ✅
- 14 NC backfill-anih iz historical kvarova ✅
- 5 KPI rezultata za travanj 2026 ✅
- 16 ISO settings ✅
- iso_recompute_kpis() funkcija ✅
- 4 nova ISO HTML modula (dokumenti, nesukladnosti, mjerna-oprema, ciljevi) ✅
- ISO postavke tab u admin/postavke.html ✅

**Što ostaje za sljedeću sesiju (Faza 2):**
- iso/capa.html — workflow s effectiveness gate-om
- iso/rizici.html — registar s prob×impact matricom (i Klimatski rizici!)
- iso/auditi.html + iso/audit-checklist generator (PRVI Gemini AI use case za demo upravi)
- iso/dobavljaci.html — auto-bodovanje
- iso/osposobljavanje.html — training matrix
- iso/reklamacije.html — workflow + Gmail integracija
- iso/ocjena-uprave.html — godišnji izvještaj (kasnije s AI draftom)
- iso/procesi.html — pregled OB_20
- Realan import iz `ISO 9001/2025/` foldera (kad je `pip install supabase` napravljen)
- Manual recompute gumb na iso-pregled.html
- pg_cron schedule za nightly KPI recompute (kad MCP omogući extension management)

---

### 28. Travnja 2026 - Sesija 4: OEE preusmjerenje na smjenske izvještaje + EPU Bonus + Klasični Bonus auto-izračun ⭐⭐⭐

**🔥 Veliki preokret OEE modula** — odustanak od ESP32 brojača, kompletno baziran na smjenskim izvještajima koje voditelji ručno popunjavaju.

**Novi DB infrastrukura:**
- ⭐ **`v_shift_reports_oee`** v2 — popravljen za Tuber camelCase, dodan Tisak (rows/metri), realna Quality iz `scrap_pcs_raw`, capping A/P na 100%, novi `is_suspicious` flag
- ⭐ **`v_oee_daily_summary`, `v_oee_monthly`, `v_oee_dashboard`, `v_oee_operator_ranking`** — usklađeni s novim v_shift_reports_oee
- ⭐ **`f_normalize_strojar(text)`** — funkcija + trigger `trg_normalize_strojar` na `prod_shift_reports.strojar` (53 varijante → 18 kanonskih imena, npr. "VEDRAN P" → "Vedran Popić")
- ⭐ **`v_oee_valid_strojari`** — popis aktivnih strojara/voditelja iz `employees` (filter po `position`)
- ⭐ **`v_oee_epu_shift`** — EPU + Speed Gate (≥85%) + Util Gate (≥75%, BEZ kvara) + Bonus po smjeni (NLI Bottomer)
- ⭐ **`v_oee_epu_monthly_bonus`** — distribucija po nositelju izvještaja (filter validnih strojara, bez pomoćnika)
- ⭐ **`f_nominal_speed_for_article(article_id)`** — nominalna brzina po artiklu iz settings (VL=180, VL2=165, VL2n=150, VLRn=160 + korekcija širine, special cases <36cm)
- ⭐ **`f_fix_shift_8h(report_data, machine_type)`** — automatski popravak da svaka smjena ima 8h logged (ADD u zadnji nalog ili CAP)
- ⭐ **`v_classical_bonus_monthly`** — auto-izračun klasičnog bonusa po postavi/mjesecu iz smjenskih izvještaja (formula iz HR Produktivnost: KOEF/2200 × razlika produktivnosti − škart korekcija)
- ⭐ **`v_classical_bonus_per_employee`** — distribucija klasičnog bonusa po članovima postave (voditelj = 25.5% koef, ostali = 12.5%)

**Novi settings ključevi:**
- ⭐ **Kategorija `OEE_BONUS`** (19 ključeva): pragovi gates (85%, 75%), EPU formula (ref_speed=180, setup_credit=10800), bonus formula (prag=70k EPU, koef=4.29 €/1000 EPU, cap=150 €), nominalne brzine po valve_type
- ⭐ **Kategorija `PRODUKTIVNOST`** (14 ključeva): koeficijenti (KOEF_VODITELJ=25.5, KOEF_OSTALI=12.5, BAZA=2200), škart koeficijenti (-12, -8, dozvoljeni=1%), `bonus_avg_bag_weight_g=60` (kg→kom konverzija), `bonus_exclude_skart` toggle, plan po stroju (Bottomer/Tuber kom/h, **Tisak m/h**)
- ⭐ Sve uređivo kroz **Postavke modul** (admin/postavke.html) — dvije nove sekcije: "💰 EPU & Bonus pravila" i "📋 Klasični bonus"

**OEE Dashboard ([views/proizvodnja/oee.html](views/proizvodnja/oee.html)) — kompletni redizajn:**
- ⭐ **5 tabova**: Pregled, Po stroju, Izvještaji, **OEE Bonusi (admin only)**, Kako se mjeri
- ⭐ **Period filteri** (Danas / Tjedan / Mjesec / Prošli mjesec / Custom) + Linija + Stroj + **Strojar**
- ⭐ **Filter "Strojar"** — populiran iz live podataka, normaliziran kroz f_normalize_strojar
- ⭐ **Pregled tab** — KPI (kom, škart kg, smjena, sumnjive), 4 gauges (OEE/A/P/Q), Canvas trend chart kroz dane, drill-down tablica s sortiranjem + EPU kolone (admin)
- ⭐ **EPU & OEE Bonus sekcija** — vidljiva svima za NLI Bottomer (KPI: Avg EPU, % s bonusom), bonus € KPI samo admin
- ⭐ **Po stroju tab** — 5 kartica (NLI Bottomer/Tuber, WH Bottomer/Tuber, Tisak), ranking po **Kom/h (rad_h)** s 🥇🥈🥉 medaljama
- ⭐ **Izvještaji tab** — lista svih izvještaja, edit modal (admin uvijek, voditelj samo današnji), promjena strojar normalizirana kroz trigger
- ⭐ **Bonusi tab (admin only)** — 2 sekcije:
  - **OEE Bonus** (CLAUDE_CODE_TASK formula) — strojari/voditelji NLI Bottomera
  - **Klasični bonus po postavi** — auto-izračun iz smjenskih izvještaja, sve članove postave
  - Kombinirani prikaz "+ OEE €" i "UKUPNO €"
- ⭐ **Kako se mjeri tab** — sažetak na vrhu (60s) + tablica usporedbe Klasični vs OEE bonus + detaljnije objašnjenja po komponentama

**Smjenski izvještaji ([views/proizvodnja/tuber.html](views/proizvodnja/tuber.html), [bottomer-voditelj.html](views/proizvodnja/bottomer-voditelj.html), [tisak.html](views/proizvodnja/tisak.html)):**
- ⭐ Dodana kolona **"Škart (kom)"** uz "Škart (kg)" — Tuber: `skartKom` (camelCase), Bottomer/Tisak: `skart_kom` (snake_case)
- ⭐ Save logika: ako nitko ne unese → null (view tretira kao "neuneseno → Q=100% + sumnjivo")

**SQL one-time popravci:**
- ⭐ **f_fix_shift_8h** primijenjen na 85 izvještaja (ADD/CAP do 8h ukupno) — 30 nepromjenjivih (admin pregleda)
- ⭐ **machine_type normalizacija** — "Bottomer" + "bottomer" lowercase ujedno na "Bottomer" (33 smjene siječnja sad vidljive u OEE)
- ⭐ **strojar normalizacija** kroz trigger — sve buduće upise normalizira automatski

**Pristup:**
- ⭐ **OEE Pregled, Po stroju, Izvještaji, Kako se mjeri** — vidljivi svima
- ⭐ **OEE Bonusi tab** — samo admin/superadmin
- ⭐ **Bonus € KPI i kolone** u Pregled tabu — samo admin (ostali vide "—" za bonus)

**Što ne radimo (zasad):**
- WH Bottomer/Tuber i Tisak EPU/Bonus (samo NLI Bottomer pokriven u prvoj iteraciji)
- Setup credit (10.800 EPU) — flag `oee_apply_setup_credit=0` default
- Cap kao % plaće — implementacija na obračunskoj razini
- Automatska sinkronizacija s `bonuses` tablicom — `bonuses` ostaje za HR ručne korekcije

**Migracije (sql/):**
- `oee_shift_reports_view_v2.sql`
- `normalize_strojar.sql`
- `oee_bonus_settings.sql` + `oee_nominal_speed_function.sql` + `oee_epu_view.sql`
- (od kasnijih sesija: classical_bonus_settings, v_classical_bonus_monthly, v_classical_bonus_per_employee — primijenjene preko mcp__supabase__apply_migration)

---

### 27. Travnja 2026 - Sesija 3: UI refactor + FIFO finalizacija + Live Server bug ⭐⭐

**🔥 KRITIČNI BUG OTKRIVEN: Live Server + inline `<svg>`**
- VSCode Live Server ima regex `/(<\/body>|<\/svg>)/i` i injektira auto-reload `<script>` ispred SVAKOG `</svg>` taga
- Dashboard s 30 ikona = 30 injekcija unutar SVG elementa = razbijen DOM
- Symptom: `Uncaught SyntaxError: replaceChild Invalid token`, podaci ne dolaze, KPI "-"
- **Pravilo 25 dodano**: ne pisati inline `<svg>` u view fragmentima
- Rješenje: URL-encoded SVG kao CSS background-image (`%3Csvg...%3C%2Fsvg%3E`)

**Krediti modul (kompletna implementacija):**
- ⭐ **Plan otplate UI** — list-picker rata iz `prod_loan_payment_schedule`, status pilovi (Plaćeno/Prekoračeno/Uskoro), filteri, modal za markiranje plaćanja
- ⭐ **EU PROJEKT 79 dodatnih rata** (rows 101-180, 2028-05 do 2034-12) — `sql/loan_payment_schedule_eu_projekt_full.sql`
- ⭐ **4 nove KPI kartice** za payment tracking (Preostalo / Sljedećih 30 dana / Prekoračene / Plaćeno)
- ⭐ **Profesionalni UI**: SVG ikone (CSS klase), tamni table header, hover states
- ⭐ **Router defenzivni try/catch** za script re-execution

**Planiranje — grupiranje po narudžbi:**
- ⭐ **2-razinsko grupiranje** glavne tablice: Narudžba → Artikli (collapsible)
- ⭐ Grupni red: kupac, broj artikala, RN%, Proizv%, ukupno naručeno/proizvedeno, najraniji rok, status, privici
- ⭐ Auto-expand na search match, "Proširi sve / Skupi sve" gumbi
- ⭐ Sort_order ↑↓ unutar narudžbe + grupno pomicanje cijele narudžbe

**Planiranje — RN tablica grupiranje (3-razinsko):**
- ⭐ **Tip → Narudžba → RN** hijerarhija (Glavni / Tisak / Rezanje)
- ⭐ Status breakdown po grupama, ukupne količine
- ⭐ Reuse `.order-group-row` CSS pattern

**Tisak — Pregled po RN:**
- ⭐ Checkbox "Samo aktivni" → puni filter red (Status, Kupac, Artikl, Pretraga)
- ⭐ Grupiranje po narudžbi (kao u planiranju)

**Skladište — 2 nova taba:**
- ⭐ **📊 Rola po RN** — pregled potrošenih i djelomično potrošenih rola iz `prod_inventory_consumed_rolls` grupirano po RN
- ⭐ **🧹 Zaostali POP** (admin only) — cleanup tool za POP-ove na stanju kojima je RN već završen na bottomeru (ESP32 desync mitigation)

**Bottomer (voditelj + slagač):**
- ⭐ **Auto-prompt zaostali POP** — nakon `complete_bottomer_phase`, ako ima POP-ova na stanju za taj RN, modal pita treba li ih označiti kao Utrošeno (Pravilo 18 idempotency, going forward)

**Tuber — POP "Prikaži sve" toggle:**
- ⭐ Zbirni Pregled po RN: default 10 najnovijih (po `MAX(created_at)`), gumb za prikaz svih
- ⭐ Pojedinačni POP zapisi: isto, default 10, sortirano po `created_at` DESC

**Tuber-Materijal — FIFO je sada JEDINI mode** (toggle uklonjen, legacy section sakrivena):
- ⭐ **List-picker za sve slojeve** (S1-S4 osim folije) — checkbox po roli + kg input + "potpuno" toggle
- ⭐ **S1 + tisak**: lista otiskanih rola **filtrirana po `article_id`** (ne više po `work_order_number`)
- ⭐ **Stripes support** za slojeve 2-4 (`prod_inventory_strips`) — uz stock role
- ⭐ **Manualni unos role** modal (rola koja fizički postoji ali nije u bazi)
- ⭐ **Filter po proizvođaču** dropdown (auto-detect ako sloj ima 2+ proizvođača)
- ⭐ **Kalkulacija sekcija** — Potrebno (formula) vs Označeno (kg) po sloju, color-coded status, validacija prije save
- ⭐ **POP idempotency check** (Pravilo 18) — banner ako su neki POP-ovi već imali skidanje, blokirano ako svi
- ⭐ **Direct save** umjesto `TuberFifo.executePlan()` — piše direktno u `prod_inventory_consumed_rolls` + update source tablice (rolls/printed/strips/manual)

**Dashboard refactor (Pregled):**
- ⭐ **Sekcija kamere uklonjena** — fleksibilnija "Proizvodnja danas/jučer" preuzima cijelu širinu
- ⭐ **Sve emojiji zamijenjeni** SVG ikonama (URL-encoded CSS data URLs nakon Live Server bug-a)
- ⭐ **Animacije**: KPI count-up (0→target easeOutCubic), OEE conic-gradient donut, progress bar fill, pulse dot
- ⭐ **Defenzivni count-up** — postavi vrijednost odmah, animacija povratno (failsafe ako RAF ne fire-a)
- ⭐ **Profesionalni stil**: accent bar 4px po KPI kartici, hover lift, stagger fade-in

**Git stanje (sesija 3):**
- ⭐ ~25 commitova lokalno, **nije push-ano** (čeka final test)
- ⭐ Memory rule (`feedback_no_svg_in_js_strings.md`) ažuriran s root cause-om

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

**Verzija dokumenta:** 2.0
**Zadnje ažuriranje:** 4. Svibnja 2026 (sesija 9 — UI redizajn dark glass blue + multi-theme arhitektura: Dark/Light/Sage Mid Green prebacivanje kroz Postavke → Izgled tab)
**Autor:** AI Assistant (Claude)

---

💡 **Savjet:** Prije pisanja koda, UVIJEK prvo pročitaj **25 Zlatnih Pravila Razvoja** i **Kritični Bugovi** sekcije!
