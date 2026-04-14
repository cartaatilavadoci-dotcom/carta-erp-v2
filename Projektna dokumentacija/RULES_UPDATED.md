# CARTA ERP - Pravila i Konvencije

## 🎯 23 ključna pravila

### 1. BAZA PRIJE KODA
```
❌ Pretpostaviti da kolona postoji
✅ Provjeriti strukturu tablice prije pisanja koda
```

### 2. POSTAVKE SU CENTRALNE
```
Tablica: prod_settings (key-value) - proizvodne postavke
Tablica: settings - opće postavke
```

### 3. LIMIT UVIJEK EKSPLICITAN
```javascript
// ❌ NIKAD
const { data } = await supabase.from('tablica').select('*');

// ✅ UVIJEK
const { data } = await supabase.from('tablica').select('*').limit(10000);
```

### 4. UUID ZA REFERENCE
```javascript
// ❌ Shared values (može biti duplicirano)
work_order_number: 'WO-2025-001'

// ✅ UUID (uvijek jedinstveno)
work_order_id: 'a1b2c3d4-e5f6-...'
```

### 5. ENCODING = UTF-8
```
Problem: Upload kroz neke mehanizme kvari encoding
Simptom: mojibake znakovi umjesto č, ć, š, ž, đ
Rješenje: Direktni upload datoteke ili sed fix
```

### 6. MOBILE FIRST
```css
/* Fontovi: 11-12px za mobile */
/* Padding: 50% manje */
/* Touch targets: min 44px */
```

### 7. LINIJA = TEMA
```
WH: Zelena (#2e7d32) - body.linija-wh
NLI: Narančasta (#e65100) - body.linija-nli
```

### 8. SMJENA PERSISTIRA
```
LocalStorage: tuber_linija, tuber_aktivniRN_{LINIJA}
Baza: prod_shift_log.status = 'Aktivno'
```

### 9. FUNKCIJE PO MODULU
```javascript
// Prefix funkcije
tuberLoadData()
tuberPokreniSmjenu()
rezacPrikaziRole()
esp32Init()
```

### 10. NOVE STRANICE = SIDEBAR + ROLE
```
1. Dodaj u config.js NAV_ITEMS
2. Dodaj u DEFAULT_ROLES
3. Dodaj u router.js viewPath mapping
4. Dodaj u prod_roles (baza)
```

### 11. PUTANJE U VIEWOVIMA - APSOLUTNE OD ROOTA
```html
<!-- ✅ ISPRAVNO (apsolutno od roota) -->
<link rel="stylesheet" href="views/proizvodnja/tuber.css">
```

### 12. MODULI - SVE INLINE (za sada)
```
Svi moduli imaju CSS i JS INLINE u HTML datoteci.
```

### 13. PROIZVODNI DATUM I TIMEZONE ⭐ KRITIČNO
```
Proizvodni dan traje od 06:00 do 06:00, NE od 00:00 do 00:00!

Smjene:
- 1. smjena: 06:00 - 14:00
- 2. smjena: 14:00 - 22:00  
- 3. smjena: 22:00 - 06:00 (prelazi u sljedeći kalendarski dan!)

OBAVEZNO koristi funkcije iz utils.js:
- getProductionDate()
- getYesterdayProductionDate()
- getCurrentShiftNumber()
- getProductionDateFromTimestamp(ts)
- getProductionDayStartISO(dateStr)
- getProductionDayEndISO(dateStr)
```

### 14. NE IZOSTAVLJAJ I NE RADI PO SVOM ⭐ KRITIČNO
```
1. NE IZOSTAVLJAJ NIŠTA
   - Ako korisnik ne kaže da nešto treba maknuti, NE MICAJ

2. NE RADI PO SVOM
   - Ako nisi siguran što korisnik želi, PITAJ
```

### 15. INTERNI MODULI NASLJEĐUJU PRISTUP
```
Neki moduli su "interni" - nemaju vlastitu stavku u sidebaru
i nasljeđuju pristup od parent modula.

Primjer: tuber-materijal nasljeđuje pristup od tuber

// router.js
const interniModuli = {
  'tuber-materijal': 'tuber'
};
```

### 16. ESP32 BROJAČ - NE RESETIRAJ POSTOJEĆI ⭐ KRITIČNO
```
KRITIČNO: Prije pokretanja naloga UVIJEK provjeri postoji li
          aktivan brojač za taj nalog!

❌ POGREŠNO:
tuberZapocni() → start_machine_counter → UVIJEK count=0
→ ESP32 dohvati serverCount=0 → IZGUBLJENI KOMADI!

✅ ISPRAVNO:
tuberZapocni() → get_counter_status → 
  → Ako postoji za ISTI nalog → NE DIRAJ
  → Ako NE postoji → start_machine_counter → count=0
```

### 17. ZamjenePostave JE GLOBALNI OBJEKT ⭐ NOVO 26.01.2026
```
KRITIČNO: ZamjenePostave dijele SVI moduli!

❌ PROBLEM:
Ako korisnik navigira Bottomer → Tuber,
ZamjenePostave može sadržavati Bottomer podatke.

✅ RJEŠENJE:
Za podatke specifične za stroj, koristi lokalne varijable:
  - tuber.html → window.tuberTrenutnaSmjenaData
  - bottomer-voditelj.html → lokalni dohvat iz baze

Ili provjeri stroj_tip i liniju:
  if (ZamjenePostave.data.stroj_tip === 'Tuber' && 
      ZamjenePostave.data.linija === window.LINIJA)
```

---

## ⚠️ KRITIČNI BUGOVI - PAZI!

### GENERATED kolone - NE AŽURIRATI!
```
prod_orders.quantity_remaining je GENERATED kolona!
Formula: quantity_ordered - quantity_produced
❌ NE radi: .update({ quantity_remaining: 100 })
✅ Samo ažuriraj: quantity_ordered ili quantity_produced
```

### Timezone problem
```
Supabase sprema vrijeme u UTC!
Hrvatska je UTC+1 (zima) / UTC+2 (ljeto)

✅ ISPRAVNO:
new Date('2026-01-20T06:00:00').toISOString()
```

### ESP32 brojač sinkronizacija
```
ESP32 heartbeat (svakih 30s kad stroj stoji):
  → poziva get_active_work_order()
  → ako tubes==syncedCount && buffer==0
  → tubes = serverCount (iz baze!)

⚠️ Ako je serverCount=0 (zbog pogrešnog reseta), ESP32 gubi count!
```

---

## 🆕 Ažuriranja (26. Siječanj 2026) - SMJENSKI IZVJEŠTAJI

### Tuber smjenski izvještaj - Promjene naziva kolona
```
Prije                    Poslije
─────────────────────    ─────────────────────
Čekanje tuljke      →    Čekanje tiska
Rad van stroja      →    Rad van stroja (prelom u 2 reda)
Čekanje             →    Čekanje bottomera
```

### Tuber i Bottomer - Logika učitavanja izvještaja
```
Kolone 1-3 (Br. Naloga, Opis, Količina):
  → UVIJEK se učitavaju iz proizvodnje (svježi podaci)
  → Ne koriste se spremljene vrijednosti

Kolone 4-11 (Škart, Preštel., Rad, Kvar, vremena...):
  → Učitavaju se iz spremljenog izvještaja ako postoji
  → Omogućuje višestruko spremanje tijekom smjene

Workflow:
1. Otvori izvještaj → dohvati RN-ove s količinama iz proizvodnje
2. Ako ima spremljeni izvještaj → učitaj ručne unose (kolone 4-11)
3. Unesi/mijenjaj ručne unose tijekom smjene
4. Spremi → sačuva ručne unose u bazu
5. Osvježi stranicu → kolone 1-3 osvježene, kolone 4-11 ostaju
```

---

## ✅ Riješeni bugovi (Siječanj 2026)

### BUG-027: Hardkodirana linija W&H u izvještaju ⭐ 26.01.2026
```
Status: ✅ RIJEŠENO
Modul: tuber.html
Problem: Smjenski izvještaj uvijek prikazivao "W&H" umjesto stvarne linije
Rješenje: Dodan id="izvjestajLinija" element koji se dinamički postavlja iz window.LINIJA
```

### BUG-026: Tuber izvještaj prikazuje krivu postavu ⭐ 26.01.2026
```
Status: ✅ RIJEŠENO
Modul: tuber.html
Problem: Smjenski izvještaj prikazivao postavu s Bottomera umjesto Tubera
         - ZamjenePostave je GLOBALNI objekt koji dijele svi moduli
         - Ako korisnik bio na Bottomer stranici, ZamjenePostave ima Bottomer podatke
         
Rješenje: 
  - Izvještaj sada koristi SAMO window.tuberTrenutnaSmjenaData
  - To je Tuber-specifična varijabla koja se ne može prepisati
```

### BUG-025: ESP32 resetira count pri pokretanju naloga ⭐ 26.01.2026
```
Status: ✅ RIJEŠENO
Modul: tuber.html
Problem: tuberZapocni() UVIJEK poziva start_machine_counter
         → Resetira count na 0 u bazi
         → ESP32 heartbeat dohvati serverCount=0
         → IZGUBLJENO 1000+ KOMADA!
         
Rješenje: 
  1. tuberZapocni() PRVO provjerava postoji li aktivan brojač
     → Ako DA za ISTI nalog → NE resetira
  2. tuberNastavi() NE poziva start_machine_counter
  3. Nova funkcija esp32ResetCounter() za ručni reset
```

### BUG-022: Voditelj završi nalog, Slagač ne može spremiti paletu ⭐ 25.01.2026
```
Status: ✅ RIJEŠENO
Problem: Voditelj završi nalog → status = 'Završeno' → Slagač više ne vidi nalog
Rješenje: Odvojeni statusi (bottomer_voditelj_status, bottomer_slagac_status)
```

### BUG-023: Višestruki aktivni nalozi ⭐ 25.01.2026
```
Status: ✅ RIJEŠENO
Moduli: tuber.html, bottomer-slagac.html
Problem: Operater može pokrenuti više naloga istovremeno
Rješenje: Provjera aktivnog naloga prije pokretanja/nastavljanja
```

### BUG-024: Tuber izvještaji se ne spremaju ⭐ 25.01.2026
```
Status: ✅ RIJEŠENO
Modul: tuber.html
Problem: spremiTuberIzvjestaj() bio placeholder
Rješenje: Potpuna implementacija s upsert logikom i učitavanjem
```

### BUG-021: Duplo skidanje materijala ⭐ 25.01.2026
```
Status: ✅ RIJEŠENO
Problem: "Završi nalog" skida materijal za SVE POP-ove
Rješenje: Nova kolona material_deducted u prod_inventory_pop
```

---

## 📂 Struktura datoteka

### Core JS datoteke
```
js/
├── config.js          -> Konfiguracija, role, navigacija
├── supabase-client.js -> DB konekcija
├── auth.js            -> Autentifikacija, sesije, dozvole
├── router.js          -> SPA navigacija (#hash) + interni moduli
├── utils.js           -> Pomoćne funkcije + PROIZVODNI DATUM
├── mobile.js          -> Mobile optimizacije
├── zamjene-postave.js -> Cross-module zamjene članova (GLOBALNI!)
└── scanner.js         -> Barkod/QR scanner modul
```

### Proizvodni moduli
```
views/proizvodnja/
├── tuber.html             -> Tuber stroj ⭐ AŽURIRANO 26.01.
├── tuber-materijal.html   -> Evidencija materijala
├── bottomer-wh.html       -> Bottomer W&H
├── bottomer-nli.html      -> Bottomer NLI
├── bottomer-slagac.html   -> Slaganje paleta ⭐ AŽURIRANO
├── bottomer-voditelj.html -> Upravljanje strojem ⭐ AŽURIRANO 26.01.
├── rezac.html             -> Rezač
├── tisak.html             -> Tisak
├── skladiste.html         -> Skladište
├── planiranje.html        -> Planiranje proizvodnje
├── oee.html               -> OEE dashboard
└── ...
```

---

## 🆕 Nova pravila (01. Veljače 2026)

### 18. MATERIJAL SE NE SKIDA AUTOMATSKI ⭐ KRITIČNO
```
Pri unosu POP-a materijal se NE skida sa stanja automatski!

Workflow:
1. tuberDodajProizvodnju() → INSERT u prod_inventory_pop
   → material_deducted = false (default)
   → MATERIJAL NIJE SKINUT!

2. Završetak smjene/naloga → otvoriZavrsetakSmjene/otvoriZavrsetakNaloga
   → Dohvati POP-ove gdje material_deducted = false
   → Otvori tuber-materijal modul

3. tuber-materijal → Operater skenira role
   → spremiSkidanje() → SADA se skida materijal
   → UPDATE material_deducted = true

⚠️ Ako se preskoči korak 3, materijal NIKAD neće biti skinut!
```

### 19. TRANSFORMACIJE BARKODA ⭐ KRITIČNO
```
Sustav pokušava 3 načina pretraživanja materijala:

1. ORIGINALNI barkod (direktno)
   → Ako pronađeno → GOTOVO

2. TRANSFORMACIJA 1: Billerud rotacija
   → Zadnja 2 znaka prebaci naprijed
   → Skrati za zadnja 2 znaka
   → Primjer: "1234567890" → "9012345678" → "90123456"
   
   var temp = barkod.slice(-2) + barkod.slice(0, -2);
   var transform1 = temp.slice(0, -2);

3. TRANSFORMACIJA 2: Pozicije 2-10
   → Izvuci znakove 2-10 (0-indexed: 1-9)
   → Primjer: "A123456789XYZ" → "123456789"
   
   var transform2 = barkod.substring(1, 10);
```

### 20. DETEKCIJA TIPA MATERIJALA PO PREFIXU
```
Šifra materijala određuje tablicu za pretragu:

| Prefix      | Tablica                  | Tip     |
|-------------|--------------------------|---------|
| T- ili TIS  | prod_inventory_printed   | printed |
| R-          | prod_inventory_strips    | strips  |
| F           | prod_inventory_foil      | foil    |
| S ili B     | prod_inventory_strips    | strips  |
| *ostalo*    | prod_inventory_rolls     | rolls   |

VAŽNO: Pretraga je CASE-INSENSITIVE (toUpperCase)
```

### 21. REZERVACIJE POP-a - AUTOMATSKO UPRAVLJANJE ⭐

```
Problem: Bottomer skida POP sa stanja PRIJE nego što Tuber fizički proizvede POP
Rješenje: Sistem rezervacija sa automatskim skidanjem

┌─────────────────────────────────────────────────────────────────┐
│                    REZERVACIJE POP-a WORKFLOW                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  BOTTOMER-SLAGAČ (skiniPOPSaStanja):                            │
│  ───────────────────────────────────                            │
│  1. Dodaje GOP paletu (treba 1000 POP)                          │
│  2. Na skladištu: 200 POP                                       │
│  3. Skida: 200 kom (quantity_in_stock -= 200)                   │
│  4. REZERVIRA: 800 kom (quantity_reserved += 800) ⭐            │
│  5. Upozorenje: "📌 Rezervirano 800 kom"                        │
│                                                                 │
│  TUBER (tuberSkiniRezervacije):                                 │
│  ──────────────────────────────                                 │
│  1. Dodaje novi POP (2000 kom)                                  │
│  2. Provjerava: quantity_reserved za taj RN                     │
│  3. AUTOMATSKI skida rezervacije (FIFO):                        │
│     • quantity_reserved = 0 (briše rezervaciju)                 │
│     • quantity_in_stock = 2000 - 800 = 1200 ⭐                   │
│  4. Obavijest: "📌 Automatski skinuto 800 kom za Bottomer"      │
│                                                                 │
│  REZULTAT:                                                      │
│  ────────                                                       │
│  ✅ Točno stanje zaliha (1200 kom stvarno dostupno)             │
│  ✅ Nema "duhova" u inventaru                                   │
│  ✅ Transparentnost - quantity_reserved jasno pokazuje što čeka │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

Nove kolone u prod_inventory_pop:
  - quantity_reserved (INT) - rezervirano od Bottomer-a
  - quantity_available (GENERATED) - dostupno = in_stock - reserved

⚠️ KRITIČNO: quantity_available je GENERATED kolona - NE ažurirati ručno!
```

### 22. remaining_kg JE GENERATED KOLONA ⭐ KRITIČNO 11.02.2026
```
prod_inventory_rolls.remaining_kg = initial_weight_kg - consumed_kg

❌ GREŠKA - Supabase odbija:
.insert({ remaining_kg: 500 })
.update({ remaining_kg: novaTezina })

✅ ISPRAVNO - ažuriraj consumed_kg:
const noviConsumedKg = initial_weight_kg - novaTezina;
.update({ consumed_kg: noviConsumedKg })

GENERALIZIRANO: 3 GENERATED kolone u sustavu:
1. prod_orders.quantity_remaining = quantity_ordered - quantity_produced
2. prod_inventory_rolls.remaining_kg = initial_weight_kg - consumed_kg
3. prod_inventory_pop.quantity_available = quantity_in_stock - quantity_reserved
```

### 23. COUNTER SYNC JE BIDIREKCIJSKI ⭐ NOVO 11.02.2026
```
Sinkronizacija brojača u planiranju dozvoljava i SMANJIVANJE!
Koristite nakon brisanja RN-ova za vraćanje brojača na stvarni max.

❌ STARO (samo povećava):
const newValue = Math.max(currentValue, maxFound);

✅ NOVO (bidirekcijsko):
const newValue = maxFound;
const needsUpdate = newValue !== currentValue;
```

---

## ✅ Riješeni bugovi (Veljača 2026)

### BUG: remaining_kg direktni update/insert ⭐ 11.02.2026
```
Status: ✅ RIJEŠENO
Modul: rezac.html
Problem: submitNovaRolaRezac() slao remaining_kg u INSERT
         confirmOverrideTezine() ažurirao remaining_kg u UPDATE
         Supabase odbijao jer je remaining_kg GENERATED kolona
Rješenje:
  - INSERT: uklonjen remaining_kg (sustav ga automatski izračuna)
  - UPDATE: samo consumed_kg i status (ne remaining_kg)
```

---

*Zadnje ažuriranje: 11. Veljače 2026*
- ⭐ Dodano pravilo #22: remaining_kg je GENERATED kolona (prod_inventory_rolls)
- ⭐ Dodano pravilo #23: Counter sync je bidirekcijski
- ⭐ Riješen BUG: remaining_kg direktni update/insert u rezac.html
- ⭐ Dodano pravilo #21: Rezervacije POP-a - automatsko upravljanje
- ⭐ Dodano pravilo #18: Materijal se ne skida automatski
- ⭐ Dodano pravilo #19: Transformacije barkoda (Billerud rotacija, pozicije 2-10)
- ⭐ Dodano pravilo #20: Detekcija tipa materijala po prefixu
- ⭐ Ažuriran broj pravila: 21 → 23
