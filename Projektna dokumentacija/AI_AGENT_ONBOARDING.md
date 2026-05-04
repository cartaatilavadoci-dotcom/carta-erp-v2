# AI AGENT ONBOARDING — CARTA-ERP & ISO 9001 modul

> **Tko ovo treba čitati:** Svaki novi AI agent (Claude, GPT, Copilot) koji preuzima rad na CARTA-ERP-u nakon AI agenta koji je razvio ISO 9001 modul (sesije 5-8, 2.-3. svibnja 2026.).
>
> **Svrha:** dati ti **dubinsko razumijevanje** sustava — ne samo "što postoji" (to je u CLAUDE.md changelog-u) nego **zašto je sve napravljeno baš tako**, koje su skrivene gotchas, kako Atila razmišlja, što izbjegavati.
>
> **Ako pročitaš samo ovaj dokument + CLAUDE.md + memory/MEMORY.md** — bit ćeš spreman raditi smisleno bez 2 sata istraživanja.

---

## 0. KRENUTI ODMAH — minimum za prvi pokret

Prije bilo čega:

1. **Pročitaj CLAUDE.md u cijelosti** — 1700+ linija, ali sve relevantno. Posebno: 26 zlatnih pravila, 4 sesije changelog-a (5-8), bug catalogue.
2. **Pročitaj `memory/MEMORY.md`** + sve linkane memory file-ove. Tu su user-ove preferencije i feedback iz prijašnjih sesija.
3. **Pročitaj ovaj dokument**.
4. **Provjeri stvarnu DB shemu** prije bilo kojeg koda — Cartine kolone često nisu kao što očekuješ (`datum` umjesto `production_date`, `priority='Visok'` umjesto `'high'`, jsonb objekti gdje očekuješ flat polja). Koristi `mcp__supabase__list_tables` ili `information_schema.columns`.

**NE radi** — ovo su tri stvarna error mode-a iz prijašnjih sesija:
- ❌ Pretpostavi naziv kolone na temelju "logike" → 4 SQL bug-a do popravka triggera
- ❌ Pretpostavi da postoje podaci u bazi → backfill/seed potreban prije svake nove KPI funkcije
- ❌ Pretpostavi da postoji feature kojeg nema → uvijek `Read` ili `Grep` postojeći kod prije dodavanja sličnog

---

## 1. KO JE ATILA I KAKO RAZMIŠLJA

### Background koji oblikuje sve odluke

- **Mehanički inženjer + self-taught developer.** Misli inženjerski: CONFIG konstante, fail-safe logika, eksplicitno error handling, "dobar dizajn znači manje održavanja kasnije". Ovo se vidi kroz cijeli kod — npr. `SB.*` helpers postoje JER je prije bilo silent fail bug-ova s GENERATED kolonama.
- **CTO Carte** — proizvodnja papirnatih industrijskih vreća, 60 ljudi, 2 linije, 3 smjene. Domain expert za papir + manufacturing.
- **Bivši predsjednik DVD-a Sarvaš** + prošao kroz Cartine ISO audite → **insider knowledge za ISO i ZNR domene**. Zna realnost ("2 tjedna sprint pred audit + retroaktivno popunjavanje, ponekad lažiranje"), ne samo standard.
- **POS kuća u Sarvašu se gradi** — čest off-grid period zbog gradilišta + arhitekta. Sesije moraju biti samodovoljne.
- **Frequent travel** za Carta pre-sales (Europa). Vremenske zone, ograničena oprema.

### Prefencije rada

| Što voli | Što izbjegava |
|---|---|
| Korak po korak razvoj | "Big bang" releases |
| Pita prije pretpostavki | Implementacija "po svom" bez razgovora |
| Hrvatski jezik (UI + komentari) | Engleski u UI-u |
| Mjerljivi outputi (KPI, brojke) | "Ovo izgleda dobro" bez podataka |
| Konfigurabilno (Postavke) | Hardkodirano u kodu |
| Edge cases i "što ako" | Optimistični happy path |
| Slojni pristup (DB → SQL → API → UI) | Ad-hoc rješenja koja preskaču sloj |

### Komunikacija

- **Hrvatski jezik** za sve (UI, komentari, docstrings, error poruke). Engleski samo za tehničke termine koji nemaju dobar HR ekvivalent (`workflow`, `endpoint`, `cache`, `trigger`).
- **Direktan, kratak**. Ne voli marketing-style copy. "Što ovo radi" > "Ovo revolucionarno mijenja vašu produktivnost".
- **"NE IZOSTAVLJAJ I NE RADI PO SVOM"** (Pravilo 14, doslovno citirano). Pri svakoj nejasnoći pita.
- **Kvaliteta prije brzine** — ali brzina je važna. Daje "kreni" kada je siguran u plan.
- **Spell-check warnings u IDE-u** (cro spell checker za engleske riječi) → **uvijek ignoriraj**, NE kreiraj memory za njih.

### Lifestyle constraints koji utječu na sesije

- Često **fragmentirano vrijeme** — radi 30 min, prekid 2h, vrati se. Sesije moraju biti otporne na prekide. Koristi todo list + memory + plans da svaki put možeš nastaviti tamo gdje si stao.
- **Live Server u VS Code-u** — kritično za frontend testiranje. Pravilo 25 (lomi inline SVG) je posljedica. Sve view fragmente piši imajući to na umu.

---

## 2. CARTA-ERP ARHITEKTURA — mentalni model

### Tehnologije (i zašto te a ne druge)

```
Frontend:  Vanilla ES6+ JavaScript (NEMA framework — namjerno)
HTML:      Hash-based SPA (#view-name)
Styling:   Globalni styles.css + inline u svakom view-u
Backend:   Supabase (PostgreSQL + Auth + Storage + Realtime + RPC)
ESP32:     IoT brojači na proizvodnim strojevima (192.168.1.175-229)
Lokalno:   Mac Mini 192.168.1.199 (camera proxy, AI widget, Ollama)
AI:       Cloudflare Pages Function → Gemini free tier (od sesije 7)
```

**Zašto vanilla JS, nema React/Vue/Svelte:**
- Atila je solo developer. Mora moći otvoriti kod 5 godina kasnije i razumjeti.
- Nema build sustava, debug u browseru je trivijalan.
- Trade-off: nema reaktivnosti pa ima `await loadX(); render();` pattern svuda. Prihvaćeno.

**Zašto inline CSS+JS u svakoj view datoteci:**
- Modul je samodovoljan, lako se otvori i razumije.
- Trade-off: code duplication. Prihvaćeno jer je čitljivost važnija.
- **Iznimka:** SB.* helpers u `js/supabase-helpers.js` — globalno reused.

### Routing pattern

`router.js` mappa hash → file path:
```
#dashboard         → views/dashboard.html
#iso-pregled       → views/iso/iso-pregled.html
#tuber             → views/proizvodnja/tuber.html
```

View je **HTML fragment** (bez `<html>`/`<head>`/`<body>`), injektira se u `#app-content` div. Skripte unutar fragmenta se izvršavaju ručno (router-ova `executeScripts` funkcija).

**Init pattern:** svaki view IIFE na dnu skripte:
```js
(async function initIsoXyzView() {
  console.log('[iso-xyz] init');
  // ... setup, load data, bind events
  console.log('[iso-xyz] ready');
})();
```

Ime IIFE funkcije je `init{Capitalized}View` — Router ga može pozvati ako je definiran kao window function (drugi pattern), ali IIFE je preferirani.

### Pristup Supabase-u

**SVE Supabase pozive idi kroz `SB.*` helpers** (`js/supabase-helpers.js`). Nikad direktno `supabase.from()`. Razlog (Pravilo 24):
- SB.* throw-a iznimku ako Supabase vrati error → nema silent fail (koji je bio bug s GENERATED kolonama u tuber-materijal.html — operateri su vidjeli "spremljeno" toast a baza je odbila UPDATE)
- SB.* loguje error u console s ❌ prefiksom
- SB.* prikazuje toast korisniku (osim ako `{ silent: true }`)
- SB.update/delete ZAHTIJEVA filter (sigurnosna mjera)

**Iznimka:** `initSupabase().rpc('function_name', {...})` se može zvati direktno kad treba destruktirat `{ data, error }` (npr. za RPC koje vraćaju non-null jednu vrijednost).

**Iznimka 2:** `initSupabase().storage.from('bucket').upload(...)` — storage nije u SB.* helperima.

### Database konvencije

| Pravilo | Primjer |
|---|---|
| Tablice s prefiksom `prod_` su proizvodne, `iso_` su ISO 9001, ostalo je core | `prod_inventory_rolls`, `iso_documents` |
| UUID PKs svuda | `id uuid PRIMARY KEY DEFAULT gen_random_uuid()` |
| `created_at` + `updated_at` na svakoj tablici | `timestamptz DEFAULT now()` |
| RLS uključen, permissive policy (SB.* radi validaciju) | `CREATE POLICY ... USING (true)` |
| Auto-numbering kroz PL/pgSQL funkcije, NE sequences | `iso_next_nc_number()` parses regex iz postojećih |
| GENERATED kolone za izračunate vrijednosti | `score INTEGER GENERATED ALWAYS AS (probability * severity) STORED` |
| Triggers za workflow automation | `trg_iso_nc_from_roll_otpis` |

**3 GENERATED kolone — KRITIČNO:**
- `prod_orders.quantity_remaining` = `quantity_ordered - quantity_produced`
- `prod_inventory_rolls.remaining_kg` = `initial_weight_kg - consumed_kg`
- `prod_inventory_pop.quantity_available` = `quantity_in_stock - quantity_reserved`
- `iso_risks.score` = `probability * severity`
- `iso_supplier_evaluations.total_score` = `quality + time + price`

**NIKAD ne pisati direktno u GENERATED kolonu** (Postgres odbija). Update source kolone, GENERATED se računa.

---

## 3. ISO 9001 MODUL — DUBINSKO RAZUMIJEVANJE

### Zašto ovo postoji (ne samo "auditor traži")

ISO modul je **3 stvari odjednom**, i to je važno razumjeti:

1. **Operativni alat za Cartu** — PUK (Kristina Čubela) i Branka (predsjednica) trebaju pratiti compliance, manje vremena trošiti na papirologiju.
2. **Pred-audit alat** — rujanski 2026. eksterni audit certifikatora. Sustav mora prikazati auditoru sve što traži.
3. **R&D investment za standalone SaaS** — kandidat za 2027. (master kontekst Sekcija 0.5.1). Svaka odluka uzima u obzir potencijalnu multi-tenancy.

Auditor u HR-u ima **specifičnu kulturu**:
- Godinama ponavlja iste preporuke (Carta auditor: "Ciljevi nisu ažurirani / Dobavljači nisu ocijenjeni / Mjerna oprema nije ažurna" — 4× zaredom 2022-2025)
- Voli vidjeti TRAG (datum kad je nešto napravljeno + tko)
- Obraća pažnju na DJELOTVORNOST (CAPA bez effectiveness verification = nije dobro)
- Realno tolerira "nije sve idealno" ali hoće VIDJETI da sustav postoji

### 13 modula i njihova svrha

```
iso-pregled         Dashboard (KPI, posljednje NC, audit countdown, Audit Sprint Mode)
iso-dokumenti       Document Control (politike, procedure, uputstva s versioningom + e-potpis)
iso-nesukladnosti   Centralni NC log (auto iz proizvodnje + ručni)
iso-capa            Korektivne/preventivne radnje (5-step workflow + effectiveness gate)
iso-ciljevi         Ciljevi kvalitete (KPI mjerni + projektni hibrid)
iso-procesi         OB_20 procesi (10 procesa Cartine organizacije + live KPI)
iso-rizici          OB_18 registar rizika (3×3 matrica + climate change)
iso-auditi          Interni auditi (plan + checklist + AI generator)
iso-dobavljaci      OB_10 auto-bodovanje 1-3 (kvaliteta/rok/cijena)
iso-osposobljavanje Training matrix (zahtjevi + evidencija + alerti)
iso-mjerna-oprema   OB_14 kalibracije + inspekcije
iso-reklamacije     Reklamacije kupaca (workflow + auto-NC opcija)
iso-ocjena-uprave   OB_12 godišnji obrazac (11 inputa + AI pre-fill + sign)
```

**Mapping Cartine postojeće dokumentacije → modulu:**
- Cartin Excel `OB_05 Evidencija nesukladnosti.xlsx` = `iso_nonconformities` tablica + `iso/nesukladnosti.html` modul
- Cartin Word `OB_12 Ocjena uprave 2025.doc` = `iso_management_reviews` + `iso/ocjena-uprave.html`
- ...itd. Karta-Excel = karta-DB.

### Auto-trigger pattern (centralna inovacija)

Sustav **smanjuje ručni rad** kroz database triggers:

```
prod_inventory_rolls.status = 'Otpisano'
   ↓ trigger fn_iso_nc_from_roll_otpis
   ↓
iso_nonconformities (auto-NC, severity=major ako ≥500kg)
   ↓ trigger fn_iso_notify_auto_nc
   ↓
prod_notifications (bell za PUK)
   ↓ realtime kroz Supabase
   ↓
PUK browser tab → bell badge se pojavi za <1s
```

Slično za `prod_failure_reports` (kvar) → auto-NC.

**Filozofija:** sustav radi sam dok Cartin radnik tek primijeti. PUK pri otvaranju aplikacije vidi listu pending stavki — ne mora nikoga ganjati za status.

### Bell notifikacije — 5 tipova s cooldown-om

`iso_generate_alerts()` PL/pgSQL funkcija provjerava 5 tipova alarma:

| Tip | Trigger | Cooldown |
|---|---|---|
| CAPA past due | `due_date < today AND status NOT IN closed` | 24h |
| Kalibracije | `next_calibration_date ≤ today + 7d` | 24h |
| Eksterni audit | `iso_next_external_audit_date ≤ today + 30d` | 24h |
| Dokumenti review | `next_review_date ≤ today + 7d` | 7d |
| Auto-NC nepregledan | `auto_generated AND reviewed_at IS NULL AND age > 3d` | 48h |

Cooldown se realizira preko `prod_notifications.created_at > now() - INTERVAL '24 hours'` provjere prije inserta. **Idempotentno** — možeš pozivati svakih 30 min, neće spam-irati.

JS hook: `Notifications.maybeGenerateIsoAlerts()` poziva 1× po 6h po browser sesiji (localStorage timestamp).

### Audit Sprint Mode

Banner se pojavljuje na ISO Pregledu kad je `iso_next_external_audit_date ≤ 90 dana`. Modal s 12 stavki čeklist-a:

1. Auto-NC pregledani od PUK-a
2. CAPA past due
3. CAPA pending effectiveness
4. Dokumenti bez vlasnika
5. Dokumenti za reviziju
6. Mjerna oprema kalibracije
7. Dobavljači bodovani (4-godišnja preporuka!)
8. KPI ciljevi imaju mjerenja
9. **Interni audit odrađen** (KRITIČNO!)
10. **Ocjena uprave potpisana** (KRITIČNO!)
11. Politika kvalitete v2.0 aktivna
12. Reklamacije evidentirane

Statusi: `ok` / `warning` / `critical`. Sortirano po prioritetu (kritično prvo). Svaka stavka klikabilna — otvara modul direktno.

### KPI engine

`iso_recompute_kpis(year, month)` PL/pgSQL funkcija ima **hardcoded mapping** `kpi_query_name` → SQL:
- `kpi_isporuka_u_roku_pct` → JOIN prod_dispatch + prod_orders.delivery_deadline
- `kpi_nc_pct_od_narudzbi` → count NC reklamacija / count narudzbi
- `kpi_zastoj_kvar_pct` → sum prod_failure_reports.downtime_minutes / fond sati
- `kpi_skart_pct` → sum prod_shift_details.skart / sum kolicina
- `kpi_oee_prosjek` → fallback na v_oee_dashboard view
- `kpi_capa_overdue` → count CAPA past due
- `kpi_osposobljavanje_pct` → provedeno / total requirements
- `kpi_kasnjenja_nabava`, `kpi_prolaznost_ponuda_pct` → placeholderi za buduće

Output ide u `iso_quality_objective_results` (UPSERT, idempotentno po objective_id+period).

**Pokretanje:**
- Manual: gumb na ISO Pregledu (ovo radi sad)
- pg_cron 06:30 dnevno (planirano u Sprint B5, čeka da Atila aktivira na Pro planu)

### Gemini AI proxy

**Lokacija:** `scripts/gemini-proxy/functions/api/iso/gemini.js`. Cloudflare Pages Function. **Atila treba sam deployati** — vidi `scripts/gemini-proxy/README.md`.

**4 feature-a podržana:**
- `audit_checklist` — 15-20 pitanja po ISO klauzuli s real-time brojkama
- `doc_generator` — draft procedure/uputstva u HR
- `rca` — 5-Why root cause analysis
- `mgmt_review` — komentari za 11 sekcija OB_12

**Cache + audit log u `iso_ai_outputs` tablicu:**
- SHA-256 prompt hash → cache lookup prije Gemini poziva
- Ako cache hit: 0 tokena, instant response
- Ako miss: poziv Gemini → spremiš prompt + response + tokens_used + duration_ms

**Frontend UI (audit_checklist):** gumb "Generiraj checklist (AI)" na audit detail panelu. Trenutno samo on, ostali features (Sprint A1-A5) još se trebaju ugraditi u UI.

**Strategija "AI proof-of-value first":** Atila prvo dokazuje upravi vrijednost s besplatnim Gemini tier-om prije nego dobije odobrenje za plaćeni AI (Claude API ili Gemini Pro). Ne predlaži Claude API kao first-line za Carta projekt — koristi Gemini.

---

## 4. ROADMAP I PRIORITETI

### Sad u tijeku (sprint A/B/C odobreni od Atile)

**Sprint A — AI ekspanzija** (5 podsprintova, kreće nakon što Atila deploya Cloudflare proxy):
- A1 mgmt review komentari (45 min)
- A2 5-Why CAPA (30 min)
- A3 doc generator (45 min)
- A4 reklamacija klasifikacija (30 min)
- A5 policy chat widget (2h)

**Sprint B — Quality of Life** (6 podsprintova):
- B1 backfill osposobljavanja iz PDF (Python skripta + pypdf)
- B2 backfill reklamacija s Drive (Drive MCP search + import)
- B3 PDF traceability export (jsPDF + autoTable)
- B4 anketa zadovoljstva (čeka domenu — Atila nema, bit će ga)
- B5 pg_cron za KPI (Atila ima Pro plan — možemo aktivirati)
- B6 mobile QR scanner

**Sprint C — Šira poboljšanja** (4 podsprinta):
- **C1 ZNR/HACCP modul** (3-4 sesije, NAJVEĆE) — slično ISO patternu, koristi master kontekst Sekcija 0.5.1 ZNR insights. Atila eksplicitno: "ZNR nakon ISO".
- C2 CARTA AI Widget proširenje
- C3 ESG report generator
- C4 multi-tenant priprema (post-audit)

**Atilina volja:** "želim sve nakon toga". Tj. sve A/B/C ide redom.

### Što DEFINITIVNO ne raditi

- ❌ **Ne predlaži Claude API** za Carta projekte — Gemini free tier je politika dok uprava ne odobri plaćeni AI
- ❌ **Ne diraj postojeće modul-e izvan ISO** osim ako tvoj task to specifično traži (planiranje, tuber, bottomer itd. su validirana proizvodnja)
- ❌ **Ne pretpostavi da podaci postoje** u DB-u — uvijek `SELECT count` provjeri prije nego napišeš funkciju koja vrača prazan rezultat
- ❌ **Ne hardkodiraj imena ljudi** (Branka, Kristina, Ivica, Vedrana) — koristi `settings` tablicu (PUK ID, predsjednica ID itd.)
- ❌ **Ne piši inline SVG** u view fragmentima (Pravilo 25 — Live Server lomi)
- ❌ **Ne koristi emoji** za nove ikone u sustavu (Pravilo 26 — koristi `svg-icon-XXX` klase iz `css/icons.css`, generator je `scripts/generate_icons_css.py`)

---

## 5. KAKO IDE TIPIČNA SESIJA

### Početak

1. Pročitaj `MEMORY.md` index → otvori relevantne memory fileove
2. Pročitaj posljednji changelog entry u CLAUDE.md (sesija N) — što je posljednje napravljeno
3. Pitaj Atilu: "Što treba danas?"

### Tijekom

1. Koristi **TodoWrite** za multi-step taskove (3+ koraka). Označi `in_progress` čim počneš, `completed` čim si završio.
2. **Provjeri DB schemu** prije svakog SQL koda (`mcp__supabase__list_tables` ili `information_schema.columns`)
3. **Apply migracije** kroz `mcp__supabase__apply_migration` (NE `execute_sql` za DDL) — Supabase prati migracije
4. **Check stvarne podatke** s `execute_sql` da vidiš kakav format je u kolonama (npr. priority='Visok' ne 'high')
5. Za UI: **Read postojeći sličan modul** (npr. iso/dokumenti.html) prije nego pišeš novi — pattern je ustaljen, slijedi ga

### Kraj sesije

1. **Update CLAUDE.md changelog** — nova sesija s prefiksom `### Datum - Sesija N: Naslov`
2. **Update memory** ako si naučio nešto novo (feedback, project state, reference)
3. **Update MEMORY.md index** s pointerom
4. **Sažmi za Atilu** — što je napravljeno + što slijedi + pitanja

### Postojeći memory entries (iz prijašnjih sesija)

Provjeri `memory/MEMORY.md` za current set. Trenutno (svibanj 2026.):

- `feedback_no_svg_in_js_strings.md` — Live Server bug (Pravilo 25)
- `feedback_svg_icon_system.md` — Pravilo 26
- `project_iso_9001_implementation.md` — sve odluke za ISO razvoj
- `project_iso_carta_team.md` — Carta tim (Branka, Kristina, Ivica, Vedrana, Krunoslav)
- `project_ovjera_rn_duplicate.md` — bug iz prošlosti
- `reference_carta_google_drive.md` — carta.atilavadoci@gmail.com Drive
- `user_ai_strategy_proof_first.md` — Gemini free tier strategy

---

## 6. LJUDI U CARTI (referentno)

| Ime | Uloga | Što obavlja u ISO |
|---|---|---|
| **Branka Hitner** | Predsjednica uprave | Potpisuje politiku kvalitete + ocjenu uprave (OB_12) |
| **Ivica Vajnberger** | Član uprave za proizvodnju, službeni PUK | Lead auditor, sudjeluje u Ocjeni uprave |
| **Kristina Čubela** | Back office manager, **operativni PUK** | Vodi dokumentaciju, ažurira evidencije |
| **Vedrana Tomljanović** | Voditeljica kontrolinga | Radi OB_20 Analizu procesa, financijski kontroling |
| **Krunoslav Matočec** | **Vanjski ISO konzultant** | Sudjeluje u Ocjeni uprave, daje vanjsku perspektivu |
| **Atila Vadoci** | Tehnički direktor | Razvija sustav, vlasnik CARTA-ERP-a |

**KONFIGURABILNO** — sve uloge spremljene su u `settings` tablici (`iso_predsjednica_uprave_employee_id`, `iso_puk_employee_id` itd.). NE hardkodiraj ih u kodu — uloge se mijenjaju.

---

## 7. KLJUČNI BUG CATALOGUE (iz dosadašnjih sesija)

### Bug 1 — Pravilo 25: Live Server lomi inline `<svg>`
**Symptom:** view fragment s inline SVG → script tag nakon `</svg>` ne izvršava → KPI ostaju "-"
**Uzrok:** Live Server regex `/(<\/body>|<\/svg>)/i` ubacuje WebSocket script ispred SVAKOG `</svg>` taga
**Workaround:** URL-encoded SVG kao CSS background ili `mask-image`. NIKAD inline SVG u view fragmentima.

### Bug 2 — GENERATED kolone silent fail
**Symptom:** UPDATE ili INSERT s direktnom vrijednosti za GENERATED kolonu → Postgres odbija → ali tuber-materijal kod nije provjeravao error → operateri vidjeli "spremljeno" toast a stvarno ništa
**Workaround:** Uvijek `SB.*` helpers (throw on error). NIKAD direct `from().update()` bez error checka. Update source kolonu, ne GENERATED.

### Bug 3 — ZamjenePostave globalni objekt
**Symptom:** `ZamjenePostave.data` dijele svi moduli. Ako Tuber otvoren pa Bottomer pa natrag Tuber, postava može biti od krivog modula.
**Workaround:** Module-specific varijable u window: `window.tuberTrenutnaSmjenaData`, `window.bottomerVoditeljSmjena` itd. Provjeri `stroj_tip` + `linija`.

### Bug 4 — ESP32 sinkronizacija
**Symptom:** Operater pokrene RN, ESP32 izgubi 1000+ komada
**Uzrok:** `start_machine_counter` UVIJEK radi UPSERT s count=0, ESP32 heartbeat dohvati serverCount=0 i postavi tubes=0
**Workaround:** UVIJEK `get_counter_status` PRIJE `start_machine_counter`. Ako postoji aktivan brojač za isti RN → ne diraj.

### Bug 5 — Hrvatske vs engleske vrijednosti u priority
**Symptom:** ISO trigger `fn_iso_nc_from_failure` čekao `priority='high'` — nikad nije okidao za stvarne kvarove
**Uzrok:** Cartin `prod_failure_reports.priority` koristi 'Kritičan'/'Visok'/'Normalan'/'Nizak' (hrvatski)
**Workaround:** Trigger sad koristi `IN ('Visok', 'Kritičan', 'high', 'critical')` (oboje za buduću kompatibilnost). **GENERIČKI URO:** uvijek provjeri SQL `SELECT DISTINCT column FROM table` prije nego pretpostaviš vrijednosti.

### Bug 6 — Production date != calendar date
**Pravilo:** Proizvodni dan počinje u 06:00, NE u ponoć!
- 02:00 ujutro 20.01. → proizvodni dan 19.01., smjena 3
- 06:24 ujutro 20.01. → proizvodni dan 20.01., smjena 1

Funkcije u `js/utils.js`: `getProductionDate()`, `getProductionDateFromTimestamp(ts)`, `getProductionDayStartISO(dateStr)`.

**NIKAD** ne koristi `new Date().toISOString().split('T')[0]` za proizvodni datum.

### Bug 7 — Edit failed silently
**Symptom (sesija 5):** Promjena u utils.js buildSidebar nije se primijenila iako je Edit reportirao success.
**Uzrok:** Vjerojatno race condition s Live Serverom ili IDE-om koji je nadrauto refresh-ao. **Workaround:** uvijek `Read` nakon Edit-a da provjeriš da je promjena stvarno tu.

---

## 8. DECISION FRAMEWORK — kako odluči

Pri svakoj odluci, primijeni ovu sekvencu:

### A) Postoji li već?
Prije nego napišeš novi kod, **GREP postojeći** — Atila ima 70+ JS files i 30+ HTML view-a. Slična funkcionalnost možda već postoji.

### B) Hoće li sutra Atila razumjeti?
Vanilla JS s eksplicitnim varijablama > Clever short syntax. Komentar samo gdje WHY nije očito.

### C) Što ako se zalome rubni slučajevi?
- Korisnik klikne 2× na gumb? Disable nakon prvog.
- Mreža padne? `try/catch` + jasna error poruka.
- Format datuma "DD.MM.YYYY" vs "YYYY-MM-DD"? Uvijek konvertiraj u ISO za DB, prikaz je u HR locale.

### D) Mogu li to uraditi kroz postojeći pattern?
Pogledaj sličan modul (npr. ako pišeš novi audit-related view, otvori `iso/auditi.html`). Pattern: KPI grid + filter toolbar + tablica + add/edit modal + detail panel. Ne izmišljaj nove paradigme bez razloga.

### E) Što auditor traži?
Za sve ISO funkcionalnosti, ovo je primarna lećna. Ako nešto nije auditor-friendly (npr. nema datum/vrijeme, nema potpisa, nema linka na dokaz) — ne ide.

### F) Hoće li Atila htjeti znati prije implementacije?
- Velika promjena (> 1h razvoja) → predloži pristup, čekaj OK
- Mala promjena (< 1h) ili bug fix → samo napravi
- Promjena postojećeg DB schemom (DROP, ALTER s data loss-om) → UVIJEK pitaj
- Novi modul → predloži scope u 1 paragrafu, čekaj OK

---

## 9. EFIKASNOST KOD ALATA

### Kad koristiti što

| Tool | Kada |
|---|---|
| `Read` | Kad znaš točan put — direktno čita fajl |
| `Grep` | Pretraga sadržaja, single keyword/symbol |
| `Glob` | Pretraga po imenu fajla |
| `Agent (Explore)` | Otvoreno istraživanje, > 3 grep query, "gdje je X definiran" |
| `Edit` | Ciljana promjena u postojećem fajlu |
| `Write` | Novi fajl ili kompletan rewrite |
| `Bash` (PowerShell na Win) | Shell, git, npm, python pokretanje |
| `mcp__supabase__list_tables` | Brzi pregled DB strukture |
| `mcp__supabase__execute_sql` | SELECT, brze provjere podataka |
| `mcp__supabase__apply_migration` | DDL operacije (CREATE, ALTER, FUNCTION) |
| `mcp__claude_ai_Google_Drive__*` | Cartin Drive (carta.atilavadoci@gmail.com) |

### Parallel calls

Kad imaš 2+ neovisna tool calls, **šalji ih u jednoj poruci**:
- Read više fajlova paralelno
- Grep + List tables istovremeno
- Apply migration + execute test SELECT istovremeno

**NE** ako je drugi tool ovisan o rezultatu prvog (npr. Read pa onda Edit s tim sadržajem).

---

## 10. ZAVRŠNA NAPOMENA

ISO 9001 modul je **tehnički potpun**, ali pravi posao tek počinje:
1. **Atila treba unijeti stvarne podatke** (vlasnici dokumenata, dobavljači, audit, ocjena uprave). Ti to ne možeš za njega.
2. **Cartin rujanski audit** je validacija da je sve napravljeno dobro. Tek nakon njega znamo je li politika pisana ispravno, jesu li interni audit pitanja relevantna, postoje li gaps koje nismo predvidjeli.
3. **ZNR/HACCP modul** će biti veliki posao — koristi ovaj ISO modul kao šablon, ali ZNR ima drugačiju strukturu (više mjernih opreme tipova, ozljede na radu, posebne propise iz Pravilnika o ZOP-u).

Tvoj zadatak je **nastaviti pomagati Atili** — on radi solo, treba sigurnog AI partnera koji ga ne preopterećuje pitanjima ali koji prepoznaje kad treba pitati. Pogledaj kako je sesija 5-8 vodena: korak po korak, provjera podataka prije pretpostavki, eksplicitne odluke prije implementacije.

Sretno. 🛡️
