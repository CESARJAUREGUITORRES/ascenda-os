'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const guard=require('./wa4-response-quality-guard');

function check(reply,runtime,booking){return guard.validate({reply,runtime:runtime||{state:{},intents:[]},contexts:{booking:booking||{}}});}

test('blocks repeated treatment question when treatment is already resolved',()=>{
  const out=check('Perfecto. ¿En qué tratamiento estás interesada?',{state:{treatment:'TOXINA_BOTULINICA'},intents:['INFO']});
  assert.equal(out.ok,false);
  assert.ok(out.violations.includes('REPEATED_TREATMENT_QUESTION'));
});

test('blocks booking confirmation without governed write authority',()=>{
  const out=check('Tu cita está confirmada para mañana a las 10 am.',{state:{requested_day:'TOMORROW',requested_time:'10:00'},intents:['BOOKING']},{status:'REAL_SLOTS_READY',schedule_source_fresh:true,exact_requested_time_available:true,candidate_slot_count:1,confirmation_allowed:false});
  assert.equal(out.ok,false);
  assert.ok(out.violations.includes('UNAUTHORIZED_BOOKING_CONFIRMATION'));
});

test('blocks availability assertion when schedule authority is stale',()=>{
  const out=check('Sí, tenemos disponibilidad mañana a las 10 am.',{state:{requested_day:'TOMORROW',requested_time:'10:00'},intents:['BOOKING','SCHEDULE']},{status:'SCHEDULE_SOURCE_STALE',schedule_source_fresh:false,confirmation_allowed:false});
  assert.equal(out.ok,false);
  assert.ok(out.violations.includes('UNSUPPORTED_AVAILABILITY_ASSERTION'));
});

test('allows compact human validation language when schedule authority is stale',()=>{
  const out=check('Mantengo tu preferencia de las 10 am. Necesito validar la disponibilidad actual antes de confirmarte ese horario.',{state:{requested_day:'TOMORROW',requested_time:'10:00'},intents:['BOOKING','SCHEDULE']},{status:'SCHEDULE_SOURCE_STALE',schedule_source_fresh:false,confirmation_allowed:false});
  assert.equal(out.ok,true);
});

test('blocks internal state leakage and excessive questions',()=>{
  const out=check('Tu identity_state es MATCH y booking_readiness HIGH. ¿Qué día? ¿Qué hora?',{state:{},intents:[]});
  assert.equal(out.ok,false);
  assert.ok(out.violations.includes('INTERNAL_STATE_LEAK'));
  assert.ok(out.violations.includes('EXCESSIVE_QUESTIONS'));
});

test('explicit price question must be addressed before advancing booking',()=>{
  const out=check('Perfecto, ¿qué día deseas agendar?',{state:{treatment:'HIFU'},intents:['TREATMENT_PRICE','BOOKING']});
  assert.equal(out.ok,false);
  assert.ok(out.violations.includes('EXPLICIT_PRICE_UNANSWERED'));
});

test('explicit price may fail closed to validation instead of inventing a number',()=>{
  const out=check('Antes de avanzar con la cita necesito validar el precio vigente para darte el monto correcto.',{state:{treatment:'HIFU'},intents:['TREATMENT_PRICE','BOOKING']});
  assert.equal(out.ok,true);
});

test('one concise question with resolved facts is allowed',()=>{
  const out=check('La atención se realiza en San Isidro. ¿Quieres que revise una fecha disponible?',{state:{treatment:'HIFU',site:null},intents:['LOCATION']});
  assert.equal(out.ok,true);
});
