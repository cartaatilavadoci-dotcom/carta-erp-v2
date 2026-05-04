/**
 * Cloudflare Pages Function — Gemini AI Proxy za ISO 9001 modul
 *
 * Endpoint: POST /api/iso/gemini
 * Request: { feature: 'audit_checklist'|'doc_generator'|'rca'|'mgmt_review',
 *            context: {...},
 *            audit_id?: 'uuid' }
 * Response: { questions: [...] } | { content: '...' } | error
 *
 * Setup:
 * 1) Cloudflare Dashboard → Pages → Create project → tvoj GitHub repo carta-erp
 * 2) Settings → Environment variables → Add:
 *    GEMINI_API_KEY = (iz https://aistudio.google.com/apikey)
 *    SUPABASE_URL = https://gusudzydgofdcywmvwbh.supabase.co
 *    SUPABASE_SERVICE_KEY = (service_role iz Supabase dashboarda)
 * 3) Deploy. URL će biti https://carta-erp-PROJECT.pages.dev
 * 4) U index.html dodaj:
 *      window.CONFIG = window.CONFIG || {};
 *      window.CONFIG.AI_PROXY_URL = 'https://carta-erp-PROJECT.pages.dev/api/iso/gemini';
 *
 * Free tier limit: 15 req/min, 1500 req/dan (Gemini 2.5 Flash). Cache + audit log u iso_ai_outputs.
 */

const GEMINI_MODEL = 'gemini-2.5-flash';
const GEMINI_API_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

// SHA-256 hash za prompt cache key
async function hashPrompt(text) {
  const data = new TextEncoder().encode(text);
  const buf = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, '0')).join('');
}

// Provjeri cache u iso_ai_outputs (preko Supabase REST API-ja)
async function checkCache(env, promptHash) {
  const url = `${env.SUPABASE_URL}/rest/v1/iso_ai_outputs?prompt_hash=eq.${promptHash}&select=response&limit=1`;
  const r = await fetch(url, {
    headers: {
      apikey: env.SUPABASE_SERVICE_KEY,
      Authorization: `Bearer ${env.SUPABASE_SERVICE_KEY}`
    }
  });
  if (!r.ok) return null;
  const arr = await r.json();
  return arr.length > 0 ? arr[0].response : null;
}

// Spremi u cache + audit log
async function logResponse(env, payload) {
  await fetch(`${env.SUPABASE_URL}/rest/v1/iso_ai_outputs`, {
    method: 'POST',
    headers: {
      apikey: env.SUPABASE_SERVICE_KEY,
      Authorization: `Bearer ${env.SUPABASE_SERVICE_KEY}`,
      'Content-Type': 'application/json',
      Prefer: 'return=minimal'
    },
    body: JSON.stringify(payload)
  });
}

// ============================================================
// PROMPTS — feature-specific
// ============================================================
function buildPrompt(feature, context) {
  if (feature === 'audit_checklist') {
    return `Pripremi internu audit checklist za ISO 9001:2015 sustav kvalitete u tvrtci Carta d.o.o. (proizvodnja papirnatih industrijskih vreća, 60 zaposlenika, 2 proizvodne linije).

Audit godina: ${context.audit_year}
Opseg procesa: ${(context.scope_processes || []).join(', ')}

REAL-TIME stanje sustava:
- Otvorene nesukladnosti (NC): ${context.nc_total}
- Otvorene CAPA radnje: ${context.capa_open}
- Aktivni dokumenti: ${context.documents_published}

Vrati JSON s ključnim "questions" arrayom. Svaki element ima:
- iso_clause (string, npr. "9.2.2")
- question (string, na hrvatskom)
- expected_evidence (string, što auditor očekuje da vidi)

Generiraj 15-20 pitanja koja pokrivaju:
- Klauzula 4 (kontekst organizacije, climate change)
- Klauzula 5 (vodstvo, quality culture)
- Klauzula 6 (planiranje, rizici)
- Klauzula 7 (resursi, dokumenti, mjerna oprema)
- Klauzula 8 (operativno planiranje, dobavljači, proizvodnja)
- Klauzula 9 (mjerenje, interni audit, ocjena uprave)
- Klauzula 10 (poboljšanje, NC, CAPA)

Pitanja trebaju biti SPECIFIČNA Cartinim procesima i koristiti stvarne brojke iz konteksta.

Odgovor SAMO kao validan JSON, bez markdown wrappera.`;
  }

  if (feature === 'doc_generator') {
    return `Pripremi draft dokumenta za ISO 9001 sustav kvalitete u tvrtci Carta d.o.o. (proizvodnja papirnatih industrijskih vreća).

Tip dokumenta: ${context.doc_type}
Naslov: ${context.title}
Svrha: ${context.purpose || 'Opisati postupak prema ISO 9001:2015'}
Procesi koje pokriva: ${(context.processes || []).join(', ')}

Generiraj kompletan tekst dokumenta na hrvatskom u professionalnom tonu, prilagođen Cartinim specifičnostima (industrijske papirnate vreće, NLI i W&H linije, 3 smjene). Uključi:
- Svrha
- Opseg
- Odgovornosti
- Postupak (numerirani koraci)
- Reference (HRN EN ISO 9001:2015)

Odgovori kao plain text (ne JSON).`;
  }

  if (feature === 'rca') {
    return `Pomozi u Root Cause Analysis (5-Why) za nesukladnost u Cartinom proizvodnom sustavu.

Opis nesukladnosti:
${context.description}

${context.immediate_action ? `Trenutna mjera: ${context.immediate_action}` : ''}

Provedi 5-Why analizu:
- Prvi "Zašto?" → odgovor 1
- Drugi "Zašto?" → odgovor 2 (na temelju odgovora 1)
- ... 5 razina

Vrati JSON: { "five_why": ["odg1","odg2","odg3","odg4","odg5"], "root_cause": "konačan korijen", "preporuke": "akcije za sprječavanje" }`;
  }

  if (feature === 'mgmt_review') {
    return `Pripremi draft ocjene uprave (OB_12) za Cartu d.o.o. za godinu ${context.year}.

Stvarne brojke iz baze:
- Nesukladnosti: ${context.ncs} (${context.ncs_major} major, ${context.ncs_minor} minor)
- CAPA: ${context.capas_open} otvorenih, ${context.capas_closed} zatvorenih
- Audit nalazi: ${context.findings_major} major, ${context.findings_minor} minor, ${context.findings_obs} observation
- KPI ciljevi: ${context.kpi_achieved}/${context.kpi_total} zadovoljava
- Dobavljači klasa A: ${context.suppliers_a}, klasa C: ${context.suppliers_c}
- Reklamacije kupaca: ${context.complaints_total} (${context.complaints_closed} zatvorenih)

Generiraj komentare za svaku od 11 sekcija OB_12 (a, b, c1-c7, d, e, f). Svaki komentar 2-4 rečenice, profesionalno, na hrvatskom, citirajući brojke gdje primjereno.

Vrati JSON: { "a": "komentar", "b": "komentar", ..., "f": "komentar", "conclusions": "glavni zaključci + akcijski plan" }`;
  }

  throw new Error('Nepoznata feature: ' + feature);
}

// ============================================================
// MAIN HANDLER
// ============================================================
export async function onRequestPost({ request, env }) {
  try {
    if (!env.GEMINI_API_KEY) {
      return new Response(JSON.stringify({ error: 'GEMINI_API_KEY nije postavljen u Cloudflare env varijablama' }), {
        status: 500, headers: { 'Content-Type': 'application/json' }
      });
    }

    const body = await request.json();
    const { feature, context, audit_id } = body;

    if (!feature) return new Response(JSON.stringify({ error: 'feature je obavezan' }), { status: 400 });

    const prompt = buildPrompt(feature, context || {});
    const promptHash = await hashPrompt(prompt);

    // CACHE LOOKUP
    if (env.SUPABASE_URL && env.SUPABASE_SERVICE_KEY) {
      const cached = await checkCache(env, promptHash);
      if (cached) {
        try {
          const parsed = JSON.parse(cached);
          return new Response(JSON.stringify({ ...parsed, cached: true }), {
            headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
          });
        } catch (_e) { /* fall through na novi poziv */ }
      }
    }

    // GEMINI CALL
    const startTime = Date.now();
    const geminiResp = await fetch(`${GEMINI_API_URL}?key=${env.GEMINI_API_KEY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.4,
          maxOutputTokens: 4096,
          responseMimeType: feature === 'doc_generator' ? 'text/plain' : 'application/json'
        }
      })
    });

    if (!geminiResp.ok) {
      const errText = await geminiResp.text();
      return new Response(JSON.stringify({ error: 'Gemini API error', detail: errText }), {
        status: geminiResp.status, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    const data = await geminiResp.json();
    const duration = Date.now() - startTime;
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
    const usage = data.usageMetadata || {};

    // Parse output
    let resultObj;
    if (feature === 'doc_generator') {
      resultObj = { content: text };
    } else {
      // Strip markdown code fences if present
      const cleaned = text.replace(/^```json\s*/i, '').replace(/```\s*$/, '').trim();
      try {
        resultObj = JSON.parse(cleaned);
      } catch (parseErr) {
        return new Response(JSON.stringify({ error: 'Gemini vratio invalidan JSON', raw: text }), {
          status: 502, headers: { 'Content-Type': 'application/json' }
        });
      }
    }

    // LOG + CACHE u iso_ai_outputs
    if (env.SUPABASE_URL && env.SUPABASE_SERVICE_KEY) {
      try {
        await logResponse(env, {
          feature,
          prompt_hash: promptHash,
          prompt,
          context_data: context,
          ai_provider: 'gemini',
          ai_model: GEMINI_MODEL,
          response: JSON.stringify(resultObj),
          tokens_used: (usage.totalTokenCount || 0),
          duration_ms: duration,
          used_in_table: audit_id ? 'iso_audits' : null,
          used_in_id: audit_id || null
        });
      } catch (logErr) {
        console.warn('Cache log failed:', logErr);
      }
    }

    return new Response(JSON.stringify(resultObj), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500, headers: { 'Content-Type': 'application/json' }
    });
  }
}

// CORS preflight
export async function onRequestOptions() {
  return new Response(null, {
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type'
    }
  });
}
