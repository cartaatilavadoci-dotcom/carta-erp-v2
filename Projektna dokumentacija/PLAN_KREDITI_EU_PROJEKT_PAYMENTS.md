# Krediti modul — EU PROJEKT completion + Payment tracking

> **Za:** Sljedeću Claude Code sesiju (self-contained, bez potrebe za dodatnim kontekstom)
> **Task:** Dovršiti plan otplate za EU PROJEKT (79 rata) + dodati payment tracking UI u krediti.html
> **Pripremljeno:** 23.04.2026

---

## 🎯 Kontekst

**Što je već napravljeno (ne ponavljati):**
- Modul **Krediti** wiran u config.js + router.js + admin dozvole (commit `a0f3fbd`)
- Tablica `prod_loan_payment_schedule` kreirana (commit `ea8455d`)
- Seed za 193 rate (NP-17/14, NP-18/14, OBS COVID, OBS KRIZA, PREPRINT kompletno + EU PROJEKT prvih 36 rata do 30.04.2028)
- Novi zapis NP-18/14 (UUID `aaaaaaaa-1814-0000-0000-000000000000`)
- PDF skenovi su u `Plan_otplate_scan/` (gitignore-ano)
- `views/upravljanje/krediti.html` postoji (858 linija) ali **NE ČITA** `prod_loan_payment_schedule`

**Što treba napraviti:**
1. **EU PROJEKT — 79 preostalih rata** (od 31.05.2028 do 31.12.2034) u SQL seed fajl
2. **Payment tracking UI** u `krediti.html` — lista rata, checkbox "plaćeno", modal za unos plaćenog iznosa

---

## 📋 ZADATAK 1: EU PROJEKT rate 101-180

### Pristup

Kreirati **drugi** SQL fajl `sql/loan_payment_schedule_eu_projekt_full.sql` (ne modificirati postojeći seed). Sadrži samo INSERT-e za EU PROJEKT red.br. 101-180. UUID: `56eb7fcc-795f-4268-b851-de6bfdaabc35`. ON CONFLICT DO NOTHING za idempotentnost.

### Podaci iz PDF-a (već pročitani, transkribirani iz Plan_otplate_scan/EU PROJEKT.pdf str 2-4)

Svi retci: `redni_br, datum, rata_total_eur, kamate_eur, porez=0, otplatna=13096.23 (osim zadnjih 2), ostatak_duga`

**2028 (8 rata, od row 101):**

```
101 | 2028-05-31 | 14810.38 | 1714.15 | 0 | 13096.23 | 1034601.70
102 | 2028-06-30 | 14734.35 | 1638.12 | 0 | 13096.23 | 1021505.47
103 | 2028-07-31 | 14767.53 | 1671.30 | 0 | 13096.23 | 1008409.24
104 | 2028-08-31 | 14746.10 | 1649.87 | 0 | 13096.23 |  995313.01
105 | 2028-09-30 | 14672.14 | 1575.91 | 0 | 13096.23 |  982216.78
106 | 2028-10-31 | 14630.67 | 1534.44 | 0 | 13096.23 |  969120.55
107 | 2028-11-30 | 14660.39 | 1564.16 | 0 | 13096.23 |  956024.32
108 | 2028-12-31 | 14638.97 | 1542.74 | 0 | 13096.23 |  942928.09
```

**2029 (12 rata):**

```
109 | 2029-01-31 | 14470.31 | 1374.08 | 0 | 13096.23 |  929831.86
110 | 2029-02-28 | 14596.11 | 1499.88 | 0 | 13096.23 |  916735.63
111 | 2029-03-31 | 14526.99 | 1430.76 | 0 | 13096.23 |  903639.40
112 | 2029-04-30 | 14553.26 | 1457.03 | 0 | 13096.23 |  890543.17
113 | 2029-05-31 | 14485.52 | 1389.29 | 0 | 13096.23 |  877446.94
114 | 2029-06-30 | 14510.40 | 1414.17 | 0 | 13096.23 |  864350.71
115 | 2029-07-31 | 14488.98 | 1392.75 | 0 | 13096.23 |  851254.48
116 | 2029-08-31 | 14423.31 | 1327.08 | 0 | 13096.23 |  838158.25
117 | 2029-09-30 | 14446.12 | 1349.89 | 0 | 13096.23 |  825062.02
118 | 2029-10-31 | 14381.84 | 1285.61 | 0 | 13096.23 |  811965.79
119 | 2029-11-30 | 14403.27 | 1307.04 | 0 | 13096.23 |  798869.56
120 | 2029-12-31 | 14381.84 | 1285.61 | 0 | 13096.23 |  785773.33
```

**2030 (12 rata):**

```
121 | 2030-01-31 | 14238.08 | 1141.85 | 0 | 13096.23 |  772677.10
122 | 2030-02-28 | 14338.99 | 1242.76 | 0 | 13096.23 |  759580.87
123 | 2030-03-31 | 14278.16 | 1181.93 | 0 | 13096.23 |  746484.64
124 | 2030-04-30 | 14296.13 | 1199.90 | 0 | 13096.23 |  733388.41
125 | 2030-05-31 | 14236.69 | 1140.46 | 0 | 13096.23 |  720292.18
126 | 2030-06-30 | 14253.28 | 1157.05 | 0 | 13096.23 |  707195.95
127 | 2030-07-31 | 14231.85 | 1135.62 | 0 | 13096.23 |  694099.72
128 | 2030-08-31 | 14174.49 | 1078.26 | 0 | 13096.23 |  681003.49
129 | 2030-09-30 | 14189.00 | 1092.77 | 0 | 13096.23 |  667907.26
130 | 2030-10-31 | 14133.01 | 1036.78 | 0 | 13096.23 |  654811.03
131 | 2030-11-30 | 14146.15 | 1049.92 | 0 | 13096.23 |  641714.80
132 | 2030-12-31 | 14124.72 | 1028.49 | 0 | 13096.23 |  628618.57
```

**2031 (12 rata):**

```
133 | 2031-01-31 | 14005.84 |  909.61 | 0 | 13096.23 |  615522.34
134 | 2031-02-28 | 14081.87 |  985.64 | 0 | 13096.23 |  602426.11
135 | 2031-03-31 | 14029.34 |  933.11 | 0 | 13096.23 |  589329.88
136 | 2031-04-30 | 14039.01 |  942.78 | 0 | 13096.23 |  576233.65
137 | 2031-05-31 | 13987.86 |  891.63 | 0 | 13096.23 |  563137.42
138 | 2031-06-30 | 13996.16 |  899.93 | 0 | 13096.23 |  550041.19
139 | 2031-07-31 | 13974.73 |  878.50 | 0 | 13096.23 |  536944.96
140 | 2031-08-31 | 13925.66 |  829.43 | 0 | 13096.23 |  523848.73
141 | 2031-09-30 | 13931.88 |  835.65 | 0 | 13096.23 |  510752.50
142 | 2031-10-31 | 13884.19 |  787.96 | 0 | 13096.23 |  497656.27
143 | 2031-11-30 | 13889.02 |  792.79 | 0 | 13096.23 |  484560.04
144 | 2031-12-31 | 13867.60 |  771.37 | 0 | 13096.23 |  471463.81
```

**2032 (12 rata):**

```
145 | 2032-01-31 | 13797.79 |  701.56 | 0 | 13096.23 |  458367.58
146 | 2032-02-29 | 13824.74 |  728.51 | 0 | 13096.23 |  445271.35
147 | 2032-03-31 | 13780.51 |  684.28 | 0 | 13096.23 |  432175.12
148 | 2032-04-30 | 13781.89 |  685.66 | 0 | 13096.23 |  419078.89
149 | 2032-05-31 | 13739.04 |  642.81 | 0 | 13096.23 |  405982.66
150 | 2032-06-30 | 13739.04 |  642.81 | 0 | 13096.23 |  392886.43
151 | 2032-07-31 | 13717.61 |  621.38 | 0 | 13096.23 |  379790.20
152 | 2032-08-31 | 13676.83 |  580.60 | 0 | 13096.23 |  366693.97
153 | 2032-09-30 | 13674.76 |  578.53 | 0 | 13096.23 |  353597.74
154 | 2032-10-31 | 13635.36 |  539.13 | 0 | 13096.23 |  340501.51
155 | 2032-11-30 | 13631.90 |  535.67 | 0 | 13096.23 |  327405.28
156 | 2032-12-31 | 13610.47 |  514.24 | 0 | 13096.23 |  314309.05
```

**2033 (12 rata):**

```
157 | 2033-01-31 | 13541.36 |  445.13 | 0 | 13096.23 |  301212.82
158 | 2033-02-28 | 13567.62 |  471.39 | 0 | 13096.23 |  288116.59
159 | 2033-03-31 | 13531.68 |  435.45 | 0 | 13096.23 |  275020.36
160 | 2033-04-30 | 13524.77 |  428.54 | 0 | 13096.23 |  261924.13
161 | 2033-05-31 | 13490.21 |  393.98 | 0 | 13096.23 |  248827.90
162 | 2033-06-30 | 13481.91 |  385.68 | 0 | 13096.23 |  235731.67
163 | 2033-07-31 | 13460.49 |  364.26 | 0 | 13096.23 |  222635.44
164 | 2033-08-31 | 13428.00 |  331.77 | 0 | 13096.23 |  209539.21
165 | 2033-09-30 | 13417.63 |  321.40 | 0 | 13096.23 |  196442.98
166 | 2033-10-31 | 13386.53 |  290.30 | 0 | 13096.23 |  183346.75
167 | 2033-11-30 | 13374.78 |  278.55 | 0 | 13096.23 |  170250.52
168 | 2033-12-31 | 13353.35 |  257.12 | 0 | 13096.23 |  157154.29
```

**2034 (11 rata, završava 31.12.2034):**

```
169 | 2034-01-31 | 13309.12 |  212.89 | 0 | 13096.23 |  144058.06
170 | 2034-02-28 | 13310.50 |  214.27 | 0 | 13096.23 |  130961.83
171 | 2034-03-31 | 13282.85 |  186.62 | 0 | 13096.23 |  117865.60
172 | 2034-04-30 | 13267.64 |  171.41 | 0 | 13096.23 |  104769.37
173 | 2034-05-31 | 13241.38 |  145.15 | 0 | 13096.23 |   91673.14
174 | 2034-06-30 | 13224.79 |  128.56 | 0 | 13096.23 |   78576.91
175 | 2034-07-31 | 13224.79 |  128.56 | 0 | 13096.23 |   65480.68
176 | 2034-08-31 | 13179.17 |   82.94 | 0 | 13096.23 |   52384.45   ← PDF pokazuje 39.288,22 ovdje, PROVJERITI!
177 | 2034-09-30 | 13179.17 |   82.94 | 0 | 13096.23 |   39288.22
178 | 2034-10-31 | 13160.51 |   64.28 | 0 | 13096.23 |   26191.99
179 | 2034-11-30 | 13137.70 |   41.47 | 0 | 13095.76 |   13095.76   ← otplata 13095.76 (ne 13096.23)
180 | 2034-12-31 | 13117.19 |   21.43 | 0 | 13095.76 |       0.00   ← završna rata
```

**⚠️ Napomena 1:** Iz PDF-a str 3 (zadnji vidljivi redak "31.07.2034 ... 65.480,68 EUR") i str 4 (prvi vidljivi "3. 30.09.2034 ... 39.288,22 EUR") — nedostaje jedan red između. Vjerojatno 31.08.2034 s ostatkom 52.384,45 EUR. **Potrebno potvrditi s korisnikom prije commitanja** ili regenerirati iz same formule.

**⚠️ Napomena 2:** Zadnja 2 reda (179, 180) imaju otplatnu kvotu 13.095,76 umjesto 13.096,23 — zaokruživanje na kraju (ukupna zaduženost bila je 2.024.070,46 = 13.096,23 × 154 + 13.095,76 × 2 otprilike, razlika se pretvara u nekoliko kunica manje u zadnjih 2 rata).

### SQL template

```sql
-- ============================================================
-- EU PROJEKT - preostale 79 rata (2028-05 do 2034-12)
-- Dopuna na sql/loan_payment_schedule.sql
-- ============================================================

INSERT INTO prod_loan_payment_schedule
  (loan_id, redni_br, datum_dospijeca, rata_total_eur, kamate_eur, porez_na_kamate_eur, otplatna_kvota_eur, ostatak_duga_eur)
VALUES
  ('56eb7fcc-795f-4268-b851-de6bfdaabc35', 101, '2028-05-31', 14810.38, 1714.15, 0, 13096.23, 1034601.70),
  -- ... popuniti iz tabele gore ...
  ('56eb7fcc-795f-4268-b851-de6bfdaabc35', 180, '2034-12-31', 13117.19, 21.43, 0, 13095.76, 0.00)
ON CONFLICT (loan_id, datum_dospijeca) DO NOTHING;

-- Verifikacija
SELECT COUNT(*) AS ukupno_rata,
       MIN(datum_dospijeca) AS prva,
       MAX(datum_dospijeca) AS zadnja,
       ROUND(SUM(rata_total_eur)::numeric, 2) AS ukupno_eur
FROM prod_loan_payment_schedule
WHERE loan_id = '56eb7fcc-795f-4268-b851-de6bfdaabc35';
-- Očekivano: 115 rata, od 2025-05-31 do 2034-12-31, ukupno ~1.777.000 EUR
```

### Checklist ZADATAK 1

- [ ] Kreirati `sql/loan_payment_schedule_eu_projekt_full.sql`
- [ ] Copy-paste sve 79 redova iz tabele gore (pažljivo s row 176!)
- [ ] Provjeriti s korisnikom row 176 vrijednost (inače PDF potrebno ponovno čitati str 3-4)
- [ ] Commit + push
- [ ] Reći korisniku da pokrene u Supabase Dashboard SQL Editoru
- [ ] Verifikacija: HBOR-EU mora imati 115 rata (36 iz prvog seed-a + 79 novih)

---

## 📋 ZADATAK 2: Payment Tracking UI

### Context

`krediti.html` (858 linija) trenutno **ne čita** `prod_loan_payment_schedule`. Treba mu dodati:
- Tablica rata za odabrani kredit (sortirana po datumu)
- Checkbox "plaćeno" po retku
- Modal za unos stvarnog plaćenog iznosa + datuma
- Update u bazu: `placeno=true, placeno_datum, placeno_iznos_eur, napomena`
- Vizualno označiti "plaćeno" zeleno, "prekoračeno" crveno, "dospijeva u 7 dana" narančasto

### UX Wireframe

```
┌─────────────────────────────────────────────────────────────┐
│ 🏦 Krediti — pregled                                        │
├─────────────────────────────────────────────────────────────┤
│ [KPI kartice: ukupno kredita, mjesečna rata, dug]          │
│                                                              │
│ [ Timeline / tablica kredita s klikabilnim redovima ]       │
│                                                              │
│ ┌── Kad se klikne na kredit ────────────────────────────┐  │
│ │ 🏦 EU PROJEKT - Plan otplate (115 rata)              │  │
│ │                                                       │  │
│ │ Filter: [ ☑ Sve  ☐ Neplaćene  ☐ Plaćene ]           │  │
│ │                                                       │  │
│ │ ┌─────┬────────────┬──────────┬──────────┬────────┐ │  │
│ │ │  #  │ Datum      │ Rata     │ Ostatak  │ Status │ │  │
│ │ ├─────┼────────────┼──────────┼──────────┼────────┤ │  │
│ │ │ 65  │ 31.05.2025 │15.581,75 │ 1.506.065│✓ plaće.│ │  │
│ │ │ 66  │ 30.06.2025 │15.480,83 │ 1.492.969│✓ plaće.│ │  │
│ │ │ ... │    ...     │   ...    │   ...    │  ...   │ │  │
│ │ │ 77  │ 31.05.2026 │15.324,63 │ 1.348.911│⚠ 7 dana│ │  │
│ │ │ 78  │ 30.06.2026 │15.232,01 │ 1.335.814│  ·     │ │  │
│ │ └─────┴────────────┴──────────┴──────────┴────────┘ │  │
│ │                                                       │  │
│ │ Klik na red → modal "Označi kao plaćeno":            │  │
│ │   • Datum plaćanja: [datepicker, default = danas]    │  │
│ │   • Plaćeni iznos: [input, default = rata]           │  │
│ │   • Napomena: [textarea]                             │  │
│ │   [Odustani] [💾 Spremi]                             │  │
│ └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Logika označavanja statusa

| Status | Uvjet | Boja |
|--------|-------|------|
| ✓ Plaćeno | `placeno = true` | Zelena (`#4caf50`) |
| ⚠ Dospijeva uskoro | `placeno=false` AND `datum ≤ danas+7d` AND `datum ≥ danas` | Narančasta (`#ff9800`) |
| 🔴 Prekoračeno | `placeno=false` AND `datum < danas` | Crvena (`#f44336`) |
| · Buduće | `placeno=false` AND `datum > danas+7d` | Neutralna (sivo) |

### Implementation Skeleton

**Korak 1:** Dodati sekciju u `krediti.html` (unutar postojećeg layout-a, nakon KPI kartica):

```html
<!-- Plan otplate - prikazuje se kad korisnik klikne na kredit -->
<div id="loanScheduleSection" style="display:none; margin-top:20px;">
  <div class="card">
    <div class="card-header" style="display:flex;justify-content:space-between;align-items:center;">
      <h3 style="margin:0;">📅 Plan otplate — <span id="scheduleLoanName"></span></h3>
      <div>
        <label><input type="radio" name="scheduleFilter" value="all" checked onchange="renderSchedule()"> Sve</label>
        <label style="margin-left:10px;"><input type="radio" name="scheduleFilter" value="unpaid" onchange="renderSchedule()"> Neplaćene</label>
        <label style="margin-left:10px;"><input type="radio" name="scheduleFilter" value="paid" onchange="renderSchedule()"> Plaćene</label>
      </div>
    </div>
    <div class="card-body" style="padding:0;">
      <div style="max-height:500px;overflow-y:auto;">
        <table style="width:100%;border-collapse:collapse;font-size:13px;">
          <thead style="position:sticky;top:0;background:#f5f5f5;">
            <tr>
              <th style="padding:8px;text-align:right;">#</th>
              <th style="padding:8px;">Datum</th>
              <th style="padding:8px;text-align:right;">Rata</th>
              <th style="padding:8px;text-align:right;">Kamate</th>
              <th style="padding:8px;text-align:right;">Glavnica</th>
              <th style="padding:8px;text-align:right;">Ostatak</th>
              <th style="padding:8px;">Status</th>
              <th style="padding:8px;"></th>
            </tr>
          </thead>
          <tbody id="scheduleTableBody">
            <tr><td colspan="8" style="padding:20px;text-align:center;color:#999;">Odaberi kredit da vidiš plan otplate</td></tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</div>

<!-- Modal za označiti plaćeno -->
<div id="markPaidModal" class="modal" style="display:none;">
  <div class="modal-content" style="max-width:450px;">
    <div class="modal-header">
      <h3>💰 Označi ratu kao plaćenu</h3>
      <span class="modal-close" onclick="closeModal('markPaidModal')">×</span>
    </div>
    <div class="modal-body">
      <div id="markPaidInfo" style="background:#f5f5f5;padding:10px;border-radius:6px;margin-bottom:15px;"></div>
      <div class="form-group">
        <label>Datum plaćanja *</label>
        <input type="date" id="markPaidDate" class="form-control">
      </div>
      <div class="form-group">
        <label>Plaćeni iznos (EUR) *</label>
        <input type="number" step="0.01" id="markPaidAmount" class="form-control">
      </div>
      <div class="form-group">
        <label>Napomena</label>
        <textarea id="markPaidNote" class="form-control" rows="2" placeholder="opcionalno"></textarea>
      </div>
      <input type="hidden" id="markPaidScheduleId">
    </div>
    <div class="modal-actions">
      <button class="btn btn-secondary" onclick="closeModal('markPaidModal')">Odustani</button>
      <button class="btn" style="background:#f44336;color:white;" onclick="undoPayment()">Poništi plaćanje</button>
      <button class="btn btn-primary" onclick="savePayment()">💾 Spremi</button>
    </div>
  </div>
</div>
```

**Korak 2:** Dodati JS funkcije u `krediti.html` script blok:

```javascript
var currentLoanSchedule = []; // cache

async function loadLoanSchedule(loanId, loanName) {
  document.getElementById('scheduleLoanName').textContent = loanName;
  document.getElementById('loanScheduleSection').style.display = 'block';
  try {
    var data = await SB.select('prod_loan_payment_schedule', {
      eq: { loan_id: loanId },
      order: { datum_dospijeca: 'asc' },
      limit: 500
    });
    currentLoanSchedule = data || [];
    renderSchedule();
  } catch (e) {
    console.error('loadLoanSchedule:', e);
    showMessage('Greška učitavanja plana: ' + e.message, 'error');
  }
}

function renderSchedule() {
  var tbody = document.getElementById('scheduleTableBody');
  var filter = document.querySelector('input[name="scheduleFilter"]:checked').value;
  var today = new Date();
  today.setHours(0,0,0,0);
  var soon = new Date(today); soon.setDate(soon.getDate() + 7);

  var rows = currentLoanSchedule.filter(function(r) {
    if (filter === 'paid') return r.placeno;
    if (filter === 'unpaid') return !r.placeno;
    return true;
  });

  if (rows.length === 0) {
    tbody.innerHTML = '<tr><td colspan="8" style="padding:20px;text-align:center;color:#999;">Nema rata za ovaj filter</td></tr>';
    return;
  }

  var html = rows.map(function(r) {
    var datum = new Date(r.datum_dospijeca + 'T00:00:00');
    var status, bg, label;
    if (r.placeno) {
      bg = '#e8f5e9'; label = '<span style="color:#2e7d32;font-weight:600;">✓ Plaćeno</span>';
    } else if (datum < today) {
      bg = '#ffebee'; label = '<span style="color:#c62828;font-weight:600;">🔴 Prekoračeno</span>';
    } else if (datum <= soon) {
      bg = '#fff3e0'; label = '<span style="color:#e65100;font-weight:600;">⚠ Uskoro</span>';
    } else {
      bg = 'transparent'; label = '<span style="color:#999;">·</span>';
    }

    return '<tr style="background:' + bg + ';">' +
      '<td style="padding:6px;text-align:right;">' + (r.redni_br || '-') + '</td>' +
      '<td style="padding:6px;">' + datum.toLocaleDateString('hr-HR') + '</td>' +
      '<td style="padding:6px;text-align:right;"><strong>' + formatBroj(r.rata_total_eur) + '</strong></td>' +
      '<td style="padding:6px;text-align:right;color:#666;">' + formatBroj(r.kamate_eur) + '</td>' +
      '<td style="padding:6px;text-align:right;">' + formatBroj(r.otplatna_kvota_eur) + '</td>' +
      '<td style="padding:6px;text-align:right;">' + formatBroj(r.ostatak_duga_eur) + '</td>' +
      '<td style="padding:6px;">' + label + '</td>' +
      '<td style="padding:6px;"><button class="btn btn-sm btn-primary" onclick="openMarkPaidModal(\'' + r.id + '\')">' +
        (r.placeno ? '✏️' : '💰') + '</button></td>' +
    '</tr>';
  }).join('');
  tbody.innerHTML = html;
}

function formatBroj(n) {
  if (n == null) return '-';
  return parseFloat(n).toLocaleString('hr-HR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' €';
}

function openMarkPaidModal(scheduleId) {
  var row = currentLoanSchedule.find(function(r) { return r.id === scheduleId; });
  if (!row) return;

  document.getElementById('markPaidScheduleId').value = scheduleId;
  document.getElementById('markPaidDate').value = row.placeno_datum || row.datum_dospijeca;
  document.getElementById('markPaidAmount').value = row.placeno_iznos_eur || row.rata_total_eur;
  document.getElementById('markPaidNote').value = row.napomena || '';
  document.getElementById('markPaidInfo').innerHTML =
    '<strong>Rata #' + row.redni_br + '</strong> — ' + new Date(row.datum_dospijeca).toLocaleDateString('hr-HR') +
    '<br>Planirana rata: <strong>' + formatBroj(row.rata_total_eur) + '</strong>';
  openModal('markPaidModal');
}

async function savePayment() {
  var id = document.getElementById('markPaidScheduleId').value;
  var datum = document.getElementById('markPaidDate').value;
  var amount = parseFloat(document.getElementById('markPaidAmount').value);
  var note = document.getElementById('markPaidNote').value.trim();

  if (!datum || !amount) {
    showMessage('Datum i iznos su obavezni', 'warning');
    return;
  }

  try {
    await SB.update('prod_loan_payment_schedule', {
      placeno: true,
      placeno_datum: datum,
      placeno_iznos_eur: amount,
      napomena: note || null
    }, { id: id });

    closeModal('markPaidModal');
    showMessage('✅ Plaćanje spremljeno', 'success');

    // Osvježi cache + prikaz
    var row = currentLoanSchedule.find(function(r) { return r.id === id; });
    if (row) { row.placeno = true; row.placeno_datum = datum; row.placeno_iznos_eur = amount; row.napomena = note; }
    renderSchedule();
  } catch (e) {
    showMessage('Greška: ' + e.message, 'error');
  }
}

async function undoPayment() {
  if (!confirm('Poništiti zapis o plaćanju ove rate?')) return;
  var id = document.getElementById('markPaidScheduleId').value;
  try {
    await SB.update('prod_loan_payment_schedule', {
      placeno: false,
      placeno_datum: null,
      placeno_iznos_eur: null,
      napomena: null
    }, { id: id });
    closeModal('markPaidModal');
    showMessage('Plaćanje poništeno', 'success');
    var row = currentLoanSchedule.find(function(r) { return r.id === id; });
    if (row) { row.placeno = false; row.placeno_datum = null; row.placeno_iznos_eur = null; row.napomena = null; }
    renderSchedule();
  } catch (e) {
    showMessage('Greška: ' + e.message, 'error');
  }
}

// Window exports
window.loadLoanSchedule = loadLoanSchedule;
window.renderSchedule = renderSchedule;
window.openMarkPaidModal = openMarkPaidModal;
window.savePayment = savePayment;
window.undoPayment = undoPayment;
```

**Korak 3:** Integracija s postojećom tablicom kredita — svaki red kreditne tablice dobiva onclick koji zove `loadLoanSchedule(loan.id, loan.naziv)`.

Najjednostavnije: **pronaći postojeću funkciju koja renderira tablicu kredita** (vjerojatno `renderLoans` ili slično oko linije 400-600 u krediti.html) i u svakom retku dodati `onclick="loadLoanSchedule('${loan.id}','${loan.naziv}')"`.

### Checklist ZADATAK 2

- [ ] Read `views/upravljanje/krediti.html` da identificiraš postojeću strukturu
- [ ] Locirati gdje se renderira tablica kredita (trebala bi biti u JS sekciji)
- [ ] Dodati HTML za scheduleSection + markPaidModal (nakon KPI/timeline sekcije)
- [ ] Dodati JS funkcije (loadLoanSchedule, renderSchedule, openMarkPaidModal, savePayment, undoPayment)
- [ ] U postojećem render-u kredita dodati onclick na svaki red
- [ ] Provjeriti da postoji `SB`, `formatBroj`, `openModal`, `closeModal`, `showMessage` — ako ne, importirati ili aliasirati
- [ ] Commit + push
- [ ] Hard reload + test: klik na kredit → prikazuje plan → klik na red → modal → spremi → zeleno označeno

---

## 📊 KPI metrike (bonus, ako ostane vremena)

Na vrhu krediti.html dodati KPI kartice koje zbrajaju plan otplate:

```sql
-- Helper SELECT za KPI
SELECT
  COUNT(DISTINCT l.id) AS broj_aktivnih_kredita,
  ROUND(SUM(s.rata_total_eur) FILTER (WHERE NOT s.placeno)::numeric, 2) AS preostalo_za_platiti,
  ROUND(SUM(s.rata_total_eur) FILTER (WHERE NOT s.placeno AND s.datum_dospijeca <= CURRENT_DATE + 30)::numeric, 2) AS sljedecih_30_dana,
  COUNT(*) FILTER (WHERE NOT s.placeno AND s.datum_dospijeca < CURRENT_DATE) AS broj_prekoracenih_rata
FROM prod_company_loans l
LEFT JOIN prod_loan_payment_schedule s ON s.loan_id = l.id
WHERE l.status = 'Aktivan';
```

KPI kartice:
- 🏦 **Aktivni krediti** (count)
- 💰 **Preostalo za platiti** (EUR, sum svih neplaćenih rata)
- 📅 **Sljedećih 30 dana** (EUR, što dolazi na naplatu)
- 🔴 **Prekoračene rate** (broj)

---

## 🔄 Rollback plan

Ako novi UI slomi nešto u krediti.html:
- Uklonit JS funkcije (`loadLoanSchedule` etc.) — ostale postojeće funkcije rade kao prije
- Skriti scheduleSection div (`style="display:none"`)
- Stare klikabilni redovi rade kao prije (nemaju onclick)

Nema DB rollback potreban — `prod_loan_payment_schedule` ne utječe na postojeći `prod_company_loans` flow.

---

## 📝 Memory tips za budući AI

1. **SB wrapper** (`window.SB`) je u `js/supabase-helpers.js`, uključen u index.html
2. **formatBroj** postoji u `js/utils.js` — koristiti za hrvatski format brojeva
3. **openModal/closeModal** također iz utils.js, dodaje/uklanja klasu `.active` ili toggle `display`
4. **UUID konvencija:** krediti su hardkodirani UUID-ovi u SQL (vidi odjeljak iznad)
5. **RLS:** `prod_loan_payment_schedule` ima "Allow all for authenticated" — svi mogu read/write
6. **Ne dirati postojeće `prod_company_loans`** — samo čitati; novi zapis NP-18/14 je već dodan
7. **MCP može biti read-only** pri startu sesije — `--read-only` flag u `.claude.json`. Ako treba write, ukloni flag i reci korisniku da restartira Claude Code.

---

## ✅ Redoslijed izvršavanja

1. **Read** `krediti.html` (full file) da razumiješ postojeću strukturu
2. **Zadatak 1** — kreiraj EU PROJEKT SQL fajl, pitaj korisnika za row 176 (ili regeneriraj iz formule)
3. **Zadatak 2** — UI integracija (HTML + JS dodatak, ne mijenjati postojeći code)
4. **KPI bonus** — samo ako ima vremena
5. **Commit + push** (zasebni commitovi za jasnoću)
6. **Reci korisniku** da pokrene EU PROJEKT SQL u Dashboard-u i testira UI hard reloadom

## 📁 Datoteke za read-only reference

- `views/upravljanje/krediti.html` — cilj za modifikacije (858 linija)
- `sql/loan_payment_schedule.sql` — postojeći seed
- `js/supabase-helpers.js` — SB wrapper
- `js/utils.js` — openModal/closeModal/formatBroj/showMessage
- `CLAUDE.md` — pravila projekta
- `Plan_otplate_scan/EU PROJEKT.pdf` — PDF s ratama (stranice 3-4 za row 176-180 provjera)
