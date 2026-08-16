'use strict';

const assert=require('node:assert/strict');
const {MemoryIncidentRepository}=require('../../sentinel/incidents/memory-repository.cjs');
const {IncidentEngine}=require('../../sentinel/incidents/incident-engine.cjs');

let clock='2026-08-16T23:00:00Z';
const repo=new MemoryIncidentRepository();
const engine=new IncidentEngine({repository:repo,clock:()=>clock,reopenWindowMinutes:60});
const trace='0123456789abcdef0123456789abcdef';
const req='123e4567-e89b-42d3-a456-426614174000';
const sha='01958565af1a5ffe426ffb0ac9e0588c77341175';
const incidentFp='production:whatsapp:human-outbound:provider-status-progression:provider-stall';

function signal(overrides={}){
  return {
    event_id:'evt-wa-001',
    signal_class:'AVAILABILITY',
    environment:'production',
    domain:'WHATSAPP',
    component:'human-outbound',
    capability:'provider-status-progression',
    failure_family:'provider-stall',
    signal_fingerprint:'availability:whatsapp:provider-stall',
    incident_fingerprint:incidentFp,
    severity:'P2',
    observed_at:'2026-08-16T22:59:00Z',
    evidence_refs:[
      {kind:'sentinel-signal',id:'availability-whatsapp-001'},
      {kind:'railway-deployment',id:'dep-207'}
    ],
    correlation:{release:`ascenda-os@${sha}`,commit_sha:sha,deployment_id:'dep-207',request_id:req,trace_id:trace,confidence:'EXACT'},
    ...overrides
  };
}

// First signal opens a stable SEN id.
const opened=engine.ingest(signal());
assert.equal(opened.replay,false);
assert.equal(opened.incident.incident_id,'SEN-2026-0001');
assert.equal(opened.incident.status,'OPEN');
assert.equal(opened.incident.severity,'P2');
assert.equal(opened.incident.signal_count,1);
assert.deepEqual(opened.incident.signal_classes,['AVAILABILITY']);
assert.equal(opened.incident.correlation.confidence,'EXACT');

// Exact event replay is a no-op and returns the same incident.
const replay=engine.ingest(signal());
assert.equal(replay.replay,true);
assert.equal(replay.mutated,false);
assert.equal(replay.incident.incident_id,'SEN-2026-0001');
assert.equal(replay.incident.signal_count,1);
assert.equal(repo.eventCount(),1);

// A different signal class converges into the same incident only because incident_fingerprint + taxonomy/failure family match.
clock='2026-08-16T23:02:00Z';
const business=engine.ingest(signal({
  event_id:'evt-wa-002',
  signal_class:'BUSINESS_HEALTH',
  signal_fingerprint:'business-health:whatsapp:outbound-receipt-stall',
  severity:'P1',
  observed_at:'2026-08-16T23:01:00Z',
  evidence_refs:[{kind:'sentinel-signal',id:'business-health-wa-002'}]
}));
assert.equal(business.incident.incident_id,'SEN-2026-0001');
assert.equal(business.incident.signal_count,2);
assert.deepEqual(business.incident.signal_classes,['AVAILABILITY','BUSINESS_HEALTH']);
assert.equal(business.incident.severity,'P1');
assert.ok(business.incident.timeline.some(x=>x.type==='SEVERITY_ESCALATED'&&x.from==='P2'&&x.to==='P1'));
assert.equal(business.incident.evidence_refs.length,3);

// Lifecycle transitions are explicit and invalid backwards transitions are rejected.
clock='2026-08-16T23:03:00Z';
assert.equal(engine.transition('SEN-2026-0001','ACK').incident.status,'ACK');
assert.throws(()=>engine.transition('SEN-2026-0001','OPEN'),/F8_STATUS_TRANSITION_INVALID/);
assert.equal(engine.transition('SEN-2026-0001','INVESTIGATING').incident.status,'INVESTIGATING');
assert.equal(engine.transition('SEN-2026-0001','MITIGATED').incident.status,'MITIGATED');
clock='2026-08-16T23:10:00Z';
const resolved=engine.transition('SEN-2026-0001','RESOLVED');
assert.equal(resolved.incident.status,'RESOLVED');
assert.equal(resolved.incident.resolved_at,'2026-08-16T23:10:00.000Z');
assert.throws(()=>engine.transition('SEN-2026-0001','ACK'),/F8_STATUS_TRANSITION_INVALID/);

// Replay of an old event after resolution still does not reopen.
clock='2026-08-16T23:12:00Z';
const oldReplay=engine.ingest(signal());
assert.equal(oldReplay.replay,true);
assert.equal(oldReplay.incident.status,'RESOLVED');

// New event with the same fingerprint inside 60m reopens the SAME incident id.
clock='2026-08-16T23:25:00Z';
const reopened=engine.ingest(signal({
  event_id:'evt-wa-003',
  signal_class:'ERROR',
  signal_fingerprint:'error:whatsapp:provider-stall',
  severity:'P2',
  observed_at:'2026-08-16T23:24:00Z',
  evidence_refs:[{kind:'sentry-issue',id:'ASCENDA-OS-123'}]
}));
assert.equal(reopened.reopened,true);
assert.equal(reopened.incident.incident_id,'SEN-2026-0001');
assert.equal(reopened.incident.status,'OPEN');
assert.equal(reopened.incident.reopened_count,1);
assert.equal(reopened.incident.signal_count,3);
assert.ok(reopened.incident.timeline.some(x=>x.type==='INCIDENT_REOPENED'));

// Resolve again. A new event outside reopen window must create a NEW stable incident id.
clock='2026-08-16T23:30:00Z';
engine.transition('SEN-2026-0001','RESOLVED');
clock='2026-08-17T01:45:00Z';
const outside=engine.ingest(signal({
  event_id:'evt-wa-004',
  signal_class:'BUSINESS_HEALTH',
  signal_fingerprint:'business-health:whatsapp:outbound-receipt-stall',
  severity:'P2',
  observed_at:'2026-08-17T01:44:00Z',
  evidence_refs:[{kind:'sentinel-signal',id:'business-health-wa-004'}]
}));
assert.equal(outside.reopened,false);
assert.equal(outside.incident.incident_id,'SEN-2026-0002');
assert.equal(outside.incident.status,'OPEN');

// Different failure family/fingerprint never merges implicitly merely because module/capability is similar.
clock='2026-08-17T01:46:00Z';
const separate=engine.ingest(signal({
  event_id:'evt-wa-005',
  signal_class:'DEPENDENCY',
  failure_family:'auth-failure',
  signal_fingerprint:'dependency:whatsapp:auth-failure',
  incident_fingerprint:'production:whatsapp:human-outbound:provider-status-progression:auth-failure',
  severity:'P1',
  observed_at:'2026-08-17T01:45:30Z',
  evidence_refs:[{kind:'sentinel-signal',id:'dependency-wa-auth-005'}]
}));
assert.equal(separate.incident.incident_id,'SEN-2026-0003');
assert.equal(repo.listIncidents().length,3);

// IDs are year-scoped and padded; a new year restarts that year's sequence without mutating previous ids.
clock='2027-01-01T00:05:00Z';
const nextYear=engine.ingest(signal({
  event_id:'evt-sales-2027-001',
  signal_class:'BUSINESS_HEALTH',
  environment:'production',
  domain:'SALES',
  component:'sales-intelligence',
  capability:'aggregate-sales-read',
  failure_family:'gateway-divergence',
  signal_fingerprint:'business-health:sales:gateway-divergence',
  incident_fingerprint:'production:sales:sales-intelligence:aggregate-sales-read:gateway-divergence',
  severity:'P2',
  observed_at:'2027-01-01T00:04:00Z',
  evidence_refs:[{kind:'sentinel-signal',id:'business-health-sales-2027-001'}],
  correlation:null
}));
assert.equal(nextYear.incident.incident_id,'SEN-2027-0001');
assert.equal(repo.getIncident('SEN-2026-0001').incident_id,'SEN-2026-0001');

// Privacy/evidence boundary: raw URLs/query strings and unapproved fields are rejected.
assert.throws(()=>engine.ingest(signal({event_id:'evt-bad-001',evidence_refs:[{kind:'sentry-issue',id:'https://example.test/issue?token=secret'}]})),/F8_EVIDENCE_REF_INVALID_TECHNICAL_ID/);
assert.throws(()=>engine.ingest({...signal({event_id:'evt-bad-002'}),patient_name:'NO'}),/F8_SIGNAL_UNAPPROVED_KEY/);
assert.throws(()=>engine.ingest(signal({event_id:'evt-bad-003',incident_fingerprint:'bad fingerprint with spaces'})),/F8_INCIDENT_FINGERPRINT_INVALID_SLUG/);

console.log(JSON.stringify({
  ok:true,
  certificate:'SENTINEL_F8_INCIDENT_ENGINE_SYNTHETIC_PASS',
  multi_signal_convergence:true,
  replay_idempotent:true,
  stable_sen_ids:true,
  severity_escalation:true,
  lifecycle_transitions:true,
  reopen_same_id_within_window:true,
  new_id_outside_window:true,
  unrelated_failures_not_merged:true,
  evidence_reference_only:true,
  production_persistence:false
}));
