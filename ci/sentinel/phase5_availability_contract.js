'use strict';

const fs=require('fs');
const path=require('path');
const ROOT=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(ROOT,p),'utf8');
const json=p=>JSON.parse(read(p));
const ok=(v,m)=>{if(!v)throw new Error(m);};

const f4=read('docs/control/SENTINEL_F4_VALIDATION_REPORT_20260816.md');
const f5=json('sentinel/availability/f5-contract.json');
const compose=read('sentinel/availability/compose.yaml');
const phaseS=read('app/server-phase-s.js');
const sm=require(path.join(ROOT,'sentinel/availability/state-machine.cjs'));

ok(f4.includes('**F4:** `100_COMPLETE`'),'F4_NOT_CERTIFIED');
ok(f4.includes('**Resultado:** `18/18 PASS`'),'F4_GATES_NOT_COMPLETE');
ok(f5.schema_version==='sentinel-availability/v1'&&f5.phase==='F5','F5_CONTRACT_INVALID');
ok(f5.observer.engine==='uptime-kuma','F5_ENGINE_DRIFT');
ok(f5.observer.docker_image==='louislam/uptime-kuma:2','F5_IMAGE_DRIFT');
ok(f5.observer.must_be_independent_from_ascenda_railway_runtime===true,'F5_OBSERVER_INDEPENDENCE_REQUIRED');
ok(f5.observer.same_railway_service_forbidden===true,'F5_SAME_RUNTIME_FORBIDDEN');
ok(f5.observer.public_admin_ui_default===false,'F5_ADMIN_UI_MUST_NOT_DEFAULT_PUBLIC');
ok(f5.privacy.zero_phi_pii===true&&f5.privacy.no_auth_headers===true&&f5.privacy.no_tokens===true,'F5_PRIVACY_DRIFT');
ok(f5.cost.software_license_cost_usd_month===0&&f5.cost.automatic_paid_hosting===false,'F5_COST_GUARD_DRIFT');
ok(f5.deployment.production_deploy_in_f5_foundation===false,'F5_PROD_DEPLOY_FORBIDDEN_IN_FOUNDATION');
ok(f5.anti_flapping.failure_samples_required===3&&f5.anti_flapping.recovery_samples_required===2,'F5_ANTI_FLAP_DRIFT');
ok(f5.anti_flapping.direct_notification_from_uptime_kuma===false&&f5.anti_flapping.notifications_owned_by_phase==='F9','F5_ALERT_SCOPE_DRIFT');

ok(Array.isArray(f5.baseline_monitors)&&f5.baseline_monitors.length===1,'F5_BASELINE_MONITOR_COUNT');
const mon=f5.baseline_monitors[0];
ok(mon.url==='https://ascenda-os-production.up.railway.app/health','F5_HEALTH_URL_DRIFT');
ok(mon.method==='GET'&&mon.expected_http_status===200,'F5_HEALTH_METHOD_STATUS_DRIFT');
ok(mon.expected_json?.ok===true&&mon.expected_json?.service==='ascenda-phase-s'&&mon.expected_json?.child_alive===true&&mon.expected_json?.inner_ready===true,'F5_EXPECTED_HEALTH_DRIFT');
ok(mon.contains_phi_pii===false,'F5_MONITOR_PRIVACY_DRIFT');

ok(phaseS.includes("p==='/health'"),'F5_HEALTH_ROUTE_MISSING');
ok(phaseS.includes("{ok:ready,service:'ascenda-phase-s',child_alive:childAlive,inner_ready:ready}"),'F5_HEALTH_RESPONSE_DRIFT');

ok(compose.includes('image: louislam/uptime-kuma:2'),'F5_COMPOSE_IMAGE_DRIFT');
ok(compose.includes('127.0.0.1:3001:3001'),'F5_KUMA_UI_NOT_LOCALHOST_BOUND');
ok(compose.includes('uptime-kuma-data:/app/data'),'F5_LOCAL_PERSISTENT_VOLUME_MISSING');
ok(!/\b(?:SENTRY_DSN|SUPABASE_SERVICE_ROLE_KEY|SUPABASE_ANON_KEY|RESEND_API_KEY|Authorization|apikey)\b/.test(compose),'F5_SECRET_MATERIAL_IN_COMPOSE');
ok(!compose.includes('network_mode: host'),'F5_HOST_NETWORK_FORBIDDEN');

const c=sm.classifyAvailability;
ok(c({observerFresh:false,consecutiveSuccesses:10})==='UNKNOWN','F5_UNKNOWN_OBSERVER_STALE');
ok(c({observerFresh:true,consecutiveSuccesses:1})==='UNKNOWN','F5_INITIAL_UNKNOWN_DRIFT');
ok(c({observerFresh:true,consecutiveSuccesses:2})==='UP','F5_UP_THRESHOLD_DRIFT');
ok(c({observerFresh:true,consecutiveFailures:1})==='DEGRADED','F5_DEGRADED_DRIFT');
ok(c({observerFresh:true,consecutiveFailures:2})==='DEGRADED','F5_DEGRADED_BEFORE_THRESHOLD_DRIFT');
ok(c({observerFresh:true,consecutiveFailures:3})==='DOWN','F5_DOWN_THRESHOLD_DRIFT');
ok(sm.sentinelHealthState('UP')==='HEALTHY','F5_SENTINEL_UP_MAP');
ok(sm.sentinelHealthState('DEGRADED')==='DEGRADED','F5_SENTINEL_DEGRADED_MAP');
ok(sm.sentinelHealthState('DOWN')==='INCIDENT','F5_SENTINEL_DOWN_MAP');
ok(sm.sentinelHealthState('UNKNOWN')==='UNKNOWN','F5_SENTINEL_UNKNOWN_MAP');
ok(sm.availabilityFingerprint({environment:'production',monitorId:'ascenda-production-health'})==='availability:production:ascenda-production-health','F5_FINGERPRINT_DRIFT');

const serialized=JSON.stringify(f5);
for(const forbidden of ['service_role','Bearer ','@gmail.com','wa_id','dni','paciente','telefono']){
  ok(!serialized.toLowerCase().includes(forbidden.toLowerCase()),`F5_CONTRACT_SENSITIVE_TOKEN:${forbidden}`);
}

console.log(JSON.stringify({
  ok:true,
  certificate:'SENTINEL_F5_AVAILABILITY_FOUNDATION_PASS',
  f4_complete:true,
  observer:'uptime-kuma',
  production_host:'PENDING_APPROVAL',
  production_deploy:false,
  monitor_count:f5.baseline_monitors.length,
  zero_phi_pii:true,
  anti_flapping:true,
  direct_notifications:false,
  state_machine:true
},null,2));
