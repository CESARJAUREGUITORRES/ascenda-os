'use strict';

// WA-4B — Sales Playbook Engine.
// Pure orchestration over governed WA-4A/4A.1/4A.1B knowledge + WA-4A.1C process/price context.
// No business-fact master, no patient plan, no send authority.

const RULE_TITLES = Object.freeze({
  RULE_MEDICAL_PLAN_TO_COMMERCIAL: 'Plan médico arquitectura comercial',
  RULE_QUOTE_PROCESS: 'Cotizar proceso antes que ítems',
  RULE_RECALCULATE_PROCESS: 'Recalcular proceso no restar piezas',
  RULE_PAYMENT_SCENARIOS: 'Pago completo vs progresivo',
  RULE_TOPPINGS_BENEFITS: 'Toppings y beneficios con función',
  RULE_ETHICAL_UPSELL: 'Upselling ético y continuidad',
  RULE_PRODUCTS_AS_EXTENSION: 'Productos como extensión del tratamiento',
  POLICY_REFUND_ALIGNMENT: 'Política de pagos devoluciones alineación requerida'
});

const RULES_BY_STAGE = Object.freeze({
  DISCOVERY: [],
  INFO: [],
  PRICE_QUOTE: ['RULE_MEDICAL_PLAN_TO_COMMERCIAL','RULE_QUOTE_PROCESS'],
  PAYMENT: ['RULE_QUOTE_PROCESS','RULE_PAYMENT_SCENARIOS'],
  PROMOTION: ['RULE_TOPPINGS_BENEFITS'],
  OBJECTION: ['RULE_QUOTE_PROCESS','RULE_RECALCULATE_PROCESS'],
  CONTINUITY: ['RULE_ETHICAL_UPSELL','RULE_PRODUCTS_AS_EXTENSION'],
  BOOKING: [],
  CLINICAL_ESCALATION: []
});

function normalize(value) {
  return String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
}

function classifyStage(text) {
  const t = normalize(text);
  if (/(embaraz|lactancia|diabetes|cancer|hipertension|autoinmune|anticoagul|isotretino|alerg|reaccion|fiebre|sangra|dolor intenso|dificultad para respirar|hinchazon fuerte|complicacion)/.test(t)) return 'CLINICAL_ESCALATION';
  if (/(agend|agenda|cita|reserv|disponibilidad|horario para atender|quiero ir|separar cita)/.test(t)) return 'BOOKING';
  if (/(forma de pago|pago completo|pago progresivo|cuota|adelanto|financ|se puede pagar|como pago)/.test(t)) return 'PAYMENT';
  if (/(promo|promocion|promoción|descuento|codigo|código|oferta especial)/.test(t)) return 'PROMOTION';
  if (/(precio|cuesta|costo|coste|cotiz|presupuesto|valor de|cuanto sale|cuánto sale)/.test(t)) return 'PRICE_QUOTE';
  if (/(muy caro|caro|costoso|rebaja|bajar el precio|quitar|sacar del plan|no estoy seguro|no estoy segura|por que tanto|por qué tanto|objec)/.test(t)) return 'OBJECTION';
  if (/(mantenimiento|mantener|seguimiento|despues|después|continuidad|en casa|producto para|post tratamiento|recompra)/.test(t)) return 'CONTINUITY';
  if (/[?¿]/.test(String(text || '')) || /(que es|qué es|como funciona|cómo funciona|beneficio|sirve para|informacion|información)/.test(t)) return 'INFO';
  return 'DISCOVERY';
}

function requiredRuleCodes(stage) {
  return (RULES_BY_STAGE[String(stage || '').toUpperCase()] || []).slice();
}

function ruleSearchQueries(stage) {
  return requiredRuleCodes(stage).map(code => RULE_TITLES[code]).filter(Boolean);
}

function uniqueItems(items) {
  const out = [], seen = new Set();
  for (const item of Array.isArray(items) ? items : []) {
    const id = String(item && item.knowledge_id || '');
    if (!id || seen.has(id)) continue;
    seen.add(id); out.push(item);
  }
  return out;
}

function mergeBundles() {
  const bundles = [...arguments].filter(Boolean);
  const audience = String((bundles[0] && bundles[0].audience) || 'ADVISOR_INTERNAL');
  return {
    version:'WA4B-KNOWLEDGE-MERGE-V1',
    audience,
    items: uniqueItems(bundles.flatMap(b => Array.isArray(b.items) ? b.items : [])),
    authority:'GOVERNED_SOURCE_ONLY',
    generic_llm_authority:false
  };
}

function catalogId(item) {
  const id = String(item && item.knowledge_id || '');
  const m = id.match(/^service:([0-9a-f-]{36})$/i);
  return m ? m[1] : null;
}

function ruleId(item) {
  const id = String(item && item.knowledge_id || '');
  const m = id.match(/^clinic:(RULE_[A-Z0-9_]+|POLICY_[A-Z0-9_]+)$/);
  return m ? m[1] : null;
}

function evidenceRef(item) {
  const e = item && item.evidence_ref || {};
  if (!e.relation || !e.pk) return null;
  return {
    knowledge_id:String(item.knowledge_id || ''),
    relation:String(e.relation),
    pk:String(e.pk),
    version:e.version == null ? 'UNKNOWN' : String(e.version),
    source_code:e.source_code == null ? null : String(e.source_code),
    source_locator:e.source_locator == null ? null : String(e.source_locator),
    warning:e.warning == null ? null : String(e.warning)
  };
}

function freshnessState(items, processContexts) {
  const ks = Array.isArray(items) ? items : [];
  const ps = Array.isArray(processContexts) ? processContexts : [];
  if (ks.some(x => String(x.conflict_state || '') !== 'CLEAR')) return 'CONFLICT';
  if (ks.some(x => !['READY','READY_WITH_WARNING'].includes(String(x.retrieval_state || '')))) return 'BLOCKED';
  if (ks.some(x => ['STALE','EXPIRED','INACTIVE'].includes(String(x.freshness_state || '')))) return 'STALE';
  if (ps.some(x => String(x.freshness_state || '') === 'STALE_REVIEW' || String(x.price_state || '') !== 'READY')) return 'PRICE_REVIEW';
  if (ks.some(x => String(x.retrieval_state || '') === 'READY_WITH_WARNING' || String(x.freshness_state || '') === 'UNKNOWN')) return 'READY_WITH_WARNING';
  return 'READY';
}

function contextById(rows) {
  const map = new Map();
  for (const row of Array.isArray(rows) ? rows : []) if (row && row.entity_id) map.set(String(row.entity_id),row);
  return map;
}

function stageGuidance(stage) {
  switch (stage) {
    case 'PRICE_QUOTE': return {
      objective:'Ordenar el valor dentro del proceso sin alterar alcance clínico.',
      talking:['Identificar con precisión el servicio o producto antes de mencionar precio.','Presentar primero objetivo/proceso y luego valor; no convertir el plan en lista de piezas.','Si el alcance cambia, recalcular el proceso; no restar ítems como descuento.'],
      objection:'No negociar hechos ni fabricar descuentos; aclarar alcance y escalar si falta evidencia.'
    };
    case 'PAYMENT': return {
      objective:'Explicar escenarios de pago sin cambiar el alcance del proceso.',
      talking:['Distinguir pago completo de pago progresivo.','El modo de pago cambia la organización, no la indicación clínica ni el total canónico del mismo alcance.'],
      objection:'Si el paciente necesita cambiar alcance, rediseñar/cotizar el proceso; no ocultar descuento dentro de cuotas.'
    };
    case 'PROMOTION': return {
      objective:'Responder solo con promociones vigentes y gobernadas.',
      talking:['No inventar códigos, descuentos o vigencias.','Un beneficio/topping requiere función y contexto; no usarlo como regalo improvisado.'],
      objection:'Si no existe promoción READY, no prometer una; escalar al asesor comercial.'
    };
    case 'OBJECTION': return {
      objective:'Resolver la objeción preservando comprensión, coherencia y alcance autorizado.',
      talking:['Validar la objeción y volver al objetivo del proceso.','Si el paciente pide quitar algo, explicar impacto y recalcular en vez de hacer una resta automática.'],
      objection:'No responder presión de precio con descuentos inventados ni con afirmaciones clínicas.'
    };
    case 'CONTINUITY': return {
      objective:'Evaluar continuidad ética sin convertir productos o toppings en add-ons universales.',
      talking:['Una recomendación adicional debe mejorar resultado, reducir riesgo de proceso incompleto o proteger la inversión.','Los productos se explican por función y momento dentro del cuidado, no como retail aislado.'],
      objection:'Si no hay relación/evidencia gobernada, no sugerir continuidad específica.'
    };
    case 'BOOKING': return {
      objective:'Mover la conversación hacia coordinación humana de cita sin inventar disponibilidad.',
      talking:['Ofrecer ayudar a coordinar una evaluación o cita.','No afirmar un horario disponible hasta consultar la autoridad de Agenda/WA-6.'],
      objection:'La intención de agendar no autoriza diagnóstico, prescripción ni disponibilidad inventada.'
    };
    case 'INFO': return {
      objective:'Responder la duda con hechos públicos gobernados y evidencia.',
      talking:['Usar solo hechos PUBLIC_CLIENT citados.','No ampliar vacíos con conocimiento genérico del modelo.'],
      objection:'Si la pregunta se vuelve personalizada/ clínica, derivar al equipo clínico.'
    };
    default: return {
      objective:'Entender objetivo y contexto antes de avanzar comercialmente.',
      talking:['Aclarar qué busca la persona y qué dominio/servicio menciona.','No diagnosticar, prescribir ni asumir una necesidad clínica.'],
      objection:'Ante evidencia insuficiente, preguntar o escalar; no inventar.'
    };
  }
}

function buildPlaybook(input) {
  input = input || {};
  const inbound = String(input.inbound || '');
  const stage = input.clinicalRisk === true ? 'CLINICAL_ESCALATION' : classifyStage(inbound);
  const advisorBundle = input.advisorBundle || {items:[]};
  const publicBundle = input.publicBundle || {items:[]};
  const advisorItems = Array.isArray(advisorBundle.items) ? advisorBundle.items : [];
  const publicItems = Array.isArray(publicBundle.items) ? publicBundle.items : [];
  const processContexts = Array.isArray(input.processContexts) ? input.processContexts : [];
  const g = stageGuidance(stage);

  if (stage === 'CLINICAL_ESCALATION') {
    return {
      version:'WA4B-PLAYBOOK-V1',status:'READY',commercial_stage:stage,
      objective:'Derivar la consulta personalizada al equipo clínico sin emitir criterio médico.',
      recommended_next_action:'HUMAN_CLINICAL',
      advisor_talking_points:['Reconocer la consulta sin diagnosticar ni determinar aptitud.','Ofrecer coordinación con el equipo clínico para evaluación segura.'],
      public_safe_knowledge_ids:[],objection_strategy:null,quote_or_payment_context:null,continuity_candidates:[],
      clinical_escalation:{required:true,reason:'PERSONALIZED_CLINICAL_OR_ADVERSE_EVENT_RISK'},policy_escalation:null,
      evidence_refs:[],freshness_state:'NOT_APPLICABLE',send_authority:'HUMAN_ONLY',auto_send:false
    };
  }

  const neededRules = requiredRuleCodes(stage);
  const foundRules = new Set(advisorItems.map(ruleId).filter(Boolean));
  const missingRules = neededRules.filter(code => !foundRules.has(code));
  if (missingRules.length) {
    return {
      version:'WA4B-PLAYBOOK-V1',status:'FAIL_CLOSED',commercial_stage:stage,objective:g.objective,
      recommended_next_action:'HUMAN_COMMERCIAL',advisor_talking_points:g.talking,
      public_safe_knowledge_ids:publicItems.map(x=>String(x.knowledge_id)),objection_strategy:g.objection,
      quote_or_payment_context:null,continuity_candidates:[],clinical_escalation:{required:false,reason:null},
      policy_escalation:{required:true,reason:'GOVERNED_RULE_EVIDENCE_REQUIRED',missing_rule_codes:missingRules},
      evidence_refs:uniqueItems([...advisorItems,...publicItems]).map(evidenceRef).filter(Boolean),
      freshness_state:freshnessState([...advisorItems,...publicItems],processContexts),send_authority:'HUMAN_ONLY',auto_send:false
    };
  }

  if (!publicItems.length && !['OBJECTION','PAYMENT'].includes(stage)) {
    return {
      version:'WA4B-PLAYBOOK-V1',status:'FAIL_CLOSED',commercial_stage:stage,objective:g.objective,
      recommended_next_action:'HUMAN_COMMERCIAL',advisor_talking_points:g.talking,public_safe_knowledge_ids:[],
      objection_strategy:g.objection,quote_or_payment_context:null,continuity_candidates:[],
      clinical_escalation:{required:false,reason:null},policy_escalation:{required:true,reason:'PUBLIC_GOVERNED_EVIDENCE_REQUIRED'},
      evidence_refs:advisorItems.map(evidenceRef).filter(Boolean),freshness_state:freshnessState(advisorItems,processContexts),
      send_authority:'HUMAN_ONLY',auto_send:false
    };
  }

  const ids = uniqueItems([...publicItems,...advisorItems]).map(catalogId).filter(Boolean);
  const byId = contextById(processContexts);
  const matched = ids.map(id => byId.get(id)).filter(Boolean);
  const priceStage = stage === 'PRICE_QUOTE' || stage === 'PAYMENT';
  if (priceStage && ids.length > 0) {
    const missingCtx = ids.filter(id => !byId.has(id));
    const blockedCtx = matched.filter(x => x.ready_for_quote !== true || String(x.price_state || '') !== 'READY' || String(x.freshness_state || '') === 'STALE_REVIEW');
    if (missingCtx.length || blockedCtx.length) {
      return {
        version:'WA4B-PLAYBOOK-V1',status:'FAIL_CLOSED',commercial_stage:stage,objective:g.objective,
        recommended_next_action:'HUMAN_COMMERCIAL',advisor_talking_points:g.talking,
        public_safe_knowledge_ids:publicItems.map(x=>String(x.knowledge_id)),objection_strategy:g.objection,
        quote_or_payment_context:null,continuity_candidates:[],clinical_escalation:{required:false,reason:null},
        policy_escalation:{required:true,reason:'PRICE_CONTEXT_NOT_READY',missing_entity_ids:missingCtx,blocked_entity_ids:blockedCtx.map(x=>String(x.entity_id))},
        evidence_refs:uniqueItems([...advisorItems,...publicItems]).map(evidenceRef).filter(Boolean),
        freshness_state:freshnessState([...advisorItems,...publicItems],processContexts),send_authority:'HUMAN_ONLY',auto_send:false
      };
    }
  }

  if (stage === 'PROMOTION' && !publicItems.some(x => x.domain === 'PROMOTION')) {
    return {
      version:'WA4B-PLAYBOOK-V1',status:'FAIL_CLOSED',commercial_stage:stage,objective:g.objective,
      recommended_next_action:'HUMAN_COMMERCIAL',advisor_talking_points:g.talking,
      public_safe_knowledge_ids:publicItems.map(x=>String(x.knowledge_id)),objection_strategy:g.objection,
      quote_or_payment_context:null,continuity_candidates:[],clinical_escalation:{required:false,reason:null},
      policy_escalation:{required:true,reason:'NO_READY_PROMOTION_EVIDENCE'},
      evidence_refs:uniqueItems([...advisorItems,...publicItems]).map(evidenceRef).filter(Boolean),
      freshness_state:freshnessState([...advisorItems,...publicItems],processContexts),send_authority:'HUMAN_ONLY',auto_send:false
    };
  }

  const quoteContext = priceStage ? matched.filter(x => x.ready_for_quote === true).map(x => ({
    entity_id:String(x.entity_id),entity_type:String(x.entity_type || ''),entity_name:String(x.entity_name || ''),
    quote_price:Number(x.quote_price),price_state:String(x.price_state || ''),freshness_state:String(x.freshness_state || ''),
    commercial_phase_codes:Array.isArray(x.commercial_phase_codes)?x.commercial_phase_codes:[],
    price_evidence_ref:x.price_evidence_ref == null ? null : String(x.price_evidence_ref)
  })) : null;

  const continuity = processContexts.filter(x =>
    String(x.entity_type || '') === 'PRODUCTO' &&
    Array.isArray(x.commercial_phase_codes) && x.commercial_phase_codes.includes('COMMERCIAL_F3_CONTINUITY') &&
    x.ready_for_quote === true
  ).map(x => ({entity_id:String(x.entity_id),entity_name:String(x.entity_name || ''),role:'PRODUCT_SUPPORT_CANDIDATE',auto_add:false,price_evidence_ref:x.price_evidence_ref == null?null:String(x.price_evidence_ref)}));

  const action = stage === 'BOOKING' ? 'OFFER_BOOKING' : 'REPLY';
  const refs = uniqueItems([...advisorItems,...publicItems]).map(evidenceRef).filter(Boolean);
  for (const x of matched) if (x.price_evidence_ref) refs.push({knowledge_id:'price:'+String(x.entity_id),relation:'public.aos_catalogo_servicios',pk:String(x.entity_id),version:String(x.price_evidence_ref),source_code:null,source_locator:null,warning:null});

  return {
    version:'WA4B-PLAYBOOK-V1',status:'READY',commercial_stage:stage,objective:g.objective,
    recommended_next_action:action,advisor_talking_points:g.talking,
    public_safe_knowledge_ids:publicItems.map(x=>String(x.knowledge_id)),objection_strategy:g.objection,
    quote_or_payment_context:quoteContext,continuity_candidates:stage==='CONTINUITY'?continuity:[],
    clinical_escalation:{required:false,reason:null},policy_escalation:null,evidence_refs:refs,
    freshness_state:freshnessState([...advisorItems,...publicItems],processContexts),send_authority:'HUMAN_ONLY',auto_send:false
  };
}

function promptContext(playbook) {
  const p = playbook || {};
  return {
    commercial_stage:p.commercial_stage || 'DISCOVERY',
    objective:p.objective || '',
    recommended_next_action:p.recommended_next_action || 'HUMAN_COMMERCIAL',
    advisor_talking_points:Array.isArray(p.advisor_talking_points)?p.advisor_talking_points.slice(0,6):[],
    objection_strategy:p.objection_strategy || null,
    quote_or_payment_context:p.quote_or_payment_context || null,
    continuity_candidates:Array.isArray(p.continuity_candidates)?p.continuity_candidates.slice(0,8):[],
    freshness_state:p.freshness_state || 'UNKNOWN',
    send_authority:'HUMAN_ONLY'
  };
}

module.exports = {
  RULE_TITLES,RULES_BY_STAGE,normalize,classifyStage,requiredRuleCodes,ruleSearchQueries,
  mergeBundles,buildPlaybook,promptContext,catalogId,ruleId
};
