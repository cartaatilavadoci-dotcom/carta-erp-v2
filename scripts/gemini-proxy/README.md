# Gemini AI Proxy — Setup za CARTA-ERP ISO modul

> **Svrha:** Cloudflare Pages Function koja proxy-a pozive iz CARTA-ERP browsera prema Google Gemini API-ju.
> Atila prvo dokazuje vrijednost AI-ja s **besplatnim Gemini tier-om** prije nego dobije odobrenje uprave za plaćeni AI ([memory: AI strategy: prove cheap first](../../.claude/memory)).

## Što ovaj proxy radi

1. **Skriva API key** — Gemini key ostaje na serveru, ne u browseru
2. **Cache** — `iso_ai_outputs` tablica služi kao prompt cache (SHA-256 hash). Ponovljen poziv = 0 tokena
3. **Audit log** — svaki poziv logiran s tokens_used i duration_ms (auditor friendly)
4. **Format normalizacija** — JSON output s konzistentnim shape-om za frontend

## Free tier limiti (Gemini 2.5 Flash)

- 15 req/min
- 1.500 req/dan
- 1M tokena context

Za ISO use case (audit checklist 1× mjesečno, doc gen na zahtjev, RCA na NC) — više nego dovoljno.

## Setup koraci

### 1. Pribavi Gemini API key (besplatno)

→ <https://aistudio.google.com/apikey>
→ "Create API key" → kopiraj
→ **Sigurno!** Ne commitaj nigdje, postavi tek kao env var

### 2. Cloudflare Pages projekt

#### Opcija A — Direktan deploy preko Wrangler CLI

```bash
npm install -g wrangler
cd scripts/gemini-proxy
wrangler pages deploy . --project-name=carta-erp-ai
```

#### Opcija B — GitHub integracija

1. Cloudflare Dashboard → Workers & Pages → Create
2. Pages → Connect to Git → odaberi `carta-erp` repo
3. Build settings:
   - **Build command:** _ostavi prazno_
   - **Build output directory:** `scripts/gemini-proxy`
   - **Root directory:** ostavi prazno
4. Deploy → URL će biti `https://carta-erp-ai-XXX.pages.dev`

### 3. Env varijable u Cloudflare

Settings → Environment variables → Production:

| Naziv | Vrijednost |
|---|---|
| `GEMINI_API_KEY` | Tvoj key iz Google AI Studio |
| `SUPABASE_URL` | `https://gusudzydgofdcywmvwbh.supabase.co` |
| `SUPABASE_SERVICE_KEY` | service_role iz Supabase Dashboard → Settings → API |

⚠️ Service key bypassa RLS — drži ga sigurno.

### 4. Konfiguriraj CARTA-ERP da poziva proxy

U `index.html` dodaj prije `</body>`:

```html
<script>
  window.CONFIG = window.CONFIG || {};
  window.CONFIG.AI_PROXY_URL = 'https://carta-erp-ai-XXX.pages.dev/api/iso/gemini';
</script>
```

Ili definiraj u `js/config.js` `CONFIG` objektu (preferirano):

```js
const CONFIG = {
  // ... postojeće
  AI_PROXY_URL: 'https://carta-erp-ai-XXX.pages.dev/api/iso/gemini'
};
```

I onda u UI-u (npr. `iso-auditi.html`) provjera:

```js
const proxyUrl = (window.CONFIG && window.CONFIG.AI_PROXY_URL) || '/api/iso/gemini';
```

### 5. Test

U browseru otvori **ISO 9001 → Interni auditi**, kreiraj prvi audit, otvori detail, klikni **"Generiraj checklist (AI)"**. Trebao bi dobiti 15-20 pitanja po ISO klauzulama u par sekundi.

Provjeri u Supabase → SQL Editor:
```sql
SELECT feature, ai_model, tokens_used, duration_ms, created_at
FROM iso_ai_outputs
ORDER BY created_at DESC LIMIT 10;
```

## AI funkcije podržane

| Feature | Što radi | Gdje se koristi |
|---|---|---|
| `audit_checklist` | 15-20 pitanja po ISO klauzuli s real-time brojkama | iso/auditi.html |
| `doc_generator` | Draft procedure / uputstva | (planirano: iso/dokumenti.html) |
| `rca` | 5-Why root cause analysis | (planirano: iso/capa.html) |
| `mgmt_review` | Komentari za sve 11 sekcija OB_12 | iso/ocjena-uprave.html |

## Demo za upravu

3 konkretna trenutka koja pokazuju ROI:

1. **AI Audit Checklist** (postoji već) — 4h → 10 sekundi po procesu × 11 procesa = 44h godišnje ušteđeno
2. **AI draft procedure** — 3h → 15 sekundi po proceduri × 20 procedura/god = 40h
3. **AI Management Review** — 1 dan → 5 minuta godišnje (PUK samo verificira komentare)

**Trošak: 0 EUR** (sve unutar besplatnog Gemini tier-a).

Nakon što uprava vidi vrijednost (3-6 mjeseci), otvara se razgovor o nadogradnji na plaćeni Gemini Pro / Claude API.

## Troubleshooting

### "AI proxy nije dostupan"

- Provjeri da Cloudflare Pages projekt deployed (`wrangler pages deployment list`)
- Provjeri CORS — proxy već vraća `Access-Control-Allow-Origin: *`
- Provjeri u Cloudflare Dashboard → Functions → Logs

### "Gemini API error 429"

- Hit rate limit (15 req/min). Pričekaj 60s.
- Cache pomaže — drugi poziv s istim contextom ide iz cache-a

### "Gemini vratio invalidan JSON"

- Ponekad model vrati markdown wrapper (` ```json\n...\n``` `). Proxy strip-a ali za neke prompte može trebati dodatni regex
- Pošalji raw output u Issue, popravim prompt
