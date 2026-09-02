'use strict';
const fs=require('fs');
const test=require('node:test');
const assert=require('node:assert/strict');

const cc=fs.readFileSync('app/public/calls-performance-v1.js','utf8');
const agenda=fs.readFileSync('app/public/agenda-governed-status-v1.js','utf8');
const f4=fs.readFileSync('app/public/f4-production-canary-hotfix.js','utf8');
const panel=fs.readFileSync('app/public/panel-access-authority-v1.js','utf8');
const io=fs.readFileSync('supabase/migrations/20260901033000_p0_callcenter_io_booking_fastpath_v1.sql','utf8');
const hot=fs.readFileSync('supabase/migrations/20260902002500_mkt_loop6_p0_booking_hotpath_v3.sql','utf8');
const hotRollback=fs.readFileSync('supabase/rollbacks/20260902002500_mkt_loop6_p0_booking_hotpath_v3_recovery.sql','utf8');
const agSql=fs.readFileSync('supabase/migrations/20260901034000_p0_agenda_status_governed_v1.sql','utf8');

test('Call Center waits for Loop6 and coalesces duplicated panel reads',()=>{
  assert.match(cc,/__AOS_CC_LOOP6_POSTLOAD_READY__!=='v2\.3-postload'/);
  assert.match(cc,/aos_siguiente_lead_v2'\?'aos_siguiente_lead'/);
  assert.match(cc,/aos_panel_asesor:2500/);
  assert.match(cc,/aos_horarios_semana:30000/);
});

test('Call Center governed writes prefer canonical strong-session token and fail closed',()=>{
  const storage=cc.indexOf("sessionStorage.getItem('aos_app_token')");
  const legacy=cc.indexOf('window.AOS_getToken');
  assert.ok(storage>=0,'canonical app token read missing');
  assert.ok(legacy>storage,'legacy shell token must remain fallback after canonical session token');
  assert.match(cc,/^\s*var governed=\/\^aos_callcenter_/m);
  assert.match(cc,/d\.error==='UNAUTHORIZED'&&i<candidates\.length/);
  assert.doesNotMatch(cc,/UNAUTHORIZED.*ok\)ok\(\{ok:true/s);
});

test('Call Center attribution fast-path is transaction-scoped, not a global reporting filter',()=>{
  assert.match(io,/current_setting\('aos\.callcenter_phone',true\)/);
  assert.match(io,/set_config\('aos\.callcenter_phone',v_num,true\)/);
  assert.match(io,/s\.phone='' or l\.numero_limpio=s\.phone/);
  assert.match(io,/aos_callcenter_commit_action_core_impl_v2/);
});

test('Loop6 booking V3 resolves PHONE identity with predicate pushdown and preserves conflict semantics',()=>{
  assert.match(hot,/idx_aos_pacientes_phone_resolve_loop6_v3/);
  assert.match(hot,/idx_aos_f5_source_rows_phone_resolve_loop6_v3/);
  assert.match(hot,/aos_callcenter_resolve_identity_fast_v3/);
  assert.match(hot,/aos_f5_source_rows_phone_resolve_loop6_v3/);
  assert.match(hot,/candidate_count/);
  assert.match(hot,/IDENTITY_CONFLICT/);
  assert.match(hot,/F5_REVIEWED_MATCH/);
  assert.match(hot,/CANONICAL_CURRENT/);
  assert.doesNotMatch(hot,/from public\.aos_rev_patient_identity_alias_v2/i);
});

test('Loop6 booking V3 defers analytical lifecycle but keeps realtime policy evidence',()=>{
  assert.match(hot,/aos_callcenter_patient_state_fast_v3/);
  assert.match(hot,/'lifecycle',null/);
  assert.match(hot,/'lifecycleDeferred',true/);
  assert.match(hot,/priorSale/);
  assert.match(hot,/priorAttention/);
  assert.match(hot,/priorAttendedAppointment/);
  assert.match(hot,/activeAppointment/);
  assert.match(hot,/lastNoShow/);
  assert.match(hot,/ownerFollowupAfterNoShow/);
  assert.match(hot,/aos_callcenter_credit_context_v2/);
  assert.match(hot,/aos_callcenter_patient_state_fast_v3\(v_num,v_event\)/);
  assert.doesNotMatch(hot,/aos_rev_customer_lifecycle_v1\(/);
});

test('Loop6 P0 does not hide the incident by raising statement timeout',()=>{
  assert.doesNotMatch(hot,/statement_timeout/i);
  assert.doesNotMatch(hot,/set_config\([^\n]*statement_timeout/i);
  assert.doesNotMatch(hot,/auto_reply_enabled[\s\S]*true/i);
  assert.doesNotMatch(hot,/ai_send_enabled[\s\S]*true/i);
  assert.doesNotMatch(hot,/auto_routing_enabled[\s\S]*true/i);
});

test('Loop6 booking hotpath has an explicit recovery to the certified patient-state dependency',()=>{
  assert.match(hotRollback,/aos_callcenter_patient_state_v1\(v_num,v_event\)/);
  assert.match(hotRollback,/drop function if exists public\.aos_callcenter_patient_state_fast_v3/);
  assert.match(hotRollback,/drop function if exists public\.aos_callcenter_resolve_identity_fast_v3/);
  assert.match(hotRollback,/drop index if exists public\.idx_aos_f5_source_rows_phone_resolve_loop6_v3/);
});

test('Agenda status is an atomic strong-session RPC and preserves WhatsApp direct-write guard',()=>{
  assert.match(agSql,/aos_app_actor_v3\(p_token,'advisor-agenda',false\)/);
  assert.match(agSql,/aos_app_actor_v3\(p_token,'admin-agenda',true\)/);
  assert.match(agSql,/set_config\('aos\.wa4_governed_booking_write','1',true\)/);
  assert.match(agSql,/AGENDA_STATUS_GOVERNED_V1/);
  assert.match(agenda,/rpc\/aos_agenda_set_status_v1/);
  assert.doesNotMatch(agenda,/method:'PATCH'/);
  assert.doesNotMatch(agenda,/setInterval\(/);
  assert.doesNotMatch(agenda,/setTimeout\(/);
});

test('P0 runtimes reuse the already-certified F4 observer instead of creating new recurrent network owners',()=>{
  assert.match(f4,/calls-performance-v1\.js/);
  assert.match(f4,/agenda-governed-status-v1\.js/);
  assert.match(f4,/ensureAgendaGovernedPostload/);
  assert.doesNotMatch(panel,/calls-performance-v1\.js/);
  assert.doesNotMatch(panel,/agenda-governed-status-v1\.js/);
  assert.doesNotMatch(panel,/MutationObserver/);
});
