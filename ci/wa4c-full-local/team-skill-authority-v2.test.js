'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');

const ROOT=path.resolve(__dirname,'../..');
const resolver=require(path.join(ROOT,'app/wa4-booking-resolver.js'));
const migration=fs.readFileSync(path.join(ROOT,'supabase/migrations/20260901003000_wa4c_team_skill_authority_v2.sql'),'utf8');
const classification=fs.readFileSync(path.join(ROOT,'supabase/migrations/20260901003500_wa4c_team_skill_catalog_classification_v3.sql'),'utf8');
const freeze=fs.readFileSync(path.join(ROOT,'supabase/migrations/20260901030000_wa4c_clinical_matrix_freeze_panel_authority_v1.sql'),'utf8');
const panelRuntime=fs.readFileSync(path.join(ROOT,'app/public/panel-access-authority-v1.js'),'utf8');
const sentinelBoot=fs.readFileSync(path.join(ROOT,'app/public/sentinel-hub-bootstrap.js'),'utf8');

test('AMBOS means either governed clinical role, not two simultaneous professionals',()=>{
  const out=resolver.roleFromRows([{requiere_doctora:true,requiere_enfermeria:true}]);
  assert.equal(out.status,'READY');
  assert.deepEqual(out.roles,['DOCTORA','ENFERMERIA']);
  assert.doesNotMatch(fs.readFileSync(path.join(ROOT,'app/wa4-booking-resolver.js'),'utf8'),/pair==='DN'\)return \{status:'COMPLEX_ROLE_REQUIRES_HUMAN'/);
});

test('Team skill master exposes the missing facial mesotherapy capability without auto-granting it',()=>{
  assert.match(migration,/\('MESOTERAPIA FACIAL','ACTIVO'/);
  assert.match(migration,/MESOTERAPIA C\/ PLASMA FACIAL x1'\),'MESOTERAPIA FACIAL'/);
  assert.match(migration,/MICRONEEDLING FACIAL/);
  assert.match(migration,/BIOREVITALIZACION FACIAL/);
  assert.match(migration,/MESOTERAPIA CORPORAL/);
  assert.doesNotMatch(migration,/update\s+public\.aos_usuarios\s+set\s+servicios/i);
});

test('Equipo user skill authority replicates to booking profiles by exact codigo_asesor',()=>{
  assert.match(migration,/trg_aos_team_sync_professional_services_v2/);
  assert.match(migration,/where p\.codigo_asesor=new\.codigo_asesor/);
  assert.match(migration,/trg_aos_team_guard_profile_services_v2/);
  assert.match(migration,/where u\.codigo_asesor=new\.codigo_asesor/);
});

test('dual-role availability preserves doctor exact-provider and nursing site-pool capacities',()=>{
  assert.match(migration,/'role','DOCTORA','mode','EXACT_PROVIDER'/);
  assert.match(migration,/'libres',1-v_occupied,'capacidad',1/);
  assert.match(migration,/v_capacity:=v_members\*2/);
  assert.match(migration,/'role','ENFERMERIA','mode','SITE_POOL'/);
  assert.match(migration,/'MULTI_ROLE'/);
});

test('WhatsApp commit remains HUMAN_ONLY and revalidates the selected role + slot',()=>{
  assert.match(migration,/HUMAN_ONLY/);
  assert.match(migration,/upper\(coalesce\(s->>'role',''\)\)=v_role/);
  assert.match(migration,/WA4_BOOKING_SLOT_NO_LONGER_AVAILABLE/);
  assert.match(migration,/set_config\('aos\.wa4_governed_booking_write','1',true\)/);
  assert.doesNotMatch(migration,/(auto_reply_enabled|ai_send_enabled|auto_routing_enabled)\s*=\s*true/i);
});

test('cannulas are products and remain outside booking capability authority',()=>{
  assert.match(migration,/Cannulas remain intentionally unmapped/);
  assert.doesNotMatch(migration,/aos_booking_norm_v1\('CÁNULAS AZULES 23G'\)/);
  assert.doesNotMatch(migration,/aos_booking_norm_v1\('CÁNULAS ROSADAS 18G'\)/);
  assert.match(classification,/'INSUMOS CLÍNICOS','PRODUCTO'/);
  assert.match(classification,/where nombre in \('CÁNULAS AZULES 23G','CÁNULAS ROSADAS 18G'\)/);
  assert.match(classification,/set tipo='PRODUCTO'/);
  assert.match(classification,/categoria='INSUMOS CLÍNICOS'/);
  assert.match(classification,/requiere_doctora=false/);
  assert.match(classification,/requiere_enfermeria=false/);
});

test('HIFU is governed as doctor-only in category, service rows and Team skill master',()=>{
  assert.match(classification,/where upper\(nombre\)='HIFU'/);
  assert.match(classification,/rol_profesional='DOCTORA'/);
  assert.match(classification,/where upper\(coalesce\(categoria,''\)\)='HIFU'/);
  assert.match(classification,/set requiere_doctora=true,\s*requiere_enfermeria=false/);
  assert.match(classification,/where upper\(tratamiento\)='HIFU'/);
  assert.match(classification,/WA4C_HIFU_DOCTOR_ONLY_SERVICE_FAILED/);
  assert.match(classification,/WA4C_HIFU_DOCTOR_ONLY_SKILL_FAILED/);
});

test('Clinical Matrix Freeze converts inherited child truth into explicit rows without overwriting existing scope',()=>{
  assert.match(freeze,/CLINICAL_MATRIX_FREEZE_V1/);
  assert.match(freeze,/not exists \([\s\S]*aos_professional_procedure_scope_v1/);
  assert.match(freeze,/on conflict \(codigo_asesor,capability,procedure_key\) do nothing/);
  assert.match(freeze,/ZIV-002','ZIV-003','ZIV-004','ZIV-006','ZIV-007','ZIV-008/);
});

test('Roles y Permisos governs mixed admin + operational sidebar from explicit paneles_acceso',()=>{
  assert.match(panelRuntime,/SIDEBAR_ADMIN,allowed,seen/);
  assert.match(panelRuntime,/SIDEBAR_ASESOR,allowed,seen/);
  assert.match(panelRuntime,/if\(isPanelId\(id\)&&!hasPanel\(id\)\)/);
  assert.match(panelRuntime,/advisor-calls/);
  assert.match(panelRuntime,/advisor-commissions/);
  assert.doesNotMatch(panelRuntime,/nivel\s*<=\s*1[^\n]*return true/);
});

test('Team privilege writes require strong 2FA admin-team authority and hierarchy checks',()=>{
  assert.match(freeze,/aos_app_actor_v3\(p_token,'admin-team',true\)/);
  assert.match(freeze,/SUPER_ADMIN_NOT_DELEGABLE/);
  assert.match(freeze,/SUPER_ADMIN_SELF_DEMOTION_BLOCKED/);
  assert.match(freeze,/ADMIN_PANEL_REQUIRES_ADMIN_LEVEL/);
  assert.match(freeze,/SALES_INTELLIGENCE_OWNER_ONLY/);
  assert.match(freeze,/AOS_TEAM_ACCESS_RPC_REQUIRED/);
  assert.match(panelRuntime,/aos_team_set_access_v1/);
  assert.match(panelRuntime,/aos_app_token/);
});

test('Previously hardcoded admin surfaces become selectable and Sentinel requires explicit assignment',()=>{
  for(const id of ['admin-catalogo','admin-inventario','admin-studio','admin-sentinel']) assert.match(freeze,new RegExp(id));
  assert.match(sentinelBoot,/panelList\(\)\.indexOf\('admin-sentinel'\)>=0/);
  assert.match(sentinelBoot,/panel-access-authority-v1\.js/);
});
