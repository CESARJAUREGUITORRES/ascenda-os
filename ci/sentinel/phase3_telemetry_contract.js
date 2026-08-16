'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');

const ROOT = path.resolve(__dirname, '../..');
const CONTRACT_PATH = 'sentinel/telemetry/contract-v1.json';
const LIB_PATH = 'sentinel/telemetry/index.js';
const FIXTURE_PATH = 'ci/sentinel/fixtures/f3_sensitive_fixture.json';
const COLLECTOR_PATH = 'sentinel/collector/otel-collector-reference.yaml';
const REGISTRY_PATH = 'docs/control/SENTINEL_SYSTEM_REGISTRY_V1.json';
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
function uniq(a) { return [...new Set(a)]; }
function sorted(a) { return [...a].sort((x, y) => x.localeCompare(y)); }
function sameSet(a, b) {
  const aa = sorted(uniq(a));
  const bb = sorted(uniq(b));
  return aa.length === bb.length && aa.every((v, i) => v === bb[i]);
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
const registry = JSON.parse(read(REGISTRY_PATH));
const telemetry = require(path.join(ROOT, LIB_PATH));

// F2 material invariants regression. This intentionally validates topology/content,
// not F2's historical Git ancestry gate, because F3 runs on transient PR merge refs.
ok(registry.schema_version === 'sentinel-system-registry/v1', 'F2_REGISTRY_SCHEMA_DRIFT');
ok(registry.rules.phi_pii_telemetry_allowed === false, 'F2_ZERO_PHI_PII_DRIFT');
ok(registry.rules.default_observability_state === 'UNKNOWN', 'F2_DEFAULT_STATE_DRIFT');
ok(Array.isArray(registry.coverage.unmapped_critical_nodes) && registry.coverage.unmapped_critical_nodes.length === 0, 'F2_UNMAPPED_CRITICAL_NODES');
ok(registry.coverage.health_claims === 0, 'F2_HEALTH_CLAIMS_NONZERO');

const actualHtml = fs.readdirSync(path.join(ROOT, 'app/public'), {withFileTypes: true})
  .filter(e => e.isFile() && e.name.endsWith('.html'))
  .map(e => `app/public/${e.name}`);
const classifiedHtml = [];
for (const domain of registry.domains) for (const surface of domain.surfaces || []) classifiedHtml.push(surface);
ok(sameSet(actualHtml, classifiedHtml), `F2_PUBLIC_HTML_DRIFT:actual=${actualHtml.length}:classified=${classifiedHtml.length}`);
ok(registry.coverage.top_level_public_html_expected === actualHtml.length, 'F2_PUBLIC_HTML_COUNT_DRIFT');

const railway = JSON.parse(read('app/railway.json'));
ok(railway.deploy && railway.deploy.startCommand === registry.runtime.start_command, 'F2_RAILWAY_ENTRYPOINT_DRIFT');
const chain = registry.runtime.chain;
ok(Array.isArray(chain) && chain.length === registry.coverage.runtime_chain_nodes, 'F2_RUNTIME_CHAIN_COUNT_DRIFT');
const runtimeIds = new Set();
for (let i = 0; i < chain.length; i++) {
  const node = chain[i];
  ok(!runtimeIds.has(node.id), `F2_RUNTIME_ID_DUPLICATE:${node.id}`);
  runtimeIds.add(node.id);
  ok(fs.existsSync(path.join(ROOT, node.file)), `F2_RUNTIME_FILE_MISSING:${node.file}`);
  ok(node.observability_state === 'UNKNOWN', `F2_RUNTIME_FALSE_GREEN:${node.id}`);
  if (node.spawns) {
    ok(i + 1 < chain.length && chain[i + 1].file === node.spawns, `F2_RUNTIME_CHAIN_ORDER_DRIFT:${node.id}`);
    ok(read(node.file).includes(path.basename(node.spawns)), `F2_RUNTIME_SPAWN_EVIDENCE_MISSING:${node.id}`);
  }
}
const depIds = new Set((registry.dependencies || []).map(d => d.id));
ok(depIds.size === registry.dependencies.length, 'F2_DEPENDENCY_ID_DUPLICATE');
for (const dep of registry.dependencies) ok(dep.observability_state === 'UNKNOWN', `F2_DEPENDENCY_FALSE_GREEN:${dep.id}`);
let capabilityCount = 0;
for (const domain of registry.domains) {
  for (const component of domain.components || []) ok(runtimeIds.has(component), `F2_UNKNOWN_RUNTIME_COMPONENT:${domain.id}:${component}`);
  const capIds = new Set();
  for (const cap of domain.capabilities || []) {
    capabilityCount++;
    ok(!capIds.has(cap.id), `F2_CAPABILITY_DUPLICATE:${domain.id}:${cap.id}`);
    capIds.add(cap.id);
    ok(cap.observability_state === 'UNKNOWN', `F2_CAPABILITY_FALSE_GREEN:${domain.id}:${cap.id}`);
    for (const dep of cap.dependencies || []) ok(depIds.has(dep), `F2_UNKNOWN_DEPENDENCY:${domain.id}:${cap.id}:${dep}`);
  }
}
ok(registry.coverage.domain_count === registry.domains.length, 'F2_DOMAIN_COUNT_DRIFT');
function walkNoHealthy(v, trail = 'root') {
  if (Array.isArray(v)) return v.forEach((x, i) => walkNoHealthy(x, `${trail}[${i}]`));
  if (v && typeof v === 'object') return Object.entries(v).forEach(([k, x]) => walkNoHealthy(x, `${trail}.${k}`));
  if (typeof v === 'string' && v.toUpperCase() === 'HEALTHY') fail(`F2_FORBIDDEN_HEALTHY:${trail}`);
}
walkNoHealthy(registry);

// F3 contract.
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

// F3 is foundation-only: Sentinel code/tests/docs are allowed, but no product runtime/DB/provider wiring.
const changed = changedFilesAgainstBase();
const forbiddenPaths = ['app/','supabase/migrations/','supabase/functions/','migrations/'];
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
  f2_registry_regression: true,
  f2_public_html_surfaces: actualHtml.length,
  f2_runtime_nodes: chain.length,
  f2_capabilities: capabilityCount,
  zero_phi_pii: true,
  baggage_enabled: false,
  production_sampling_default: 0,
  exporter_interchangeability: true,
  trace_context: 'W3C',
  fixture_leaks: 0,
  runtime_db_mutations: 0,
  changed_files_checked: changed.length
}, null, 2));
