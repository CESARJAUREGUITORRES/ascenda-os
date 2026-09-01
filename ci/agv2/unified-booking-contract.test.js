const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');

const ROOT=path.resolve(__dirname,'../..');
const mig=fs.readFileSync(path.join(ROOT,'supabase/migrations/20260901013500_agv2_unified_transactional_booking_contract_v1.sql'),'utf8');
const rb=fs.readFileSync(path.join(ROOT,'supabase/rollbacks/20260901013500_agv2_unified_transactional_booking_contract_v1_rollback.sql'),'utf8');
const frozen=fs.readFileSync(path.join(ROOT,'docs/control/AGV2_1_CONVERSATIONAL_BOOKING_CONTRACT_DRAFT.md'),'utf8');
const contract=fs.readFileSync(path.join(ROOT,'docs/control/AGV2_2_TRANSACTIONAL_BOOKING_CONTRACT.md'),'utf8');

test('AGV2-1 business decisions are frozen',()=>{
  assert.match(frozen,/Estado: `BUSINESS_FROZEN`/);
  assert.match(frozen,/primera disponibilidad real/i);
  assert.match(frozen,/mismo appointment lógico/i);
  assert.match(frozen,/hasta \*\*3 fechas\*\*/);
  assert.match(frozen,/hasta \*\*5 slots\*\*/);
  assert.match(frozen,/DNI.*Opcional/is);
  assert.match(frozen,/No hardcodear “evaluación gratuita”/);
});

test('shared BOOK and REBOOK authority is additive and channel-neutral',()=>{
  for(const token of [
    'aos_booking_operations_v2','aos_agenda_events_v2',
    'aos_booking_resolve_selected_slot_v2','aos_booking_commit_core_v2','aos_booking_rebook_core_v2',
    'aos_agenda_commit_booking_v2','aos_agenda_rebook_v2',
    'aos_wa4_commit_booking_v2','aos_wa4_rebook_booking_v2'
  ]) assert.ok(mig.includes(token),`missing ${token}`);
  assert.match(mig,/operation_type text not null check \(operation_type in \('BOOK','REBOOK'\)\)/);
  assert.match(mig,/channel text not null check \(channel in \('AGENDA','WHATSAPP'\)\)/);
  assert.doesNotMatch(mig,/create or replace function public\.aos_wa4_commit_booking_v1\(/);
});

test('slot is checked, locked and checked again before write',()=>{
  const calls=(mig.match(/aos_booking_resolve_selected_slot_v2\(v_t\.id,v_date,v_site,v_time/g)||[]).length;
  assert.ok(calls>=4,`expected repeated BOOK+REBOOK revalidation, got ${calls}`);
  assert.match(mig,/pg_advisory_xact_lock\(hashtextextended\('agv2-slot:'/);
  assert.match(mig,/AGV2_SLOT_NO_LONGER_AVAILABLE/);
  assert.doesNotMatch(mig,/force[_ ]?booking|override[_ ]?capacity/i);
});

test('rebooking mutates the same appointment and appends history',()=>{
  assert.match(mig,/update public\.aos_agenda_citas[\s\S]*where id=p_appointment_id;/);
  assert.match(mig,/event_type[^\n]*RESCHEDULED|,'RESCHEDULED'/);
  assert.match(mig,/AGV2_EVENT_LEDGER_APPEND_ONLY/);
  assert.doesNotMatch(mig,/delete from public\.aos_agenda_citas/i);
  assert.match(contract,/mismo `appointment_id`|mismo appointment/i);
});

test('Agenda uses strong session authority and WA preserves HUMAN_ONLY ownership',()=>{
  assert.match(mig,/aos_app_actor_v3\(p_token,'advisor-agenda',false\)/);
  assert.match(mig,/aos_app_actor_v3\(p_token,'admin-agenda',true\)/);
  assert.match(mig,/AGENDA_2FA_PANEL_REQUIRED/);
  assert.match(mig,/v_conv\.owner_user_id is distinct from p_actor_id/);
  assert.match(mig,/aos_wa_assignments_v1[\s\S]*state='ACTIVE'/);
  assert.match(mig,/HUMAN_ACTIVE','AI_COPILOT/);
});

test('identity conflicts fail closed and optional data does not become invented authority',()=>{
  assert.match(mig,/aos_rev_resolve_patient_identity_v2\('PHONE'/);
  assert.match(mig,/AGV2_IDENTITY_CONFLICT/);
  assert.match(mig,/AGV2_EMAIL_INVALID/);
  assert.doesNotMatch(mig,/DNI_REQUIRED/);
  assert.match(contract,/Email y DNI no son bloqueantes/);
});

test('core has no provider side-effect send and rollback removes only additive surfaces',()=>{
  assert.doesNotMatch(mig,/sendAgentEmail|graph\.facebook|messages\/send|resend\.com/i);
  for(const token of ['aos_wa4_commit_booking_v2','aos_agenda_commit_booking_v2','aos_booking_operations_v2','aos_agenda_events_v2']){
    assert.ok(rb.includes(token),`rollback missing ${token}`);
  }
  assert.doesNotMatch(rb,/aos_wa4_commit_booking_v1/);
});
