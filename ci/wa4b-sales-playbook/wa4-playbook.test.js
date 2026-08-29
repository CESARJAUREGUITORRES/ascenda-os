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
function catalog(id,name,price,extra){return item('service:'+id,'CATALOG',name,Object.assign({tipo:'SERVICIO',nombre:name,precio_base:price,precio_oferta:price,descripcion_comercial:'Descripción aprobada'},extra||{}));}
function thinCatalog(id,name,price,extra){return item('service:'+id,'CATALOG',name,Object.assign({tipo:'SERVICIO',nombre:name,precio_base:price,precio_oferta:price,descripcion_comercial:'',beneficios:'',faqs:[]},extra||{}));}
function ctx(id,type,name,price,ready=true,moneda='PEN'){return {entity_id:id,entity_type:type,entity_name:name,commercial_phase_codes:type==='PRODUCTO'?['COMMERCIAL_F3_CONTINUITY']:['COMMERCIAL_F2_INTERVENTION'],quote_price:price,moneda,price_state:ready?'READY':'REVIEW_REQUIRED_OFFER_ABOVE_BASE',freshness_state:'FRESH',ready_for_quote:ready,price_evidence_ref:'aos_catalogo_servicios:'+id+':'+moneda+':v1'};}

function assertSafe(out){
  assert.equal(out.send_authority,'HUMAN_ONLY');
  assert.equal(out.auto_send,false);
}

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
  assertSafe(out);
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
  assertSafe(out);
});

test('USD price context keeps USD explicit',()=>{
  const publicBundle=bundle('PUBLIC_CLIENT',[catalog(SERVICE_ID,'SERVICIO USD',1699)]);
  const advisorBundle=bundle('ADVISOR_INTERNAL',[catalog(SERVICE_ID,'SERVICIO USD',1699),rule('RULE_MEDICAL_PLAN_TO_COMMERCIAL'),rule('RULE_QUOTE_PROCESS')]);
  const out=p.buildPlaybook({inbound:'precio SERVICIO USD',publicBundle,advisorBundle,processContexts:[ctx(SERVICE_ID,'SERVICIO','SERVICIO USD',1699,true,'USD')]});
  assert.equal(out.status,'READY');
  assert.equal(out.quote_or_payment_context[0].quote_price,1699);
  assert.equal(out.quote_or_payment_context[0].currency,'USD');
  assertSafe(out);
});

test('offer-above-base or otherwise non-ready 1C price fails closed',()=>{
  const publicBundle=bundle('PUBLIC_CLIENT',[catalog(SERVICE_ID,'SERVICIO TEST',450)]);
  const advisorBundle=bundle('ADVISOR_INTERNAL',[catalog(SERVICE_ID,'SERVICIO TEST',450),rule('RULE_MEDICAL_PLAN_TO_COMMERCIAL'),rule('RULE_QUOTE_PROCESS')]);
  const out=p.buildPlaybook({inbound:'precio SERVICIO TEST',publicBundle,advisorBundle,processContexts:[ctx(SERVICE_ID,'SERVICIO','SERVICIO TEST',450,false)]});
  assert.equal(out.status,'FAIL_CLOSED');
  assert.equal(out.recommended_next_action,'HUMAN_COMMERCIAL');
  assert.equal(out.policy_escalation.reason,'PRICE_CONTEXT_NOT_READY');
  assertSafe(out);
});

test('missing or unsupported currency is price-context fail closed',()=>{
  const publicBundle=bundle('PUBLIC_CLIENT',[catalog(SERVICE_ID,'SERVICIO TEST',450)]);
  const advisorBundle=bundle('ADVISOR_INTERNAL',[catalog(SERVICE_ID,'SERVICIO TEST',450),rule('RULE_MEDICAL_PLAN_TO_COMMERCIAL'),rule('RULE_QUOTE_PROCESS')]);
  for(const moneda of ['', 'EUR']){
    const out=p.buildPlaybook({inbound:'precio SERVICIO TEST',publicBundle,advisorBundle,processContexts:[ctx(SERVICE_ID,'SERVICIO','SERVICIO TEST',450,true,moneda)]});
    assert.equal(out.status,'FAIL_CLOSED');
    assert.equal(out.policy_escalation.reason,'PRICE_CONTEXT_NOT_READY');
    assertSafe(out);
  }
});

test('missing governed commercial rule fails closed instead of using generic LLM knowledge',()=>{
  const publicBundle=bundle('PUBLIC_CLIENT',[catalog(SERVICE_ID,'SERVICIO TEST',450)]);
  const advisorBundle=bundle('ADVISOR_INTERNAL',[catalog(SERVICE_ID,'SERVICIO TEST',450),rule('RULE_QUOTE_PROCESS')]);
  const out=p.buildPlaybook({inbound:'precio SERVICIO TEST',publicBundle,advisorBundle,processContexts:[ctx(SERVICE_ID,'SERVICIO','SERVICIO TEST',450)]});
  assert.equal(out.status,'FAIL_CLOSED');
  assert.equal(out.policy_escalation.reason,'GOVERNED_RULE_EVIDENCE_REQUIRED');
  assert.deepEqual(out.policy_escalation.missing_rule_codes,['RULE_MEDICAL_PLAN_TO_COMMERCIAL']);
  assertSafe(out);
});

test('INFO fails closed for a thin catalog row even when price and included benefit exist',()=>{
  const thin=thinCatalog(SERVICE_ID,'SERVICIO PARCIAL',699,{included_benefit:'1 sesión LED',included_benefit_source:'CATALOG_SEP2026_CURRENT_SKU'});
  const out=p.buildPlaybook({inbound:'¿Qué es SERVICIO PARCIAL?',publicBundle:bundle('PUBLIC_CLIENT',[thin]),advisorBundle:bundle('ADVISOR_INTERNAL',[thin]),processContexts:[]});
  assert.equal(out.status,'FAIL_CLOSED');
  assert.equal(out.recommended_next_action,'HUMAN_COMMERCIAL');
  assert.equal(out.policy_escalation.reason,'PUBLIC_INFO_EVIDENCE_INSUFFICIENT');
  assertSafe(out);
});

test('INFO accepts service-specific public description and preserves canonical included benefit as evidence fact',()=>{
  const rich=catalog(SERVICE_ID,'SERVICIO INFO',699,{included_benefit:'1 sesión LED',included_benefit_source:'CATALOG_SEP2026_CURRENT_SKU'});
  const out=p.buildPlaybook({inbound:'¿Qué es SERVICIO INFO?',publicBundle:bundle('PUBLIC_CLIENT',[rich]),advisorBundle:bundle('ADVISOR_INTERNAL',[rich]),processContexts:[]});
  assert.equal(out.status,'READY');
  assert.equal(out.commercial_stage,'INFO');
  assert.equal(rich.facts.included_benefit,'1 sesión LED');
  assertSafe(out);
});

test('promotion intent cannot manufacture a promotion when READY promo evidence is absent',()=>{
  const publicBundle=bundle('PUBLIC_CLIENT',[catalog(SERVICE_ID,'SERVICIO TEST',450)]);
  const advisorBundle=bundle('ADVISOR_INTERNAL',[catalog(SERVICE_ID,'SERVICIO TEST',450),rule('RULE_TOPPINGS_BENEFITS')]);
  const out=p.buildPlaybook({inbound:'¿Hay alguna promoción?',publicBundle,advisorBundle,processContexts:[]});
  assert.equal(out.status,'FAIL_CLOSED');
  assert.equal(out.policy_escalation.reason,'NO_READY_PROMOTION_EVIDENCE');
  assertSafe(out);
});

test('continuity exposes only governed F3 product candidates and never auto-adds',()=>{
  const prod=item('service:'+PRODUCT_ID,'CATALOG','PRODUCTO TEST',{tipo:'PRODUCTO',nombre:'PRODUCTO TEST',precio_base:99,precio_oferta:99,descripcion_comercial:'Producto aprobado'});
  const publicBundle=bundle('PUBLIC_CLIENT',[prod]);
  const advisorBundle=bundle('ADVISOR_INTERNAL',[prod,rule('RULE_ETHICAL_UPSELL'),rule('RULE_PRODUCTS_AS_EXTENSION')]);
  const out=p.buildPlaybook({inbound:'¿Qué producto uso después para mantenimiento?',publicBundle,advisorBundle,processContexts:[ctx(PRODUCT_ID,'PRODUCTO','PRODUCTO TEST',99)]});
  assert.equal(out.status,'READY');
  assert.equal(out.continuity_candidates.length,1);
  assert.equal(out.continuity_candidates[0].role,'PRODUCT_SUPPORT_CANDIDATE');
  assert.equal(out.continuity_candidates[0].auto_add,false);
  assertSafe(out);
});

test('WA-4C official canary matrix is frozen before LIVE execution',()=>{
  const service=catalog(SERVICE_ID,'SERVICIO CANARY',450,{beneficios:'Beneficio comercial aprobado'});
  const product=item('service:'+PRODUCT_ID,'CATALOG','PRODUCTO CANARY',{tipo:'PRODUCTO',nombre:'PRODUCTO CANARY',descripcion_comercial:'Producto de continuidad aprobado',precio_base:99,precio_oferta:99});
  const cases=[
    {
      name:'INFO',
      input:{inbound:'¿Qué es SERVICIO CANARY?',publicBundle:bundle('PUBLIC_CLIENT',[service]),advisorBundle:bundle('ADVISOR_INTERNAL',[service]),processContexts:[]},
      expect:{status:'READY',stage:'INFO',action:'REPLY'}
    },
    {
      name:'PRICE_PEN',
      input:{inbound:'¿Cuánto cuesta SERVICIO CANARY?',publicBundle:bundle('PUBLIC_CLIENT',[service]),advisorBundle:bundle('ADVISOR_INTERNAL',[service,rule('RULE_MEDICAL_PLAN_TO_COMMERCIAL'),rule('RULE_QUOTE_PROCESS')]),processContexts:[ctx(SERVICE_ID,'SERVICIO','SERVICIO CANARY',450,true,'PEN')]},
      expect:{status:'READY',stage:'PRICE_QUOTE',action:'REPLY',currency:'PEN'}
    },
    {
      name:'PRICE_USD',
      input:{inbound:'precio SERVICIO CANARY',publicBundle:bundle('PUBLIC_CLIENT',[service]),advisorBundle:bundle('ADVISOR_INTERNAL',[service,rule('RULE_MEDICAL_PLAN_TO_COMMERCIAL'),rule('RULE_QUOTE_PROCESS')]),processContexts:[ctx(SERVICE_ID,'SERVICIO','SERVICIO CANARY',1699,true,'USD')]},
      expect:{status:'READY',stage:'PRICE_QUOTE',action:'REPLY',currency:'USD'}
    },
    {
      name:'PAYMENT',
      input:{inbound:'¿Se puede pagar en cuotas?',publicBundle:bundle('PUBLIC_CLIENT',[service]),advisorBundle:bundle('ADVISOR_INTERNAL',[service,rule('RULE_QUOTE_PROCESS'),rule('RULE_PAYMENT_SCENARIOS')]),processContexts:[ctx(SERVICE_ID,'SERVICIO','SERVICIO CANARY',450,true,'PEN')]},
      expect:{status:'READY',stage:'PAYMENT',action:'REPLY',currency:'PEN'}
    },
    {
      name:'OBJECTION',
      input:{inbound:'Me parece muy caro, ¿puedo quitar una parte?',publicBundle:bundle('PUBLIC_CLIENT',[service]),advisorBundle:bundle('ADVISOR_INTERNAL',[service,rule('RULE_QUOTE_PROCESS'),rule('RULE_RECALCULATE_PROCESS')]),processContexts:[ctx(SERVICE_ID,'SERVICIO','SERVICIO CANARY',450,true,'PEN')]},
      expect:{status:'READY',stage:'OBJECTION',action:'REPLY'}
    },
    {
      name:'CONTINUITY',
      input:{inbound:'¿Qué producto uso después para mantenimiento?',publicBundle:bundle('PUBLIC_CLIENT',[product]),advisorBundle:bundle('ADVISOR_INTERNAL',[product,rule('RULE_ETHICAL_UPSELL'),rule('RULE_PRODUCTS_AS_EXTENSION')]),processContexts:[ctx(PRODUCT_ID,'PRODUCTO','PRODUCTO CANARY',99,true,'PEN')]},
      expect:{status:'READY',stage:'CONTINUITY',action:'REPLY',continuity:1}
    },
    {
      name:'CLINICAL_ESCALATION',
      input:{inbound:'Estoy embarazada, ¿puedo hacerlo?',clinicalRisk:true},
      expect:{status:'READY',stage:'CLINICAL_ESCALATION',action:'HUMAN_CLINICAL'}
    }
  ];
  assert.equal(cases.length,7);
  for(const c of cases){
    const out=p.buildPlaybook(c.input);
    assert.equal(out.status,c.expect.status,c.name+' status');
    assert.equal(out.commercial_stage,c.expect.stage,c.name+' stage');
    assert.equal(out.recommended_next_action,c.expect.action,c.name+' action');
    if(c.expect.currency)assert.equal(out.quote_or_payment_context[0].currency,c.expect.currency,c.name+' currency');
    if(c.expect.continuity!=null)assert.equal(out.continuity_candidates.length,c.expect.continuity,c.name+' continuity');
    assertSafe(out);
  }
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

test('copilot integration uses governed search v3 and never reads raw catalog/promotions directly',()=>{
  const src=fs.readFileSync(path.join(__dirname,'../../app/wa4-copilot.js'),'utf8');
  assert.equal(src.includes('/rest/v1/aos_catalogo_servicios'),false);
  assert.equal(src.includes('/rest/v1/aos_promociones'),false);
  assert.equal(src.includes('aos_wa4a_knowledge_search_v3'),true);
  assert.equal(src.includes('aos_wa4a_knowledge_search_v2'),false);
  assert.equal(src.includes('aos_wa4_process_entity_context_v1'),true);
  assert.equal(src.includes('mapping_confidence'),true);
  assert.equal(src.includes('moneda'),true);
  assert.equal(src.includes('cited_knowledge_ids'),true);
  assert.equal(src.includes('auto_send:false'),true);
});

test('knowledge v3 migration exposes only canonical per-SKU included benefit and preserves service-role boundary',()=>{
  const migration=fs.readFileSync(path.join(__dirname,'../../supabase/migrations/20260828235500_wa4c_included_benefit_knowledge_v3.sql'),'utf8');
  assert.equal(migration.includes('aos_wa4a_knowledge_search_v2'),true);
  assert.equal(migration.includes("info_extendida #>> '{catalog_sep2026,gift_raw}'"),true);
  assert.equal(migration.includes("'included_benefit'"),true);
  assert.equal(migration.includes("'included_benefit_source', 'CATALOG_SEP2026_CURRENT_SKU'"),true);
  assert.equal(migration.includes('grant execute on function public.aos_wa4a_knowledge_search_v3'),true);
  assert.equal(migration.includes('to service_role'),true);
  assert.equal(migration.includes('aos_promociones'),false);
});
