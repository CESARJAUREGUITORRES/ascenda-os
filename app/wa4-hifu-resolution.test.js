'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {isGenericHifuContext,preferHifuFrozenRows,isGenericHifuPriceFastLane,deterministicHifuPriceDraft,gatePublicCatalogMoney,bookingHotLaneRequested,selectedHifuVariant,deterministicBookingPreflightDraft,deterministicAvailabilityDraft,composePatientReply,hasApprovedIntro,deterministicPlaybookEnvelope}=require('./wa4-copilot');
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
    facts:{tipo:'SERVICIO',nombre:p.entity_name,categoria:'HIFU',precio_base:p.precio_base,precio_oferta:p.precio_oferta,moneda:'PEN',descripcion_comercial:'HIFU usa ultrasonido focalizado para trabajar firmeza y contorno facial.',beneficios:'Estimulación de colágeno profundo. Reducción de flacidez. Definición de contorno facial.'},
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
  assert.match(draft.reply,/estimular colágeno/i);
  assert.match(draft.reply,/flacidez/i);
  assert.match(draft.reply,/pérdida de firmeza/i);
  assert.equal(draft.reply.includes('HIFU 7D BRAZOS'),false);
  assert.equal(draft.needs_human,false);
});


test('availability this week is handled by deterministic booking preflight before knowledge fanout',()=>{
  const rt={booking_readiness:'HIGH',intents:['SCHEDULE'],state:{treatment:'HIFU',requested_day:null,site:null}};
  assert.equal(bookingHotLaneRequested(rt,'¿Qué disponibilidad tienen esta semana?'),true);
  const draft=deterministicBookingPreflightDraft(rt,[],'¿Qué disponibilidad tienen esta semana?');
  assert.ok(draft);
  assert.equal(draft.needs_human,false);
  assert.match(draft.reply,/qué día/i);
  assert.match(draft.reply,/San Isidro/i);
  assert.match(draft.reply,/Pueblo Libre/i);
});

test('generic HIFU booking asks exact Zi Frozen variant after date and site are known',()=>{
  const rt={booking_readiness:'HIGH',intents:['SCHEDULE'],state:{treatment:'HIFU',requested_day:'TOMORROW',site:'SAN_ISIDRO'}};
  const messages=[
    {direction:'INBOUND',message_body:'Quiero HIFU',created_at:'2026-09-15T01:00:00Z'},
    {direction:'OUTBOUND',message_body:'Beauty, Full Face o Cisne',created_at:'2026-09-15T01:00:05Z'},
    {direction:'INBOUND',message_body:'mañana en San Isidro',created_at:'2026-09-15T01:00:10Z'}
  ];
  assert.equal(selectedHifuVariant(messages),null);
  const draft=deterministicBookingPreflightDraft(rt,messages,'mañana en San Isidro');
  assert.ok(draft);
  assert.match(draft.reply,/Beauty/);
  assert.match(draft.reply,/Full Face/);
  assert.match(draft.reply,/Cisne/);
});

test('selected HIFU variant is inferred only from inbound customer messages',()=>{
  const messages=[
    {direction:'OUTBOUND',message_body:'Beauty, Full Face o Cisne',created_at:'2026-09-15T01:00:00Z'},
    {direction:'INBOUND',message_body:'Full Face',created_at:'2026-09-15T01:00:10Z'}
  ];
  assert.equal(selectedHifuVariant(messages),'ZI FROZEN FULL FACE');
});

test('fresh governed booking slots render deterministically without broad RAG',()=>{
  const draft=deterministicAvailabilityDraft({
    status:'REAL_SLOTS_READY',
    candidate_slots:[
      {time:'10:00',professional_name:'Dra. Uno'},
      {time:'11:30',professional_name:'Dra. Dos'}
    ]
  },{booking_readiness:'HIGH'});
  assert.ok(draft);
  assert.equal(draft.needs_human,false);
  assert.match(draft.reply,/10:00/);
  assert.match(draft.reply,/11:30/);
  assert.match(draft.reply,/¿Cuál te acomoda mejor\?/);
});


test('conversation session re-introduces Sofía after a long inactivity gap',()=>{
  const messages=[
    {direction:'OUTBOUND',message_body:'¡Hola! 👋 Soy Sofía de Zi Vital. Claro, te ayudo 😊',created_at:'2026-09-14T20:00:00Z'},
    {direction:'INBOUND',message_body:'Gracias',created_at:'2026-09-14T20:01:00Z'},
    {direction:'INBOUND',message_body:'Hola quisiera información sobre HIFU y cuánto cuesta',created_at:'2026-09-15T14:24:58Z'}
  ];
  assert.equal(hasApprovedIntro(messages),false);
  const out=composePatientReply('✨ Qué genial que te interese HIFU.\n\nEstas son las opciones vigentes.',messages,'Hola quisiera información sobre HIFU y cuánto cuesta');
  assert.match(out,/Soy Sofía de Zi Vital/);
});

test('conversation session does not repeat Sofía inside an active session',()=>{
  const messages=[
    {direction:'INBOUND',message_body:'Hola quisiera información sobre HIFU',created_at:'2026-09-15T14:24:58Z'},
    {direction:'OUTBOUND',message_body:'¡Hola! 👋 Soy Sofía de Zi Vital. Claro, te ayudo 😊',created_at:'2026-09-15T14:25:02Z'},
    {direction:'INBOUND',message_body:'Quisiera agendar una cita',created_at:'2026-09-15T14:25:18Z'}
  ];
  assert.equal(hasApprovedIntro(messages),true);
  const out=composePatientReply('Claro 😊 Para revisar disponibilidad necesito día y sede.',messages,'Quisiera agendar una cita');
  assert.equal((out.match(/Soy Sofía de Zi Vital/g)||[]).length,0);
});


test('deterministic fast lanes preserve a stable playbook envelope',()=>{
  const price=deterministicPlaybookEnvelope('Hola, quisiera información sobre HIFU y saber cuánto cuesta',{next_action:'REPLY',cited_knowledge_ids:['service:test']});
  assert.equal(price.status,'READY');
  assert.equal(price.commercial_stage,'PRICE_QUOTE');
  assert.equal(price.auto_send,false);
  assert.equal(price.send_authority,'HUMAN_ONLY');

  const booking=deterministicPlaybookEnvelope('Quisiera agendar una cita',{next_action:'OFFER_BOOKING',cited_knowledge_ids:[]});
  assert.equal(booking.commercial_stage,'BOOKING');
  assert.equal(booking.recommended_next_action,'OFFER_BOOKING');
});
