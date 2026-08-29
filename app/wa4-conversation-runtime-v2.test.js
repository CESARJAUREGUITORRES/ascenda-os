'use strict';
const assert=require('assert');
const rt=require('./wa4-conversation-runtime-v2');

function m(direction,text,sec){
  return {direction,message_body:text,created_at:new Date(Date.UTC(2026,7,29,20,0,sec||0)).toISOString()};
}
function has(r,intent){assert(r.intents.includes(intent),'missing intent '+intent+' in '+JSON.stringify(r.intents));}

// Real WhatsApp pattern: fragmented direct booking request should become one semantic turn.
{
  const messages=[
    m('INBOUND','Buenas tardes',0),
    m('INBOUND','Una cita por favor',1),
    m('INBOUND','Puede ser este viernes',2),
    m('INBOUND','A las 7 pm',3),
    m('INBOUND','Me confirma gracias',4)
  ];
  const r=rt.buildRuntimeContext({messages,conversation:{campaign_source:'Toxina · líneas de expresión'}});
  assert.strictEqual(r.semantic_turn.count,5);
  assert.strictEqual(r.semantic_turn.burst,true);
  has(r,'BOOKING'); has(r,'SCHEDULE');
  assert.strictEqual(r.state.treatment,'TOXINA_BOTULINICA');
  assert.strictEqual(r.state.requested_day,'VIERNES');
  assert.strictEqual(r.state.requested_time,'19:00');
  assert.strictEqual(r.booking_readiness,'HIGH');
  assert.strictEqual(r.next_best_action,'CHECK_REQUESTED_SLOT');
}

// Price + session count in adjacent fragments must both survive.
{
  const messages=[m('INBOUND','Hola, el precio de la sesión',0),m('INBOUND','¿Cuántas sesiones tiene que ser?',2)];
  const r=rt.buildRuntimeContext({messages,conversation:{campaign_source:'Bioestimuladores de colágeno para hombres'}});
  has(r,'PRICE_PER_SESSION'); has(r,'SESSION_COUNT');
  assert.strictEqual(r.state.treatment,'BIOESTIMULADOR_COLAGENO');
  assert.strictEqual(r.next_best_action,'ANSWER_EXPLICIT_QUESTIONS');
}

// Hard time constraint must be preserved and checked first.
{
  const messages=[m('INBOUND','Para mañana temprano a las 9 am',0),m('INBOUND','Solo tengo disponibilidad a esa hora porque estaré cerca',2)];
  const r=rt.buildRuntimeContext({messages,conversation:{campaign_source:'Capilar'}});
  has(r,'SCHEDULE'); has(r,'HARD_TIME_CONSTRAINT'); has(r,'PROXIMITY_CONSTRAINT');
  assert.strictEqual(r.state.requested_day,'TOMORROW');
  assert.strictEqual(r.state.requested_time,'09:00');
  assert.strictEqual(r.state.time_constraint,'HARD');
  assert.strictEqual(r.next_best_action,'CHECK_EXACT_SLOT_FIRST');
}

// Minimal Meta reply must inherit campaign treatment instead of restarting discovery.
{
  const r=rt.buildRuntimeContext({messages:[m('INBOUND','Precio',0)],conversation:{campaign_source:'Toxina · líneas de expresión'}});
  has(r,'TREATMENT_PRICE');
  assert.strictEqual(r.state.treatment,'TOXINA_BOTULINICA');
  assert.notStrictEqual(r.next_best_action,'CLARIFY_TREATMENT_OR_GOAL');
}

// Topic switches preserve prior treatment context.
{
  const messages=[m('INBOUND','Quiero información de HIFU',0),m('OUTBOUND','Claro, te ayudo.',5),m('INBOUND','¿Dónde queda?',10)];
  const r=rt.buildRuntimeContext({messages,conversation:{campaign_source:null}});
  has(r,'LOCATION');
  assert.strictEqual(r.state.treatment,'HIFU');
  assert.strictEqual(r.next_best_action,'ANSWER_EXPLICIT_QUESTIONS');
}

// User deferral is a pause, not another close attempt.
{
  const r=rt.buildRuntimeContext({messages:[m('INBOUND','Llamaré la próxima semana para coordinar',0)],conversation:{}});
  has(r,'DEFER_OR_FOLLOW_UP_LATER');
  assert.strictEqual(r.booking_readiness,'PAUSED');
  assert.strictEqual(r.next_best_action,'ACKNOWLEDGE_DEFER');
  assert.strictEqual(r.question_mode,'NONE');
}

// Sunday is closed for booking and must never be offered as a normal option.
{
  const r=rt.buildRuntimeContext({messages:[m('INBOUND','Quiero una cita el domingo',0)],conversation:{campaign_source:'Toxina'}});
  has(r,'BOOKING'); has(r,'SCHEDULE');
  assert.strictEqual(r.state.requested_day,'DOMINGO');
  assert.strictEqual(r.next_best_action,'REJECT_CLOSED_DAY_AND_REQUEST_ALTERNATIVE');
}

// Professional and product/brand questions are explicit intents, not generic discovery.
{
  const r1=rt.buildRuntimeContext({messages:[m('INBOUND','¿La doctora es la que atiende?',0)],conversation:{campaign_source:'Armonización facial'}});
  has(r1,'WHO_PERFORMS');
  assert.strictEqual(r1.next_best_action,'ANSWER_EXPLICIT_QUESTIONS');
  const r2=rt.buildRuntimeContext({messages:[m('INBOUND','¿Con qué productos cuentan?',0)],conversation:{campaign_source:'Capilar'}});
  has(r2,'PRODUCT_OR_BRAND_OPTIONS');
  assert.strictEqual(r2.next_best_action,'ANSWER_EXPLICIT_QUESTIONS');
}

console.log('WA4C Conversation Runtime V2 deterministic tests: PASS');
