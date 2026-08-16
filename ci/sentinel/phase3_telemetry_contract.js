'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');

const ROOT = path.resolve(__dirname, '../..');
const CONTRACT_PATH = 'sentinel/telemetry/contract-v1.json';
const LIB_PATH = 'sentinel/telemetry/index.js';
const FIXTURE_PATH = 'ci/sentinel/fixtures/f3_sensitive_fixture.json';
const COLLECTOR_PATH = 'sentinel/collector/otel-collector-reference.yaml';
const REPORT_PATH = 'docs/control/SENTINEL_F3_VALIDATION_REPORT_20260816.md';
const POLICY_PATH = 'docs/control/SENTINEL_F3_TELEMETRY_CONTRACT_V1.md';
const WORKFLOW_PATH = '.github/workflows/sentinel-phase3-telemetry.yml';

function fail(msg) { throw new Error(msg); }
function ok(v, msg) { if (!v) fail(msg); }
function read(p) {
  const abs = path.join(ROOT, p);
  ok(fs.existsSync(abs), `MISSING_FILE:${p}`);
  return fs.readFileSync(abs, 'utf8');
}
function changedFilesAgainstBase() {
  try {
    const base = process.env.GITHUB_BASE_REF || 'main';
    cp.execFileSync('git', ['fetch', 'origin', base, '--depth=1'], {cwd: ROOT, stdio: 'ignore'});
    const mb = cp.execFileSync('git', ['merge-base', 'HEAD', `origin/${base}`], {cwd: ROOT, encoding: 'utf8'}).trim();
    return cp.execFileSync('git', ['diff', '--name-only', `${mb}...HEAD`], {cwd: ROOT, encoding: 'utf8'})
      .split(/\r?\n/).map(s => s.trim()).filter(Boolean);
  } catch (_) { return []; }
}

const contract = JSON.parse(read(CONTRACT_PATH));
const fixture = JSON.parse(read(FIXTURE_PATH));
const telemetry = require(path.join(ROOT, LIB_PATH));

ok(contract.schema_version === 'sentinel-telemetry-contract/v1', 'CONTRACT_SCHEMA_INVALID');
ok(contract.system === 'ascenda-os', 'SYSTEM_INVALID');
ok(contract.design.vendor_neutral === true, 'VENDOR_NEUTRAL_REQUIRED');
ok(contract.design.runtime_activation_in_f3 === false, 'F3_RUNTIME_ACTIVATION_FORBIDDEN');
ok(contract.design.network_export_in_f3 === false, 'F3_NETWORK_EXPORT_FORBIDDEN');
ok(contract.design.zero_phi_pii === true, 'ZERO_PHI_PII_REQUIRED');
ok(contract.design.allowlist_first === true, 'ALLOWLIST_FIRST_REQUIRED');
ok(contract.design.baggage_enabled === false, 'BAGGAGE_MUST_BE_DISABLED');
ok(contract.exporter.production_network_exporter_allowed === false, 'PROD_NETWORK_EXPORTER_FORBIDDEN');
ok(contract.sampling.defaults.production === 0, 'PRODUCTION_SAMPLING_MUST_BE_ZERO');
ok(contract.sampling.defaults['zero-cost'] === 1, 'ZERO_COST_SAMPLING_EXPECTED_ONE');

for (const key of ['service.namespace','service.name','service.version','deployment.environment.name']) {
  ok(contract.resource.required.includes(key), `RESOURCE_REQUIRED_MISSING:${key}`);
}
for (const key of ['sentinel.domain','sentinel.component','sentinel.capability','sentinel.request_id','error.type','error.code']) {
  ok(contract.attributes.allowed.includes(key), `ALLOWED_ATTRIBUTE_MISSING:${key}`);
}
for (const fragment of ['authorization','cookie','token','phone','telefono','dni','email','paciente','patient','body','message','prompt','response']) {
  ok(contract.redaction.denied_key_fragments.includes(fragment), `DENY_FRAGMENT_MISSING:${fragment}`);
}

const inbound = telemetry.parseTraceparent(fixture.traceparent);
ok(inbound && inbound.trace_id === '4bf92f3577b34da6a3ce929d0e0e4736', 'TRACEPARENT_PARSE_FAILED');
ok(inbound.sampled === true, 'TRACEPARENT_FLAGS_FAILED');
const context = telemetry.createTraceContext({traceparent: fixture.traceparent, request_id: fixture.request_id});
ok(context.parent_span_id === '00f067aa0ba902b7', 'PARENT_SPAN_PROPAGATION_FAILED');
ok(context.request_id === fixture.request_id, 'REQUEST_ID_PROPAGATION_FAILED');
const outboundTraceparent = telemetry.formatTraceparent(context);
ok(/^00-[0-9a-f]{32}-[0-9a-f]{16}-(00|01)$/.test(outboundTraceparent), 'TRACEPARENT_FORMAT_FAILED');

const cleanResource = telemetry.sanitizeResource(fixture.resource);
ok(cleanResource['service.namespace'] === 'ascenda-os', 'SERVICE_NAMESPACE_NOT_NORMALIZED');
ok(!('patient.email' in cleanResource), 'PHI_RESOURCE_NOT_DROPPED');
ok(!('authorization' in cleanResource), 'AUTH_RESOURCE_NOT_DROPPED');

const cleanAttributes = telemetry.sanitizeAttributes(fixture.attributes);
ok(cleanAttributes['sentinel.operation'] === '[REDACTED]', 'SENSITIVE_ALLOWED_VALUE_NOT_REDACTED');
for (const key of ['email','telefono','dni','authorization','access_token','request.body','prompt','unknown.custom']) {
  ok(!(key in cleanAttributes), `SENSITIVE_OR_UNKNOWN_ATTRIBUTE_LEAK:${key}`);
}

const envelope = telemetry.buildEnvelope({
  signal: 'error',
  timestamp: '2026-08-16T15:00:00.000Z',
  resource: fixture.resource,
  context,
  attributes: fixture.attributes,
  sample_rate: 1
});
ok(envelope.schema_version === 'sentinel-telemetry-envelope/v1', 'ENVELOPE_SCHEMA_INVALID');
ok(envelope.context.sampled === true, 'FIXTURE_EXPECTED_SAMPLED');
ok(envelope.resource['deployment.environment.name'] === 'zero-cost', 'FIXTURE_ENV_INVALID');

const serialized = JSON.stringify(envelope);
for (const leaked of [
  'fake.patient@example.invalid',
  '+51 999 999 999',
  '00000000',
  'fake-secret-value',
  'fake-access-token',
  'synthetic AI prompt that must never leave',
  'FAKE NAME'
]) ok(!serialized.includes(leaked), `FIXTURE_LEAK:${leaked}`);

const noop = telemetry.createNoopExporter();
const noopResult = telemetry.exportEnvelope(noop, envelope);
ok(noopResult.accepted === false && noopResult.reason === 'noop', 'NOOP_EXPORTER_FAILED');

const memory = telemetry.createMemoryExporter();
const memoryResult = telemetry.exportEnvelope(memory, envelope);
ok(memoryResult.accepted === true, 'MEMORY_EXPORTER_FAILED');
ok(memory.records().length === 1, 'MEMORY_EXPORTER_COUNT_FAILED');
ok(JSON.stringify(memory.records()[0]) === JSON.stringify(envelope), 'EXPORTER_ENVELOPE_DRIFT');

let customRecord = null;
const custom = {name: 'custom-fixture', export(e) { customRecord = JSON.parse(JSON.stringify(e)); return {accepted: true}; }};
telemetry.exportEnvelope(custom, envelope);
ok(JSON.stringify(customRecord) === JSON.stringify(envelope), 'CUSTOM_EXPORTER_INTERCHANGEABILITY_FAILED');

ok(telemetry.defaultSampleRate('production') === 0, 'PROD_DEFAULT_SAMPLE_RATE_DRIFT');
ok(telemetry.shouldSample('00000000000000000000000000000001', 0) === false, 'RATE_ZERO_FAILED');
ok(telemetry.shouldSample('ffffffffffffffffffffffffffffffff', 1) === true, 'RATE_ONE_FAILED');
ok(telemetry.shouldSample('00000000000000000000000000000001', 0.5) === true, 'DETERMINISTIC_SAMPLE_LOW_BUCKET_FAILED');
ok(telemetry.shouldSample('ffffffffffffffffffffffffffffffff', 0.5) === false, 'DETERMINISTIC_SAMPLE_HIGH_BUCKET_FAILED');

const collector = read(COLLECTOR_PATH);
for (const token of ['NOT DEPLOYED','memory_limiter','filter/sentinel','redaction/sentinel','batch','exporters:','debug:']) {
  ok(collector.includes(token), `COLLECTOR_REFERENCE_MISSING:${token}`);
}
for (const forbidden of ['sentry.io','api_key:','authorization: Bearer','otlphttp/sentry','service_role']) {
  ok(!collector.toLowerCase().includes(forbidden.toLowerCase()), `COLLECTOR_REFERENCE_FORBIDDEN:${forbidden}`);
}

const policy = read(POLICY_PATH);
for (const token of ['W3C Trace Context','deployment.environment.name','baggage','production=0','allowlist-first','Zero PHI/PII','export(envelope)']) {
  ok(policy.includes(token), `POLICY_MISSING:${token}`);
}
const report = read(REPORT_PATH);
ok(report.includes('SENTINEL F3'), 'REPORT_ID_MISSING');
ok(report.includes('F3-G01') && report.includes('F3-G18'), 'REPORT_GATES_MISSING');

const workflow = read(WORKFLOW_PATH);
for (const token of ['self-hosted','Windows','X64','ascenda-fast','node ci/sentinel/phase3_telemetry_contract.js','cancel-in-progress: true']) {
  ok(workflow.includes(token), `WORKFLOW_MISSING:${token}`);
}
for (const forbidden of ['ubuntu-latest','windows-latest','macos-latest']) ok(!workflow.includes(forbidden), `HOSTED_RUNNER_FORBIDDEN:${forbidden}`);

// F3 is a foundation-only phase. It may add Sentinel code/tests/docs but must not wire production runtime or mutate DB/provider config.
const changed = changedFilesAgainstBase();
const forbiddenPaths = [
  'app/',
  'supabase/migrations/',
  'supabase/functions/',
  'migrations/'
];
for (const p of changed) {
  ok(!forbiddenPaths.some(prefix => p.startsWith(prefix)), `F3_RUNTIME_OR_DB_MUTATION:${p}`);
  ok(p !== 'app/package.json', `F3_PACKAGE_MUTATION:${p}`);
  ok(p !== 'app/railway.json', `F3_RAILWAY_MUTATION:${p}`);
}

const secretPatterns = [
  /\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b/,
  /\bsb_secret_[A-Za-z0-9_-]{20,}\b/,
  /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/,
  /https:\/\/[A-Za-z0-9_-]{16,}@[A-Za-z0-9.-]+\.ingest(?:\.[A-Za-z0-9.-]+)?\.sentry\.io\/[0-9]+/i
];
for (const p of [CONTRACT_PATH, LIB_PATH, COLLECTOR_PATH, POLICY_PATH, REPORT_PATH, WORKFLOW_PATH]) {
  const text = read(p);
  for (const re of secretPatterns) ok(!re.test(text), `SECRET_GUARD:${p}`);
}

console.log(JSON.stringify({
  ok: true,
  certificate: 'SENTINEL_F3_TELEMETRY_CONTRACT_PASS',
  contract: contract.schema_version,
  zero_phi_pii: true,
  baggage_enabled: false,
  production_sampling_default: 0,
  exporter_interchangeability: true,
  trace_context: 'W3C',
  fixture_leaks: 0,
  runtime_db_mutations: 0,
  changed_files_checked: changed.length
}, null, 2));
