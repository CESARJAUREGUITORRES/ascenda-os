'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const style=require('../../app/wa4-conversation-style');
const runtimeV2=require('../../app/wa4-conversation-runtime-v2');
const copilot=require('../../app/wa4-copilot');
const knowledge=require('../../app/wa4-knowledge');

const H1='11111111-1111-4111-8111-111111111111';
const N1='22222222-2222-4222-8222-222222222222';
const H3='33333333-3333-4333-8333-333333333333';
const N3='44444444-4444-4444-8444-444444444444';
function item(id,name){return {knowledge_id:'service:'+id,domain:'CATALOG',title:name,facts:{tipo:'SERVICIO',nombre:name,categoria:'TOXINA'},authority_tier:10,freshness_state:'FRESH',conflict_state:'CLEAR',retrieval_state:'READY',evidence_ref:{relation:'public.aos_catalogo_servicios',pk:id,version:'v1'}};}
function ctx(id,name,price){return {entity_id:id,entity_type:'SERVICIO',entity_name:name,category:'TOXINA',quote_price:price,precio_base:price,precio_oferta:price,moneda:'PEN',price_state:'READY',freshness_state:'FRESH',ready_for_quote:true,price_evidence_ref:'catalog:'+id};}
function bundle(){return {version:'R7-TEST',audience:'PUBLIC_CLIENT',authority:'GOVERNED_SOURCE_ONLY',generic_llm_authority:false,items:[item(H1,'HUTOX 1 ZONA 15U'),item(N1,'NABOTA 1 ZONA 15U'),item(H3,'HUTOX 3 ZONAS 50U'),item(N3,'NABOTA 3 ZONAS 50U')]};}
function contexts(){return [ctx(H1,'HUTOX 1 ZONA 15U',299),ctx(N1,'NABOTA 1 ZONA 15U',399),ctx(H3,'HUTOX 3 ZONAS 50U',799),ctx(N3,'NABOTA 3 ZONAS 50U',999)];}
function msg(direction,body,sec){return {direction,message_body:body,created_at:new Date(1788654000000+(sec||0)*1000).toISOString()};}

test('R7 first contact keeps Sofía persona, Zi Vital canon and restrained emoji density',()=>{
  const out=style.firstContactToxin();
  assert.ok(out.startsWith('¡Hola! 👋 Soy Sofía de Zi Vital. Claro, te ayudo 😊'));
  assert.ok(out.includes('toxina botulínica'));
  assert.ok(out.includes('✨'));
  assert.equal(out.includes('ZI VITAL'),false);
  assert.equal(out.includes('�'),false);
  const m=style.styleMetrics(out);
  assert.ok(m.emoji>=2&&m.emoji<=4,m.emoji);
  assert.ok(m.chars<320,m.chars);
});

test('R7 price card matches Zi Vital commercial WhatsApp pattern: short heading, grouped prices, bullets and one CTA',()=>{
  const out=style.toxinPriceCard([
    {brand:'HUTOX',zones:1,units:'15U',price:299,priceLabel:'S/ 299'},
    {brand:'NABOTA',zones:1,units:'15U',price:399,priceLabel:'S/ 399'},
    {brand:'HUTOX',zones:3,units:'50U',price:799,priceLabel:'S/ 799'},
    {brand:'NABOTA',zones:3,units:'50U',price:999,priceLabel:'S/ 999'}
  ]);
  for(const x of ['*TOXINA BOTULÍNICA*','*1 zona*','*3 zonas*','HUTOX 15U — S/ 299','NABOTA 15U — S/ 399','HUTOX 50U — S/ 799','NABOTA 50U — S/ 999'])assert.ok(out.includes(x),x);
  assert.equal((out.match(/^• /gm)||[]).length,4);
  assert.equal((out.match(/\?/g)||[]).length,1);
  assert.ok(out.endsWith('😊'));
  const m=style.styleMetrics(out);assert.ok(m.emoji<=4,m.emoji);assert.ok(m.chars<500,m.chars);
});

test('R7 no-promo copy is honest and preserves regular-price card rather than handing off',()=>{
  const out=style.noPromotionCard([{label:'HUTOX · 3 zonas (50U)',price:'S/ 799'},{label:'NABOTA · 3 zonas (50U)',price:'S/ 999'}]);
  assert.match(out,/no tengo una promoción vigente confirmada/i);
  assert.ok(out.includes('*Precios regulares vigentes*'));
  assert.ok(out.includes('S/ 799'));assert.ok(out.includes('S/ 999'));
  assert.ok(out.includes('revisamos una cita 📅'));
  assert.equal(/descuento|oferta exclusiva|promoción vigente:\s*S\//i.test(out),false);
});

test('R7 runtime carries toxin context across a short price follow-up instead of treating it as contextless',()=>{
  const messages=[
    msg('INBOUND','Hola, quisiera información sobre toxina botulínica',0),
    msg('OUTBOUND',style.firstContactToxin(),3),
    msg('INBOUND','cual es el precio?',20)
  ];
  const r=runtimeV2.buildRuntimeContext({messages,conversation:{campaign_source:null}});
  assert.equal(r.state.treatment,'TOXINA_BOTULINICA');
  assert.ok(r.intents.includes('TREATMENT_PRICE'));
  assert.equal(copilot.isPriceFastLane(r),true);
});

test('R7 runtime keeps treatment through promo and booking progression without restarting discovery',()=>{
  const promo=runtimeV2.buildRuntimeContext({messages:[msg('INBOUND','quiero información sobre botox',0),msg('OUTBOUND',style.firstContactToxin(),2),msg('INBOUND','hay alguna promo?',20)],conversation:{}});
  assert.equal(promo.state.treatment,'TOXINA_BOTULINICA');assert.ok(promo.intents.includes('PROMOTION_REQUEST'));
  const booking=runtimeV2.buildRuntimeContext({messages:[msg('INBOUND','quiero información sobre botox',0),msg('OUTBOUND',style.firstContactToxin(),2),msg('INBOUND','quiero agendar una cita',20)],conversation:{}});
  assert.equal(booking.state.treatment,'TOXINA_BOTULINICA');assert.equal(booking.booking_readiness,'HIGH');assert.ok(booking.intents.includes('BOOKING'));
});

test('R7 deterministic price draft uses governed evidence and style card, not prose dump',()=>{
  const priced=copilot.gatePublicCatalogMoney(bundle(),contexts(),'PRICE_QUOTE',{intents:['TREATMENT_PRICE']});
  const draft=copilot.deterministicToxinPriceDraft(priced,contexts());
  assert.ok(draft);assert.equal(draft.needs_human,false);assert.equal(draft.cited_knowledge_ids.length,4);
  assert.ok(draft.reply.includes('*TOXINA BOTULÍNICA*'));
  assert.equal((draft.reply.match(/^• /gm)||[]).length,4);
  const grounded=knowledge.validateGroundedSuggestion(draft,priced);assert.equal(grounded.ok,true,grounded.error||'grounding');
});

test('R7 response-style contract is wired before generic LLM path and retains one Meta text sender',()=>{
  const wa4=fs.readFileSync(require.resolve('../../app/wa4-copilot'),'utf8');
  const bridge=fs.readFileSync(require.resolve('../../app/wa-l10-autonomous-bridge'),'utf8');
  assert.ok(wa4.includes("require('./wa4-conversation-style')"));
  assert.ok(wa4.indexOf('deterministicOwnerApprovedIntroDraft')<wa4.indexOf('resilience.chat'));
  assert.ok(wa4.indexOf('deterministicToxinPriceDraft')<wa4.indexOf('resilience.chat'));
  assert.equal(/graph\.facebook\.com/i.test(wa4),false);
  assert.equal(/graph\.facebook\.com/i.test(bridge),false);
});
