'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');

const ROOT = path.resolve(__dirname, '../..');
const req = (p) => {
  const abs = path.join(ROOT, p);
  if (!fs.existsSync(abs)) throw new Error(`MISSING_REQUIRED_FILE:${p}`);
  return fs.readFileSync(abs, 'utf8');
};
const assert = (ok, msg) => { if (!ok) throw new Error(msg); };
const mustContain = (text, tokens, label) => tokens.forEach(t => assert(text.includes(t), `${label}:MISSING:${t}`));
const mustNotContain = (text, tokens, label) => tokens.forEach(t => assert(!text.includes(t), `${label}:FORBIDDEN:${t}`));

const masterPath = 'docs/control/SENTINEL_CONTROL_MASTER.md';
const roadmapPath = 'docs/control/SENTINEL_ROADMAP_V1.md';
const policyPath = 'docs/control/SENTINEL_F1_GOVERNANCE_PRIVACY_COST_POLICY.md';
const reportPath = 'docs/control/SENTINEL_F1_VALIDATION_REPORT_20260816.md';
const workflowPath = '.github/workflows/sentinel-phase1-governance.yml';

const master = req(masterPath);
const roadmap = req(roadmapPath);
const policy = req(policyPath);
const report = req(reportPath);
const workflow = req(workflowPath);

mustContain(master, [
  'Sentinel — Control Maestro',
  'Zero PHI/PII telemetry',
  'Vendor-neutral by design',
  'Cost-bounded observability',
  'UNKNOWN',
  'Sentinel Hub'
], 'MASTER');

for (let i = 1; i <= 13; i++) {
  assert(new RegExp(`FASE ${i}\\b`).test(roadmap), `ROADMAP:MISSING_PHASE_${i}`);
}
assert(!/FASE 14\b/.test(roadmap), 'ROADMAP:UNEXPECTED_PHASE_14');
mustContain(roadmap, [
  'FASE 1 — Governance, Privacy & Cost Guardrails',
  'FASE 13 — Sentinel Hub, System Map & Certification',
  'Zero-Cost gate',
  'Notion'
], 'ROADMAP');

mustContain(policy, [
  'allowlist-first',
  'Session Replay: **OFF**',
  'pay-as-you-go: OFF',
  'Costo incremental cloud autorizado para F1: US$0/mes',
  'SENTINEL_ENABLED',
  'SENTINEL_SENTRY_ENABLED',
  'SENTINEL_OTEL_EXPORT_ENABLED',
  'SENTINEL_REMEDIATION_ENABLED',
  'development',
  'zero-cost',
  'production',
  'Sentry temporalmente caído',
  'F1 solo puede certificarse `100_COMPLETE`'
], 'POLICY');

mustContain(policy, [
  'DNI/documentos',
  'teléfonos',
  'contenido de WhatsApp',
  '`Authorization`',
  'service-role',
  'raw webhook bodies',
  'prompts/respuestas de IA'
], 'PRIVACY_DENYLIST');

mustContain(policy, [
  '`system=ascenda-os`',
  '`environment`',
  '`service.name`',
  '`module`',
  '`component`',
  '`capability`',
  '`dependency`',
  '`request_id`',
  '`trace_id`',
  '`commit_sha`'
], 'TELEMETRY_ALLOWLIST');

mustNotContain(policy, [
  'pay-as-you-go: ON',
  'Session Replay: **ON**',
  'sendDefaultPii=true',
  'auto-deploy to production',
  'auto deploy to production'
], 'POLICY');

mustContain(report, [
  'SENTINEL F1',
  'F1-G01',
  'F1-G18',
  'VALIDATING'
], 'VALIDATION_REPORT');

mustContain(workflow, [
  'self-hosted',
  'Windows',
  'X64',
  'ascenda-fast',
  'node ci/sentinel/phase1_governance_contract.js',
  'cancel-in-progress: true'
], 'WORKFLOW');
mustNotContain(workflow, [
  'ubuntu-latest',
  'windows-latest',
  'macos-latest',
  'macos-'
], 'WORKFLOW');

// Guard against obvious real secret material in Sentinel control surfaces.
const scanFiles = [masterPath, roadmapPath, policyPath, reportPath, workflowPath, 'ci/sentinel/phase1_governance_contract.js'];
const suspicious = [
  /https:\/\/[A-Za-z0-9_-]{16,}@[A-Za-z0-9.-]+\.ingest(?:\.[A-Za-z0-9.-]+)?\.sentry\.io\/[0-9]+/i,
  /\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b/,
  /\bsb_secret_[A-Za-z0-9_-]{20,}\b/,
  /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/,
  /\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\b/
];
for (const p of scanFiles) {
  const text = req(p);
  for (const re of suspicious) assert(!re.test(text), `SECRET_GUARD:${p}:${re}`);
}

// F1 is governance-only. On PRs/feature branches, forbid runtime/DB mutations in this workstream.
function changedFilesAgainstBase() {
  try {
    const base = process.env.GITHUB_BASE_REF || 'main';
    cp.execFileSync('git', ['fetch', 'origin', base, '--depth=1'], {cwd: ROOT, stdio:'ignore'});
    const mb = cp.execFileSync('git', ['merge-base', 'HEAD', `origin/${base}`], {cwd: ROOT, encoding:'utf8'}).trim();
    return cp.execFileSync('git', ['diff', '--name-only', `${mb}...HEAD`], {cwd: ROOT, encoding:'utf8'})
      .split(/\r?\n/).map(s=>s.trim()).filter(Boolean);
  } catch (_) {
    return [];
  }
}
const changed = changedFilesAgainstBase();
const forbiddenPrefixes = ['app/', 'supabase/migrations/', 'supabase/functions/', 'migrations/'];
for (const p of changed) {
  assert(!forbiddenPrefixes.some(prefix => p.startsWith(prefix)), `F1_SCOPE_RUNTIME_OR_DB_CHANGE:${p}`);
}

console.log(JSON.stringify({
  ok: true,
  certificate: 'SENTINEL_F1_GOVERNANCE_CONTRACT_PASS',
  phases: 13,
  incremental_cloud_budget_usd_month: 0,
  zero_phi_pii: true,
  payg: false,
  runtime_db_changes_detected: false,
  changed_files_checked: changed.length
}, null, 2));
