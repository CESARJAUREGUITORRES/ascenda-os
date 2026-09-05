'use strict';

// WA-4A/4A.1 Knowledge Fabric adapter.
// Accepts only READY governed rows and enforces audience isolation for Zi Vital clinic knowledge.

const AUDIENCES = Object.freeze(new Set([
  'PUBLIC_CLIENT','ADVISOR_INTERNAL','OWNER_ADMIN','CLINICAL_RESTRICTED','SYSTEM_REFERENCE'
]));
const SEP26_CURRENT_SKU = 'CATALOG_SEP2026_CURRENT_SKU';
const CATALOG_IDENTITY_ALLOWLIST = Object.freeze(new Set([
  'family_name','commercial_variant','clinical_sessions','brand','zones','unit_cap','syringes','volume_ml'
]));
const FAQ_BOUNDS = Object.freeze({ maxItems: 6, questionChars: 220, answerChars: 650 });
const CITATION_REPAIR_VISIBLE_ITEMS = 4;

const FIELD_ALLOWLIST = Object.freeze({
  CATALOG: new Set(['tipo','nombre','nombre_corto','categoria','precio_base','precio_oferta','moneda','duracion_sesion','num_sesiones','frecuencia','descripcion_comercial','beneficios','faqs','requiere_doctora','requiere_enfermeria','included_benefit','included_benefit_source','catalog_identity','catalog_identity_source']),
  PROMOTION: new Set(['nombre','descripcion','tipo_descuento','valor_descuento','tratamientos','segmentos','codigo','vigencia_inicio','vigencia_fin']),
  BRANCH: new Set(['nombre','direccion','telefono','maps_link']),
  HOURS: new Set(['sede','dia_semana','hora_apertura','hora_cierre','activo']),
  CATEGORY: new Set(['nombre','descripcion_comercial','beneficios','faqs']),
  CLINIC_KNOWLEDGE: new Set(['code','node_type','parent_code','title','aliases','answer','public_summary','system_reference','risk_level','audience'])
});

function normalize(value) {
  return String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
}

function normalizeAudience(value) {
  const audience = String(value || 'PUBLIC_CLIENT').toUpperCase();
  return AUDIENCES.has(audience) ? audience : 'PUBLIC_CLIENT';
}

function boundedText(value,maxChars) {
  const text = String(value == null ? '' : value).trim();
  return text ? text.slice(0,maxChars) : '';
}

function sanitizeFaqs(value) {
  if (!Array.isArray(value)) return [];
  const out = [];
  for (const item of value) {
    if (out.length >= FAQ_BOUNDS.maxItems) break;
    if (item && typeof item === 'object' && !Array.isArray(item)) {
      const q = boundedText(item.q,FAQ_BOUNDS.questionChars);
      const a = boundedText(item.a,FAQ_BOUNDS.answerChars);
      if (q || a) out.push({q,a});
      continue;
    }
    const text = boundedText(item,FAQ_BOUNDS.answerChars);
    if (text) out.push({q:'',a:text});
  }
  return out;
}

function sanitizeCatalogIdentity(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const out = {};
  for (const key of CATALOG_IDENTITY_ALLOWLIST) {
    if (!Object.prototype.hasOwnProperty.call(value,key)) continue;
    if (['family_name','commercial_variant','brand'].includes(key)) {
      const text = String(value[key] == null ? '' : value[key]).trim();
      if (text) out[key] = text.slice(0,180);
      continue;
    }
    const n = Number(value[key]);
    if (Number.isFinite(n) && n > 0 && n <= 10000) out[key] = n;
  }
  return Object.keys(out).length ? out : null;
}

function sanitizeFacts(domain, facts) {
  const normalizedDomain = String(domain || '').toUpperCase();
  const allowed = FIELD_ALLOWLIST[normalizedDomain];
  if (!allowed || !facts || typeof facts !== 'object' || Array.isArray(facts)) return {};
  const out = {};
  for (const key of allowed) {
    if (!Object.prototype.hasOwnProperty.call(facts,key)) continue;
    if (key === 'faqs') {
      const faqs = sanitizeFaqs(facts[key]);
      if (faqs.length) out[key] = faqs;
      continue;
    }
    if (normalizedDomain === 'CATALOG' && key === 'included_benefit') {
      if (facts.included_benefit_source !== SEP26_CURRENT_SKU) continue;
      const text = String(facts[key] == null ? '' : facts[key]).trim();
      if (text) out[key] = text.slice(0,500);
      continue;
    }
    if (normalizedDomain === 'CATALOG' && key === 'included_benefit_source') {
      if (facts[key] === SEP26_CURRENT_SKU) out[key] = SEP26_CURRENT_SKU;
      continue;
    }
    if (normalizedDomain === 'CATALOG' && key === 'catalog_identity') {
      if (facts.catalog_identity_source !== SEP26_CURRENT_SKU) continue;
      const identity = sanitizeCatalogIdentity(facts[key]);
      if (identity) out[key] = identity;
      continue;
    }
    if (normalizedDomain === 'CATALOG' && key === 'catalog_identity_source') {
      if (facts[key] === SEP26_CURRENT_SKU) out[key] = SEP26_CURRENT_SKU;
      continue;
    }
    out[key] = facts[key];
  }
  return out;
}

function buildKnowledgeBundle(rows, maxItems, expectedAudience) {
  const limit = Math.max(1, Math.min(Number(maxItems || 12), 24));
  const audience = normalizeAudience(expectedAudience);
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
    const domain = String(row.domain || '').toUpperCase();
    const facts = sanitizeFacts(domain,row.facts);
    if (domain === 'CLINIC_KNOWLEDGE') {
      const rowAudience = normalizeAudience(facts.audience || evidence.audience);
      if (rowAudience !== audience) continue;
      if (!String(facts.answer || '').trim()) continue;
      if (audience === 'PUBLIC_CLIENT') {
        delete facts.system_reference;
        delete facts.public_summary;
      }
    }
    seen.add(id);
    items.push({
      knowledge_id: id,
      domain,
      title: String(row.title || '').slice(0,240),
      facts,
      authority_tier: Number(row.authority_tier || 99),
      freshness_state: String(row.freshness_state || 'UNKNOWN'),
      retrieval_state: String(row.retrieval_state),
      evidence_ref: {
        relation: String(evidence.relation).slice(0,120),
        pk: String(evidence.pk).slice(0,120),
        version: evidence.version == null ? 'UNKNOWN' : String(evidence.version).slice(0,160),
        warning: evidence.warning == null ? null : String(evidence.warning).slice(0,120),
        source_code: evidence.source_code == null ? null : String(evidence.source_code).slice(0,120),
        source_locator: evidence.source_locator == null ? null : String(evidence.source_locator).slice(0,200),
        audience: domain === 'CLINIC_KNOWLEDGE' ? audience : null
      }
    });
    if (items.length >= limit) break;
  }
  return {version:'WA4A1-KNOWLEDGE-V2',audience,items,authority:'GOVERNED_SOURCE_ONLY',generic_llm_authority:false};
}

function moneyValuesByCurrency(bundle) {
  const values = {PEN:new Set(),USD:new Set()};
  for (const item of bundle.items || []) {
    const f = item.facts || {};
    if (item.domain === 'CATALOG') {
      // Legacy knowledge rows predate explicit currency and were PEN. Runtime WA-4B
      // always re-gates catalog money through 1C before it reaches the model.
      const currency = String(f.moneda || f.currency || 'PEN').toUpperCase();
      if (!values[currency]) continue;
      for (const key of ['precio_base','precio_oferta']) {
        const n = Number(f[key]);
        if (Number.isFinite(n)) values[currency].add(n.toFixed(2));
      }
    }
    if (item.domain === 'PROMOTION' && String(f.tipo_descuento || '').toLowerCase().includes('monto')) {
      const n = Number(f.valor_descuento);
      if (Number.isFinite(n)) values.PEN.add(n.toFixed(2));
    }
  }
  return values;
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

function moneyMentions(reply) {
  const mentions = [];
  const patterns = [
    {currency:'PEN',re:/(?:s\/\.?\s*|soles?\s*)(\d+(?:[.,]\d{1,2})?)/gi},
    {currency:'USD',re:/(?:us\$\s*|usd\s*\$?\s*|\$\s*|d[oó]lares?\s*)(\d+(?:[.,]\d{1,2})?)/gi}
  ];
  for (const p of patterns) {
    let m;
    while ((m = p.re.exec(String(reply || '')))) {
      const value = Number(m[1].replace(',','.'));
      if (Number.isFinite(value)) mentions.push({currency:p.currency,value});
    }
  }
  return mentions;
}

function itemFamily(item) {
  if (!item || String(item.domain || '').toUpperCase() !== 'CATALOG') return '';
  const f = item.facts || {};
  const identity = f.catalog_identity && typeof f.catalog_identity === 'object' ? f.catalog_identity : {};
  return normalize(identity.family_name || f.categoria || f.nombre || item.title).trim();
}

function itemSupportsMoney(item,mention) {
  if (!item || !mention) return false;
  const values = moneyValuesByCurrency({items:[item]});
  return Boolean(values[mention.currency] && values[mention.currency].has(Number(mention.value).toFixed(2)));
}

function deterministicCitationRepair(reply,bundle) {
  const source = Array.isArray(bundle && bundle.items) ? bundle.items : [];
  const visible = source.slice(0,CITATION_REPAIR_VISIBLE_ITEMS);
  if (!visible.length) return [];
  const mentions = moneyMentions(reply);

  if (mentions.length) {
    const ids = new Set();
    for (const mention of mentions) {
      const matches = visible.filter(item=>itemSupportsMoney(item,mention));
      if (!matches.length) return [];
      const catalogFamilies = new Set(matches.filter(x=>x.domain==='CATALOG').map(itemFamily).filter(Boolean));
      const nonCatalog = matches.filter(x=>x.domain!=='CATALOG');
      // Multiple unrelated items at the same amount are ambiguous and must not be auto-cited.
      if (catalogFamilies.size > 1 || (nonCatalog.length > 1) || (catalogFamilies.size && nonCatalog.length)) return [];
      for (const item of matches) ids.add(String(item.knowledge_id));
    }
    return [...ids].filter(Boolean).slice(0,CITATION_REPAIR_VISIBLE_ITEMS);
  }

  const catalogs = visible.filter(item=>String(item.domain||'').toUpperCase()==='CATALOG');
  if (!catalogs.length) return [];
  const families = new Set(catalogs.map(itemFamily).filter(Boolean));
  if (families.size !== 1) return [];
  const family = [...families][0];
  const familyTokens = family.split(/[^a-z0-9]+/).filter(t=>t.length>=4);
  const replyTokens = new Set(normalize(reply).split(/[^a-z0-9]+/).filter(Boolean));
  if (!familyTokens.some(t=>replyTokens.has(t))) return [];
  return catalogs.map(x=>String(x.knowledge_id)).filter(Boolean).slice(0,CITATION_REPAIR_VISIBLE_ITEMS);
}

function validateGroundedSuggestion(obj, bundle) {
  if (!obj || typeof obj !== 'object') return {ok:false,error:'WA4A_INVALID_MODEL_OBJECT'};
  const reply = String(obj.reply || '').trim();
  if (!reply || reply.length > 1600) return {ok:false,error:'WA4A_INVALID_REPLY'};
  const items = Array.isArray(bundle && bundle.items) ? bundle.items : [];
  let citations = Array.isArray(obj.cited_knowledge_ids) ? obj.cited_knowledge_ids.map(String).filter(Boolean) : [];
  const allowedIds = new Set(items.map(x=>String(x.knowledge_id)));
  if (citations.some(id=>!allowedIds.has(id))) return {ok:false,error:'WA4A_UNGROUNDED_CITATION'};

  const nextAction = String(obj.next_action || 'REPLY').toUpperCase();
  const humanOnly = nextAction === 'HUMAN_CLINICAL' || nextAction === 'HUMAN_COMMERCIAL';
  let citationRepaired = false;
  if (!humanOnly && citations.length === 0) {
    citations = deterministicCitationRepair(reply,bundle);
    citationRepaired = citations.length > 0;
  }
  if (!humanOnly && citations.length === 0) return {ok:false,error:'WA4A_EVIDENCE_REQUIRED'};
  if (!humanOnly && items.length === 0) return {ok:false,error:'WA4A_KNOWLEDGE_REQUIRED'};

  // Commercial claims must be supported by the evidence actually cited. Human-only
  // drafts without citations remain non-autonomous and retain the broader governed set.
  const citedItems = citations.length ? items.filter(x=>citations.includes(String(x.knowledge_id))) : (humanOnly ? items : []);
  const allowedMoney = moneyValuesByCurrency({items:citedItems});
  const mentions = moneyMentions(reply);
  if (mentions.some(x=>!allowedMoney[x.currency].has(Number(x.value).toFixed(2)))) return {ok:false,error:'WA4A_UNGROUNDED_PRICE'};

  const allowedTimes = timeValues({items:citedItems});
  const mentionedTimes = [...reply.matchAll(/\b(?:[01]?\d|2[0-3]):[0-5]\d\b/g)].map(x=>x[0].padStart(5,'0'));
  if (mentionedTimes.some(t=>!allowedTimes.has(t))) return {ok:false,error:'WA4A_UNGROUNDED_HOURS'};

  const n = normalize(reply);
  if (/(direccion|dirección|ubicad|sede|como llegar|cómo llegar)/.test(n)) {
    const citedDomains = new Set(citedItems.map(x=>x.domain));
    if (!citedDomains.has('BRANCH')) return {ok:false,error:'WA4A_BRANCH_EVIDENCE_REQUIRED'};
  }

  return {ok:true,reply,citations,nextAction,citationRepaired};
}

module.exports = {
  AUDIENCES,SEP26_CURRENT_SKU,CATALOG_IDENTITY_ALLOWLIST,FAQ_BOUNDS,FIELD_ALLOWLIST,CITATION_REPAIR_VISIBLE_ITEMS,
  normalize,normalizeAudience,boundedText,sanitizeFaqs,sanitizeCatalogIdentity,sanitizeFacts,buildKnowledgeBundle,
  moneyValuesByCurrency,moneyMentions,itemFamily,deterministicCitationRepair,validateGroundedSuggestion
};
