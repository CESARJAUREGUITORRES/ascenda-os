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
const startObserver=read('sentinel/availability/creactive/start-observer.sh');
const installObserver=read('sentinel/availability/creactive/install-observer.sh');
const installTask=read('sentinel/availability/creactive/Install-SentinelCreactiveTask.ps1');
const localAgent=read('sentinel/availability/local-observer-agent.py');
const sm=require(path.join(ROOT,'sentinel/availability/state-machine.cjs'));

ok(f4.includes('**F4:** `100_COMPLETE`'),'F4_NOT_CERTIFIED');
ok(f4.includes('**Resultado:** `18/18 PASS`'),'F4_GATES_NOT_COMPLETE');
ok(f5.schema_version==='sentinel-availability/v1.1'&&f5.phase==='F5','F5_CONTRACT_INVALID');
ok(f5.availability_architecture==='hybrid-cloud-plus-local','F5_HYBRID_ARCHITECTURE_DRIFT');

ok(f5.continuous_coverage.required===true,'F5_CONTINUOUS_COVERAGE_REQUIRED');
ok(f5.continuous_coverage.provider==='sentry-uptime','F5_CLOUD_PROVIDER_DRIFT');
ok(f5.continuous_coverage.included_monitors===1,'F5_CLOUD_MONITOR_QUOTA_DRIFT');
ok(f5.continuous_coverage.incremental_cost_usd_month===0,'F5_CLOUD_COST_DRIFT');
ok(f5.continuous_coverage.target_url==='https://ascenda-os-production.up.railway.app/health','F5_CLOUD_TARGET_DRIFT');
ok(f5.continuous_coverage.api_dependency_for_sentinel_core===false,'F5_CLOUD_API_LOCKIN_FORBIDDEN');

ok(f5.observer.engine==='uptime-kuma','F5_ENGINE_DRIFT');
ok(f5.observer.docker_image==='louislam/uptime-kuma:2','F5_IMAGE_DRIFT');
ok(f5.observer.mode==='intermittent-workstation-observer','F5_LOCAL_MODE_DRIFT');
ok(f5.observer.host==='CREACTIVE','F5_LOCAL_HOST_DRIFT');
ok(f5.observer.must_be_independent_from_ascenda_railway_runtime===true,'F5_OBSERVER_INDEPENDENCE_REQUIRED');
ok(f5.observer.same_railway_service_forbidden===true,'F5_SAME_RUNTIME_FORBIDDEN');
ok(f5.observer.public_admin_ui_default===false,'F5_ADMIN_UI_MUST_NOT_DEFAULT_PUBLIC');
ok(f5.observer.restart_policy==='unless-stopped','F5_RESTART_POLICY_DRIFT');
ok(f5.observer.offline_semantics==='UNKNOWN'&&f5.observer.offline_is_not_ascenda_down===true,'F5_LOCAL_OFFLINE_SEMANTICS_DRIFT');

ok(f5.gap_reconciliation.enabled===true,'F5_GAP_RECONCILIATION_DISABLED');
ok(f5.gap_reconciliation.coverage_gap_state==='UNKNOWN','F5_GAP_STATE_DRIFT');
ok(f5.gap_reconciliation.retroactive_health_claims_forbidden===true,'F5_RETROACTIVE_FALSE_GREEN_RISK');
ok(f5.gap_reconciliation.resume_report===true&&f5.gap_reconciliation.persist_observer_heartbeat===true,'F5_RESUME_REPORT_DRIFT');
ok(f5.gap_reconciliation.automatic_cloud_api_query_required===false,'F5_FREE_PLAN_API_DEPENDENCY_FORBIDDEN');

ok(f5.privacy.zero_phi_pii===true&&f5.privacy.no_auth_headers===true&&f5.privacy.no_tokens===true,'F5_PRIVACY_DRIFT');
ok(f5.privacy.no_patient_identifiers===true&&f5.privacy.no_message_content===true&&f5.privacy.no_request_bodies===true,'F5_DATA_BOUNDARY_DRIFT');
ok(f5.privacy.no_provider_secrets_in_monitor_config===true,'F5_PROVIDER_SECRET_BOUNDARY_DRIFT');
ok(f5.cost.software_license_cost_usd_month===0&&f5.cost.sentry_uptime_incremental_cost_usd_month===0,'F5_COST_GUARD_DRIFT');
ok(f5.cost.automatic_paid_hosting===false&&f5.cost.paid_hosting_required_for_hybrid_baseline===false,'F5_AUTOMATIC_SPEND_FORBIDDEN');
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
ok(compose.includes('restart: unless-stopped'),'F5_COMPOSE_RESTART_POLICY_MISSING');
ok(!/\b(?:SENTRY_DSN|SUPABASE_SERVICE_ROLE_KEY|SUPABASE_ANON_KEY|RESEND_API_KEY|Authorization|apikey)\b/.test(compose),'F5_SECRET_MATERIAL_IN_COMPOSE');
ok(!compose.includes('network_mode: host'),'F5_HOST_NETWORK_FORBIDDEN');
ok(!compose.includes('/var/run/docker.sock'),'F5_DOCKER_SOCKET_FORBIDDEN');

ok(startObserver.includes('wait_for_docker'),'F5_LOCAL_DOCKER_WAIT_MISSING');
ok(startObserver.includes('--restart unless-stopped'),'F5_LOCAL_KUMA_RESTART_MISSING');
ok(startObserver.includes('127.0.0.1:3001:3001'),'F5_LOCAL_KUMA_UI_EXPOSURE_DRIFT');
ok(startObserver.includes('exec python3 "$AGENT"'),'F5_LOCAL_AGENT_FOREGROUND_MISSING');
ok(startObserver.includes('SENTINEL_LOCAL_OBSERVER_PYTHON_MISSING'),'F5_LOCAL_PYTHON_GUARD_MISSING');
ok(installObserver.includes('local-observer-agent.py'),'F5_LOCAL_INSTALL_AGENT_DRIFT');
ok(installObserver.includes('.local/share/ascenda-sentinel/availability'),'F5_LOCAL_INSTALL_PATH_DRIFT');
ok(installTask.includes('AtLogOn'),'F5_WINDOWS_LOGON_TRIGGER_MISSING');
ok(installTask.includes('RunLevel Limited'),'F5_WINDOWS_ELEVATION_FORBIDDEN');
ok(installTask.includes('IgnoreNew'),'F5_WINDOWS_DUPLICATE_INSTANCE_GUARD_MISSING');
ok(localAgent.includes("'retroactive_health_claim': False"),'F5_GAP_FALSE_GREEN_GUARD_MISSING');
ok(localAgent.includes("'history_location': 'Sentry Monitors/Uptime'"),'F5_CLOUD_HISTORY_REFERENCE_MISSING');
ok(localAgent.includes('urllib.request'),'F5_AGENT_NOT_STDLIB_HTTP');
ok(!localAgent.includes('requests.'),'F5_AGENT_EXTERNAL_PYTHON_DEPENDENCY_FORBIDDEN');

const c=sm.classifyAvailability;
ok(c({observerFresh:false,consecutiveSuccesses:10})==='UNKNOWN','F5_UNKNOWN_OBSERVER_STALE');
ok(c({observerFresh:true,consecutiveSuccesses:1})==='UNKNOWN','F5_INITIAL_UNKNOWN_DRIFT');
ok(c({observerFresh:true,consecutiveSuccesses:2})==='UP','F5_UP_THRESHOLD_DRIFT');
ok(c({observerFresh:true,consecutiveFailures:1})==='DEGRADED','F5_DEGRADED_DRIFT');
ok(c({observerFresh:true,consecutiveFailures:2})==='DEGRADED','F5_DEGRADED_BEFORE_THRESHOLD_DRIFT');
ok(c({observerFresh:true,consecutiveFailures:3})==='DOWN','F5_DOWN_THRESHOLD_DRIFT');
ok(sm.classifyCoverage({cloudObserverFresh:true,localObserverFresh:true})==='CLOUD_AND_LOCAL','F5_COVERAGE_BOTH_DRIFT');
ok(sm.classifyCoverage({cloudObserverFresh:true,localObserverFresh:false})==='CLOUD_ONLY','F5_COVERAGE_CLOUD_DRIFT');
ok(sm.classifyCoverage({cloudObserverFresh:false,localObserverFresh:true})==='LOCAL_ONLY','F5_COVERAGE_LOCAL_DRIFT');
ok(sm.classifyCoverage({cloudObserverFresh:false,localObserverFresh:false})==='UNKNOWN','F5_COVERAGE_UNKNOWN_DRIFT');
ok(sm.sentinelHealthState('UP')==='HEALTHY','F5_SENTINEL_UP_MAP');
ok(sm.sentinelHealthState('DEGRADED')==='DEGRADED','F5_SENTINEL_DEGRADED_MAP');
ok(sm.sentinelHealthState('DOWN')==='INCIDENT','F5_SENTINEL_DOWN_MAP');
ok(sm.sentinelHealthState('UNKNOWN')==='UNKNOWN','F5_SENTINEL_UNKNOWN_MAP');
ok(sm.availabilityFingerprint({environment:'production',monitorId:'ascenda-production-health'})==='availability:production:ascenda-production-health','F5_FINGERPRINT_DRIFT');

const serialized=[JSON.stringify(f5),compose,startObserver,installObserver,installTask,localAgent].join('\n');
const secretPatterns=[
  /\bsb_secret_[A-Za-z0-9_-]{20,}\b/,
  /\b(?:eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,})\b/,
  /\bBearer\s+[A-Za-z0-9._~-]{20,}\b/i,
  /https:\/\/[A-Za-z0-9_-]{16,}@[A-Za-z0-9.-]+\.ingest(?:\.[A-Za-z0-9.-]+)?\.sentry\.io\/\d+/i,
  /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/,
  /\b(?:sk-(?:proj-)?|xox[baprs]-)[A-Za-z0-9_-]{20,}\b/
];
for(const re of secretPatterns)ok(!re.test(serialized),`F5_MATERIAL_SECRET:${re}`);
ok(!Object.prototype.hasOwnProperty.call(mon,'headers'),'F5_MONITOR_HEADERS_FORBIDDEN');
ok(!Object.prototype.hasOwnProperty.call(mon,'body'),'F5_MONITOR_BODY_FORBIDDEN');
ok(!Object.prototype.hasOwnProperty.call(mon,'username')&&!Object.prototype.hasOwnProperty.call(mon,'password'),'F5_MONITOR_CREDENTIAL_FIELDS_FORBIDDEN');

console.log(JSON.stringify({
  ok:true,
  certificate:'SENTINEL_F5_HYBRID_OBSERVER_CONTRACT_PASS',
  f4_complete:true,
  architecture:f5.availability_architecture,
  cloud_provider:f5.continuous_coverage.provider,
  local_observer:f5.observer.host,
  local_agent_runtime:'python3-stdlib',
  local_offline_semantics:f5.observer.offline_semantics,
  gap_reconciliation:true,
  zero_phi_pii:true,
  incremental_cost_usd_month:0,
  direct_notifications:false,
  state_machine:true
},null,2));
