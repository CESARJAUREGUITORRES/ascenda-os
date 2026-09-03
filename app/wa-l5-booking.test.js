'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {createL5Booking,bookingToolPlan}=require('./wa-l5-booking');

const CID='11111111-1111-4111-8111-111111111111';
const TID='22222222-2222-4222-8222-222222222222';

test('rebook intent always starts stronger verification',()=>{
  const p=bookingToolPlan({booking_readiness:'HIGH',intents:['RESCHEDULE_INTENT'],state:{}},{});
  assert.equal(p.action,'START_REBOOK_VERIFICATION');
  assert.equal(p.requires_strong_verification,true);
  assert.equal(p.write,false);
});

test('explicit confirmation is state proof step, not a direct write',()=>{
  const p=bookingToolPlan({booking_readiness:'HIGH',intents:['CONFIRM_BOOKING'],state:{}},{});
  assert.equal(p.action,'MARK_EXPLICIT_CONFIRMATION');
  assert.equal(p.write,false);
  assert.equal(p.requires_pending_confirmation,true);
});

test('exact governed slot produces prepare-confirmation tool payload',()=>{
  const p=bookingToolPlan(
    {booking_readiness:'HIGH',intents:['BOOKING','SCHEDULE'],state:{requested_time:'10:30'}},
    {status:'REAL_SLOTS_READY',treatment_id:TID,target_date:'2026-09-04',site:'SAN ISIDRO',candidate_slots:[{time:'10:30',role:'DOCTORA',professional_id:'prof-1'}]}
  );
  assert.equal(p.action,'PREPARE_EXPLICIT_CONFIRMATION');
  assert.equal(p.write,false);
  assert.equal(p.payload.treatment_id,TID);
  assert.equal(p.payload.time,'10:30');
  assert.equal(p.explicit_confirmation_required,true);
  assert.equal(p.autonomous_commit_requires_l4,true);
});

test('real slot list is bounded to five and keeps free text',()=>{
  const slots=Array.from({length:9},(_,i)=>({time:`1${i}:00`,role:'ENFERMERIA'}));
  const p=bookingToolPlan({booking_readiness:'HIGH',intents:['BOOKING'],state:{}},{status:'REAL_SLOTS_READY',candidate_slots:slots});
  assert.equal(p.action,'OFFER_REAL_SLOTS');
  assert.equal(p.options.length,5);
  assert.equal(p.free_text_allowed,true);
});

test('adapter routes only to governed L5 RPCs and exact date uses one-day search',async()=>{
  const calls=[];
  const api=createL5Booking({serviceRpc:async(name,payload)=>{calls.push({name,payload});return {data:{ok:true,name}};}});
  const a=await api.availability(CID,{treatment_id:TID,site:'SAN_ISIDRO',date:'2026-09-04'});
  assert.equal(a.ok,true);
  assert.equal(calls[0].name,'aos_wa_l5_availability_v1');
  assert.equal(calls[0].payload.p_search_days,1);
  assert.equal(calls[0].payload.p_site,'SAN ISIDRO');

  await api.prepare(CID,{flow:'BOOK',treatment_id:TID,site:'PUEBLO_LIBRE',date:'2026-09-04',time:'11:00',given_name:'QA',family_name:'Local'});
  assert.equal(calls[1].name,'aos_wa_l5_prepare_confirmation_v1');
  assert.equal(calls[1].payload.p_confirmation_ttl_seconds,600);
});

test('invalid adapter inputs fail locally before any service-role RPC',async()=>{
  let called=false;
  const api=createL5Booking({serviceRpc:async()=>{called=true;return {data:{ok:true}};}});
  const out=await api.prepare(CID,{flow:'BOOK',treatment_id:'not-a-uuid',site:'SAN_ISIDRO',date:'2026-09-04',time:'11:00'});
  assert.equal(out.ok,false);
  assert.equal(out.error,'WA_L5_TREATMENT_REQUIRED');
  assert.equal(called,false);
});
