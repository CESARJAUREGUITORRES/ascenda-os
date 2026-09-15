'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {isGenericHifuContext,preferHifuFrozenRows,isGenericHifuPriceFastLane,deterministicHifuPriceDraft,gatePublicCatalogMoney}=require('./wa4-copilot');
const runtime=require('./wa4-conversation-runtime-v2');

function row(title,category){
  return {knowledge_id:'service:'+title,domain:'CATALOG',title,facts:{nombre:title,categoria:category}};
}

test('generic HIFU resolves only to Zi Frozen catalog family when available',()=>{
  const rows=[
    row('HIFU 7D BRAZOS','CORPORAL'),
    row('HIFU CORP ABDOMEN ALTO','CORPORAL'),
    row('ZI FROZEN BEAUTY','HIFU'),
    row('ZI FROZEN CISNE','HIFU'),
    row('ZI FROZEN FULL FACE','HIFU'),
    {knowledge_id:'clinic:hifu',domain:'CLINIC_KNOWLEDGE',title:'HIFU general',facts:{}}
  ];
  const ctx={state:{treatment:'HIFU'}};
  assert.equal(isGenericHifuContext('hola quiero mas informacion sobre el Hifu',ctx),true);
  const out=preferHifuFrozenRows(rows,'hola quiero mas informacion sobre el Hifu',ctx);
  assert.deepEqual(out.filter(x=>x.domain==='CATALOG').map(x=>x.title),[
    'ZI FROZEN BEAUTY','ZI FROZEN CISNE','ZI FROZEN FULL FACE'
  ]);
  assert.ok(!out.some(x=>x.title==='HIFU 7D BRAZOS'));
});

test('body-specific HIFU keeps corporal catalog eligible',()=>{
  const rows=[row('HIFU 7D BRAZOS','CORPORAL'),row('ZI FROZEN BEAUTY','HIFU')];
  const ctx={state:{treatment:'HIFU'}};
  assert.equal(isGenericHifuContext('quiero HIFU para brazos',ctx),false);
  assert.deepEqual(preferHifuFrozenRows(rows,'quiero HIFU para brazos',ctx),rows);
});

test('follow-up benefits and availability retain HIFU treatment context',()=>{
  const messages=[
    {direction:'INBOUND',message_body:'hola quiero mas informacion sobre el Hifu',created_at:'2026-09-14T21:57:44Z'},
    {direction:'OUTBOUND',message_body:'Te cuento sobre HIFU.',created_at:'2026-09-14T21:57:57Z'},
    {direction:'INBOUND',message_body:'cuales son los beneficios ?',created_at:'2026-09-14T21:58:18Z'},
    {direction:'INBOUND',message_body:'disponibilidad ?',created_at:'2026-09-14T21:59:37Z'}
  ];
  const out=runtime.buildRuntimeContext({messages,conversation:{campaign_source:null}});
  assert.equal(out.state.treatment,'HIFU');
  assert.ok(out.intents.includes('SCHEDULE'));
  assert.equal(out.booking_readiness,'HIGH');
});


test('generic HIFU price uses deterministic Zi Frozen hot path and excludes corporal variants',()=>{
  const rt={state:{treatment:'HIFU'},intents:['TREATMENT_PRICE']};
  assert.equal(isGenericHifuPriceFastLane(rt,'Hola, quisiera información sobre HIFU y saber cuánto cuesta'),true);
  assert.equal(isGenericHifuPriceFastLane(rt,'¿Cuánto cuesta HIFU para brazos?'),false);

  const contexts=[
    {entity_id:'11111111-1111-4111-8111-111111111111',entity_type:'SERVICIO',entity_name:'ZI FROZEN BEAUTY',category:'HIFU',mapping_state:'MAPPED',precio_base:599,precio_oferta:599,quote_price:599,moneda:'PEN',price_state:'READY',freshness_state:'FRESH',ready_for_quote:true,price_evidence_ref:'beauty'},
    {entity_id:'22222222-2222-4222-8222-222222222222',entity_type:'SERVICIO',entity_name:'ZI FROZEN FULL FACE',category:'HIFU',mapping_state:'MAPPED',precio_base:699,precio_oferta:699,quote_price:699,moneda:'PEN',price_state:'READY',freshness_state:'FRESH',ready_for_quote:true,price_evidence_ref:'full'},
    {entity_id:'33333333-3333-4333-8333-333333333333',entity_type:'SERVICIO',entity_name:'ZI FROZEN CISNE',category:'HIFU',mapping_state:'MAPPED',precio_base:899,precio_oferta:899,quote_price:899,moneda:'PEN',price_state:'READY',freshness_state:'FRESH',ready_for_quote:true,price_evidence_ref:'cisne'}
  ];
  const items=contexts.map(p=>({
    knowledge_id:'service:'+p.entity_id,domain:'CATALOG',title:p.entity_name,
    facts:{tipo:'SERVICIO',nombre:p.entity_name,categoria:'HIFU',precio_base:p.precio_base,precio_oferta:p.precio_oferta,moneda:'PEN'},
    authority_tier:1,freshness_state:'FRESH',retrieval_state:'READY',
    evidence_ref:{relation:'aos_catalogo_servicios',pk:p.entity_id,version:p.price_evidence_ref}
  }));
  const raw={version:'TEST',audience:'PUBLIC_CLIENT',items,authority:'GOVERNED_SOURCE_ONLY',generic_llm_authority:false};
  const priced=gatePublicCatalogMoney(raw,contexts,'PRICE_QUOTE',rt);
  const draft=deterministicHifuPriceDraft(priced,contexts);
  assert.ok(draft);
  assert.match(draft.reply,/ZI FROZEN/);
  assert.match(draft.reply,/S\/ 599/);
  assert.match(draft.reply,/S\/ 699/);
  assert.match(draft.reply,/S\/ 899/);
  assert.equal(draft.reply.includes('HIFU 7D BRAZOS'),false);
  assert.equal(draft.needs_human,false);
});
