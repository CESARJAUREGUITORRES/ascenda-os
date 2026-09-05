'use strict';
const https = require('https');

const MODELS = Object.freeze({
  fast: 'openai/gpt-oss-20b',
  reasoning: 'openai/gpt-oss-120b',
  safety: 'openai/gpt-oss-safeguard-20b',
  multimodalCandidate: 'qwen/qwen3.6-27b'
});

const COSTS = Object.freeze({
  'openai/gpt-oss-20b': { input: 0.075, output: 0.30 },
  'openai/gpt-oss-120b': { input: 0.15, output: 0.60 },
  'openai/gpt-oss-safeguard-20b': { input: 0.075, output: 0.30 },
  'qwen/qwen3.6-27b': { input: 0.60, output: 3.00 }
});

const SAFETY_MAX_COMPLETION_TOKENS = 180;
const SAFETY_MAX_KNOWLEDGE_ITEMS = 12;

function requestJson(opts, payload, timeoutMs) {
  return new Promise((resolve, reject) => {
    const data = payload == null ? '' : JSON.stringify(payload);
    const headers = Object.assign({}, opts.headers || {});
    if (data) headers['Content-Length'] = Buffer.byteLength(data);
    const req = https.request(Object.assign({}, opts, { headers, timeout: timeoutMs || 15000 }), res => {
      let raw = '';
      res.on('data', c => { raw += c; });
      res.on('end', () => {
        let body = null;
        try { body = raw ? JSON.parse(raw) : {}; } catch (_) {
          return reject(Object.assign(new Error('GROQ_INVALID_JSON'), { status: 502, upstreamStatus: res.statusCode, raw: raw.slice(0, 300) }));
        }
        if (res.statusCode >= 200 && res.statusCode < 300) return resolve({ status: res.statusCode, body });
        const err = new Error('GROQ_REJECTED');
        err.status = 502;
        err.upstreamStatus = res.statusCode;
        err.code = body && body.error && body.error.code ? String(body.error.code) : null;
        err.messageSafe = body && body.error && body.error.message ? String(body.error.message).slice(0, 180) : null;
        reject(err);
      });
    });
    req.on('timeout', () => req.destroy(Object.assign(new Error('GROQ_TIMEOUT'), { status: 504 })));
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

function boundedText(value, max) {
  const text = String(value == null ? '' : value).trim();
  return text ? text.slice(0, max) : '';
}

function compactList(value, maxItems, maxChars) {
  return Array.isArray(value) ? value.slice(0, maxItems).map(x => boundedText(x, maxChars)).filter(Boolean) : [];
}

function compactSafetyFacts(domain, facts) {
  const f = facts && typeof facts === 'object' && !Array.isArray(facts) ? facts : {};
  const d = String(domain || '').toUpperCase();
  const out = {};
  const copyText = (key, max = 320) => { const v = boundedText(f[key], max); if (v) out[key] = v; };
  const copyNumber = key => { const n = Number(f[key]); if (Number.isFinite(n)) out[key] = n; };
  const copyBool = key => { if (typeof f[key] === 'boolean') out[key] = f[key]; };

  if (d === 'CATALOG') {
    ['tipo','nombre','nombre_corto','categoria','moneda','duracion_sesion','frecuencia'].forEach(k => copyText(k, 180));
    ['precio_base','precio_oferta','num_sesiones'].forEach(copyNumber);
    copyText('descripcion_comercial', 360);
    const beneficios = compactList(f.beneficios, 5, 180); if (beneficios.length) out.beneficios = beneficios;
    copyBool('requiere_doctora'); copyBool('requiere_enfermeria');
    copyText('included_benefit', 240);
    if (f.catalog_identity && typeof f.catalog_identity === 'object' && !Array.isArray(f.catalog_identity)) {
      const identity = {};
      for (const key of ['family_name','commercial_variant','brand','zones','unit_cap','syringes','volume_ml']) {
        const value = f.catalog_identity[key];
        if (typeof value === 'number' && Number.isFinite(value)) identity[key] = value;
        else { const text = boundedText(value, 120); if (text) identity[key] = text; }
      }
      if (Object.keys(identity).length) out.catalog_identity = identity;
    }
  } else if (d === 'PROMOTION') {
    ['nombre','descripcion','tipo_descuento','codigo','vigencia_inicio','vigencia_fin'].forEach(k => copyText(k, k === 'descripcion' ? 360 : 180));
    copyNumber('valor_descuento');
    const tratamientos = compactList(f.tratamientos, 8, 160); if (tratamientos.length) out.tratamientos = tratamientos;
    const segmentos = compactList(f.segmentos, 8, 120); if (segmentos.length) out.segmentos = segmentos;
  } else if (d === 'BRANCH') {
    ['nombre','direccion','telefono','maps_link'].forEach(k => copyText(k, k === 'direccion' || k === 'maps_link' ? 300 : 160));
  } else if (d === 'HOURS') {
    ['sede','dia_semana','hora_apertura','hora_cierre'].forEach(k => copyText(k, 80)); copyBool('activo');
  } else if (d === 'CATEGORY') {
    ['nombre','descripcion_comercial'].forEach(k => copyText(k, k === 'descripcion_comercial' ? 360 : 180));
    const beneficios = compactList(f.beneficios, 5, 180); if (beneficios.length) out.beneficios = beneficios;
  } else if (d === 'CLINIC_KNOWLEDGE') {
    ['code','node_type','parent_code','title','risk_level','audience'].forEach(k => copyText(k, 160));
    copyText('answer', 650);
  }
  return out;
}

function compactSafetyKnowledge(bundle) {
  const b = bundle && typeof bundle === 'object' ? bundle : {};
  const items = Array.isArray(b.items) ? b.items : [];
  return {
    version: boundedText(b.version, 80) || 'WA4A1-KNOWLEDGE-V2',
    audience: boundedText(b.audience, 80) || 'PUBLIC_CLIENT',
    authority: boundedText(b.authority, 80) || 'GOVERNED_SOURCE_ONLY',
    generic_llm_authority: false,
    price_authority: boundedText(b.price_authority, 80) || null,
    price_stage: b.price_stage === true,
    items: items.slice(0, SAFETY_MAX_KNOWLEDGE_ITEMS).map(item => ({
      knowledge_id: boundedText(item && item.knowledge_id, 160),
      domain: boundedText(item && item.domain, 80),
      title: boundedText(item && item.title, 180),
      authority_tier: Number(item && item.authority_tier || 99),
      freshness_state: boundedText(item && item.freshness_state, 80),
      facts: compactSafetyFacts(item && item.domain, item && item.facts)
    })).filter(item => item.knowledge_id)
  };
}

function compactSafetyMessages(messages) {
  const source = Array.isArray(messages) ? messages : [];
  return source.map(m => {
    if (!m || m.role !== 'user' || typeof m.content !== 'string') return m;
    let obj;
    try { obj = JSON.parse(m.content); } catch (_) { return m; }
    if (!obj || typeof obj !== 'object' || !obj.approved_public_knowledge) return m;
    const copy = Object.assign({}, obj, { approved_public_knowledge: compactSafetyKnowledge(obj.approved_public_knowledge) });
    return Object.assign({}, m, { content: JSON.stringify(copy) });
  });
}

async function listModels(apiKey) {
  if (!apiKey) throw Object.assign(new Error('GROQ_KEY_REQUIRED'), { status: 503 });
  const out = await requestJson({
    hostname: 'api.groq.com',
    path: '/openai/v1/models',
    method: 'GET',
    headers: { Authorization: 'Bearer ' + apiKey, 'Content-Type': 'application/json', 'User-Agent': 'AscendaOS-WA4/1.0' }
  }, null, 12000);
  const ids = new Set((Array.isArray(out.body && out.body.data) ? out.body.data : []).map(x => String(x.id || '')).filter(Boolean));
  return {
    ids,
    active: {
      fast: ids.has(MODELS.fast),
      reasoning: ids.has(MODELS.reasoning),
      safety: ids.has(MODELS.safety),
      multimodalCandidate: ids.has(MODELS.multimodalCandidate)
    }
  };
}

async function chat(apiKey, model, messages, options) {
  if (!apiKey) throw Object.assign(new Error('GROQ_KEY_REQUIRED'), { status: 503 });
  options = options || {};
  const isSafety = model === MODELS.safety;
  const requestedTokens = Number(options.maxTokens || (isSafety ? SAFETY_MAX_COMPLETION_TOKENS : 700));
  const maxTokens = isSafety ? Math.min(requestedTokens, SAFETY_MAX_COMPLETION_TOKENS) : Math.min(requestedTokens, 3000);
  const body = {
    model,
    messages: isSafety ? compactSafetyMessages(messages) : messages,
    max_completion_tokens: Math.max(64, maxTokens),
    response_format: { type: 'json_object' }
  };
  if (model === MODELS.fast || model === MODELS.reasoning || model === MODELS.safety) {
    body.reasoning_effort = options.reasoningEffort || (model === MODELS.reasoning ? 'medium' : 'low');
  }
  const started = Date.now();
  const out = await requestJson({
    hostname: 'api.groq.com',
    path: '/openai/v1/chat/completions',
    method: 'POST',
    headers: { Authorization: 'Bearer ' + apiKey, 'Content-Type': 'application/json', 'User-Agent': 'AscendaOS-WA4/1.0' }
  }, body, Number(options.timeoutMs || 20000));
  const first = out.body && Array.isArray(out.body.choices) ? out.body.choices[0] : null;
  const content = first && first.message ? first.message.content : null;
  if (typeof content !== 'string' || !content.trim()) throw Object.assign(new Error('GROQ_EMPTY_RESPONSE'), { status: 502 });
  let json;
  try { json = JSON.parse(content); } catch (_) {
    throw Object.assign(new Error('GROQ_NON_JSON_RESPONSE'), { status: 502 });
  }
  return {
    model: String(out.body.model || model),
    json,
    usage: out.body.usage || {},
    latencyMs: Date.now() - started
  };
}

function estimateCost(model, usage) {
  const rate = COSTS[model] || { input: 0, output: 0 };
  const input = Number((usage && (usage.prompt_tokens ?? usage.input_tokens)) || 0);
  const output = Number((usage && (usage.completion_tokens ?? usage.output_tokens)) || 0);
  return Number(((input * rate.input + output * rate.output) / 1_000_000).toFixed(8));
}

function redactPII(value) {
  let s = String(value || '');
  s = s.replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, '[EMAIL]');
  s = s.replace(/\b(?:\+?\d[\s().-]*){9,15}\b/g, '[TEL]');
  s = s.replace(/\b\d{8}\b/g, '[DOC]');
  return s;
}

function normalize(value) {
  return String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
}

function chooseModel(lastInbound, context) {
  const text = normalize(lastInbound);
  const complex = Boolean(context && context.forceReasoning === true) ||
    String(lastInbound || '').length > 700 ||
    /(compar|diferencia|mejor opcion|cuantas sesiones|plan|paquete|presupuesto|objec|resultado|duracion|combinar|alternativa|recomiend)/.test(text);
  return complex ? MODELS.reasoning : MODELS.fast;
}

function personalizedClinicalRisk(text) {
  const t = normalize(text);
  return /(estoy embaraz|embarazada|lactancia|tengo (diabetes|cancer|hipertension|autoinmune)|tomo (anticoagul|isotretino|medic)|soy alerg|me dio reaccion|tengo fiebre|me sangra|me duele mucho|dolor intenso|dificultad para respirar|hinchazon fuerte|complicacion)/.test(t);
}

function validateSuggestion(obj, allowedCatalogIds, allowedSoles) {
  if (!obj || typeof obj !== 'object') return { ok: false, error: 'WA4_INVALID_MODEL_OBJECT' };
  const reply = String(obj.reply || '').trim();
  if (!reply || reply.length > 1600) return { ok: false, error: 'WA4_INVALID_REPLY' };
  const allowedActions = new Set(['REPLY', 'OFFER_BOOKING', 'HUMAN_CLINICAL', 'HUMAN_COMMERCIAL']);
  const nextAction = String(obj.next_action || 'REPLY').toUpperCase();
  if (!allowedActions.has(nextAction)) return { ok: false, error: 'WA4_INVALID_NEXT_ACTION' };
  const citations = Array.isArray(obj.cited_catalog_ids) ? obj.cited_catalog_ids.map(String) : [];
  const allowed = new Set((allowedCatalogIds || []).map(String));
  if (citations.some(id => !allowed.has(id))) return { ok: false, error: 'WA4_UNGROUNDED_CITATION' };

  const amounts = [];
  const re = /(?:s\/\.?\s*|s\/\s*|soles?\s*)(\d+(?:[.,]\d{1,2})?)/gi;
  let m;
  while ((m = re.exec(reply))) amounts.push(Number(m[1].replace(',', '.')));
  const allowedMoney = new Set((allowedSoles || []).map(x => Number(x)).filter(Number.isFinite).map(x => x.toFixed(2)));
  if (amounts.some(x => !allowedMoney.has(Number(x).toFixed(2)))) return { ok: false, error: 'WA4_UNGROUNDED_PRICE' };
  return { ok: true, reply, nextAction, citations };
}

module.exports = {
  MODELS, COSTS, SAFETY_MAX_COMPLETION_TOKENS, SAFETY_MAX_KNOWLEDGE_ITEMS,
  listModels, chat, estimateCost, redactPII, normalize, chooseModel,
  personalizedClinicalRisk, validateSuggestion, compactSafetyFacts,
  compactSafetyKnowledge, compactSafetyMessages
};