'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');

const team=fs.readFileSync('app/public/admin-team.html','utf8');
const ui=fs.readFileSync('app/public/admin-team-skill-hierarchy.js','utf8');
const mig=fs.readFileSync('supabase/migrations/20260901012000_wa4c_professional_skill_hierarchy_v1.sql','utf8');

test('Admin Equipo loads hierarchy runtime',()=>{
  assert.match(team,/admin-team-skill-hierarchy\.js\?v=20260901-1/);
  assert.match(ui,/aos_team_skill_hierarchy_v1/);
  assert.match(ui,/aos_team_save_skill_hierarchy_v1/);
  assert.match(ui,/categor[ií]a → skill → procedimiento → profesional → horario/i);
});

test('hierarchy DB authority is explicit and fail-closed',()=>{
  for(const token of [
    'aos_booking_procedure_map_v1',
    'aos_professional_procedure_scope_v1',
    'aos_booking_procedure_for_service_v1',
    'aos_professional_can_service_v1',
    'aos_team_skill_hierarchy_v1',
    'aos_team_save_skill_hierarchy_v1',
    'aos_team_skill_hierarchy_audit_v1',
    "'PROCEDURE_UNMAPPED'"
  ]) assert.ok(mig.includes(token),`missing ${token}`);
  assert.match(mig,/public\.aos_professional_can_service_v1\(p\.id::text,v_t\.id\)/);
});

test('commercial variants collapse under clinical procedures',()=>{
  for(const token of ['CELLBOOSTER GLOW','NANOPLASMA FACIAL','MESOGLOW','HUTOX','NABOTA','HIPERHIDROSIS','HIFU ABDOMEN']){
    assert.ok(mig.includes(token),`missing procedure ${token}`);
  }
});

test('backward compatibility is inherit-by-default, explicit scopes opt in',()=>{
  assert.match(mig,/if not v_has_scope then return true; end if;/);
  assert.match(ui,/scope_mode/);
  assert.match(ui,/mode:'INHERIT'/);
  assert.match(ui,/mode:'EXPLICIT'/);
});

test('HUMAN_ONLY controls are not enabled by hierarchy change',()=>{
  assert.doesNotMatch(mig,/ai_send_enabled\s*=\s*true/i);
  assert.doesNotMatch(mig,/auto_reply_enabled\s*=\s*true/i);
  assert.doesNotMatch(mig,/auto_routing_enabled\s*=\s*true/i);
});
