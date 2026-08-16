'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');

const ROOT = path.resolve(__dirname, '../..');
const APP = path.join(ROOT, 'app');
const INIT_PATH = 'app/sentinel-sentry-init.cjs';
const CONTRACT_PATH = 'sentinel/sentry/f4-contract.json';
const FIXTURE_PATH = 'ci/sentinel/fixtures/f4_sentry_sensitive_event.json';
const F1_POLICY = 'docs/control/SENTINEL_F1_GOVERNANCE_PRIVACY_COST_POLICY.md';
const F3_CONTRACT = 'sentinel/telemetry/contract-v1.json';
const F2_REGISTRY = 'docs/control/SENTINEL_SYSTEM_REGISTRY_V1.json';
const REPORT_PATH = 'docs/control/SENTINEL_F4_VALIDATION_REPORT_20260816.md';
const WORKFLOW_PATH = '.github/workflows/sentinel-phase4-sentry.yml';

function fail(msg) { throw new Error(msg); }
function ok(v, msg) { if (!v) fail(msg); }
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
const fixture = json(FIXTURE_PATH);
const initSource = read(INIT_PATH);
const workflow = read(WORKFLOW_PATH);
const report = read(REPORT_PATH);

// Baseline / dependency pin.
ok(f4.schema_version === 'sentinel-sentry-core/v1', 'F4_SCHEMA_INVALID');
ok(f4.phase === 'F4', 'F4_PHASE_INVALID');
ok(f4.baseline_main === 'e3ff8914447c06a2b94b3be5cccbade73526ce0d', 'F4_BASELINE_DRIFT');
ok(pkg.dependencies && pkg.dependencies['@sentry/node'] === '10.70.0', 'SENTRY_SDK_NOT_EXACT_PIN_10_70_0');
ok(f4.sdk.package === '@sentry/node' && f4.sdk.version === '10.70.0', 'F4_SDK_CONTRACT_DRIFT');

const installedPkgPath = path.join(APP, 'node_modules/@sentry/node/package.json');
ok(fs.existsSync(installedPkgPath), 'SENTRY_NODE_NOT_INSTALLED_IN_CI');
const installed = JSON.parse(fs.readFileSync(installedPkgPath, 'utf8'));
ok(installed.version === '10.70.0', `SENTRY_INSTALLED_VERSION_DRIFT:${installed.version}`);

// Material F1/F3 invariants, without reusing old phase scope restrictions.
for (const token of [
  'Zero-PHI/PII',
  'allowlist-first',
  'Session Replay: **OFF**',
  'attachments: **OFF**',
  'request/response body capture: **OFF**',
  'pay-as-you-go: OFF',
  'SENTINEL_ENABLED',
  'SENTINEL_SENTRY_ENABLED',
  'Sentry temporalmente caído'
]) ok(f1.includes(token), `F1_MATERIAL_INVARIANT_MISSING:${token}`);
ok(f3.schema_version === 'sentinel-telemetry-contract/v1', 'F3_SCHEMA_DRIFT');
ok(f3.design.zero_phi_pii === true, 'F3_ZERO_PHI_PII_DRIFT');
ok(f3.design.allowlist_first === true, 'F3_ALLOWLIST_DRIFT');
ok(f3.design.baggage_enabled === false, 'F3_BAGGAGE_DRIFT');
ok(f3.sampling.defaults.production === 0, 'F3_PRODUCTION_SAMPLING_DRIFT');
ok(f3.exporter.production_network_exporter_allowed === false, 'F3_NETWORK_EXPORT_BASELINE_DRIFT');

// F2 topology remains material and false-green safe.
ok(f2.rules.default_observability_state === 'UNKNOWN', 'F2_UNKNOWN_DEFAULT_DRIFT');
ok(f2.rules.phi_pii_telemetry_allowed === false, 'F2_PHI_POLICY_DRIFT');
ok(Array.isArray(f2.runtime.chain) && f2.runtime.chain.length === 8, 'F2_RUNTIME_CHAIN_DRIFT');
const publicHtml = fs.readdirSync(path.join(APP, 'public')).filter(x => x.endsWith('.html'));
ok(publicHtml.length === 41, `F2_PUBLIC_HTML_DRIFT:${publicHtml.length}`);

// F4 contract settings.
ok(f4.activation.default_active === false, 'F4_MUST_DEFAULT_OFF');
ok(f4.activation.master_switch === 'SENTINEL_ENABLED', 'F4_MASTER_SWITCH_DRIFT');
ok(f4.activation.sensor_switch === 'SENTINEL_SENTRY_ENABLED', 'F4_SENSOR_SWITCH_DRIFT');
ok(f4.activation.dsn_variable === 'SENTRY_DSN', 'F4_DSN_VAR_DRIFT');
ok(f4.activation.preload_value === '--require ./sentinel-sentry-init.cjs', 'F4_PRELOAD_DRIFT');
ok(f4.privacy.send_default_pii === false, 'F4_SEND_DEFAULT_PII_MUST_FALSE');
ok(f4.privacy.breadcrumbs === 0, 'F4_BREADCRUMBS_MUST_ZERO');
ok(f4.privacy.logs === false, 'F4_LOGS_MUST_OFF');
ok(f4.privacy.local_variables === false, 'F4_LOCAL_VARIABLES_MUST_OFF');
ok(f4.sampling.traces_sample_rate === 0, 'F4_TRACES_MUST_ZERO');
ok(f4.cost.incremental_cloud_budget_usd_month === 0, 'F4_BUDGET_MUST_ZERO');
ok(f4.cost.pay_as_you_go === false, 'F4_PAYG_MUST_FALSE');
ok(f4.human_boundary_gate.required === true && f4.human_boundary_gate.no_100_complete_before_gate === true, 'F4_HUMAN_GATE_REQUIRED');

// Source must encode defensive SDK options explicitly.
for (const token of [
  'sendDefaultPii: false',
  'tracesSampleRate: 0',
  'enableLogs: false',
  'maxBreadcrumbs: 0',
  'includeLocalVariables: false',
  'beforeBreadcrumb: () => null',
  'beforeSend: event => sanitizeEvent(event)',
  "SENTINEL_ENABLED",
  "SENTINEL_SENTRY_ENABLED",
  "SENTRY_DSN"
]) ok(initSource.includes(token), `INIT_GUARD_MISSING:${token}`);

// Load the preloader with switches explicitly disabled. It must not need DSN or network.
process.env.SENTINEL_ENABLED = 'false';
process.env.SENTINEL_SENTRY_ENABLED = 'false';
delete process.env.SENTRY_DSN;
const telemetry = require(path.join(ROOT, INIT_PATH));
ok(telemetry.status.requested === false, 'KILL_SWITCH_DEFAULT_REQUESTED');
ok(telemetry.status.active === false, 'KILL_SWITCH_DEFAULT_ACTIVE');
ok(telemetry.status.reason === 'disabled', 'KILL_SWITCH_DEFAULT_REASON');

// Dual-switch truth table.
ok(telemetry.requested({SENTINEL_ENABLED:'true', SENTINEL_SENTRY_ENABLED:'true'}) === true, 'DUAL_SWITCH_TRUE_FAILED');
ok(telemetry.requested({SENTINEL_ENABLED:'true', SENTINEL_SENTRY_ENABLED:'false'}) === false, 'SENSOR_SWITCH_FALSE_FAILED');
ok(telemetry.requested({SENTINEL_ENABLED:'false', SENTINEL_SENTRY_ENABLED:'true'}) === false, 'MASTER_SWITCH_FALSE_FAILED');

// Missing DSN must fail closed for telemetry without loading a network exporter.
const childCode = "process.env.SENTINEL_ENABLED='true';process.env.SENTINEL_SENTRY_ENABLED='true';delete process.env.SENTRY_DSN;const x=require('./sentinel-sentry-init.cjs');process.stdout.write(JSON.stringify(x.status));";
const childRaw = cp.execFileSync(process.execPath, ['-e', childCode], {cwd: APP, encoding: 'utf8'}).trim();
const childStatus = JSON.parse(childRaw);
ok(childStatus.requested === true && childStatus.active === false && childStatus.reason === 'missing_dsn', 'MISSING_DSN_FAIL_CLOSED_FAILED');

// Adversarial privacy fixture must be minimized before Sentry export.
const clean = telemetry.sanitizeEvent(fixture);
const serialized = JSON.stringify(clean);
for (const leaked of [
  'fake.patient@example.invalid',
  '+51 999 999 999',
  '00000000',
  'fake-access-token',
  'fake-cookie',
  'fake-service-role',
  'fake-secret-value',
  'synthetic AI prompt that must never leave',
  'synthetic private message',
  'FAKE NAME',
  'FAKEUSER',
  'patient-00000000'
]) ok(!serialized.includes(leaked), `F4_PRIVACY_LEAK:${leaked}`);

for (const forbiddenKey of ['user','request','breadcrumbs','extra','contexts','transaction','modules','spans']) {
  ok(!(forbiddenKey in clean), `F4_FORBIDDEN_EVENT_FIELD:${forbiddenKey}`);
}
ok(clean.exception.values[0].value === '[REDACTED_MESSAGE]', 'F4_EXCEPTION_MESSAGE_NOT_REDACTED');
ok(clean.exception.values[0].stacktrace.frames[0].filename === 'server-phase-s.js', 'F4_FRAME_PATH_NOT_MINIMIZED');
ok(!('abs_path' in clean.exception.values[0].stacktrace.frames[0]), 'F4_ABS_PATH_LEAK');
ok(!('email' in clean.tags) && !('unknown.custom' in clean.tags), 'F4_TAG_ALLOWLIST_FAILED');
ok(clean.tags.system === 'ascenda-os' && clean.tags['sentinel.phase'] === 'F4', 'F4_REQUIRED_TAGS_LOST');

// Safe synthetic code remains useful for grouping/title.
const safeEvent = telemetry.sanitizeEvent({
  level: 'error',
  message: 'SENTINEL_F4_SYNTHETIC_ERROR',
  exception: {values:[{type:'Error', value:'SENTINEL_F4_SYNTHETIC_ERROR', stacktrace:{frames:[]}}]},
  tags: {system:'ascenda-os','sentinel.phase':'F4','service.name':'synthetic.js'}
});
ok(safeEvent.message === 'SENTINEL_F4_SYNTHETIC_ERROR', 'F4_SAFE_ERROR_CODE_LOST');
ok(safeEvent.exception.values[0].value === 'SENTINEL_F4_SYNTHETIC_ERROR', 'F4_SAFE_EXCEPTION_CODE_LOST');

// Release/environment rules.
ok(telemetry.normalizeEnvironment('production') === 'production', 'ENV_PRODUCTION_FAILED');
ok(telemetry.normalizeEnvironment('staging') === 'zero-cost', 'ENV_STAGING_FAILED');
ok(telemetry.buildRelease({RAILWAY_GIT_COMMIT_SHA:'e3ff8914447c06a2b94b3be5cccbade73526ce0d'}) === 'ascenda-os@e3ff8914447c06a2b94b3be5cccbade73526ce0d', 'RELEASE_SHA_FAILED');
ok(telemetry.buildRelease({}) === 'ascenda-os@unknown', 'RELEASE_FALLBACK_FAILED');

// Scope: F4 foundation may add only dormant Sentry integration/test/control files.
function changedFiles() {
  try {
    // GitHub PR checkout is a synthetic merge commit: first parent is base.
    cp.execFileSync('git', ['rev-parse', 'HEAD^2'], {cwd: ROOT, stdio:'ignore'});
    return cp.execFileSync('git', ['diff', '--name-only', 'HEAD^1', 'HEAD'], {cwd: ROOT, encoding:'utf8'})
      .split(/\r?\n/).map(x => x.trim()).filter(Boolean);
  } catch (_) {
    try {
      cp.execFileSync('git', ['fetch','origin','main','--depth=1'], {cwd: ROOT, stdio:'ignore'});
      return cp.execFileSync('git', ['diff','--name-only','origin/main...HEAD'], {cwd: ROOT, encoding:'utf8'})
        .split(/\r?\n/).map(x => x.trim()).filter(Boolean);
    } catch (_) { return []; }
  }
}
const changed = changedFiles();
const allowedExact = new Set([
  'app/package.json',
  'app/sentinel-sentry-init.cjs',
  CONTRACT_PATH,
  FIXTURE_PATH,
  'ci/sentinel/phase4_sentry_contract.js',
  REPORT_PATH,
  'docs/control/SENTINEL_F4_SENTRY_RUNBOOK.md',
  WORKFLOW_PATH
]);
for (const p of changed) ok(allowedExact.has(p), `F4_SCOPE_UNEXPECTED_FILE:${p}`);
ok(!changed.includes('app/railway.json'), 'F4_FOUNDATION_MUST_NOT_CHANGE_RAILWAY');
ok(!changed.some(p => p.startsWith('supabase/migrations/') || p.startsWith('supabase/functions/')), 'F4_FOUNDATION_DB_MUTATION');

// Secret/DSN guard. Fixture contains only fake invalid values; repository must contain no real DSN/token patterns.
const scanPaths = [INIT_PATH, CONTRACT_PATH, REPORT_PATH, 'docs/control/SENTINEL_F4_SENTRY_RUNBOOK.md', WORKFLOW_PATH, 'app/package.json'];
const suspicious = [
  /https:\/\/[A-Za-z0-9_-]{16,}@[A-Za-z0-9.-]+\.ingest(?:\.[A-Za-z0-9.-]+)?\.sentry\.io\/[0-9]+/i,
  /\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b/,
  /\bsb_secret_[A-Za-z0-9_-]{20,}\b/,
  /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/
];
for (const p of scanPaths) for (const re of suspicious) ok(!re.test(read(p)), `F4_SECRET_GUARD:${p}`);

for (const token of ['F4-G01','F4-G18','HUMAN_BOUNDARY_PENDING']) ok(report.includes(token), `F4_REPORT_MISSING:${token}`);
for (const token of ['self-hosted','Windows','X64','ascenda-fast','npm install','node ci/sentinel/phase4_sentry_contract.js','cancel-in-progress: true']) {
  ok(workflow.includes(token), `F4_WORKFLOW_MISSING:${token}`);
}
for (const forbidden of ['ubuntu-latest','windows-latest','macos-latest']) ok(!workflow.includes(forbidden), `F4_HOSTED_RUNNER_FORBIDDEN:${forbidden}`);

console.log(JSON.stringify({
  ok: true,
  certificate: 'SENTINEL_F4_FOUNDATION_CONTRACT_PASS',
  sdk: '@sentry/node@10.70.0',
  f1_privacy_material_regression: true,
  f2_topology_material_regression: true,
  f3_telemetry_material_regression: true,
  default_active: false,
  missing_dsn_fail_closed: true,
  zero_phi_pii_fixture: true,
  fixture_leaks: 0,
  traces_sample_rate: 0,
  logs: false,
  breadcrumbs: 0,
  pay_as_you_go: false,
  human_boundary: 'PENDING',
  changed_files_checked: changed.length
}, null, 2));
