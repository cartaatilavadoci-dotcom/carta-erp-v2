# Tuber FIFO UI Redesign — Implementation Plan

> **Za:** Sljedeću Claude Code sesiju (self-contained, treba raditi bez dodatnog konteksta)
> **Task:** Dodati novi FIFO skidanje materijala UI u `tuber-materijal.html` uz postojeći (toggle mode)
> **Pripremljeno:** 14.04.2026

---

## 🎯 Kontekst i zašto

**Problem:** Operateri ručno računaju i unose kg-e po roli za skidanje materijala. To je sklono greškama i oduzima vrijeme. Postojeći flow ima bug (cc96144 fix - `throw` on update error koji je surface-ao postojeće probleme).

**Cilj:** Operater **samo skenira šifre** rola koje je koristio, označava "nije potpuno potrošena" onima koje nisu potrošene — sustav automatski radi FIFO skidanje. Ako skenira šifru koja nije u bazi, sustav "posudi" kg iz najstarije role istog tipa papira (placeholder). Kad stvarna rola kasnije bude unesena kroz rezač/tisak/skladište, trigger resolve-a placeholder.

**Očekivani ishod:** Jednostavniji UI, manje grešaka, audit-friendly, AI-ready (operater samo skenira).

---

## ✅ Što je VEĆ napravljeno (ne ponavljati)

### Database foundation (applied in Supabase, commit `d8469f8`)

Verificirano u bazi - 6 objekata postoji:

| Objekt | Tip | Svrha |
|--------|-----|-------|
| `prod_inventory_placeholder_consumption` | Table | Bilježi "posuđene" kg kad šifra nije u bazi |
| `resolve_placeholders_on_roll_insert()` | Trigger function | Auto-resolve pri INSERT nove role |
| `trg_resolve_placeholder_on_roll_insert` | Trigger | BEFORE INSERT on prod_inventory_rolls |
| `fifo_roll_candidates(internal_id, min_remaining)` | RPC | Vrati FIFO listu rola za internal_id |
| `atomic_consume_roll(roll_id, amount)` | RPC | Conditional UPDATE (race-safe) |
| `wo_has_printing(wo_number)` | RPC | Boolean - ima li RN tisak |
| `fifo_printed_rolls_for_wo(wo_number)` | RPC | FIFO printed rolls za RN |

**Verifikacija** (korisnik potvrdio - pokreni opet da budeš siguran):
```sql
SELECT 'prod_inventory_placeholder_consumption' AS obj, COUNT(*)::text FROM prod_inventory_placeholder_consumption
UNION ALL SELECT 'fifo_roll_candidates', (SELECT COUNT(*)::text FROM pg_proc WHERE proname='fifo_roll_candidates')
UNION ALL SELECT 'atomic_consume_roll', (SELECT COUNT(*)::text FROM pg_proc WHERE proname='atomic_consume_roll')
UNION ALL SELECT 'wo_has_printing', (SELECT COUNT(*)::text FROM pg_proc WHERE proname='wo_has_printing');
```

### JavaScript library (file postoji u repozitoriju)

- **`js/tuber-fifo.js`** (320 linija) - exposes `window.TuberFifo`
  - `TuberFifo.computePlan(ctx)` - dohvati artikl + scanned, računaj FIFO
  - `TuberFifo.executePlan(ctx, plan, remainderAssignments)` - DB writes
  - `TuberFifo._resolveScannedRoll(code, expectedInternalId)` - internal helper
  - `TuberFifo._computeLayerPlan(...)` - po sloju računa
  - `TuberFifo._executeLayer(...)` - po sloju upisuje u bazu

- **`js/supabase-helpers.js`** - `window.SB` wrapper (već u index.html)

### Relevantni commitovi
- `d8469f8` — DB + JS foundation
- `cc96144` — fix GENERATED column bug (throw added)
- `4a9fc8f` — fix update_roll_status trigger
- `f3a4bd6` — FK RESTRICT constraints
- `013ac54` — prod_pop_roll_link integration in old flow

---

## ⚠️ KRITIČNO: Backward compatibility

**Produkcija koristi drugačiji deploy (ne ovaj repo direktno).** Zato:

1. **NE DIRATI** postojeći `spremiSkidanje` u `tuber-materijal.html` (lines 1934-2253)
2. **NE DIRATI** postojeće DOM elemente (#kalkulacijaSlojevi, slojevi[], etc.)
3. **NE DIRATI** postojeći CSS (.kalk-sloj-*, .manual-roll-*, etc.)
4. **NE BRISATI** postojeće window.* funkcije koje se zovu iz HTML-a
5. **NE MIJENJATI** postojeće tablice/kolone/RPC-ove koje stari kod zove
6. **NOVO = ADITIVNO** (novi div, nove window.fifo* funkcije)

Ako se postojeći flow slomi, produkcija prestaje raditi.

---

## 🏗️ Implementation Strategy: Toggle Mode

```
Postojeći UI (default)  ◄──── Operater bira preko checkbox-a ────►  Novi FIFO UI
    (radi kao prije)                                                 (beta test)
```

Checkbox "🧪 Novi FIFO način (beta)" na vrhu stranice:
- OFF (default): postojeći UI vidljiv, stari `spremiSkidanje()` radi
- ON: postojeći UI se skriva (`display:none`), novi FIFO UI se prikazuje

Kad korisnik potvrdi da FIFO radi kroz par smjena, u kasnijem commit-u (zasebna sesija) uklanja se postojeći kod.

---

## 📝 Konkretne izmjene

### Datoteka 1: `index.html`

**Lokacija:** Dodaj novi `<script>` tag u sekciji gdje su drugi js/ loadi (nakon `js/supabase-helpers.js`).

```html
<!-- Postojeće -->
<script src="js/utils.js"></script>
<script src="js/supabase-helpers.js"></script>
<script src="js/notifications.js"></script>
<script src="js/mobile.js"></script>
<!-- DODAJ OVU LINIJU: -->
<script src="js/tuber-fifo.js"></script>
<script src="js/scanner.js"></script>
```

**Napomena:** `tuber-fifo.js` koristi `initSupabase` i `SB`, pa mora biti nakon njih. Može i prije `scanner.js`.

### Datoteka 2: `views/proizvodnja/tuber-materijal.html` (glavni rad)

#### 2a. Dodaj toggle banner (HTML)

Nađi `<div id="tuberMaterijalContent" ...>` (oko linije 491). ODMAH poslije tog div-a, prije bilo kojeg postojećeg sadržaja, dodaj:

```html
<!-- FIFO MODE TOGGLE (novi način, beta) -->
<div style="background: linear-gradient(135deg, #fff3e0, #ffe0b2); padding: 10px 14px; border-radius: 6px; margin-bottom: 15px; border-left: 4px solid #f57c00;">
  <label style="display: flex; align-items: center; gap: 10px; cursor: pointer;">
    <input type="checkbox" id="fifoModeToggle" onchange="toggleFifoMode()" style="width:18px; height:18px;">
    <span>
      <strong>🧪 Novi FIFO način (beta)</strong>
      <span style="color: #666; font-size: 0.9em;">— samo skeniraš šifre, sustav sam računa FIFO skidanje</span>
    </span>
  </label>
</div>

<!-- FIFO UI SEKCIJA (skrivena dok se toggle ne uključi) -->
<div id="fifoSection" style="display: none;">
  <!-- Header info -->
  <div id="fifoHeader" style="background: #f5f5f5; padding: 12px; border-radius: 6px; margin-bottom: 15px;">
    <div id="fifoHeaderContent">Učitavanje...</div>
  </div>

  <!-- Banner ako RN ima tisak -->
  <div id="fifoPrintingBanner" style="display: none; background: linear-gradient(135deg, #e3f2fd, #bbdefb); padding: 10px 14px; border-radius: 6px; margin-bottom: 15px; border-left: 4px solid #1976d2;">
    🖨️ <strong>Ovaj RN koristi otisnuti papir.</strong>
    Sloj 1 će skidati FIFO iz otisnutih rola (printed).
  </div>

  <!-- Slojevi (dinamički rendered) -->
  <div id="fifoLayers"></div>

  <!-- Akcije -->
  <div style="display: flex; gap: 10px; justify-content: flex-end; margin-top: 20px;">
    <button class="btn btn-secondary" onclick="natragBezSpremanja()">Odustani</button>
    <button class="btn btn-primary" onclick="fifoSave()">💾 Spremi (FIFO)</button>
  </div>
</div>

<!-- POSTOJEĆI UI (nepromijenjen) - samo obuhvati u wrapper div da ga lakše sakrivamo -->
<div id="legacySection">
  <!-- ... OSTAJE ORIGINALNI SADRŽAJ tuberMaterijalContent-a ... -->
```

**VAŽNO:** Na kraju legacySection div-a, dodaj `</div>` koji zatvara wrapper. Cijela postojeća struktura (do `</div>` od tuberMaterijalContent-a) mora biti wrappana unutar `#legacySection`.

#### 2b. Dodaj remainder modal (HTML, na kraj fajla, prije `</script>`)

Nađi gdje završava `<script>` blok (linija ~2620). **PRIJE** tog `</script>`, dodaj novi modal:

```html
<!-- FIFO Remainder Distribution Modal -->
<div class="select-popup-overlay" id="fifoRemainderModal">
  <div class="select-popup" style="max-width: 550px;">
    <div class="select-popup-header">
      <h3>📦 Raspodjela ostatka po slojevima</h3>
      <button class="select-popup-close" onclick="closeModal('fifoRemainderModal')">×</button>
    </div>
    <div class="select-popup-body" id="fifoRemainderBody">
      <!-- dynamically populated -->
    </div>
    <div class="select-popup-footer">
      <button class="btn btn-secondary" onclick="closeModal('fifoRemainderModal')">Odustani</button>
      <button class="btn btn-primary" onclick="fifoRemainderConfirm()">Nastavi →</button>
    </div>
  </div>
</div>
```

**Napomena:** U tuber-materijal.html trenutno se koristi klasa `select-popup-overlay` — provjeri je li definirana (trebala bi biti, u liniji 562-579 postoji `#selectPopup`). Ako nije, koristi klasu `.modal` umjesto.

#### 2c. Dodaj FIFO state + funkcije (JavaScript)

Na kraj script bloka (oko linije 2619, prije `</script>`), dodaj:

```javascript
// ============================================
// FIFO MODE (novi način skidanja - beta)
// ============================================

var fifoState = {
  active: false,
  article: null,              // prod_articles row
  hasPrinting: false,
  popIds: [],
  scanned: { 1: [], 2: [], 3: [], 4: [] }  // {code, fullyConsumed, resolved: {roll, isPlaceholder, placeholderSource}}
};

async function toggleFifoMode() {
  var isOn = document.getElementById('fifoModeToggle').checked;
  fifoState.active = isOn;
  document.getElementById('fifoSection').style.display = isOn ? 'block' : 'none';
  document.getElementById('legacySection').style.display = isOn ? 'none' : 'block';

  if (isOn && !fifoState.article) {
    await fifoInit();
  }
}

async function fifoInit() {
  // Dohvati artikl + has_printing status + pop_ids
  if (!materijalKontekst || !materijalKontekst.articleId) {
    document.getElementById('fifoHeaderContent').innerHTML = '<span style="color:#d32f2f;">⚠️ Nema materijalKontekst.articleId - otvori tuber-materijal iz tuber modula.</span>';
    return;
  }

  try {
    // Artikl
    var articles = await SB.select('prod_articles', {
      eq: { id: materijalKontekst.articleId },
      single: true
    });
    fifoState.article = articles;

    // Printing check
    fifoState.hasPrinting = await SB.rpc('wo_has_printing',
      { p_wo_number: materijalKontekst.workOrderNumber }, { silent: true }) || false;

    // POP IDs (ako je tip 'nalog' ili 'smjena')
    fifoState.popIds = materijalKontekst.popIds || [];

    // Render
    fifoRenderHeader();
    fifoRenderLayers();
  } catch (e) {
    console.error('fifoInit greška:', e);
    document.getElementById('fifoHeaderContent').innerHTML = '<span style="color:#d32f2f;">Greška: ' + e.message + '</span>';
  }
}

function fifoRenderHeader() {
  var a = fifoState.article;
  var h = '<div style="display:grid; grid-template-columns: 1fr 1fr; gap: 8px; font-size:14px;">';
  h += '<div><strong>RN:</strong> ' + (materijalKontekst.workOrderNumber || '-') + '</div>';
  h += '<div><strong>Linija:</strong> ' + (materijalKontekst.linija || '-') + '</div>';
  h += '<div style="grid-column:1/3;"><strong>Artikl:</strong> ' + (a.name || '-') + ' (' + (a.code || '-') + ')</div>';
  h += '<div><strong>POP proizvedeno:</strong> ' + (materijalKontekst.proizvedenoPOP || 0).toLocaleString('hr-HR') + '</div>';
  h += '<div><strong>REZ:</strong> ' + (materijalKontekst.rez || '-') + '</div>';
  h += '</div>';
  document.getElementById('fifoHeaderContent').innerHTML = h;

  document.getElementById('fifoPrintingBanner').style.display = fifoState.hasPrinting ? 'block' : 'none';
}

function fifoRenderLayers() {
  var html = '';
  var a = fifoState.article;
  for (var s = 1; s <= 4; s++) {
    var code = a['paper_s' + s + '_code'];
    if (!code) continue;

    // Folija - preskoči
    if (code.charAt(0).toUpperCase() === 'F') {
      html += '<div style="background:#fff; border:1px dashed #ccc; padding:10px; border-radius:6px; margin-bottom:10px; color:#999;">';
      html += '<strong>SLOJ ' + s + ':</strong> ' + code + ' <em>(folija - preskačem, ne trebaš skidati)</em>';
      html += '</div>';
      continue;
    }

    var width = a['paper_s' + s + '_width'] || '-';
    var gram = a['paper_s' + s + '_grammage'] || '-';
    var bojaLabel = code.charAt(0).toUpperCase() === 'B' ? '⚪ Bijeli' : (code.charAt(0).toUpperCase() === 'S' ? '🟫 Smeđi' : code.charAt(0));

    html += '<div style="background:#fff; border:1px solid #e0e0e0; padding:12px; border-radius:6px; margin-bottom:12px;" data-layer="' + s + '">';
    html += '<div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;">';
    html += '<div><strong>SLOJ ' + s + ':</strong> ' + code + ' <span style="color:#666;">(' + bojaLabel + ', ' + gram + 'g, ' + width + 'cm)</span>';
    if (s === 1 && fifoState.hasPrinting) html += ' <span style="background:#1976d2;color:white;padding:2px 8px;border-radius:3px;font-size:0.75em;margin-left:6px;">🖨️ OTISAK</span>';
    html += '</div></div>';

    // Input za skeniranje
    html += '<div style="display:flex; gap:8px; margin-bottom:10px;">';
    html += '<input type="text" placeholder="Skeniraj/unesi šifru role" class="form-control" style="flex:1;" id="fifoInput_' + s + '" onkeydown="if(event.key===\'Enter\') fifoScanRoll(' + s + ')">';
    html += '<button class="btn btn-primary btn-sm" onclick="fifoScanRoll(' + s + ')">+ Dodaj</button>';
    html += '</div>';

    // Lista skeniranih
    html += '<div id="fifoList_' + s + '"></div>';
    html += '</div>';
  }
  document.getElementById('fifoLayers').innerHTML = html;

  // Re-render liste iz fifoState.scanned
  for (var s = 1; s <= 4; s++) fifoRenderList(s);
}

function fifoRenderList(layer) {
  var items = fifoState.scanned[layer] || [];
  var container = document.getElementById('fifoList_' + layer);
  if (!container) return;

  if (items.length === 0) {
    container.innerHTML = '<div style="color:#999; font-style:italic; padding:4px;">Nema skeniranih rola za ovaj sloj</div>';
    return;
  }

  var html = '';
  items.forEach(function(item, idx) {
    var bgColor = item.resolved.isPlaceholder ? '#fff3e0' : '#f5f5f5';
    var iconColor = item.resolved.isPlaceholder ? '⚠️' : (item.fullyConsumed ? '✓' : '◐');
    var weight = item.resolved.isPlaceholder
      ? '(placeholder - posuđuje iz ' + (item.resolved.placeholderSource && item.resolved.placeholderSource.roll_code || 'FIFO') + ')'
      : (parseFloat(item.resolved.roll && item.resolved.roll.remaining_kg) || 0).toFixed(1) + ' kg';

    html += '<div style="background:' + bgColor + '; padding:8px 10px; border-radius:4px; margin-bottom:4px; display:flex; justify-content:space-between; align-items:center;">';
    html += '<div>' + iconColor + ' <strong>' + item.code + '</strong> — ' + weight + '</div>';
    html += '<div style="display:flex; gap:10px; align-items:center;">';
    if (!item.resolved.isPlaceholder) {
      html += '<label style="font-size:13px; cursor:pointer;"><input type="checkbox"' + (item.fullyConsumed ? '' : ' checked') + ' onchange="fifoToggleConsumed(' + layer + ',' + idx + ')"> nije potpuno potrošena</label>';
    }
    html += '<button onclick="fifoRemoveRoll(' + layer + ',' + idx + ')" style="background:none;border:none;cursor:pointer;color:#d32f2f;">🗑️</button>';
    html += '</div></div>';
  });
  container.innerHTML = html;
}

async function fifoScanRoll(layer) {
  var input = document.getElementById('fifoInput_' + layer);
  var code = (input.value || '').trim();
  if (!code) return;
  input.value = '';

  var paperCode = fifoState.article['paper_s' + layer + '_code'];
  var resolved = await TuberFifo._resolveScannedRoll(code, paperCode);

  fifoState.scanned[layer].push({
    code: code,
    fullyConsumed: true,  // default = da je potrošena
    resolved: resolved
  });

  fifoRenderList(layer);
  input.focus();
}

function fifoToggleConsumed(layer, index) {
  fifoState.scanned[layer][index].fullyConsumed = !fifoState.scanned[layer][index].fullyConsumed;
  fifoRenderList(layer);
}

function fifoRemoveRoll(layer, index) {
  fifoState.scanned[layer].splice(index, 1);
  fifoRenderList(layer);
}

// Remainder modal state
var fifoRemainderChoices = {};
var fifoCurrentPlan = null;
var fifoCurrentCtx = null;

async function fifoSave() {
  // Build context za TuberFifo
  var ctx = {
    workOrderId: materijalKontekst.workOrderId,
    workOrderNumber: materijalKontekst.workOrderNumber,
    articleId: materijalKontekst.articleId,
    article: fifoState.article,
    articleName: materijalKontekst.articleName,
    popProduced: materijalKontekst.proizvedenoPOP || 0,
    rez: materijalKontekst.rez || 0,
    productionLine: materijalKontekst.linija,
    shiftDate: getProductionDate ? getProductionDate() : new Date().toISOString().split('T')[0],
    operator: (typeof Auth !== 'undefined' && Auth.getUser && Auth.getUser().name) || 'Operator',
    tip: materijalKontekst.tip || 'nalog',
    popIds: fifoState.popIds,
    paperCodes: {
      1: fifoState.article.paper_s1_code,
      2: fifoState.article.paper_s2_code,
      3: fifoState.article.paper_s3_code,
      4: fifoState.article.paper_s4_code
    },
    scannedRolls: fifoState.scanned
  };

  try {
    if (typeof showLoading === 'function') showLoading('Računam FIFO plan...');
    var plan = await TuberFifo.computePlan(ctx);
    if (typeof hideLoading === 'function') hideLoading();

    // Preview warnings (short summary)
    var warnings = [];
    Object.keys(plan.layers).forEach(function(k) {
      var L = plan.layers[k];
      if (L.warning) warnings.push('Sloj ' + k + ': ' + L.warning);
    });
    if (warnings.length > 0 && !confirm('Upozorenja:\n- ' + warnings.join('\n- ') + '\n\nNastaviti?')) return;

    // Ako treba raspodjela ostatka, pokaži modal
    if (plan.needsRemainderChoice) {
      fifoCurrentPlan = plan;
      fifoCurrentCtx = ctx;
      fifoShowRemainderModal(plan);
      return; // nastavlja se u fifoRemainderConfirm()
    }

    // Izvrši direktno
    await fifoExecuteFinal(ctx, plan, {});
  } catch (e) {
    if (typeof hideLoading === 'function') hideLoading();
    console.error('fifoSave:', e);
    showMessage('Greška: ' + e.message, 'error');
  }
}

function fifoShowRemainderModal(plan) {
  var html = '<p style="color:#666; margin-bottom:15px;">Neki slojevi imaju više rola koje nisu potpuno potrošene. Odaberi na koju rolu ide ostatak:</p>';

  Object.keys(plan.layers).forEach(function(k) {
    var L = plan.layers[k];
    if (L.unmarkedCount <= 1 || L.remainder <= 0.01) return;

    html += '<div style="background:#f5f5f5; padding:12px; border-radius:6px; margin-bottom:10px;">';
    html += '<strong>Sloj ' + k + '</strong> — ostatak: <strong>' + L.remainder.toFixed(1) + ' kg</strong>';
    html += '<div style="margin-top:8px;">';
    L.scannedResolved.forEach(function(r) {
      if (r.fullyConsumed || r.isPlaceholder || !r.roll) return;
      html += '<label style="display:block; padding:4px 0; cursor:pointer;">';
      html += '<input type="radio" name="remainder_' + k + '" value="' + r.roll.id + '" onchange="fifoRemainderChoose(' + k + ',\'' + r.roll.id + '\')"> ';
      html += r.roll.roll_code + ' (' + (parseFloat(r.roll.remaining_kg) || 0).toFixed(1) + ' kg)';
      html += '</label>';
    });
    html += '</div></div>';
  });

  document.getElementById('fifoRemainderBody').innerHTML = html;
  openModal('fifoRemainderModal');
}

function fifoRemainderChoose(layer, rollId) {
  fifoRemainderChoices[layer] = rollId;
}

async function fifoRemainderConfirm() {
  // Provjeri da je izabrano za sve koji trebaju
  var missing = [];
  Object.keys(fifoCurrentPlan.layers).forEach(function(k) {
    var L = fifoCurrentPlan.layers[k];
    if (L.unmarkedCount > 1 && L.remainder > 0.01 && !fifoRemainderChoices[k]) {
      missing.push(k);
    }
  });
  if (missing.length > 0) {
    alert('Odaberi rolu za slojeve: ' + missing.join(', '));
    return;
  }

  closeModal('fifoRemainderModal');
  await fifoExecuteFinal(fifoCurrentCtx, fifoCurrentPlan, fifoRemainderChoices);
}

async function fifoExecuteFinal(ctx, plan, remainderAssignments) {
  try {
    if (typeof showLoading === 'function') showLoading('Spremanje FIFO skidanja...');
    var result = await TuberFifo.executePlan(ctx, plan, remainderAssignments);
    if (typeof hideLoading === 'function') hideLoading();

    if (result.errors && result.errors.length > 0) {
      console.error('FIFO errors:', result.errors);
      showMessage('⚠️ ' + result.errors.length + ' grešaka — provjeri console. Uspjelo: ' + result.successCount + ' slojeva.', 'warning');
    } else {
      showMessage('✅ FIFO skidanje spremljeno (' + result.successCount + ' slojeva)', 'success');
    }

    // Reset state
    fifoState.scanned = { 1: [], 2: [], 3: [], 4: [] };
    fifoRemainderChoices = {};

    // Povratak u tuber
    setTimeout(function() {
      if (typeof natragSaSpremanjem === 'function') natragSaSpremanjem();
    }, 1500);
  } catch (e) {
    if (typeof hideLoading === 'function') hideLoading();
    console.error('fifoExecuteFinal:', e);
    showMessage('Greška: ' + e.message, 'error');
  }
}

// Window exports za onclick handlere
window.toggleFifoMode = toggleFifoMode;
window.fifoScanRoll = fifoScanRoll;
window.fifoToggleConsumed = fifoToggleConsumed;
window.fifoRemoveRoll = fifoRemoveRoll;
window.fifoSave = fifoSave;
window.fifoRemainderChoose = fifoRemainderChoose;
window.fifoRemainderConfirm = fifoRemainderConfirm;
```

---

## 🧪 Test scenariji (ručni, u browseru)

Pokreni CARTA ERP, otvori tuber, završi smjenu/nalog → ulaziš u tuber-materijal.

### Test 1: Toggle smoke test
- ✅ Vidim narančastu traku "🧪 Novi FIFO način (beta)" na vrhu
- ✅ Checkbox OFF = stari UI vidljiv, novi skriven
- ✅ Checkbox ON = novi UI vidljiv, stari skriven

### Test 2: Inicijalizacija
- Toggle ON
- ✅ Header pokazuje RN/Linija/Artikl/POP/REZ
- ✅ Ako RN ima tisak — vidim plavi banner "Ovaj RN koristi otisnuti papir"
- ✅ Slojevi se prikazuju (folija s prefixom F se preskače s info porukom)

### Test 3: Skeniranje postojeće role
- U SLOJ 1 input unesi postojeću šifru (npr. `22034256220293`)
- Enter ili klik "+ Dodaj"
- ✅ Red se prikaže s ✓ oznakom, weight_kg
- ✅ Checkbox "nije potpuno potrošena" (default: checked=false, rola je potrošena)

### Test 4: Skeniranje nepoznate šifre (placeholder)
- Unesi `TEST99999`
- ✅ Red s ⚠️ oznakom
- ✅ Poruka "placeholder - posuđuje iz {šifra FIFO izvora}"

### Test 5: Uklanjanje role
- 🗑️ gumb uz rolu
- ✅ Red nestaje iz liste

### Test 6: Puni flow - 1 rola potpuno potrošena
- Skeni 1 rolu
- Ostavi checkbox UNCHECKED (potpuno potrošena)
- Klik "💾 Spremi (FIFO)"
- ✅ showMessage "FIFO skidanje spremljeno"
- ✅ U bazi: prod_inventory_rolls.consumed_kg = initial_weight, status = 'Utrošena'
- ✅ U bazi: prod_inventory_consumed_rolls ima zapis s type='full'

### Test 7: Puni flow - 2 role, modal za ostatak
- Skeni 2 role, OBIMA označi "nije potpuno" (checkbox checked)
- Klik Spremi
- ✅ Pokaže se modal "Raspodjela ostatka" s radio gumbima
- Odaberi jednu rolu, klik "Nastavi"
- ✅ Spremanje, druga rola dobiva novi consumed_kg

### Test 8: Placeholder fail-safe
- U prethodnom testu unio si `TEST99999` kao placeholder
- Sada u Supabase Dashboard-u (ili rezac modul) unesi novu rolu s roll_code='TEST99999'
- ✅ Trigger fired: placeholder resolved, kg vraćeni u source rolu, dodijeljeni novoj

### Test 9: Backward compat
- Toggle OFF
- ✅ Postojeći UI radi kao prije
- ✅ Postojeći spremiSkidanje i dalje sprema

---

## 📁 Datoteke za reference (read-only)

- `views/proizvodnja/tuber-materijal.html` — TARGET fajl za izmjene
- `js/tuber-fifo.js` — library koju koristimo (TuberFifo namespace)
- `js/supabase-helpers.js` — SB wrapper
- `sql/tuber_fifo_placeholder.sql` — DB migration (već primijenjena)
- `CLAUDE.md` — project guide (pravila, konvencije)
- `ANALIZA.md` — trenutni flow dijagnostika

---

## 🚨 Rollback

Ako novi FIFO UI ima bug u produkciji:
1. Otvori `tuber-materijal.html`
2. Na dnu, u funkciji `toggleFifoMode()` prvog reda dodaj: `return; // DISABLED`
3. Commit & push → sljedeći hard reload disable-a FIFO opciju
4. Postojeći stari flow neće nikad ući u FIFO granu

Nema DB rollback potreban — FIFO DB objekti (placeholder tablica + RPC-ovi) su dodatni i ne utječu na postojeći flow.

---

## ✅ Checklist za executing session

Kad krene sljedeća sesija:

- [ ] Pročitati ovaj plan
- [ ] Provjeriti MCP connection + read-only status
- [ ] Read `tuber-materijal.html` linije 491-559 (body), 693-920 (init), 2619 (kraj script)
- [ ] Read `js/tuber-fifo.js` (za signaturu funkcija)
- [ ] Read `index.html` script loading order
- [ ] Dodaj `<script src="js/tuber-fifo.js"></script>` u index.html
- [ ] Wrap postojeći body u `<div id="legacySection">...</div>`
- [ ] Insert FIFO toggle + FIFO section HTML
- [ ] Insert FIFO modal HTML
- [ ] Insert FIFO JavaScript (svih ~300 linija)
- [ ] Provjeri syntax (nema brkanja kvadratnih zagrada)
- [ ] Git add + commit s porukom `feat(tuber-materijal): add FIFO beta mode (toggle, scan-only UI)`
- [ ] Push
- [ ] Reci korisniku da napravi hard reload + toggle ON + test scenariji 1-9
- [ ] Ako sve radi, update CLAUDE.md changelog

## 🔑 Memory tips za budući AI

1. **KRITIČNO:** Ne zamjenjivati postojeći kod, samo dodavati. Postojeća produkcija ne smije pasti.
2. `SB` wrapper baca exception na DB greške. `TuberFifo.*` koristi SB interno.
3. `materijalKontekst` je globalna varijabla iz starog flow-a — preuzmi što trebaš (workOrderId, articleId, popIds, rez, tip, proizvedenoPOP).
4. `openModal`/`closeModal` i `showMessage` su global helpers iz utils.js.
5. `getProductionDate()` iz js/utils.js vraća proizvodni datum (ne kalendarski).
6. Status vokabular: rolls koriste `'Utrošena'` (ž.r.), ostali `'Utrošeno'`. Trigger update_roll_status auto-postavi 'Utrošena' na rolls — ne šalji u UPDATE-ovima ako imaš trigger.
