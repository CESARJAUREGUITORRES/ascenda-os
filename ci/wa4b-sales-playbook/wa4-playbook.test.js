'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const p=require('../../app/wa4-playbook');

const SERVICE_ID='11111111-1111-4111-8111-111111111111';
const PRODUCT_ID='22222222-2222-4222-8222-222222222222';
function item(id,domain,title,facts,audience){
  return {knowledge_id:id,domain,title,facts:facts||{},authority_tier:domain==='CATALOG'?10:15,freshness_state:domain==='CLINIC_KNOWLEDGE'?'GOVERNED':'FRESH',conflict_state:'CLEAR',retrieval_state:'READY',evidence_ref:{relation:domain==='CLINIC_KNOWLEDGE'?'public.aos_knowledge_nodes_v1':'public.aos_catalogo_servicios',pk:id.split(':').slice(1).join(':'),version:'v1',audience:audience||null,source_code:domain==='CLINIC_KNOWLEDGE'?'ZV_COMMERCIAL_ARCH_2026':null}};
}
function bundle(audience,items){return {version:'T',audience,items,authority:'GOVERNED_SOURCE_ONLY',generic_llm_authority:false};}
function rule(code){return item('clinic:'+code,'CLINIC_KNOWLEDGE',code,{answer:'Regla aprobada',audience:'ADVISOR_INTERNAL'},'ADVISOR_INTERNAL');}
function catalog(id,name,price){return item('service:'+id,'CATALOG',name,{tipo:'SERVICIO',nombre:name,precio_base:price,precio_oferta:price,descripcion_comercial:'Descripción aprobada'});}
function ctx(id,type,name,price,ready=true,moneda='PEN'){return {entity_id:id,entity_type:type,entity_name:name,commercial_phase_codes:type==='PRODUCTO'?['COMMERCIAL_F3_CONTINUITY']:['COMMERCIAL_F2_INTERVENTION'],quote_price:price,moneda,price_state:ready?'READY':'REVIEW_REQUIRED_OFFER_ABOVE_BASE',freshness_state:'FRESH',ready_for_quote:ready,price_evidence_ref:'aos_catalogo_servicios:'+id+':'+moneda+':v1'};}

test('stage classifier separates quote, payment, objection, continuity, booking and clinical escalation',()=>{
  assert.equal(p.classifyStage('¿Cuánto cuesta el tratamiento?'),'PRICE_QUOTE');
  assert.equal(p.classifyStage('¿Se puede pagar en cuotas?'),'PAYMENT');
  assert.equal(p.classifyStage('Me parece muy caro, ¿puedo quitar una parte?'),'OBJECTION');
  assert.equal(p.classifyStage('¿Qué producto uso después para mantenimiento?'),'CONTINUITY');
  assert.equal(p.classifyStage('Quiero agendar una cita'),'BOOKING');
  assert.equal(p.classifyStage('Estoy embarazada, ¿puedo hacerlo?'),'CLINICAL_ESCALATION');
});

test('clinical risk is deterministic human-only and does not require business evidence',()=>{
  const out=p.buildPlaybook({inbound:'Estoy embarazada, ¿puedo hacerlo?',clinicalRisk:true});
  assert.equal(out.status,'READY');
  assert.equal(out.recommended_next_action,'HUMAN_CLINICAL');
  assert.equal(out.send_authority,'HUMAN_ONLY');
  assert.equal(out.auto_send,false);
  assert.equal(out.evidence_refs.length,0);
});

test('price playbook is ready only with governed rules plus 1C ready price+currency context',()=>{
  const publicBundle=bundle('PUBLIC_CLIENT',[catalog(SERVICE_ID,'SERVICIO TEST',450)]);
  const advisorBundle=bundle('ADVISOR_INTERNAL',[catalog(SERVICE_ID,'SERVICIO TEST',450),rule('RULE_MEDICAL_PLAN_TO_COMMERCIAL'),rule('RULE_QUOTE_PROCESS')]);
  const out=p.buildPlaybook({inbound:'¿Cuánto cuesta SERVICIO TEST?',publicBundle,advisorBundle,processContexts:[ctx(SERVICE_ID,'SERVICIO','SERVICIO TEST',450,true,'PEN')]});
  assert.equal(out.status,'READY');
  assert.equal(out.commercial_stage,'PRICE_QUOTE');
  assert.equal(out.quote_or_payment_context[0].quote_price,450);
  assert.equal(out.quote_or_payment_context[0].currency,'PEN');
  assert.equal(out.quote_or_payment_context[0].entity_id,SERVICE_ID);
  assert.equal(out.send_authority,'HUMAN_ONLY');
  assert.equal(out.auto_send,false);
});

test('USD price context keeps USD explicit',()=>{
  const publicBundle=bundle('PUBLIC_CLIENT',[catalog(SERVICE_ID,'SERVICIO USD',1699)]);
  const advisorBundle=bundle('ADVISOR_INTERNAL',[catalog(SERVICE_ID,'SERVICIO USD',1699),rule('RULE_MEDICAL_PLAN_TO_COMMERCIAL'),rule('RULE_QUOTE_PROCESS')]);
  const out=p.buildPlaybook({inbound:'precio SERVICIO USD',publicBundle,advisorBundle,processContexts:[ctx(SERVICE_ID,'SERVICIO','SERVICIO USD',1699,true,'USD')]});
  assert.equal(out.status,'READY');
  assert.equal(out.quote_or_payment_context[0].quote_price,1699);
  assert.equal(out.quote_or_payment_context[0].currency,'USD');
});

test('offer-above-base or otherwise non-ready 1C price fails closed',()=>{
  const publicBundle=bundle('PUBLIC_CLIENT',[catalog(SERVICE_ID,'SERVICIO TEST',450)]);
  const advisorBundle=bundle('ADVISOR_INTERNAL',[catalog(SERVICE_ID,'SERVICIO TEST',450),rule('RULE_MEDICAL_PLAN_TO_COMMERCIAL'),rule('RULE_QUOTE_PROCESS')]);
  const out=p.buildPlaybook({inbound:'precio SERVICIO TEST',publicBundle,advisorBundle,processContexts:[ctx(SERVICE_ID,'SERVICIO','SERVICIO TEST',450,false)]});
  assert.equal(out.status,'FAIL_CLOSED');
  assert.equal(out.recommended_next_action,'HUMAN_COMMERCIAL');
  assert.equal(out.policy_escalation.reason,'PRICE_CONTEXT_NOT_READY');
});

test('missing or unsupported currency is price-context fail closed',()=>{
  const publicBundle=bundle('PUBLIC_CLIENT',[catalog(SERVICE_ID,'SERVICIO TEST',450)]);
  const advisorBundle=bundle('ADVISOR_INTERNAL',[catalog(SERVICE_ID,'SERVICIO TEST',450),rule('RULE_MEDICAL_PLAN_TO_COMMERCIAL'),rule('RULE_QUOTE_PROCESS')]);
  for(const moneda of ['', 'EUR']){
    const out=p.buildPlaybook({inbound:'precio SERVICIO TEST',publicBundle,advisorBundle,processContexts:[ctx(SERVICE_ID,'SERVICIO','SERVICIO TEST',450,true,moneda)]});
    assert.equal(out.status,'FAIL_CLOSED');
    assert.equal(out.policy_escalation.reason,'PRICE_CONTEXT_NOT_READY');
  }
});

test('missing governed commercial rule fails closed instead of using generic LLM knowledge',()=>{
  const publicBundle=bundle('PUBLIC_CLIENT',[catalog(SERVICE_ID,'SERVICIO TEST',450)]);
  const advisorBundle=bundle('ADVISOR_INTERNAL',[catalog(SERVICE_ID,'SERVICIO TEST',450),rule('RULE_QUOTE_PROCESS')]);
  const out=p.buildPlaybook({inbound:'precio SERVICIO TEST',publicBundle,advisorBundle,processContexts:[ctx(SERVICE_ID,'SERVICIO','SERVICIO TEST',450)]});
  assert.equal(out.status,'FAIL_CLOSED');
  assert.equal(out.policy_escalation.reason,'GOVERNED_RULE_EVIDENCE_REQUIRED');
  assert.deepEqual(out.policy_escalation.missing_rule_codes,['RULE_MEDICAL_PLAN_TO_COMMERCIAL']);
});

test('promotion intent cannot manufacture a promotion when READY promo evidence is absent',()=>{
  const publicBundle=bundle('PUBLIC_CLIENT',[catalog(SERVICE_ID,'SERVICIO TEST',450)]);
  const advisorBundle=bundle('ADVISOR_INTERNAL',[catalog(SERVICE_ID,'SERVICIO TEST',450),rule('RULE_TOPPINGS_BENEFITS')]);
  const out=p.buildPlaybook({inbound:'¿Hay alguna promoción?',publicBundle,advisorBundle,processContexts:[]});
  assert.equal(out.status,'FAIL_CLOSED');
  assert.equal(out.policy_escalation.reason,'NO_READY_PROMOTION_EVIDENCE');
});

test('continuity exposes only governed F3 product candidates and never auto-adds',()=>{
  const prod=item('service:'+PRODUCT_ID,'CATALOG','PRODUCTO TEST',{tipo:'PRODUCTO',nombre:'PRODUCTO TEST',precio_base:99,precio_oferta:99});
  const publicBundle=bundle('PUBLIC_CLIENT',[prod]);
  const advisorBundle=bundle('ADVISOR_INTERNAL',[prod,rule('RULE_ETHICAL_UPSELL'),rule('RULE_PRODUCTS_AS_EXTENSION')]);
  const out=p.buildPlaybook({inbound:'¿Qué producto uso después para mantenimiento?',publicBundle,advisorBundle,processContexts:[ctx(PRODUCT_ID,'PRODUCTO','PRODUCTO TEST',99)]});
  assert.equal(out.status,'READY');
  assert.equal(out.continuity_candidates.length,1);
  assert.equal(out.continuity_candidates[0].role,'PRODUCT_SUPPORT_CANDIDATE');
  assert.equal(out.continuity_candidates[0].auto_add,false);
  assert.equal(out.send_authority,'HUMAN_ONLY');
});

test('rule queries are deterministic and stage-scoped',()=>{
  assert.deepEqual(p.requiredRuleCodes('PAYMENT'),['RULE_QUOTE_PROCESS','RULE_PAYMENT_SCENARIOS']);
  assert.equal(p.ruleSearchQueries('CONTINUITY').length,2);
  assert.equal(p.ruleSearchQueries('INFO').length,0);
});

test('prompt context cannot grant autonomous send',()=>{
  const x=p.promptContext({commercial_stage:'INFO',recommended_next_action:'REPLY',send_authority:'WHATEVER'});
  assert.equal(x.send_authority,'HUMAN_ONLY');
});

test('copilot integration no longer reads catalog/promotions directly and uses governed contracts',()=>{
  const src=fs.readFileSync(path.join(__dirname,'../../app/wa4-copilot.js'),'utf8');
  assert.equal(src.includes('/rest/v1/aos_catalogo_servicios'),false);
  assert.equal(src.includes('/rest/v1/aos_promociones'),false);
  assert.equal(src.includes('aos_wa4a_knowledge_search_v2'),true);
  assert.equal(src.includes('aos_wa4_process_entity_context_v1'),true);
  assert.equal(src.includes('mapping_confidence'),true);
  assert.equal(src.includes('moneda'),true);
  assert.equal(src.includes('cited_knowledge_ids'),true);
  assert.equal(src.includes('auto_send:false'),true);
});
