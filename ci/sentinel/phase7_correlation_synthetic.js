'use strict';

const assert=require('node:assert/strict');
const runtime=require('../../sentinel/correlation/runtime-metadata.cjs');
const engine=require('../../sentinel/correlation/correlation-engine.cjs');

const shaOld='1111111111111111111111111111111111111111';
const shaNew='2222222222222222222222222222222222222222';
const shaOther='3333333333333333333333333333333333333333';
const req='123e4567-e89b-42d3-a456-426614174000';
const trace='0123456789abcdef0123456789abcdef';

const envMeta=runtime.fromEnv({
  RAILWAY_GIT_COMMIT_SHA:shaNew,
  RAILWAY_DEPLOYMENT_ID:'dep-new',
  RAILWAY_ENVIRONMENT_NAME:'production',
  RAILWAY_SERVICE_NAME:'ascenda-os',
  RAILWAY_REPLICA_ID:'replica-1',
  RAILWAY_GIT_AUTHOR:'SHOULD_NOT_APPEAR',
  RAILWAY_GIT_COMMIT_MESSAGE:'FREE TEXT MUST NOT APPEAR'
},{request_id:req,trace_id:trace,observed_at:'2026-08-16T23:30:00Z'});
assert.equal(envMeta.commit_sha,shaNew);
assert.equal(envMeta.release,`ascenda-os@${shaNew}`);
assert.equal(envMeta.deployment_id,'dep-new');
assert.equal(envMeta.environment,'production');
assert.equal(envMeta.request_id,req);
assert.equal(envMeta.trace_id,trace);
assert.ok(!Object.prototype.hasOwnProperty.call(envMeta,'RAILWAY_GIT_AUTHOR'));
assert.ok(!JSON.stringify(envMeta).includes('SHOULD_NOT_APPEAR'));
assert.ok(!JSON.stringify(envMeta).includes('FREE TEXT'));

const deployments=[
  {deployment_id:'dep-old',commit_sha:shaOld,environment:'production',service_name:'ascenda-os',started_at:'2026-08-16T21:00:00Z',status:'SUCCESS',health_state:'HEALTHY'},
  {deployment_id:'dep-new',commit_sha:shaNew,environment:'production',service_name:'ascenda-os',started_at:'2026-08-16T23:00:00Z',status:'SUCCESS',health_state:'DEGRADED'},
  {deployment_id:'dep-other',commit_sha:shaOther,environment:'zero-cost',service_name:'ascenda-os',started_at:'2026-08-16T22:55:00Z',status:'SUCCESS',health_state:'HEALTHY'}
];
const changes=[
  {commit_sha:shaOld,pull_request:205,merged_at:'2026-08-16T21:00:00Z'},
  {commit_sha:shaNew,pull_request:206,merged_at:'2026-08-16T22:55:00Z'}
];

const exact=engine.correlate({
  signal:{observed_at:'2026-08-16T23:30:00Z',environment:'production',service_name:'ascenda-os',release:`ascenda-os@${shaNew}`,commit_sha:shaNew,deployment_id:'dep-new',request_id:req,trace_id:trace},
  deployments,changes
});
assert.equal(exact.confidence,'EXACT');
assert.equal(exact.commit_sha,shaNew);
assert.equal(exact.deployment_id,'dep-new');
assert.equal(exact.github_change.pull_request,206);
assert.equal(exact.suspect_change.causality,'NOT_ESTABLISHED');
assert.equal(exact.rollback.status,'EXACT_TARGET');
assert.equal(exact.rollback.target.commit_sha,shaOld);
assert.equal(exact.rollback.target.deployment_id,'dep-old');
assert.equal(exact.rollback.action_authorized,false);
assert.equal(exact.automatic_action_authorized,false);

const releaseOnly=engine.correlate({
  signal:{observed_at:'2026-08-16T23:20:00Z',environment:'production',service_name:'ascenda-os',release:`ascenda-os@${shaNew}`,request_id:req,trace_id:trace},
  deployments,changes
});
assert.equal(releaseOnly.confidence,'STRONG');
assert.equal(releaseOnly.deployment_id,'dep-new');
assert.equal(releaseOnly.commit_sha,shaNew);

const temporal=engine.correlate({
  signal:{observed_at:'2026-08-16T23:10:00Z',environment:'production',service_name:'ascenda-os',request_id:req,trace_id:trace},
  deployments,changes,regression_window_minutes:30
});
assert.equal(temporal.confidence,'WEAK');
assert.equal(temporal.suspect_change.basis,'TEMPORAL_CANDIDATE');
assert.equal(temporal.suspect_change.causality,'NOT_ESTABLISHED');

const contradiction=engine.correlate({
  signal:{observed_at:'2026-08-16T23:30:00Z',environment:'production',service_name:'ascenda-os',release:`ascenda-os@${shaOld}`,commit_sha:shaNew,deployment_id:'dep-new'},
  deployments,changes
});
assert.equal(contradiction.confidence,'UNKNOWN');
assert.equal(contradiction.correlation_reason,'CONTRADICTORY_RELEASE_AND_COMMIT');
assert.equal(contradiction.suspect_change,null);
assert.equal(contradiction.rollback.status,'UNKNOWN');

const noPrior=engine.correlate({
  signal:{observed_at:'2026-08-16T21:10:00Z',environment:'production',service_name:'ascenda-os',commit_sha:shaOld,deployment_id:'dep-old'},
  deployments,changes
});
assert.equal(noPrior.confidence,'EXACT');
assert.equal(noPrior.rollback.status,'UNKNOWN');
assert.equal(noPrior.rollback.reason,'NO_PRIOR_KNOWN_GOOD_DEPLOYMENT');

const wrongEnv=engine.correlate({
  signal:{observed_at:'2026-08-16T23:30:00Z',environment:'production',service_name:'ascenda-os',commit_sha:shaOther,deployment_id:'dep-other'},
  deployments,changes
});
assert.equal(wrongEnv.confidence,'UNKNOWN');

assert.throws(()=>engine.correlate({signal:{observed_at:'2026-08-16T23:30:00Z',environment:'production',service_name:'ascenda-os',patient_name:'NO'}}),/F7_SIGNAL_UNAPPROVED_KEY/);
assert.throws(()=>engine.correlate({signal:{observed_at:'invalid',environment:'production',service_name:'ascenda-os'}}),/F7_SIGNAL_OBSERVED_AT_INVALID/);

console.log(JSON.stringify({
  ok:true,
  certificate:'SENTINEL_F7_CORRELATION_SYNTHETIC_PASS',
  exact_sha_environment:true,
  exact_deployment:true,
  request_trace_passthrough:true,
  temporal_candidate_is_inference:true,
  causality_never_asserted:true,
  rollback_exact_known_good:true,
  rollback_never_guessed:true,
  contradiction_unknown:true,
  free_text_not_ingested:true,
  production_mutation:false
}));
