'use strict';

const fs=require('fs');
const path=require('path');
const cp=require('child_process');
const ROOT=path.resolve(__dirname,'../..');
const APP=path.join(ROOT,'app');
const P={
  init:'app/sentinel-sentry-init.cjs', railway:'app/railway.json', phaseS:'app/server-phase-s.js',
  contract:'sentinel/sentry/f4-contract.json', fixture:'ci/sentinel/fixtures/f4_sentry_sensitive_event.json',
  f1:'docs/control/SENTINEL_F1_GOVERNANCE_PRIVACY_COST_POLICY.md', f1wf:'.github/workflows/sentinel-phase1-governance.yml',
  f2:'docs/control/SENTINEL_SYSTEM_REGISTRY_V1.json', f3:'sentinel/telemetry/contract-v1.json',
  report:'docs/control/SENTINEL_F4_VALIDATION_REPORT_20260816.md', runbook:'docs/control/SENTINEL_F4_SENTRY_RUNBOOK.md',
  f4wf:'.github/workflows/sentinel-phase4-sentry.yml', wa2wf:'.github/workflows/wa2-conversation-live-inbox.yml',
  phaseSwf:'.github/workflows/phase-s-wa3-stabilization.yml',
  f5:'ci/phase5-historical-identity/f5_upload_contract.js', wa2:'ci/wa2-conversation-live-inbox/ui_contract.py',
  wa3:'ci/wa3-boxes-routing-handoff/ui_contract.py', wa4:'ci/wa4-ai-sales-router/ui_contract.py',
  cartera:'ci/phase2-cartera/ui_contract.py'
};
const ok=(v,m)=>{if(!v)throw new Error(m)};
const read=p=>{const a=path.join(ROOT,p);ok(fs.existsSync(a),`MISSING_FILE:${p}`);return fs.readFileSync(a,'utf8')};
const json=p=>JSON.parse(read(p));

const pkg=json('app/package.json'), f4=json(P.contract), f3=json(P.f3), f2=json(P.f2), fixture=json(P.fixture);
const f1=read(P.f1), f1wf=read(P.f1wf), init=read(P.init), railway=json(P.railway), phaseS=read(P.phaseS);
const report=read(P.report), runbook=read(P.runbook), f4wf=read(P.f4wf), wa2wf=read(P.wa2wf), phaseSwf=read(P.phaseSwf);
const runtimeContracts={f5:read(P.f5),wa2:read(P.wa2),wa3:read(P.wa3),wa4:read(P.wa4),cartera:read(P.cartera)};

// SDK and prior-phase material invariants.
ok(pkg.dependencies?.['@sentry/node']==='10.70.0','SENTRY_SDK_NOT_EXACT_PIN_10_70_0');
ok(f4.schema_version==='sentinel-sentry-core/v1'&&f4.phase==='F4','F4_CONTRACT_INVALID');
ok(f4.sdk?.package==='@sentry/node'&&f4.sdk?.version==='10.70.0','F4_SDK_CONTRACT_DRIFT');
for(const t of ['Zero-PHI/PII','allowlist-first','Session Replay: **OFF**','attachments: **OFF**','pay-as-you-go: OFF']) ok(f1.includes(t),`F1_MATERIAL_INVARIANT_MISSING:${t}`);
ok(f2.rules?.default_observability_state==='UNKNOWN','F2_UNKNOWN_DEFAULT_DRIFT');
ok(f2.rules?.phi_pii_telemetry_allowed===false,'F2_PHI_POLICY_DRIFT');
ok(Array.isArray(f2.runtime?.chain)&&f2.runtime.chain.length===8,'F2_RUNTIME_CHAIN_DRIFT');
ok(fs.readdirSync(path.join(APP,'public')).filter(x=>x.endsWith('.html')).length===41,'F2_PUBLIC_HTML_DRIFT');
ok(f3.schema_version==='sentinel-telemetry-contract/v1','F3_SCHEMA_DRIFT');
ok(f3.design?.zero_phi_pii===true&&f3.design?.allowlist_first===true&&f3.design?.baggage_enabled===false,'F3_PRIVACY_DRIFT');
ok(f3.sampling?.defaults?.production===0,'F3_PRODUCTION_SAMPLING_DRIFT');
for(const broad of ['docs/control/SENTINEL_*.md','ci/sentinel/**']) ok(!f1wf.includes(broad),`F1_WORKFLOW_CROSS_PHASE_TRIGGER_FORBIDDEN:${broad}`);

// F4 activation/privacy/cost invariants.
ok(f4.activation?.default_active===false,'F4_DEFAULT_MUST_OFF');
ok(f4.activation?.master_switch==='SENTINEL_ENABLED'&&f4.activation?.sensor_switch==='SENTINEL_SENTRY_ENABLED','F4_SWITCH_DRIFT');
ok(f4.activation?.canary_switch==='SENTINEL_SENTRY_CANARY_MODE'&&f4.activation?.canary_default===true,'F4_CANARY_DRIFT');
ok(f4.activation?.synthetic_boot_switch==='SENTINEL_SENTRY_SYNTHETIC_ON_BOOT'&&f4.activation?.synthetic_code==='SENTINEL_F4_SYNTHETIC_ERROR','F4_SYNTHETIC_DRIFT');
ok(f4.privacy?.send_default_pii===false&&f4.privacy?.breadcrumbs===0&&f4.privacy?.logs===false&&f4.privacy?.local_variables===false,'F4_PRIVACY_OPTIONS_DRIFT');
ok(f4.sampling?.traces_sample_rate===0,'F4_TRACING_MUST_ZERO');
ok(f4.cost?.incremental_cloud_budget_usd_month===0&&f4.cost?.pay_as_you_go===false,'F4_COST_DRIFT');

// Build/runtime isolation.
const START="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s.js";
ok(railway.deploy?.startCommand===START,`F4_RUNTIME_START_COMMAND_DRIFT:${railway.deploy?.startCommand}`);
ok(f4.activation?.preload_scope==='runtime-command-only-not-global-railway-variable','F4_PRELOAD_SCOPE_DRIFT');
ok(f4.activation?.runtime_start_command===START,'F4_CONTRACT_RUNTIME_COMMAND_DRIFT');
ok(typeof railway.build?.buildCommand==='string'&&!railway.build.buildCommand.includes('NODE_OPTIONS'),'F4_BUILD_MUST_NOT_PRELOAD_SENTRY');
ok(phaseS.includes("env:Object.assign({},process.env,{PORT:String(INNER_PORT)})"),'F4_CHILD_ENV_INHERITANCE_DRIFT');
ok(runbook.includes('NO configurar `NODE_OPTIONS` como variable global de Railway'),'F4_RUNBOOK_GLOBAL_NODE_OPTIONS_GUARD_MISSING');

// Historical contracts accept only legacy Phase-S or exact Sentinel wrapper.
for(const [name,text] of Object.entries(runtimeContracts)){
  const marker=name==='f5'?'sentinelPhaseS':'sentinel_phase_s';
  ok(text.includes(marker),`${name.toUpperCase()}_RUNTIME_CONTRACT_NOT_SENTINEL_AWARE`);
  ok(text.includes('Sentinel preload must not contaminate build'),`${name.toUpperCase()}_BUILD_GUARD_MISSING`);
}
ok(!wa2wf.includes('grep -q "node server-wa2.js" app/railway.json'),'WA2_STALE_START_COMMAND_GREP');
ok(wa2wf.includes('Runtime topology/start-command compatibility is certified by ui_contract.py'),'WA2_WORKFLOW_RUNTIME_CONTRACT_HANDOFF_MISSING');

// FAST pool stays Node/runtime-only; Python and DB contracts remain on Linux Zero-Cost.
ok(!phaseSwf.includes('actions/setup-python@v5'),'PHASE_S_FAST_MUST_NOT_PROVISION_PYTHON');
ok(!phaseSwf.includes('Resolve system Python'),'PHASE_S_FAST_SYSTEM_PYTHON_DEPENDENCY_FORBIDDEN');
ok(phaseSwf.includes('Python and DB/RLS/pgTAP contracts remain owned by Linux Zero-Cost workflows.'),'PHASE_S_LINUX_DELEGATION_MISSING');
ok(phaseSwf.includes('Auth Resend private-vault regression'),'PHASE_S_AUTH_RESEND_GATE_MISSING');
ok(phaseSwf.includes("$sentinel = '\"startCommand\"\\s*:\\s*\"env NODE_OPTIONS=''--require \\./sentinel-sentry-init\\.cjs'' node server-phase-s\\.js\"'"),'PHASE_S_SENTINEL_START_GUARD_MISSING');
ok(phaseSwf.includes('Sentinel preload must not contaminate build'),'PHASE_S_BUILD_GUARD_MISSING');

// Defensive Sentry source options.
for(const t of ['sendDefaultPii: false','tracesSampleRate: 0','enableLogs: false','maxBreadcrumbs: 0','includeLocalVariables: false','beforeBreadcrumb: () => null','beforeSend: event => {','SENTINEL_ENABLED','SENTINEL_SENTRY_ENABLED','SENTINEL_SENTRY_CANARY_MODE','SENTINEL_SENTRY_SYNTHETIC_ON_BOOT','SENTRY_DSN','SENTINEL_F4_SYNTHETIC_ERROR']) ok(init.includes(t),`INIT_GUARD_MISSING:${t}`);

const installedPath=path.join(APP,'node_modules/@sentry/node/package.json');
ok(fs.existsSync(installedPath),'SENTRY_NODE_NOT_INSTALLED_IN_CI');
ok(JSON.parse(fs.readFileSync(installedPath,'utf8')).version==='10.70.0','SENTRY_INSTALLED_VERSION_DRIFT');

// Default-off and missing-DSN fail closed for telemetry only.
process.env.SENTINEL_ENABLED='false';process.env.SENTINEL_SENTRY_ENABLED='false';delete process.env.SENTRY_DSN;
const telemetry=require(path.join(ROOT,P.init));
ok(telemetry.status.requested===false&&telemetry.status.active===false&&telemetry.status.reason==='disabled','F4_DEFAULT_OFF_FAILED');
ok(telemetry.status.canary_mode===true,'F4_CANARY_DEFAULT_FAILED');
ok(telemetry.requested({SENTINEL_ENABLED:'true',SENTINEL_SENTRY_ENABLED:'true'})===true,'F4_DUAL_SWITCH_TRUE_FAILED');
ok(telemetry.requested({SENTINEL_ENABLED:'false',SENTINEL_SENTRY_ENABLED:'true'})===false,'F4_MASTER_KILL_SWITCH_FAILED');
const child="process.env.SENTINEL_ENABLED='true';process.env.SENTINEL_SENTRY_ENABLED='true';delete process.env.SENTRY_DSN;const x=require('./sentinel-sentry-init.cjs');process.stdout.write(JSON.stringify(x.status));";
const childStatus=JSON.parse(cp.execFileSync(process.execPath,['-e',child],{cwd:APP,encoding:'utf8'}).trim());
ok(childStatus.requested===true&&childStatus.active===false&&childStatus.reason==='missing_dsn','F4_MISSING_DSN_FAIL_CLOSED_FAILED');

// Adversarial privacy fixture.
const clean=telemetry.sanitizeEvent(fixture), serialized=JSON.stringify(clean);
for(const leak of ['fake.patient@example.invalid','+51 999 999 999','00000000','fake-access-token','fake-cookie','fake-service-role','fake-secret-value','synthetic AI prompt that must never leave','synthetic private message','FAKE NAME','FAKEUSER','patient-00000000']) ok(!serialized.includes(leak),`F4_PRIVACY_LEAK:${leak}`);
for(const k of ['user','request','breadcrumbs','extra','contexts','transaction','modules','spans']) ok(!(k in clean),`F4_FORBIDDEN_EVENT_FIELD:${k}`);
ok(clean.exception.values[0].value==='[REDACTED_MESSAGE]','F4_EXCEPTION_MESSAGE_NOT_REDACTED');
ok(!('abs_path' in clean.exception.values[0].stacktrace.frames[0]),'F4_ABS_PATH_LEAK');
const synth=telemetry.sanitizeEvent({level:'error',message:'SENTINEL_F4_SYNTHETIC_ERROR',exception:{values:[{type:'Error',value:'SENTINEL_F4_SYNTHETIC_ERROR',stacktrace:{frames:[]}}]},tags:{system:'ascenda-os','sentinel.phase':'F4','service.name':'synthetic.js'}});
ok(telemetry.isSyntheticEvent(synth)===true&&telemetry.isSyntheticEvent(clean)===false,'F4_CANARY_FILTER_DRIFT');
ok(telemetry.normalizeEnvironment('production')==='production','F4_ENVIRONMENT_NORMALIZATION_FAILED');
ok(telemetry.buildRelease({RAILWAY_GIT_COMMIT_SHA:'e3ff8914447c06a2b94b3be5cccbade73526ce0d'}).startsWith('ascenda-os@'),'F4_RELEASE_FORMAT_FAILED');

// Exact F4 scope; no wildcard workflow allowances.
function changedFiles(){
  try{cp.execFileSync('git',['rev-parse','HEAD^2'],{cwd:ROOT,stdio:'ignore'});return cp.execFileSync('git',['diff','--name-only','HEAD^1','HEAD'],{cwd:ROOT,encoding:'utf8'}).split(/\r?\n/).filter(Boolean)}catch(_){
    try{cp.execFileSync('git',['fetch','origin','main','--depth=1'],{cwd:ROOT,stdio:'ignore'});return cp.execFileSync('git',['diff','--name-only','origin/main...HEAD'],{cwd:ROOT,encoding:'utf8'}).split(/\r?\n/).filter(Boolean)}catch(_){return []}
  }
}
const allowed=new Set([P.f4wf,P.wa2wf,P.phaseSwf,P.railway,P.contract,'ci/sentinel/phase4_sentry_contract.js','ci/phase-s/phase-s_contract.js','.github/workflows/cartera-phase2-hardening.yml',P.report,P.runbook,P.f5,P.wa2,P.wa3,P.wa4,P.cartera]);
const changed=changedFiles();
for(const p of changed)ok(allowed.has(p),`F4_SCOPE_UNEXPECTED_FILE:${p}`);
ok(!changed.some(p=>p.startsWith('supabase/migrations/')||p.startsWith('supabase/functions/')),'F4_DB_MUTATION_FORBIDDEN');
const suspicious=[/https:\/\/[A-Za-z0-9_-]{16,}@[A-Za-z0-9.-]+\.ingest(?:\.[A-Za-z0-9.-]+)?\.sentry\.io\/[0-9]+/i,/\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b/,/\bsb_secret_[A-Za-z0-9_-]{20,}\b/,/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/];
for(const p of [P.init,P.contract,P.report,P.runbook,P.f4wf,P.railway])for(const re of suspicious)ok(!re.test(read(p)),`F4_SECRET_GUARD:${p}`);
for(const t of ['F4-G01','F4-G18'])ok(report.includes(t),`F4_REPORT_MISSING:${t}`);
const humanPending=report.includes('HUMAN_BOUNDARY_PENDING');
const terminalCertified=report.includes('**Estado:** `100_COMPLETE / CERTIFIED`')&&report.includes('**F4:** `100_COMPLETE`')&&report.includes('**Resultado:** `18/18 PASS`');
ok(humanPending||terminalCertified,'F4_REPORT_STATE_INVALID');
if(terminalCertified)ok(!humanPending,'F4_TERMINAL_REPORT_CANNOT_REMAIN_HUMAN_PENDING');
for(const t of ['self-hosted','Windows','X64','ascenda-fast','npm install','node ci/sentinel/phase4_sentry_contract.js'])ok(f4wf.includes(t),`F4_WORKFLOW_MISSING:${t}`);
for(const t of ['ubuntu-latest','windows-latest','macos-latest'])ok(!f4wf.includes(t),`F4_HOSTED_RUNNER_FORBIDDEN:${t}`);

console.log(JSON.stringify({ok:true,certificate:'SENTINEL_F4_RUNTIME_PRELOAD_CONTRACT_PASS',sdk:'@sentry/node@10.70.0',f1_privacy_material_regression:true,f2_topology_material_regression:true,f3_telemetry_material_regression:true,default_active:false,runtime_only_preload:true,build_preload:false,child_env_inheritance:true,fast_pool_python_delegated:true,auth_resend_gate_preserved:true,canary_default:true,canary_only_synthetic:true,missing_dsn_fail_closed:true,zero_phi_pii_fixture:true,fixture_leaks:0,traces_sample_rate:0,logs:false,breadcrumbs:0,pay_as_you_go:false,human_boundary:terminalCertified?'CLOSED':'PENDING',f4_terminal_certified:terminalCertified,changed_files_checked:changed.length},null,2));
