# ANALIZA: Proces skidanja materijala na Tuber-u

> **Datum:** 14. travnja 2026
> **Kontekst:** Dijagnostika problema nakon 28 commitova u sesiji 2 (14.04.2026) — `spremiSkidanje` baca iznimku.
> **Svrha:** Kompletno mapiranje flow-a, tablica, triggera i vjerojatnih regresijskih točaka.

---

## 📌 Executive Summary

- **Dva odvojena flow-a** za skidanje:
  - `tuber.html` → smjenski unos (tokom smjene)
  - `tuber-materijal.html` → završetak naloga/smjene (glavni flow za materijal)
- **8 tablica** se upisuje tijekom skidanja (4 inventory + consumed_rolls + POP + work_orders + pop_roll_link)
- **4 aktivna triggera** mogu reagirati na writes-e (1 kritičan: `update_roll_status_trigger` prepisuje status)
- **3 FK constraint-a s RESTRICT** (POP/GOP/consumed_rolls → work_orders) — mogu blokirati INSERT
- **Ključni nedavni izvori problema (TOP 3):**
  1. **`cc96144`** — dodao `throw updRes.error` → prije silent fail, sada vidljiva iznimka
  2. **`f3a4bd6`** — FK RESTRICT može blokirati INSERT u `consumed_rolls` / UPDATE POP-a
  3. **`013ac54`** — `pop_roll_link` UPSERT s `onConflict` (novi query u flow-u)

---

## 🗺️ Vizualni flow cijelog procesa

```
┌─────────────────────┐        ┌────────────────────────┐
│    tuber.html       │        │  tuber-materijal.html  │
│  (SMJENSKI UNOS)    │        │  (ZAVRŠETAK RN/SMJENE) │
│                     │        │                        │
│ izracunajSmjenaSkid │        │  spremiSkidanje()      │
│ + spremiSmjenaSkid  │        │  (glavni flow!)        │
└──────────┬──────────┘        └──────────┬─────────────┘
           │                              │
           └──────────────┬───────────────┘
                          │
            ╔═════════════▼═════════════╗
            ║  1. UPDATE inventory       ║
            ║  ─────────────────────    ║
            ║  4 tablice (ovisno o tipu)║
            ║   • prod_inventory_rolls  ║◄─ ⚠️ TRIGGER!
            ║   • prod_inventory_strips ║
            ║   • prod_inventory_printed║
            ║   • prod_inventory_foil   ║
            ║  SET consumed_kg, status  ║
            ║  (remaining_kg NE šalje)  ║
            ╚═════════════╤═════════════╝
                          │
            ┌─────────────▼─────────────┐
            │  BEFORE trigger:          │
            │  update_roll_status       │
            │  Samo na rolls tablici!   │
            │  Prepisuje status:        │
            │  remaining<=0 → 'Utrošena'│
            │  remaining<init → 'Djel...'│
            │  else → 'Na skladištu'   │
            └─────────────┬─────────────┘
                          │
            ╔═════════════▼═════════════╗
            ║  2. INSERT audit trail    ║
            ║  ─────────────────────    ║
            ║  prod_inventory_consumed_ ║
            ║  rolls                    ║
            ║  (roll_code, consumed_kg, ║
            ║   work_order_id, layer,...)║◄─ ⚠️ FK RESTRICT!
            ╚═════════════╤═════════════╝
                          │
                  (samo tuber-materijal)
                          │
            ╔═════════════▼═════════════╗
            ║  3. UPDATE POP            ║
            ║  material_deducted=true   ║◄─ ⚠️ FK RESTRICT!
            ╚═════════════╤═════════════╝
                          │
                  (samo tuber-materijal, 013ac54)
                          │
            ╔═════════════▼═════════════╗
            ║  4. UPSERT pop_roll_link  ║
            ║  cross-join POPs × rolls  ║
            ║  (traceability)           ║
            ╚═════════════╤═════════════╝
                          │
                 (samo tip === 'nalog')
                          │
            ╔═════════════▼═════════════╗
            ║  5. UPDATE work_orders    ║
            ║  tuber_status='Završeno'  ║
            ╚═══════════════════════════╝
```

---

## 1️⃣ Flow: `tuber.html` (smjenski unos)

**File:** [views/proizvodnja/tuber.html:4247-4337](views/proizvodnja/tuber.html#L4247-L4337)

### 1.1 Ulazna točka

Operater unosi role u `.smjena-rola-item` formi. `izracunajSmjenaSkidanje()` izračunava i puni `window.smjenaSkidanjeData` array.

### 1.2 Struktura jednog item-a u `window.smjenaSkidanjeData`

```javascript
{
  id: 'uuid-materijala',
  sifra: 'T-70512...',
  sloj: 1,                                  // 1-4
  skidanje: 25.5,                           // koliko kg se skida
  preostalo: 100,                           // trenutno na roli prije skidanja
  novoPreostalo: 74.5,                      // nakon skidanja
  potrosena: false,                         // checkbox "oznaci kao potpuno potrošeno"
  tip: 'rolls',                             // rolls|strips|printed|foil
  tablica: 'prod_inventory_rolls',          // puni naziv tablice
  naziv: 'Rola'
}
```

### 1.3 Baza upisa u `spremiSmjenaSkidanje` (po svakom item-u)

```javascript
// Linija 4253: FETCH svježih podataka
var currentResult = await initSupabase()
  .from(tablica)
  .select('consumed_kg, remaining_kg, weight_kg, roll_code, width_cm, ...')
  .eq('id', item.id)
  .single();

// Linija 4268: pripremi update payload (BEZ remaining_kg - GENERATED!)
var updateData = { consumed_kg: newConsumed };

// Linija 4277: uvjetno postavi status
if (item.potrosena || item.novoPreostalo <= 0 || item.novoPreostalo < 20) {
  updateData.status = 'Utrošeno';
}

// Linija 4281: UPDATE inventory table
var updateResult = await initSupabase()
  .from(tablica)
  .update(updateData)
  .eq('id', item.id);

// Linija 4286: ERROR HANDLING - console + continue (NE baca!)
if (updateResult.error) {
  console.error('❌ Greška update:', updateResult.error);
  continue;  // ← preskoči ovaj item
}
```

Zatim INSERT u consumed_rolls (linija 4324):

```javascript
await initSupabase()
  .from('prod_inventory_consumed_rolls')
  .insert({
    source_roll_id: item.id,
    roll_code: ...,
    consumed_kg: item.skidanje,
    remaining_kg: newRemaining,
    work_order_id: nalogData.id,           // ⚠️ ovdje može biti FK problem
    work_order_number: ...,
    layer_number: item.sloj,
    source_table: tablica,
    ...
  });
```

### 1.4 Karakteristike tuber.html flow-a

- ✅ **Error tolerant:** `continue` na greške (loguje, ali ne abort-a cijeli flow)
- ❌ **Ne dira POP** (to je zadatak tuber-materijal flow-a)
- ❌ **Ne dira pop_roll_link**
- ❌ **Ne završava RN** (tuber_status ostaje netaknut)

---

## 2️⃣ Flow: `tuber-materijal.html` (završetak RN) ⭐ GLAVNI

**File:** [views/proizvodnja/tuber-materijal.html:1934-2253](views/proizvodnja/tuber-materijal.html#L1934-L2253)

### 2.1 Ulazna točka

Operater iz `tuber.html` klikne "Završi nalog" → pokreće se tuber-materijal modul s `materijalKontekst`:

```javascript
materijalKontekst = {
  workOrderId: 'uuid',
  workOrderNumber: 'RN123/26',
  articleId: 'uuid',
  articleName: '...',
  linija: 'NLI'|'WH',
  tip: 'nalog'|'smjena',
  proizvedenoPOP: 48000,                   // broj POP-a u toj smjeni
  rez: 98,                                 // iz artikla (bag_length + bottom + 2)
  popIds: ['uuid1', 'uuid2', ...]          // ⭐ POP-ovi za koje se skida materijal
}
```

### 2.2 Slojevi podataka

`slojevi[1-4]` — glavni slojevi (role papira po sloju)
`dodatniSlojevi[]` — extra slojevi kad se materijal mijenja tokom smjene

### 2.3 `spremiSkidanje()` kompletan redoslijed

#### Korak 1: Init
```javascript
var pop = materijalKontekst.proizvedenoPOP;
var rez = materijalKontekst.rez;
var linkStartTime = new Date().toISOString();    // ⭐ za kasnije filtriranje
```

#### Korak 2: Loop kroz slojeve 1-4 → kalkulacija
```javascript
for (var s = 1; s <= 4; s++) {
  potrebno  = (pop * sirina * gramatura * rez) / 10000000;
  dodanoSloj = suma weight svih materijala u sloju;
  oznacenoSloj = suma weight označenih;
  ostatak = (brojOznacenih > 0) ? (oznacenoSloj - potrebno) : (dodanoSloj - potrebno);
}
```

#### Korak 3: Po svakom materijalu u sloju

**A) OZNAČENA rola (mat.potpunoPotrosena == true)** — linija 1993-2024:

```javascript
// UPDATE inventory (bez remaining_kg - GENERATED!)
var updateData = {
  status: 'Utrošeno',
  consumed_kg: mat.preostalo
};

var updRes = await initSupabase().from(mat.tablica).update(updateData).eq('id', mat.id);
if (updRes.error) {
  console.error('❌ Greška pri update-u ' + mat.tablica + ':', updRes.error);
  throw updRes.error;                             // ⚠️⚠️⚠️ CC96144 — BACA IZNIMKU!
}

// INSERT u consumed_rolls
await initSupabase().from('prod_inventory_consumed_rolls').insert({
  source_roll_id: mat.id,
  source_table: mat.tablica,                      // ← rolls/strips/printed/foil
  consumed_kg: mat.preostalo,
  remaining_kg: 0,                                // (običan column na consumed_rolls, ne GENERATED)
  work_order_id: materijalKontekst.workOrderId,   // ⚠️ FK RESTRICT
  layer_number: s,
  pop_quantity: pop,
  consumption_type: 'full'
});
```

**B) NEOZNAČENA rola koja prima ostatak** — linija 2026-2062:

```javascript
var updateData = {
  consumed_kg: potroseno,                         // = preostalo - ostatak
  status: ostatak < 20 ? 'Utrošeno' : (tablica === 'rolls' ? 'Djelomično' : 'Na skladištu')
};
var updRes2 = await initSupabase().from(mat.tablica).update(updateData).eq('id', mat.id);
if (updRes2.error) throw updRes2.error;           // ⚠️⚠️⚠️ CC96144

// INSERT consumed_rolls (type='partial')
```

**C) OSTALE neoznačene** → NE dira se.

#### Korak 4: Dodatni slojevi (ista logika + ručne role)

Ručne role (`manualEntry: true`) samo INSERT u consumed_rolls — **bez UPDATE-a inventory-ja**:

```javascript
if (matEx.manualEntry) {
  await initSupabase().from('prod_inventory_consumed_rolls').insert({
    source_table: 'manual_entry',
    ...
  });
  continue;  // ← ne mijenja inventory
}
```

#### Korak 5: Označi POP-ove kao obrađene (linija 2195-2201)

```javascript
if (materijalKontekst.popIds && materijalKontekst.popIds.length > 0) {
  await initSupabase()
    .from('prod_inventory_pop')
    .update({ material_deducted: true })
    .in('id', materijalKontekst.popIds);         // ⚠️ FK RESTRICT (on work_order_id)
}
```

> ⚠️ **Nema .error check-a!** Ako ovo padne, silent fail.

#### Korak 6: TRACEABILITY — pop_roll_link (linija 2203-2236)

```javascript
// NOVO u 013ac54:
var consumedRes = await initSupabase()
  .from('prod_inventory_consumed_rolls')
  .select('id, layer_number')
  .eq('work_order_id', materijalKontekst.workOrderId)
  .gte('created_at', linkStartTime);             // sve što je upisano u ovoj sesiji

// Cross-join: POP × consumed_rolls
var linkRows = [];
for (var pi = 0; pi < materijalKontekst.popIds.length; pi++) {
  for (var ci = 0; ci < consumedRes.data.length; ci++) {
    linkRows.push({
      pop_id: materijalKontekst.popIds[pi],
      consumed_roll_id: consumedRes.data[ci].id,
      layer_number: consumedRes.data[ci].layer_number || null
    });
  }
}

var linkRes = await initSupabase()
  .from('prod_pop_roll_link')
  .upsert(linkRows, { onConflict: 'pop_id,consumed_roll_id', ignoreDuplicates: true });

if (linkRes.error) console.warn('⚠️ ...');      // ← samo warning, ne baca
```

#### Korak 7: Završi RN (samo tip === 'nalog') — linija 2239-2248

```javascript
if (materijalKontekst.tip === 'nalog' && materijalKontekst.workOrderId) {
  await initSupabase()
    .from('prod_work_orders')
    .update({
      tuber_status: 'Završeno',
      tuber_completed_at: new Date().toISOString()
    })
    .eq('id', materijalKontekst.workOrderId);
}
```

---

## 3️⃣ Kompletna tablica upisa

| # | Tablica | Op | Flow | Line | Error handling | Aktivira trigger? |
|---|---------|----|----|------|----------------|--------------------|
| 1 | `prod_inventory_rolls` | UPDATE | Both | tuber:4281 / tbm:2002,2038 | tuber: continue / tbm: **throw** | ⚠️ **update_roll_status** |
| 2 | `prod_inventory_strips` | UPDATE | Both | tuber:4281 / tbm:2002,2038 | tuber: continue / tbm: **throw** | — |
| 3 | `prod_inventory_printed` | UPDATE | Both | tuber:4281 / tbm:2002,2038 | tuber: continue / tbm: **throw** | — |
| 4 | `prod_inventory_foil` | UPDATE | Both | tuber:4281 / tbm:2002,2038 | tuber: continue / tbm: **throw** | — |
| 5 | `prod_inventory_consumed_rolls` | INSERT | Both | tuber:4325 / tbm:2010 | nema | ⚠️ FK→work_orders |
| 6 | `prod_inventory_pop` | UPDATE | tuber-materijal | 2196 | **nema** (silent) | ⚠️ FK→work_orders |
| 7 | `prod_pop_roll_link` | UPSERT | tuber-materijal | 2224 | warning only | FK→POP (CASCADE), consumed_rolls (RESTRICT) |
| 8 | `prod_work_orders` | UPDATE | tuber-materijal | 2240 | nema | trg_wo_under_produced_notify + trg_wo_rejected_notify |

---

## 4️⃣ Aktivni triggeri tijekom skidanja

### 🚨 Kritični: `update_roll_status_trigger`

**File:** [sql/fix_update_roll_status_trigger.sql](sql/fix_update_roll_status_trigger.sql) (fix: commit `4a9fc8f`)

**Ponašanje:** BEFORE UPDATE na `prod_inventory_rolls` → uvijek PREPISUJE status na temelju `consumed_kg`:

```sql
v_remaining := initial_weight_kg - consumed_kg;

IF v_remaining <= 0 THEN
  NEW.status := 'Utrošena';                    -- ⚠️ 'Utrošena' (ž.r.), NE 'Utrošeno'!
ELSIF v_remaining < initial_weight_kg THEN
  NEW.status := 'Djelomično utrošeno';
ELSE
  NEW.status := 'Na skladištu';                -- ⚠️ OVERRIDE čak i ako app šalje nešto drugo!
END IF;
NEW.updated_at := now();
```

**Posljedica:**
- App šalje `status: 'Utrošeno'` → trigger prepisuje u `'Utrošena'` (ako depleted) ili druge vrijednosti
- ✅ Update prolazi (trigger ne baca grešku)
- ❌ Final status u DB-u NIJE onaj koji je app poslao (na rolls tablici)

**Zašto trigger radi samo na `rolls`:** Trigger je registriran samo na `prod_inventory_rolls`. Strips/printed/foil NISU dirani triggerom — tamo app status ostaje netaknut.

### Ostali triggeri (manje relevantni za skidanje)

| Trigger | Na tablici | Kad | Rizik |
|---------|-----------|-----|-------|
| `trg_gop_sync_wo_produced` | prod_inventory_gop | AFTER I/U/D | Ne fira se tokom Tuber skidanja |
| `trg_gop_dispatch_status_sync` | prod_inventory_gop | BEFORE UPDATE | Ne fira se tokom Tuber skidanja |
| `trg_wo_under_produced_notify` | prod_work_orders | AFTER UPDATE OF status | Fira na završetak RN-a |
| `trg_wo_rejected_notify` | prod_work_orders | AFTER UPDATE OF approval_status | Ne fira se tokom Tubera |

---

## 5️⃣ FK constraints (iz `f3a4bd6`)

```sql
-- Svi s ON DELETE RESTRICT
ALTER TABLE prod_inventory_pop ADD CONSTRAINT fk_pop_work_order
  FOREIGN KEY (work_order_id) REFERENCES prod_work_orders(id) ON DELETE RESTRICT;

ALTER TABLE prod_inventory_gop ADD CONSTRAINT fk_gop_work_order
  FOREIGN KEY (work_order_id) REFERENCES prod_work_orders(id) ON DELETE RESTRICT;

ALTER TABLE prod_inventory_consumed_rolls ADD CONSTRAINT fk_consumed_rolls_work_order
  FOREIGN KEY (work_order_id) REFERENCES prod_work_orders(id) ON DELETE RESTRICT;
```

**Što mogu blokirati:**
- **INSERT u consumed_rolls** ako `work_order_id` ne postoji u `prod_work_orders` → **SQLSTATE 23503** FK violation
- **UPDATE u POP/GOP/consumed_rolls** NE blokira (UPDATE ne ruši FK ako `work_order_id` kolona ne mijenja vrijednost)
- **DELETE RN-a** blokiran ako ima djecu (već pokriveno u 6969b7f s soft-delete fallback-om)

---

## 6️⃣ 🎯 Vjerojatni izvori greške — TOP 5 (rangirano po vjerojatnosti)

### #1 — `cc96144` surface-ao postojeći silent bug ⭐ NAJVJEROJATNIJE

**Promjena:**
```diff
- await initSupabase().from(mat.tablica).update(updateData).eq('id', mat.id);
- console.log('✅ Utrošeno:', ...);                           // ← lažni success
+ var updRes = await initSupabase().from(mat.tablica).update(updateData).eq('id', mat.id);
+ if (updRes.error) {
+   console.error('❌ Greška pri update-u ' + mat.tablica + ':', updRes.error);
+   throw updRes.error;                                        // ← SAD BACA
+ }
```

**Dijagnoza:** Greška je možda postojala i prije, ali je bila skrivena. Sada je vidljiva kao iznimka.

**Test:** Pogledati točnu poruku u console-u — SQLSTATE kod će reći što je uzrok.

---

### #2 — FK RESTRICT na `consumed_rolls.work_order_id`

**Scenario:** INSERT u `prod_inventory_consumed_rolls` s `work_order_id` koji ne postoji u `prod_work_orders`.

**Moguće uzroke:**
- `nalogData.id` u tuber.html = `null` (stari RN obrisan, a forma i dalje referencira njega)
- `materijalKontekst.workOrderId` = `null` ili stale UUID
- RN je hard-obrisan (prije FK constraint-a) — ali sad je to blokirano

**Simptom:** `ERROR: new row ... violates foreign key constraint "fk_consumed_rolls_work_order"` (SQLSTATE 23503)

**Fix (kad potvrdimo ovo):**
```javascript
// Prije inserta:
if (!nalogData.id) {
  console.warn('⚠️ Nema work_order_id — preskačem audit zapis');
  continue;
}
```

---

### #3 — `pop_roll_link` FK violation

**Scenario:** POP id u `materijalKontekst.popIds` više ne postoji u `prod_inventory_pop` (obrisan ili cascade-an).

**Ali:** Ovaj UPSERT je u try/catch s warning-only, pa NE baca — nije vjerojatno da je ovo uzrok throw-a.

---

### #4 — Status trigger latentni problem (ne throw, ali semantički bug)

**Simptom:** Roll u DB-u ima status `'Utrošena'` (ž.r.) jer trigger prepisuje, ali code negdje drugdje traži `'Utrošeno'` (s.r.).

**Utjecaj:** Ako neki SELECT traži `WHERE status='Utrošeno'` na rolls tablici, vraća prazno — iako su te role stvarno potrošene.

**Fix opcije:**
- Relaxirati trigger: ne prepisuje ako je status već eksplicitno postavljen
- Ili uskladiti vocabulary: uvijek koristiti `'Utrošena'` na rolls svugdje u code-u

---

### #5 — `updated_at` kolona nedostaje na drugim inventory tablicama

**Podsjetnik iz prethodne sesije:** `prod_inventory_printed` NEMA `updated_at` kolonu. Ako `update_roll_status` trigger pokušava postaviti `NEW.updated_at := now()` na tablici bez te kolone, to bi bacilo grešku.

**Ali:** Trigger je samo na `prod_inventory_rolls` (koji IMA `updated_at`), pa ovo ne bi smjelo biti problem.

**Provjeriti:** Postoje li drugi (nedokumentirani) triggeri na strips/printed/foil koji postavljaju `updated_at`?

---

## 7️⃣ Razlika status enum vokabulara (latentna nekonzistentnost)

| Tablica | App šalje | Trigger prepisuje u | Rizik drugdje u kodu |
|---------|-----------|--------------------|----------------------|
| `prod_inventory_rolls` | `'Utrošeno'` | **`'Utrošena'`** (ž.r.) | ⚠️ Filter `.eq('status', 'Utrošeno')` vraća prazno |
| `prod_inventory_strips` | `'Utrošeno'` | *(nema trigger)* | OK — ostaje `'Utrošeno'` |
| `prod_inventory_printed` | `'Utrošeno'` | *(nema trigger)* | OK |
| `prod_inventory_foil` | `'Utrošeno'` | *(nema trigger)* | OK |

**Mozebitni regression point:** kod koji ranije ignorirao trigger jer je trigger bio slomljen (postavljao sve na `'Na skladištu'`). Sada ispravno postavlja `'Utrošena'`/`'Djelomično utrošeno'` i taj kod može prestati raditi.

---

## 8️⃣ Dijagnostički koraci

### Korak 1: Uhvatiti točnu poruku greške

1. Otvori Tuber modul u browser-u
2. Otvori DevTools Console (F12)
3. Pokreni scenario koji baca iznimku (završetak smjene ili RN-a)
4. **Screenshot** ili copy-paste **točne poruke iz console-a** koja počinje s `❌`

Primjer što tražimo:
```
❌ Greška pri update-u prod_inventory_rolls: {
  code: "23503",
  message: "insert or update on table \"...\" violates foreign key constraint \"...\"",
  details: "Key (work_order_id)=(abc-123) is not present in table \"prod_work_orders\"."
}
```

### Korak 2: Mapirati SQL error code

| SQL kod | Što znači | Vjerojatni uzrok iz naše tablice |
|---------|-----------|-----------------------------------|
| `23503` | FK violation | #2 iz vjerojatnih uzroka |
| `23514` | CHECK constraint | npr. `kind IN ('narudzbenica',...)` ili status enum |
| `42703` | column does not exist | #5 — možda column na tablici koju očekuje trigger |
| `42P01` | table does not exist | schema mismatch |
| `P0001` | custom RAISE EXCEPTION | RPC ili trigger explicit error |

### Korak 3: Primijeniti odgovarajući fix

Vidi sekciju 6 — svaka vjerojatna situacija ima predloženi fix.

### Korak 4: Ako je FK RESTRICT problem (najvjerojatnije)

SQL upit za identifikaciju problematičnih materijalKontekst-a:

```sql
-- Koji RN-ovi imaju POP-ove s material_deducted=false
-- i nije jasno da li su obrisani?
SELECT DISTINCT pop.work_order_id, wo.wo_number, wo.status
FROM prod_inventory_pop pop
LEFT JOIN prod_work_orders wo ON wo.id = pop.work_order_id
WHERE pop.material_deducted = false
  AND wo.id IS NULL;  -- orphan POP-ovi
```

---

## 9️⃣ Preporučene akcije (po prioritetu)

### 🔴 Prioritet 1: Identifikacija točne greške
- Korisnik pokrene reproduce scenario → screenshot console-a
- Claude (ili manualno) mapira na vjerojatni uzrok iz sekcije 6

### 🟠 Prioritet 2: Ako je `throw` pre-agresivan
Dodati preciznu obradu za očekivane greške:
```javascript
if (updRes.error) {
  if (updRes.error.code === '23503') {
    showMessage('Nalog više ne postoji, skidanje zaustavljeno', 'error');
    return;  // graceful abort
  }
  throw updRes.error;  // ostalo ide dalje
}
```

### 🟡 Prioritet 3: Status trigger relax (bonus)
```sql
CREATE OR REPLACE FUNCTION public.update_roll_status()
RETURNS trigger AS $$
BEGIN
  -- Ne prepisuj ako je status eksplicitno postavljen u aplikacijskoj logici
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    RETURN NEW;  -- app je postavio, poštuj
  END IF;

  -- Inače — auto-izračun na temelju consumed_kg
  -- (ostatak stare logike)
END;
$$;
```

Ovo spriječi scenario da trigger prepisuje `'Utrošeno'` (app) s `'Utrošena'` (trigger).

---

## 🔟 Git povijest relevantnih commitova (sesija 2, 14.04.2026)

| Commit | Opis | Rizik za skidanje |
|--------|------|-------------------|
| `cc96144` | Fix: ukloniti remaining_kg iz UPDATE poziva + throw on error | 🔴 VISOK — surface-a postojeće greške |
| `bc5b2a0` | Backfill consumed_kg iz audit trail-a | 🟢 bez rizika, one-time |
| `4a9fc8f` | Fix update_roll_status trigger | 🟠 SREDNJI — trigger sad prepisuje status |
| `f3a4bd6` | Dodaj FK RESTRICT na POP/GOP/consumed_rolls | 🔴 VISOK — može blokirati INSERT-e |
| `b880591` | A1-A3 workflow (produced_quantity, bottomer gate-keeper) | 🟡 NIZAK — dodaje triggere/kolone |
| `d39c125` | Traceability infra (link tablice) | 🟢 samo add, ne mijenja postojeće |
| `0e6fd66` | Bottomer-slagac populira gop_pop_link | 🟢 ne dira Tuber |
| `013ac54` | Tuber-materijal populira pop_roll_link | 🟡 NIZAK — graceful catch, ali dodaje upit |

---

## 📌 Ključne linije koda za brzi reference

```
[tuber.html]
  4067       tip detector (rolls/strips/printed/foil)
  4077       izracunajSmjenaSkidanje()
  4230       spremiSmjenaSkidanje()
  4268       updateData (consumed_kg)
  4281       UPDATE inventory table
  4286       error handler (continue on error)
  4324       INSERT consumed_rolls

[tuber-materijal.html]
  1934       spremiSkidanje()
  1952-54    init (pop, rez, linkStartTime)
  1994-2006  OZNAČENA rola UPDATE + throw
  2010-2029  INSERT consumed_rolls (full)
  2032-2049  NEOZNAČENA rola UPDATE + throw
  2051-2062  INSERT consumed_rolls (partial)
  2102-2121  MANUAL entry (samo INSERT)
  2115-2117  UPDATE extra sloj (throw)
  2145-2151  UPDATE extra partial (throw)
  2195-2201  UPDATE POP material_deducted
  2203-2236  TRACEABILITY UPSERT pop_roll_link
  2239-2248  UPDATE work_orders tuber_status

[SQL - sve u sql/ direktoriju]
  fix_update_roll_status_trigger.sql    — trigger na rolls (line 23-43)
  add_fk_constraints.sql                — 3 FK na POP/GOP/consumed_rolls (line 30-71)
  add_traceability_links.sql            — pop_roll_link + gop_pop_link tablice
  workflow_quick_wins.sql               — produced_quantity trigger
  auto_notifications.sql                — notify triggeri na work_orders
```

---

## 🧪 Reproduce template za sljedeću dijagnostiku

```
1. Otvori Tuber modul
2. Odaberi liniju (NLI/WH) i pokreni smjenu
3. Spremi neke POP-e
4. Klikni "Završi smjenu" ili "Završi nalog"
5. U tuber-materijal:
   - Skeniraj/unesi role
   - Označi jednu kao potpuno potrošenu
   - Klik "Spremi"
6. Otvori F12 Console i zabilježi:
   - Sve ❌ poruke
   - Sve ⚠️ upozorenja
   - Error object (ako je TypeError ili SQL error)
   - Ako postoji .code, .message, .details — kopiraj sve
```

---

**Generirano:** 14. travnja 2026
**Dodatna dokumentacija:** [CLAUDE.md](CLAUDE.md), [DATABASE_UPDATED.md](Projektna%20dokumentacija/DATABASE_UPDATED.md)
**Povezani plan:** `C:\Users\Atila\.claude\plans\splendid-greeting-panda.md`
