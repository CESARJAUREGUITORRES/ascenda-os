'use strict';
const fs=require('fs');
const test=require('node:test');
const assert=require('node:assert/strict');

const cc=fs.readFileSync('app/public/calls-performance-v1.js','utf8');
const agenda=fs.readFileSync('app/public/agenda-governed-status-v1.js','utf8');
const panel=fs.readFileSync('app/public/panel-access-authority-v1.js','utf8');
const io=fs.readFileSync('supabase/migrations/20260901033000_p0_callcenter_io_booking_fastpath_v1.sql','utf8');
const agSql=fs.readFileSync('supabase/migrations/20260901034000_p0_agenda_status_governed_v1.sql','utf8');

test('Call Center waits for Loop6 and coalesces duplicated panel reads',()=>{
  assert.match(cc,/__AOS_CC_LOOP6_POSTLOAD_READY__!=='v2\.3-postload'/);
  assert.match(cc,/aos_siguiente_lead_v2'\?'aos_siguiente_lead'/);
  assert.match(cc,/aos_panel_asesor:2500/);
  assert.match(cc,/aos_horarios_semana:30000/);
});

test('Call Center attribution fast-path is transaction-scoped, not a global reporting filter',()=>{
  assert.match(io,/current_setting\('aos\.callcenter_phone',true\)/);
  assert.match(io,/set_config\('aos\.callcenter_phone',v_num,true\)/);
  assert.match(io,/s\.phone='' or l\.numero_limpio=s\.phone/);
  assert.match(io,/aos_callcenter_commit_action_core_impl_v2/);
});

test('Agenda status is an atomic strong-session RPC and preserves WhatsApp direct-write guard',()=>{
  assert.match(agSql,/aos_app_actor_v3\(p_token,'advisor-agenda',false\)/);
  assert.match(agSql,/aos_app_actor_v3\(p_token,'admin-agenda',true\)/);
  assert.match(agSql,/set_config\('aos\.wa4_governed_booking_write','1',true\)/);
  assert.match(agSql,/AGENDA_STATUS_GOVERNED_V1/);
  assert.match(agenda,/rpc\/aos_agenda_set_status_v1/);
  assert.doesNotMatch(agenda,/method:'PATCH'/);
});

test('SPA authority layer loads both P0 operational runtimes without creating network polling',()=>{
  assert.match(panel,/calls-performance-v1\.js/);
  assert.match(panel,/agenda-governed-status-v1\.js/);
  assert.match(panel,/new MutationObserver/);
  assert.doesNotMatch(panel,/setInterval\(/);
});
