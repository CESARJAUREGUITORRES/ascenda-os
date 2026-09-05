'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const copilot=require('../../app/wa4-copilot');
const knowledge=require('../../app/wa4-knowledge');

const H1='11111111-1111-4111-8111-111111111111';
const N1='22222222-2222-4222-8222-222222222222';
const H3='33333333-3333-4333-8333-333333333333';
const N3='44444444-4444-4444-8444-444444444444';
function item(id,name){return {knowledge_id:'service:'+id,domain:'CATALOG',title:name,facts:{tipo:'SERVICIO',nombre:name,categoria:'TOXINA'},authority_tier:10,freshness_state:'FRESH',conflict_state:'CLEAR',retrieval_state:'READY',evidence_ref:{relation:'public.aos_catalogo_servicios',pk:id,version:'v1'}};}
function ctx(id,name,price){return {entity_id:id,entity_type:'SERVICIO',entity_name:name,category:'TOXINA',quote_price:price,precio_base:price,precio_oferta:price,moneda:'PEN',price_state:'READY',freshness_state:'FRESH',ready_for_quote:true,price_evidence_ref:'catalog:'+id};}
function bundle(){return {version:'R6-TEST',audience:'PUBLIC_CLIENT',authority:'GOVERNED_SOURCE_ONLY',generic_llm_authority:false,items:[item(H1,'HUTOX 1 ZONA 15U'),item(N1,'NABOTA 1 ZONA 15U'),item(H3,'HUTOX 3 ZONAS 50U'),item(N3,'NABOTA 3 ZONAS 50U')]};}
function contexts(){return [ctx(H1,'HUTOX 1 ZONA 15U',299),ctx(N1,'NABOTA 1 ZONA 15U',399),ctx(H3,'HUTOX 3 ZONAS 50U',799),ctx(N3,'NABOTA 3 ZONAS 50U',999)];}

test('R6 restores owner-approved Sofia greeting for toxin first contact',()=>{
  const runtime={state:{treatment:'TOXINA_BOTULINICA'},intents:['INFO']};
  const d=copilot.deterministicOwnerApprovedIntroDraft(runtime,'Hola, quisiera información sobre toxina botulínica',[]);
  assert.ok(d);assert.ok(d.reply.startsWith('¡Hola! 👋 Soy Sofía de Zi Vital.'));
  assert.equal(d.reply.includes('Hablas con el asistente'),false);
  assert.equal(d.reply.includes('proteína purificada'),false);
  assert.ok(d.reply.includes('cuéntame qué zona te gustaría mejorar'));
});

test('R6 greeting-only first contact uses prior approved organic identification flow',()=>{
  const d=copilot.deterministicOwnerApprovedIntroDraft({state:{},intents:[]},'hola',[]);
  assert.ok(d);assert.match(d.reply,/Soy Sofía de Zi Vital/);assert.match(d.reply,/ya eres paciente/i);assert.match(d.reply,/primera vez/i);
});

test('R6 patient renderer canonicalizes Zi Vital and strips replacement-character mojibake',()=>{
  const out=copilot.renderWhatsAppText('En Zi��Vital te ayudamos con **S/ 399**.');
  assert.equal(out,'En Zi Vital te ayudamos con *S/ 399*.');
  assert.equal(out.includes('�'),false);
});

test('R6 short follow-up price stays in deterministic toxin fast lane using carried treatment state',()=>{
  const runtime={state:{treatment:'TOXINA_BOTULINICA'},intents:['TREATMENT_PRICE']};
  assert.equal(copilot.isPriceFastLane(runtime),true);
  assert.equal(copilot.isPriceFastLane({state:{treatment:'TOXINA_BOTULINICA'},intents:['TREATMENT_PRICE','PROMOTION_REQUEST']}),false);
});

test('R6 deterministic toxin price reply contains all governed READY prices and valid citations',()=>{
  const priced=copilot.gatePublicCatalogMoney(bundle(),contexts(),'PRICE_QUOTE',{intents:['TREATMENT_PRICE']});
  const draft=copilot.deterministicToxinPriceDraft(priced,contexts());
  assert.ok(draft);assert.equal(draft.needs_human,false);assert.equal(draft.next_action,'REPLY');
  for(const x of ['S/ 299','S/ 399','S/ 799','S/ 999'])assert.ok(draft.reply.includes(x),x);
  assert.equal((draft.reply.match(/\?/g)||[]).length,1);
  assert.equal(draft.cited_knowledge_ids.length,4);
  const grounded=knowledge.validateGroundedSuggestion(draft,priced);assert.equal(grounded.ok,true,grounded.error||'grounding');
});

test('R6 owner-copy and price fast lanes execute before expensive adapters and governed full-path fanout',()=>{
  const src=fs.readFileSync(require.resolve('../../app/wa4-copilot'),'utf8');
  const intro=src.indexOf('const introDraft=!clinicalRisk?deterministicOwnerApprovedIntroDraft');
  const price=src.indexOf('if(!clinicalRisk&&isPriceFastLane(runtime))');
  const adapters=src.indexOf('const [campaignCtx,identityCtx]=await Promise.all');
  const governed=src.indexOf('governed=await buildGovernedContext');
  assert.ok(intro>0&&price>intro&&adapters>price&&governed>adapters);
});
