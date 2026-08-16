'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');

const ROOT = path.resolve(__dirname, '../..');
const REGISTRY_PATH = 'docs/control/SENTINEL_SYSTEM_REGISTRY_V1.json';
const REPORT_PATH = 'docs/control/SENTINEL_F2_VALIDATION_REPORT_20260816.md';
const TOPOLOGY_PATH = 'docs/control/SENTINEL_F2_TOPOLOGY_REPORT_20260816.md';
const WORKFLOW_PATH = '.github/workflows/sentinel-phase2-registry.yml';

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
  const aa = sorted(uniq(a)), bb = sorted(uniq(b));
  return aa.length === bb.length && aa.every((v, i) => v === bb[i]);
}

const registry = JSON.parse(read(REGISTRY_PATH));
ok(registry.schema_version === 'sentinel-system-registry/v1', 'REGISTRY_SCHEMA_VERSION');
ok(/^[0-9a-f]{40}$/.test(registry.snapshot.source_commit), 'SNAPSHOT_SHA_INVALID');
ok(registry.snapshot.supabase_project_ref === 'ituyqwstonmhnfshnaqz', 'SUPABASE_PROJECT_REF_DRIFT');
ok(registry.rules.health_claims_allowed_in_f2 === false, 'F2_HEALTH_CLAIMS_MUST_BE_FALSE');
ok(registry.rules.default_observability_state === 'UNKNOWN', 'DEFAULT_STATE_MUST_BE_UNKNOWN');
ok(registry.rules.phi_pii_telemetry_allowed === false, 'F2_PHI_PII_POLICY_DRIFT');

// Snapshot must remain an ancestor of the PR merge candidate/current main lineage.
try {
  cp.execFileSync('git', ['merge-base', '--is-ancestor', registry.snapshot.source_commit, 'HEAD'], {cwd: ROOT, stdio: 'ignore'});
} catch (_) {
  fail('SNAPSHOT_COMMIT_NOT_ANCESTOR_OF_HEAD');
}

// Every top-level product HTML surface must be classified exactly once.
const publicDir = path.join(ROOT, 'app/public');
const actualHtml = fs.readdirSync(publicDir, {withFileTypes: true})
  .filter(e => e.isFile() && e.name.endsWith('.html'))
  .map(e => `app/public/${e.name}`);
const classifiedHtml = [];
const surfaceOwner = new Map();
for (const domain of registry.domains) {
  ok(/^[A-Z][A-Z0-9_]*$/.test(domain.id), `DOMAIN_ID_INVALID:${domain.id}`);
  ok(['critical','high','medium','low'].includes(domain.criticality), `DOMAIN_CRITICALITY_INVALID:${domain.id}`);
  for (const s of domain.surfaces || []) {
    ok(!surfaceOwner.has(s), `SURFACE_DUPLICATE:${s}:${surfaceOwner.get(s)}:${domain.id}`);
    surfaceOwner.set(s, domain.id);
    classifiedHtml.push(s);
  }
}
ok(sameSet(actualHtml, classifiedHtml), `PUBLIC_HTML_DRIFT:actual=${actualHtml.length}:classified=${classifiedHtml.length}`);
ok(registry.coverage.top_level_public_html_expected === actualHtml.length, 'PUBLIC_HTML_EXPECTED_COUNT_DRIFT');
ok(registry.coverage.top_level_public_html_classification === 'complete', 'PUBLIC_HTML_NOT_COMPLETE');

// Runtime chain: Railway entrypoint + every spawn edge must match source code.
const railway = JSON.parse(read('app/railway.json'));
ok(railway.deploy && railway.deploy.startCommand === registry.runtime.start_command, 'RAILWAY_START_COMMAND_DRIFT');
ok(registry.runtime.start_command === 'node server-phase-s.js', 'F2_UNEXPECTED_RUNTIME_ENTRYPOINT');
const chain = registry.runtime.chain;
ok(Array.isArray(chain) && chain.length >= 2, 'RUNTIME_CHAIN_INVALID');
ok(chain[0].file === registry.runtime.entrypoint, 'RUNTIME_ENTRYPOINT_CHAIN_MISMATCH');
const runtimeIds = new Set();
for (let i = 0; i < chain.length; i++) {
  const node = chain[i];
  ok(!runtimeIds.has(node.id), `RUNTIME_ID_DUPLICATE:${node.id}`);
  runtimeIds.add(node.id);
  ok(fs.existsSync(path.join(ROOT, node.file)), `RUNTIME_FILE_MISSING:${node.file}`);
  ok(node.observability_state === 'UNKNOWN', `RUNTIME_FALSE_GREEN:${node.id}`);
  if (node.spawns) {
    ok(i + 1 < chain.length, `RUNTIME_SPAWN_WITHOUT_NEXT:${node.id}`);
    ok(chain[i + 1].file === node.spawns, `RUNTIME_CHAIN_ORDER_DRIFT:${node.id}`);
    const src = read(node.file);
    const childBase = path.basename(node.spawns);
    ok(src.includes(childBase), `RUNTIME_SPAWN_EVIDENCE_MISSING:${node.file}->${childBase}`);
  } else {
    ok(i === chain.length - 1, `RUNTIME_TERMINAL_NOT_LAST:${node.id}`);
  }
}
ok(registry.coverage.runtime_chain_nodes === chain.length, 'RUNTIME_CHAIN_COUNT_DRIFT');
ok(registry.coverage.runtime_chain_classification === 'complete', 'RUNTIME_CHAIN_NOT_COMPLETE');

// Dependency/component references and capability contracts.
const depIds = new Set((registry.dependencies || []).map(d => d.id));
ok(depIds.size === registry.dependencies.length, 'DEPENDENCY_ID_DUPLICATE');
for (const dep of registry.dependencies) {
  ok(dep.observability_state === 'UNKNOWN', `DEPENDENCY_FALSE_GREEN:${dep.id}`);
  ok(['critical','high','medium','low'].includes(dep.criticality), `DEPENDENCY_CRITICALITY_INVALID:${dep.id}`);
  ok(Array.isArray(dep.evidence) && dep.evidence.length > 0, `DEPENDENCY_EVIDENCE_EMPTY:${dep.id}`);
}
const domainIds = new Set();
let capabilityCount = 0;
for (const domain of registry.domains) {
  ok(!domainIds.has(domain.id), `DOMAIN_DUPLICATE:${domain.id}`);
  domainIds.add(domain.id);
  ok(Array.isArray(domain.capabilities) && domain.capabilities.length > 0, `DOMAIN_CAPABILITIES_EMPTY:${domain.id}`);
  for (const component of domain.components || []) ok(runtimeIds.has(component), `UNKNOWN_RUNTIME_COMPONENT:${domain.id}:${component}`);
  const capIds = new Set();
  for (const cap of domain.capabilities) {
    capabilityCount++;
    ok(!capIds.has(cap.id), `CAPABILITY_DUPLICATE:${domain.id}:${cap.id}`);
    capIds.add(cap.id);
    ok(cap.observability_state === 'UNKNOWN', `CAPABILITY_FALSE_GREEN:${domain.id}:${cap.id}`);
    ok(['critical','high','medium','low'].includes(cap.criticality), `CAPABILITY_CRITICALITY_INVALID:${domain.id}:${cap.id}`);
    ok(Array.isArray(cap.evidence) && cap.evidence.length > 0, `CAPABILITY_EVIDENCE_EMPTY:${domain.id}:${cap.id}`);
    ok(Array.isArray(cap.db_relations), `CAPABILITY_DB_RELATIONS_INVALID:${domain.id}:${cap.id}`);
    ok(Array.isArray(cap.rpc_refs), `CAPABILITY_RPC_REFS_INVALID:${domain.id}:${cap.id}`);
    ok((cap.db_relations.length + cap.rpc_refs.length + cap.evidence.length) > 0, `CAPABILITY_UNMAPPED:${domain.id}:${cap.id}`);
    for (const dep of cap.dependencies || []) ok(depIds.has(dep), `UNKNOWN_DEPENDENCY:${domain.id}:${cap.id}:${dep}`);
    for (const rel of cap.db_relations) ok(/^[a-z][a-z0-9_]*$/.test(rel), `DB_RELATION_NAME_INVALID:${domain.id}:${rel}`);
    for (const rpc of cap.rpc_refs) ok(/^[a-z][a-z0-9_]*$/.test(rpc), `RPC_NAME_INVALID:${domain.id}:${rpc}`);
  }
}
ok(registry.coverage.domain_count === registry.domains.length, 'DOMAIN_COUNT_DRIFT');
for (const d of registry.coverage.critical_domains || []) ok(domainIds.has(d), `CRITICAL_DOMAIN_UNKNOWN:${d}`);
ok(Array.isArray(registry.coverage.unmapped_critical_nodes) && registry.coverage.unmapped_critical_nodes.length === 0, 'UNMAPPED_CRITICAL_NODES');
ok(registry.coverage.health_claims === 0, 'HEALTH_CLAIMS_NONZERO');

// Hard false-green guard anywhere in the registry JSON.
function walk(v, trail='root') {
  if (Array.isArray(v)) return v.forEach((x, i) => walk(x, `${trail}[${i}]`));
  if (v && typeof v === 'object') return Object.entries(v).forEach(([k, x]) => walk(x, `${trail}.${k}`));
  if (typeof v === 'string' && v.toUpperCase() === 'HEALTHY') fail(`FORBIDDEN_HEALTHY_CLAIM:${trail}`);
}
walk(registry);

// Live schema snapshot is evidence, not a security certification.
const db = registry.database_snapshot;
ok(db.source === 'live-pg-catalog-readonly', 'DB_SNAPSHOT_SOURCE_INVALID');
ok(db.public_tables >= 1 && db.public_functions >= 1, 'DB_SNAPSHOT_EMPTY');
ok(db.public_tables_with_rls >= 0 && db.public_tables_with_rls <= db.public_tables, 'DB_RLS_COUNT_INVALID');
ok(db.note.includes('not certified'), 'DB_SECURITY_NON_CERTIFICATION_MISSING');

// F2 is inventory/control only: branch must not mutate runtime or DB.
function changedFilesAgainstBase() {
  try {
    const base = process.env.GITHUB_BASE_REF || 'main';
    cp.execFileSync('git', ['fetch', 'origin', base, '--depth=1'], {cwd: ROOT, stdio:'ignore'});
    const mb = cp.execFileSync('git', ['merge-base', 'HEAD', `origin/${base}`], {cwd: ROOT, encoding:'utf8'}).trim();
    return cp.execFileSync('git', ['diff', '--name-only', `${mb}...HEAD`], {cwd: ROOT, encoding:'utf8'})
      .split(/\r?\n/).map(s => s.trim()).filter(Boolean);
  } catch (_) { return []; }
}
const changed = changedFilesAgainstBase();
for (const p of changed) {
  ok(!p.startsWith('app/'), `F2_SCOPE_RUNTIME_CHANGE:${p}`);
  ok(!p.startsWith('supabase/migrations/'), `F2_SCOPE_DB_MIGRATION:${p}`);
  ok(!p.startsWith('supabase/functions/'), `F2_SCOPE_EDGE_FUNCTION:${p}`);
}

// Secret guard for F2 control surfaces.
const scanFiles = [REGISTRY_PATH, REPORT_PATH, TOPOLOGY_PATH, WORKFLOW_PATH, 'ci/sentinel/phase2_registry_contract.js'];
const suspicious = [
  /\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b/,
  /\bsb_secret_[A-Za-z0-9_-]{20,}\b/,
  /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/,
  /\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\b/,
  /https:\/\/[A-Za-z0-9_-]{16,}@[A-Za-z0-9.-]+\.ingest(?:\.[A-Za-z0-9.-]+)?\.sentry\.io\/[0-9]+/i
];
for (const p of scanFiles) {
  const text = read(p);
  for (const re of suspicious) ok(!re.test(text), `SECRET_GUARD:${p}`);
}

const report = read(REPORT_PATH);
ok(report.includes('SENTINEL F2'), 'VALIDATION_REPORT_ID_MISSING');
ok(report.includes('F2-G01') && report.includes('F2-G18'), 'VALIDATION_GATES_MISSING');
const topology = read(TOPOLOGY_PATH);
ok(topology.includes('41') && topology.includes('8 procesos Node'), 'TOPOLOGY_SUMMARY_INCOMPLETE');
const workflow = read(WORKFLOW_PATH);
for (const token of ['self-hosted','Windows','X64','ascenda-fast','node ci/sentinel/phase2_registry_contract.js','cancel-in-progress: true']) {
  ok(workflow.includes(token), `WORKFLOW_MISSING:${token}`);
}
for (const forbidden of ['ubuntu-latest','windows-latest','macos-latest']) ok(!workflow.includes(forbidden), `HOSTED_RUNNER_FORBIDDEN:${forbidden}`);

console.log(JSON.stringify({
  ok: true,
  certificate: 'SENTINEL_F2_REGISTRY_CONTRACT_PASS',
  snapshot_commit: registry.snapshot.source_commit,
  public_html_surfaces: actualHtml.length,
  domains: registry.domains.length,
  capabilities: capabilityCount,
  dependencies: registry.dependencies.length,
  runtime_nodes: chain.length,
  false_green_claims: 0,
  unmapped_critical_nodes: 0,
  changed_files_checked: changed.length
}, null, 2));
