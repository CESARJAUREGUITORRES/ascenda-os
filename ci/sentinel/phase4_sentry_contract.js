'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');

const ROOT = path.resolve(__dirname, '../..');
const APP = path.join(ROOT, 'app');
const INIT_PATH = 'app/sentinel-sentry-init.cjs';
const RAILWAY_PATH = 'app/railway.json';
const PHASE_S_PATH = 'app/server-phase-s.js';
const CONTRACT_PATH = 'sentinel/sentry/f4-contract.json';
const FIXTURE_PATH = 'ci/sentinel/fixtures/f4_sentry_sensitive_event.json';
const F1_POLICY = 'docs/control/SENTINEL_F1_GOVERNANCE_PRIVACY_COST_POLICY.md';
const F1_WORKFLOW = '.github/workflows/sentinel-phase1-governance.yml';
const F2_REGISTRY = 'docs/control/SENTINEL_SYSTEM_REGISTRY_V1.json';
const F3_CONTRACT = 'sentinel/telemetry/contract-v1.json';
const REPORT_PATH = 'docs/control/SENTINEL_F4_VALIDATION_REPORT_20260816.md';
const RUNBOOK_PATH = 'docs/control/SENTINEL_F4_SENTRY_RUNBOOK.md';
const WORKFLOW_PATH = '.github/workflows/sentinel-phase4-sentry.yml';
const F5_RUNTIME_CONTRACT = 'ci/phase5-historical-identity/f5_upload_contract.js';
const WA2_RUNTIME_CONTRACT = 'ci/wa2-conversation-live-inbox/ui_contract.py';

function fail(msg) { throw new Error(msg); }
function ok(value, msg) { if (!value) fail(msg); }
function read(p) {
  const abs = path.join(ROOT, p);
  ok(fs.existsSync(abs), `MISSING_FILE:${p}`);
  return fs.readFileSync(abs, 'utf8');
}
function json(p) { return JSON.parse(read(p)); }

const pkg = json('app/package.json');
const f4 = json(CONTRACT_PATH);
const f3 = json(F3_CONTRACT);
const f2 = json(F2_REGISTRY);
const f1 = read(F1_POLICY);
const f1Workflow = read(F1_WORKFLOW);
const fixture = json(FIXTURE_PATH);
const initSource = read(INIT_PATH);
const railway = json(RAILWAY_PATH);
const phaseS = read(PHASE_S_PATH);
const workflow = read(WORKFLOW_PATH);
const report = read(REPORT_PATH);
const runbook = read(RUNBOOK_PATH);
const f5RuntimeContract = read(F5_RUNTIME_CONTRACT);
const wa2RuntimeContract = read(WA2_RUNTIME_CONTRACT);

ok(pkg.dependencies && pkg.dependencies['@sentry/node'] === '10.70.0', 'SENTRY_SDK_NOT_EXACT_PIN_10_70_0');
ok(f4.schema_version === 'sentinel-sentry-core/v1' && f4.phase === 'F4', 'F4_CONTRACT_INVALID');
ok(f4.sdk.package === '@sentry/node' && f4.sdk.version === '10.70.0', 'F4_SDK_CONTRACT_DRIFT');
for (const token of ['Zero-PHI/PII','allowlist-first','Session Replay: **OFF**','attachments: **OFF**','pay-as-you-go: OFF']) {
  ok(f1.includes(token), `F1_MATERIAL_INVARIANT_MISSING:${token}`);
}
ok(f2.rules.default_observability_state === 'UNKNOWN', 'F2_UNKNOWN_DEFAULT_DRIFT');
ok(f2.rules.phi_pii_telemetry_allowed === false, 'F2_PHI_POLICY_DRIFT');
ok(Array.isArray(f2.runtime.chain) && f2.runtime.chain.length === 8, 'F2_RUNTIME_CHAIN_DRIFT');
ok(fs.readdirSync(path.join(APP, 'public')).filter(x => x.endsWith('.html')).length === 41, 'F2_PUBLIC_HTML_DRIFT');
ok(f3.schema_version === 'sentinel-telemetry-contract/v1', 'F3_SCHEMA_DRIFT');
ok(f3.design.zero_phi_pii === true && f3.design.allowlist_first === true, 'F3_PRIVACY_DRIFT');
ok(f3.design.baggage_enabled === false, 'F3_BAGGAGE_DRIFT');
ok(f3.sampling.defaults.production === 0, 'F3_PRODUCTION_SAMPLING_DRIFT');

for (const broad of ['docs/control/SENTINEL_*.md', 'ci/sentinel/**']) {
  ok(!f1Workflow.includes(broad), `F1_WORKFLOW_CROSS_PHASE_TRIGGER_FORBIDDEN:${broad}`);
}

ok(f4.activation.default_active === false, 'F4_DEFAULT_MUST_OFF');
ok(f4.activation.master_switch === 'SENTINEL_ENABLED', 'F4_MASTER_SWITCH_DRIFT');
ok(f4.activation.sensor_switch === 'SENTINEL_SENTRY_ENABLED', 'F4_SENSOR_SWITCH_DRIFT');
ok(f4.activation.canary_switch === 'SENTINEL_SENTRY_CANARY_MODE' && f4.activation.canary_default === true, 'F4_CANARY_DRIFT');
ok(f4.activation.synthetic_boot_switch === 'SENTINEL_SENTRY_SYNTHETIC_ON_BOOT', 'F4_SYNTHETIC_SWITCH_DRIFT');
ok(f4.activation.synthetic_code === 'SENTINEL_F4_SYNTHETIC_ERROR', 'F4_SYNTHETIC_CODE_DRIFT');
ok(f4.activation.preload_value === '--require ./sentinel-sentry-init.cjs', 'F4_PRELOAD_VALUE_DRIFT');
ok(f4.activation.preload_scope === 'runtime-command-only-not-global-railway-variable', 'F4_PRELOAD_SCOPE_DRIFT');
ok(f4.privacy.send_default_pii === false, 'F4_SEND_DEFAULT_PII_MUST_FALSE');
ok(f4.privacy.breadcrumbs === 0 && f4.privacy.logs === false && f4.privacy.local_variables === false, 'F4_PRIVACY_OPTION_DRIFT');
ok(f4.sampling.traces_sample_rate === 0, 'F4_TRACING_MUST_ZERO');
ok(f4.cost.incremental_cloud_budget_usd_month === 0 && f4.cost.pay_as_you_go === false, 'F4_COST_DRIFT');

const expectedStart = "env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s.js";
ok(railway.deploy.startCommand === expectedStart, `F4_RUNTIME_START_COMMAND_DRIFT:${railway.deploy.startCommand}`);
ok(railway.build && typeof railway.build.buildCommand === 'string', 'F4_BUILD_COMMAND_MISSING');
ok(!railway.build.buildCommand.includes('NODE_OPTIONS'), 'F4_BUILD_MUST_NOT_PRELOAD_SENTRY');
ok(f4.activation.runtime_start_command === expectedStart, 'F4_CONTRACT_RUNTIME_COMMAND_DRIFT');
ok(phaseS.includes("env:Object.assign({},process.env,{PORT:String(INNER_PORT)})"), 'F4_CHILD_ENV_INHERITANCE_DRIFT');
ok(runbook.includes('NO configurar `NODE_OPTIONS` como variable global de Railway'), 'F4_RUNBOOK_GLOBAL_NODE_OPTIONS_GUARD_MISSING');
ok(f5RuntimeContract.includes('sentinelPhaseS') && f5RuntimeContract.includes('Sentinel preload must not contaminate build'), 'F5_RUNTIME_CONTRACT_NOT_SENTINEL_AWARE');
ok(wa2RuntimeContract.includes('sentinel_phase_s') && wa2RuntimeContract.includes('Sentinel preload must not contaminate build'), 'WA2_RUNTIME_CONTRACT_NOT_SENTINEL_AWARE');

for (const token of [
  'sendDefaultPii: false','tracesSampleRate: 0','enableLogs: false','maxBreadcrumbs: 0',
  'includeLocalVariables: false','beforeBreadcrumb: () => null','beforeSend: event => {',
  'SENTINEL_ENABLED','SENTINEL_SENTRY_ENABLED','SENTINEL_SENTRY_CANARY_MODE',
  'SENTINEL_SENTRY_SYNTHETIC_ON_BOOT','SENTRY_DSN','SENTINEL_F4_SYNTHETIC_ERROR'
]) ok(initSource.includes(token), `INIT_GUARD_MISSING:${token}`);

const installedPkgPath = path.join(APP, 'node_modules/@sentry/node/package.json');
ok(fs.existsSync(installedPkgPath), 'SENTRY_NODE_NOT_INSTALLED_IN_CI');
ok(JSON.parse(fs.readFileSync(installedPkgPath, 'utf8')).version === '10.70.0', 'SENTRY_INSTALLED_VERSION_DRIFT');

process.env.SENTINEL_ENABLED = 'false';
process.env.SENTINEL_SENTRY_ENABLED = 'false';
delete process.env.SENTRY_DSN;
const telemetry = require(path.join(ROOT, INIT_PATH));
ok(telemetry.status.requested === false && telemetry.status.active === false && telemetry.status.reason === 'disabled', 'F4_DEFAULT_OFF_FAILED');
ok(telemetry.status.canary_mode === true, 'F4_CANARY_DEFAULT_FAILED');
ok(telemetry.requested({SENTINEL_ENABLED:'true',SENTINEL_SENTRY_ENABLED:'true'}) === true, 'F4_DUAL_SWITCH_TRUE_FAILED');
ok(telemetry.requested({SENTINEL_ENABLED:'false',SENTINEL_SENTRY_ENABLED:'true'}) === false, 'F4_MASTER_KILL_SWITCH_FAILED');
const childCode = "process.env.SENTINEL_ENABLED='true';process.env.SENTINEL_SENTRY_ENABLED='true';delete process.env.SENTRY_DSN;const x=require('./sentinel-sentry-init.cjs');process.stdout.write(JSON.stringify(x.status));";
const childStatus = JSON.parse(cp.execFileSync(process.execPath, ['-e', childCode], {cwd: APP, encoding: 'utf8'}).trim());
ok(childStatus.requested === true && childStatus.active === false && childStatus.reason === 'missing_dsn', 'F4_MISSING_DSN_FAIL_CLOSED_FAILED');

const clean = telemetry.sanitizeEvent(fixture);
const serialized = JSON.stringify(clean);
for (const leaked of [
  'fake.patient@example.invalid','+51 999 999 999','00000000','fake-access-token','fake-cookie',
  'fake-service-role','fake-secret-value','synthetic AI prompt that must never leave',
  'synthetic private message','FAKE NAME','FAKEUSER','patient-00000000'
]) ok(!serialized.includes(leaked), `F4_PRIVACY_LEAK:${leaked}`);
for (const forbiddenKey of ['user','request','breadcrumbs','extra','contexts','transaction','modules','spans']) {
  ok(!(forbiddenKey in clean), `F4_FORBIDDEN_EVENT_FIELD:${forbiddenKey}`);
}
ok(clean.exception.values[0].value === '[REDACTED_MESSAGE]', 'F4_EXCEPTION_MESSAGE_NOT_REDACTED');
ok(!('abs_path' in clean.exception.values[0].stacktrace.frames[0]), 'F4_ABS_PATH_LEAK');

const safeEvent = telemetry.sanitizeEvent({
  level:'error',
  message:'SENTINEL_F4_SYNTHETIC_ERROR',
  exception:{values:[{type:'Error',value:'SENTINEL_F4_SYNTHETIC_ERROR',stacktrace:{frames:[]}}]},
  tags:{system:'ascenda-os','sentinel.phase':'F4','service.name':'synthetic.js'}
});
ok(telemetry.isSyntheticEvent(safeEvent) === true, 'F4_SYNTHETIC_EVENT_NOT_RECOGNIZED');
ok(telemetry.isSyntheticEvent(clean) === false, 'F4_REAL_FIXTURE_MUST_NOT_PASS_CANARY');
ok(telemetry.normalizeEnvironment('production') === 'production', 'F4_ENVIRONMENT_NORMALIZATION_FAILED');
ok(telemetry.buildRelease({RAILWAY_GIT_COMMIT_SHA:'e3ff8914447c06a2b94b3be5cccbade73526ce0d'}).startsWith('ascenda-os@'), 'F4_RELEASE_FORMAT_FAILED');

function changedFiles() {
  try {
    cp.execFileSync('git', ['rev-parse','HEAD^2'], {cwd:ROOT, stdio:'ignore'});
    return cp.execFileSync('git',['diff','--name-only','HEAD^1','HEAD'],{cwd:ROOT,encoding:'utf8'}).split(/\r?\n/).filter(Boolean);
  } catch (_) {
    try {
      cp.execFileSync('git',['fetch','origin','main','--depth=1'],{cwd:ROOT,stdio:'ignore'});
      return cp.execFileSync('git',['diff','--name-only','origin/main...HEAD'],{cwd:ROOT,encoding:'utf8'}).split(/\r?\n/).filter(Boolean);
    } catch (_) { return []; }
  }
}
const allowed = new Set([
  '.github/workflows/sentinel-phase1-governance.yml', WORKFLOW_PATH,
  'app/package.json', INIT_PATH, RAILWAY_PATH,
  CONTRACT_PATH, FIXTURE_PATH, 'ci/sentinel/phase4_sentry_contract.js', REPORT_PATH, RUNBOOK_PATH,
  F5_RUNTIME_CONTRACT, WA2_RUNTIME_CONTRACT
]);
const changed = changedFiles();
for (const p of changed) ok(allowed.has(p), `F4_SCOPE_UNEXPECTED_FILE:${p}`);
ok(!changed.some(p => p.startsWith('supabase/migrations/') || p.startsWith('supabase/functions/')), 'F4_DB_MUTATION_FORBIDDEN');
const suspicious = [
  /https:\/\/[A-Za-z0-9_-]{16,}@[A-Za-z0-9.-]+\.ingest(?:\.[A-Za-z0-9.-]+)?\.sentry\.io\/[0-9]+/i,
  /\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b/,
  /\bsb_secret_[A-Za-z0-9_-]{20,}\b/,
  /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/
];
for (const p of [INIT_PATH, CONTRACT_PATH, REPORT_PATH, RUNBOOK_PATH, WORKFLOW_PATH, RAILWAY_PATH]) {
  for (const re of suspicious) ok(!re.test(read(p)), `F4_SECRET_GUARD:${p}`);
}

for (const token of ['F4-G01','F4-G18','HUMAN_BOUNDARY_PENDING']) ok(report.includes(token), `F4_REPORT_MISSING:${token}`);
for (const token of ['self-hosted','Windows','X64','ascenda-fast','npm install','node ci/sentinel/phase4_sentry_contract.js']) ok(workflow.includes(token), `F4_WORKFLOW_MISSING:${token}`);
for (const forbidden of ['ubuntu-latest','windows-latest','macos-latest']) ok(!workflow.includes(forbidden), `F4_HOSTED_RUNNER_FORBIDDEN:${forbidden}`);

console.log(JSON.stringify({
  ok:true,
  certificate:'SENTINEL_F4_RUNTIME_PRELOAD_CONTRACT_PASS',
  sdk:'@sentry/node@10.70.0',
  f1_privacy_material_regression:true,
  f2_topology_material_regression:true,
  f3_telemetry_material_regression:true,
  default_active:false,
  runtime_only_preload:true,
  build_preload:false,
  child_env_inheritance:true,
  canary_default:true,
  canary_only_synthetic:true,
  missing_dsn_fail_closed:true,
  zero_phi_pii_fixture:true,
  fixture_leaks:0,
  traces_sample_rate:0,
  logs:false,
  breadcrumbs:0,
  pay_as_you_go:false,
  human_boundary:'PENDING',
  changed_files_checked:changed.length
}, null, 2));
