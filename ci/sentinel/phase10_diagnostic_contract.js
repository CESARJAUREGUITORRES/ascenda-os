'use strict';

const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const cp=require('node:child_process');
const ROOT=path.resolve(__dirname,'../..');
const {runDiagnostic,normalizeRequest}=require('../../sentinel/diagnostics/diagnostic-runner.cjs');

function fixture(){return JSON.parse(fs.readFileSync(path.join(ROOT,'ci/sentinel/phase10_synthetic_request.json'),'utf8'));}
function head(){return cp.execFileSync('git',['rev-parse','HEAD'],{cwd:ROOT,encoding:'utf8'}).trim().toLowerCase();}

const sha=head();
const base={...fixture(),commit_sha:sha,release:`ascenda-os@${sha}`};
const health={ok:true,service:'synthetic-ci',child_alive:true,inner_ready:true};

const first=runDiagnostic(base,{toolingRoot:ROOT,repoRoot:ROOT,health});
const second=runDiagnostic(base,{toolingRoot:ROOT,repoRoot:ROOT,health});
assert.deepEqual(first.report,second.report,'same input must produce same report');
assert.equal(first.digest,second.digest,'same input must produce same digest');
assert.match(first.report.diagnostic_id,/^F10-[0-9a-f]{20}$/);
assert.equal(first.report.affected_sha_state,'EXACT');
assert.equal(first.report.plan.invariant_id,'whatsapp.outbound_receipt_stall');
assert.equal(first.report.safety.read_only,true);
assert.equal(first.report.safety.production_mutation,false);
assert.ok(first.report.evidence.some(e=>e.kind==='CONTRACT_TEST'&&e.result.code==='INVARIANT_MATCH'));
assert.ok(first.report.evidence.some(e=>e.kind==='RELEASE_CORRELATION'&&e.result.code==='AFFECTED_SHA_CHECKED_OUT'));
assert.ok(first.report.evidence.some(e=>e.kind==='HEALTH_CHECK'&&e.result.code==='HEALTH_OK'));
assert.ok(first.report.hypotheses.every(h=>h.causality_confirmed===false));
assert.doesNotMatch(first.markdown,/(authorization|cookie|password|service_role|apikey|secret)\s*[:=]/i);

assert.throws(()=>runDiagnostic({...base,patient_name:'synthetic'},{toolingRoot:ROOT,repoRoot:ROOT}),/F10_SENSITIVE_INPUT_KEY/);
assert.throws(()=>runDiagnostic({...base,commit_sha:'abc'},{toolingRoot:ROOT,repoRoot:ROOT}),/F10_COMMIT_SHA_INVALID/);
assert.throws(()=>runDiagnostic({...base,unexpected:'x'},{toolingRoot:ROOT,repoRoot:ROOT}),/F10_REQUEST_UNAPPROVED_KEY/);
assert.throws(()=>runDiagnostic({...base,evidence_refs:[{kind:'ci-run',id:'bad?query=1'}]},{toolingRoot:ROOT,repoRoot:ROOT}),/F10_EVIDENCE_REF_ID/);
assert.throws(()=>normalizeRequest({...base,diagnostic_revision:0},{toolingRoot:ROOT}),/F10_DIAGNOSTIC_REVISION_INVALID/);

const noSha=fixture();
const noShaReport=runDiagnostic(noSha,{toolingRoot:ROOT,repoRoot:ROOT}).report;
assert.equal(noShaReport.affected_sha_state,'UNKNOWN');
assert.ok(noShaReport.evidence.some(e=>e.kind==='MISSING_EVIDENCE'&&e.result.code==='AFFECTED_SHA_UNKNOWN'));

const unknown={...base,domain:'MYSTERY',component:'unknown-component',capability:'unknown-capability'};
const unknownReport=runDiagnostic(unknown,{toolingRoot:ROOT,repoRoot:ROOT}).report;
assert.equal(unknownReport.plan.invariant_id,null);
assert.ok(unknownReport.evidence.some(e=>e.kind==='MISSING_EVIDENCE'&&e.result.code==='NO_EXACT_INVARIANT'));
assert.equal(unknownReport.hypotheses[0].confidence,'UNKNOWN');
assert.equal(unknownReport.hypotheses[0].causality_confirmed,false);

const workflow=fs.readFileSync(path.join(ROOT,'.github/workflows/sentinel-phase10-diagnostic-runner.yml'),'utf8');
assert.match(workflow,/workflow_dispatch:/);
assert.match(workflow,/permissions:\s*\n\s*contents:\s*read/);
assert.match(workflow,/ascenda-zero-cost-v2/);
assert.match(workflow,/timeout-minutes:/);
assert.match(workflow,/concurrency:/);
assert.doesNotMatch(workflow,/contents:\s*write|pull-requests:\s*write|deployments:\s*write|actions:\s*write/i);
assert.doesNotMatch(workflow,/SUPABASE_(?:DB|SERVICE|ACCESS)|RAILWAY_TOKEN|SERVICE_ROLE|git\s+push|supabase\s+db\s+push/i);

const runner=fs.readFileSync(path.join(ROOT,'sentinel/diagnostics/diagnostic-runner.cjs'),'utf8');
assert.doesNotMatch(runner,/execute_sql|\/rest\/v1|supabase\s+db\s+push|railway\s+up|git['"]?,\s*\[['"]push/i);

console.log(JSON.stringify({
  ok:true,
  certificate:'SENTINEL_F10_DIAGNOSTIC_CONTRACT_PASS',
  deterministic_replay:true,
  exact_sha_checkout:true,
  f6_domain_contract:true,
  f7_release_correlation:true,
  f8_incident_contract:true,
  sensitive_key_rejection:true,
  invalid_sha_rejection:true,
  unknown_evidence_explicit:true,
  causality_not_assumed:true,
  read_only_workflow:true,
  no_production_write_path:true,
  report_digest:first.digest
}));
