'use strict';

// WA-4A Knowledge Fabric adapter. PROD-ready but intentionally not wired into Copilot in WA-4A.
// It accepts only READY governed rows from aos_wa4a_knowledge_search_v1 and validates model grounding.

const FIELD_ALLOWLIST = Object.freeze({
  CATALOG: new Set(['tipo','nombre','nombre_corto','categoria','precio_base','precio_oferta','duracion_sesion','num_sesiones','frecuencia','descripcion_comercial','beneficios','faqs','requiere_doctora','requiere_enfermeria']),
  PROMOTION: new Set(['nombre','descripcion','tipo_descuento','valor_descuento','tratamientos','segmentos','codigo','vigencia_inicio','vigencia_fin']),
  BRANCH: new Set(['nombre','direccion','telefono','maps_link']),
  HOURS: new Set(['sede','dia_semana','hora_apertura','hora_cierre','activo']),
  CATEGORY: new Set(['nombre','descripcion_comercial','beneficios','faqs'])
});

function normalize(value) {
  return String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
}

function sanitizeFacts(domain, facts) {
  const allowed = FIELD_ALLOWLIST[String(domain || '').toUpperCase()];
  if (!allowed || !facts || typeof facts !== 'object' || Array.isArray(facts)) return {};
  const out = {};
  for (const key of allowed) if (Object.prototype.hasOwnProperty.call(facts,key)) out[key] = facts[key];
  return out;
}

function buildKnowledgeBundle(rows, maxItems) {
  const limit = Math.max(1, Math.min(Number(maxItems || 12), 24));
  const source = Array.isArray(rows) ? rows : [];
  const seen = new Set();
  const items = [];
  for (const row of source) {
    if (!row || !['READY','READY_WITH_WARNING'].includes(String(row.retrieval_state || ''))) continue;
    if (String(row.conflict_state || '') !== 'CLEAR') continue;
    const id = String(row.knowledge_id || '');
    if (!id || seen.has(id)) continue;
    const evidence = row.evidence_ref && typeof row.evidence_ref === 'object' ? row.evidence_ref : {};
    if (!evidence.relation || !evidence.pk) continue;
    seen.add(id);
    items.push({
      knowledge_id: id,
      domain: String(row.domain || '').toUpperCase(),
      title: String(row.title || '').slice(0,240),
      facts: sanitizeFacts(row.domain,row.facts),
      authority_tier: Number(row.authority_tier || 99),
      freshness_state: String(row.freshness_state || 'UNKNOWN'),
      retrieval_state: String(row.retrieval_state),
      evidence_ref: {
        relation: String(evidence.relation).slice(0,120),
        pk: String(evidence.pk).slice(0,120),
        version: evidence.version == null ? 'UNKNOWN' : String(evidence.version).slice(0,160),
        warning: evidence.warning == null ? null : String(evidence.warning).slice(0,120)
      }
    });
    if (items.length >= limit) break;
  }
  return {version:'WA4A-KNOWLEDGE-V1',items,authority:'GOVERNED_SOURCE_ONLY',generic_llm_authority:false};
}

function moneyValues(bundle) {
  const values = [];
  for (const item of bundle.items || []) {
    const f = item.facts || {};
    for (const key of ['precio_base','precio_oferta']) {
      const n = Number(f[key]);
      if (Number.isFinite(n)) values.push(n);
    }
    if (item.domain === 'PROMOTION' && String(f.tipo_descuento || '').toLowerCase().includes('monto')) {
      const n = Number(f.valor_descuento);
      if (Number.isFinite(n)) values.push(n);
    }
  }
  return new Set(values.map(v=>v.toFixed(2)));
}

function timeValues(bundle) {
  const out = new Set();
  for (const item of bundle.items || []) {
    if (item.domain !== 'HOURS') continue;
    for (const key of ['hora_apertura','hora_cierre']) {
      const v = String((item.facts || {})[key] || '').slice(0,5);
      if (/^\d{2}:\d{2}$/.test(v)) out.add(v);
    }
  }
  return out;
}

function validateGroundedSuggestion(obj, bundle) {
  if (!obj || typeof obj !== 'object') return {ok:false,error:'WA4A_INVALID_MODEL_OBJECT'};
  const reply = String(obj.reply || '').trim();
  if (!reply || reply.length > 1600) return {ok:false,error:'WA4A_INVALID_REPLY'};
  const items = Array.isArray(bundle && bundle.items) ? bundle.items : [];
  const citations = Array.isArray(obj.cited_knowledge_ids) ? obj.cited_knowledge_ids.map(String) : [];
  const allowedIds = new Set(items.map(x=>String(x.knowledge_id)));
  if (citations.some(id=>!allowedIds.has(id))) return {ok:false,error:'WA4A_UNGROUNDED_CITATION'};

  const nextAction = String(obj.next_action || 'REPLY').toUpperCase();
  const humanOnly = nextAction === 'HUMAN_CLINICAL' || nextAction === 'HUMAN_COMMERCIAL';
  if (!humanOnly && citations.length === 0) return {ok:false,error:'WA4A_EVIDENCE_REQUIRED'};
  if (!humanOnly && items.length === 0) return {ok:false,error:'WA4A_KNOWLEDGE_REQUIRED'};

  const allowedMoney = moneyValues(bundle || {items:[]});
  const amounts = [];
  const moneyRe = /(?:s\/\.?\s*|soles?\s*)(\d+(?:[.,]\d{1,2})?)/gi;
  let m;
  while ((m = moneyRe.exec(reply))) amounts.push(Number(m[1].replace(',','.')));
  if (amounts.some(x=>!allowedMoney.has(x.toFixed(2)))) return {ok:false,error:'WA4A_UNGROUNDED_PRICE'};

  const allowedTimes = timeValues(bundle || {items:[]});
  const mentionedTimes = [...reply.matchAll(/\b(?:[01]?\d|2[0-3]):[0-5]\d\b/g)].map(x=>x[0].padStart(5,'0'));
  if (mentionedTimes.some(t=>!allowedTimes.has(t))) return {ok:false,error:'WA4A_UNGROUNDED_HOURS'};

  const n = normalize(reply);
  if (/(direccion|dirección|ubicad|sede|como llegar|cómo llegar)/.test(n)) {
    const citedDomains = new Set(items.filter(x=>citations.includes(String(x.knowledge_id))).map(x=>x.domain));
    if (!citedDomains.has('BRANCH')) return {ok:false,error:'WA4A_BRANCH_EVIDENCE_REQUIRED'};
  }

  return {ok:true,reply,citations,nextAction};
}

module.exports = {FIELD_ALLOWLIST, normalize, sanitizeFacts, buildKnowledgeBundle, validateGroundedSuggestion};
