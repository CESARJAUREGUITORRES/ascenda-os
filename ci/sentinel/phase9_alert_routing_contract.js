'use strict';

const fs=require('fs');
const path=require('path');
const ROOT=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(ROOT,p),'utf8');
const json=p=>JSON.parse(read(p));
const ok=(v,m)=>{if(!v)throw new Error(m);};

const f8=json('sentinel/incidents/f8-contract.json');
const f9=json('sentinel/alerts/f9-contract.json');
const router=read('sentinel/alerts/alert-router.cjs');
const dispatcher=read('sentinel/alerts/alert-dispatcher.cjs');
const fake=read('sentinel/alerts/fake-transport.cjs');
const state=read('sentinel/alerts/memory-alert-state.cjs');

ok(f8.phase==='F8'&&f8.persistence_target.production_status==='certified','F9_REQUIRES_F8_CERTIFIED');
ok(f8.persistence_target.production_migration_version==='20260817000618','F9_F8_RUNTIME_PARITY_REQUIRED');
ok(f9.schema_version==='sentinel-alerts/v1'&&f9.phase==='F9','F9_CONTRACT_INVALID');
ok(f9.design.zero_phi_pii===true&&f9.design.secret_free_core===true,'F9_PRIVACY_BOUNDARY_DRIFT');
ok(f9.design.transport_agnostic===true,'F9_TRANSPORT_LOCKIN_FORBIDDEN');
ok(f9.design.telegram_live_configured===false,'F9_TELEGRAM_MUST_BEGIN_UNCONFIGURED');
ok(f9.design.telegram_secret_in_browser_forbidden===true,'F9_BROWSER_SECRET_FORBIDDEN');
ok(f9.design.automatic_remediation===false,'F9_REMEDIATION_SCOPE_DRIFT');

ok(f9.severity_routing.P0.mode==='IMMEDIATE'&&!f9.severity_routing.P0.maintenance_suppressible,'F9_P0_POLICY_DRIFT');
ok(f9.severity_routing.P1.mode==='IMMEDIATE','F9_P1_POLICY_DRIFT');
ok(f9.severity_routing.P2.mode==='DIGEST'&&f9.severity_routing.P2.digest_window_seconds===900,'F9_P2_POLICY_DRIFT');
ok(f9.severity_routing.P3.mode==='PANEL_ONLY','F9_P3_POLICY_DRIFT');
ok(f9.recovery.enabled===true&&f9.recovery.dedup_once_per_resolve_transition===true,'F9_RECOVERY_POLICY_DRIFT');
ok(f9.deduplication.severity_escalation_bypasses_cooldown===true,'F9_ESCALATION_BYPASS_DRIFT');
ok(f9.flapping.transition_threshold===4&&f9.flapping.p0_bypasses_suppression===true,'F9_FLAPPING_POLICY_DRIFT');
ok(f9.maintenance.p0_never_suppressed===true,'F9_MAINTENANCE_P0_DRIFT');
ok(f9.transport.delivery_claim_requires_transport_ack===true&&f9.transport.unconfigured_transport_state==='UNAVAILABLE','F9_DELIVERY_ACK_BOUNDARY_DRIFT');
ok(f9.gates.live_telegram_requires_separate_gate===true,'F9_LIVE_TELEGRAM_GATE_REQUIRED');

for(const src of [router,dispatcher,fake,state]){
  ok(!src.includes('api.telegram.org'),'F9_LIVE_TELEGRAM_ENDPOINT_FORBIDDEN_IN_CORE');
  ok(!/(BOT_TOKEN|TELEGRAM_TOKEN|chat_id\s*=|service_role_key)/i.test(src),'F9_SECRET_LITERAL_OR_FIELD_FORBIDDEN');
}
ok(router.includes('SUPPRESSED_COOLDOWN'),'F9_COOLDOWN_IMPLEMENTATION_MISSING');
ok(router.includes('SUPPRESSED_FLAPPING'),'F9_FLAPPING_IMPLEMENTATION_MISSING');
ok(router.includes('SUPPRESSED_MAINTENANCE'),'F9_MAINTENANCE_IMPLEMENTATION_MISSING');
ok(router.includes('DIGEST_QUEUED')&&router.includes('flushDueDigests'),'F9_DIGEST_IMPLEMENTATION_MISSING');
ok(dispatcher.includes("status:'UNAVAILABLE'"),'F9_UNAVAILABLE_DELIVERY_STATE_MISSING');
ok(dispatcher.includes('renderTelegramEnvelope'),'F9_SANITIZED_RENDERER_MISSING');

console.log(JSON.stringify({
  ok:true,
  certificate:'SENTINEL_F9_ALERT_ROUTING_CONTRACT_PASS',
  f8_certified:true,
  p0_p1_immediate:true,
  p2_grouped:true,
  p3_panel_only:true,
  cooldown:true,
  flapping:true,
  maintenance:true,
  recovery:true,
  zero_phi_pii:true,
  live_telegram_configured:false,
  transport_ack_required:true
},null,2));
