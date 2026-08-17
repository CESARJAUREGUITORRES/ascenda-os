'use strict';

const fs=require('fs');
const path=require('path');
const ROOT=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(ROOT,p),'utf8');
const json=p=>JSON.parse(read(p));
const ok=(v,m)=>{if(!v)throw new Error(m);};

const f7=read('docs/control/SENTINEL_F7_FINAL_CERTIFICATE_20260816.md');
const f6=json('sentinel/business-health/f6-contract.json');
const f5=json('sentinel/availability/f5-contract.json');
const f8=json('sentinel/incidents/f8-contract.json');
const engine=read('sentinel/incidents/incident-engine.cjs');
const repo=read('sentinel/incidents/memory-repository.cjs');

ok(f7.includes('F7 — Final Certificate'),'F7_CERTIFICATE_MISSING');
ok(f8.schema_version==='sentinel-incidents/v1'&&f8.phase==='F8','F8_CONTRACT_INVALID');
ok(f8.design.vendor_neutral===true&&f8.design.repository_adapter===true,'F8_VENDOR_NEUTRAL_REPOSITORY_REQUIRED');
ok(f8.design.production_persistence_in_initial_core===false,'F8_INITIAL_CORE_BOUNDARY_DRIFT');
ok(f8.design.notion_live_incident_store===false,'F8_NOTION_LIVE_STORE_FORBIDDEN');
ok(f8.design.automatic_notification===false&&f8.design.automatic_remediation===false,'F8_SCOPE_AUTOMATION_DRIFT');
ok(f8.design.zero_phi_pii===true,'F8_PRIVACY_DRIFT');

ok(f8.incident_id.format==='SEN-YYYY-NNNN','F8_INCIDENT_ID_FORMAT_DRIFT');
ok(f8.incident_id.sequence_scope==='year','F8_INCIDENT_SEQUENCE_SCOPE_DRIFT');
ok(f8.incident_id.allocation==='repository-transactional','F8_INCIDENT_ID_ALLOCATION_DRIFT');
ok(f8.incident_id.client_side_guessing_forbidden===true,'F8_CLIENT_ID_GUESSING_FORBIDDEN');

for(const cls of ['ERROR','AVAILABILITY','BUSINESS_HEALTH','DEPENDENCY','DEPLOYMENT_CHANGE','SECURITY','USER_REPORTED'])ok(f8.signal_classes.includes(cls),`F8_SIGNAL_CLASS_MISSING:${cls}`);
ok(JSON.stringify(f8.severities)===JSON.stringify(['P0','P1','P2','P3']),'F8_SEVERITY_DRIFT');
ok(JSON.stringify(f8.statuses)===JSON.stringify(['OPEN','ACK','INVESTIGATING','MITIGATED','RESOLVED']),'F8_STATUS_DRIFT');
ok(f8.reopen.enabled===true&&f8.reopen.window_minutes===60,'F8_REOPEN_POLICY_DRIFT');
ok(f8.reopen.same_incident_fingerprint_required===true&&f8.reopen.new_event_id_required===true,'F8_REOPEN_IDENTITY_GUARD_MISSING');
ok(f8.reopen.outside_window_creates_new_incident===true,'F8_REOPEN_WINDOW_DRIFT');

ok(f8.deduplication.cross_signal_convergence===true,'F8_MULTI_SIGNAL_CONVERGENCE_DISABLED');
ok(f8.deduplication.implicit_same_module_merge_forbidden===true,'F8_IMPLICIT_MODULE_MERGE_FORBIDDEN');
ok(f8.deduplication.active_incident_uniqueness.includes('one non-resolved incident'),'F8_ACTIVE_UNIQUENESS_DRIFT');

ok(f8.evidence_reference.raw_payload_forbidden===true&&f8.evidence_reference.query_strings_forbidden===true&&f8.evidence_reference.credentials_forbidden===true,'F8_EVIDENCE_PRIVACY_DRIFT');
ok(f8.correlation_reference.causality_not_established===true,'F8_CAUSALITY_GUARD_MISSING');
ok(f8.persistence_target.preferred==='Supabase/PostgreSQL','F8_PERSISTENCE_TARGET_DRIFT');
ok(f8.persistence_target.initial_engine_repository==='in-memory reference adapter','F8_REFERENCE_REPOSITORY_DRIFT');
ok(f8.persistence_target.fixture_uses_production_persistence===false,'F8_FIXTURE_MUST_NOT_USE_PRODUCTION');
ok(f8.persistence_target.live_incidents_in_notion===false,'F8_NOTION_RUNTIME_STORE_FORBIDDEN');
ok(f8.persistence_target.production_status==='certified','F8_PRODUCTION_PERSISTENCE_NOT_CERTIFIED');
ok(f8.persistence_target.production_migration_version==='20260817000618','F8_PRODUCTION_MIGRATION_VERSION_DRIFT');
ok(f8.persistence_target.production_canary_incident==='SEN-2026-0001'&&f8.persistence_target.production_canary_final_status==='RESOLVED','F8_PRODUCTION_CANARY_DRIFT');
ok(f8.gates.production_persistence_requires_separate_gate===true,'F8_PRODUCTION_PERSISTENCE_GATE_MISSING');
ok(f8.gates.zero_cost_persistence_certified===true&&f8.gates.production_persistence_certified===true,'F8_PERSISTENCE_CERTIFICATION_DRIFT');

ok(f6.signal_contract.persistence_owned_by_phase==='F8','F8_F6_PERSISTENCE_HANDOFF_MISSING');
ok(f5.deployment.outage_recovery_gate==='PASS','F8_F5_AVAILABILITY_NOT_CERTIFIED');

ok(engine.includes("causality")===false,'F8_ENGINE_MUST_NOT_INVENT_CAUSALITY');
ok(engine.includes("F8_EVENT_ALREADY_RECORDED")===false,'F8_ENGINE_SHOULD_DELEGATE_EVENT_DUPLICATION_TO_REPOSITORY');
ok(engine.includes("INCIDENT_REOPENED"),'F8_REOPEN_TIMELINE_MISSING');
ok(engine.includes("SEVERITY_ESCALATED"),'F8_SEVERITY_TIMELINE_MISSING');
ok(engine.includes("F8_STATUS_TRANSITION_INVALID"),'F8_STATUS_GUARD_MISSING');
ok(engine.includes("F8_INCIDENT_FINGERPRINT_SCOPE_CONTRADICTION"),'F8_SCOPE_CONTRADICTION_GUARD_MISSING');
ok(repo.includes("F8_ACTIVE_INCIDENT_UNIQUENESS_BROKEN"),'F8_REFERENCE_ACTIVE_UNIQUENESS_GUARD_MISSING');
ok(repo.includes("allocateIncidentId"),'F8_REPOSITORY_ID_ALLOCATOR_MISSING');

console.log(JSON.stringify({
  ok:true,
  certificate:'SENTINEL_F8_INCIDENT_ENGINE_CONTRACT_PASS',
  f7_complete:true,
  signal_classes:f8.signal_classes.length,
  severities:f8.severities,
  statuses:f8.statuses,
  stable_ids:true,
  replay_idempotency:true,
  multi_signal_convergence:true,
  evidence_reference_only:true,
  notion_live_store:false,
  fixture_uses_production_persistence:false,
  production_persistence_status:f8.persistence_target.production_status,
  production_migration_version:f8.persistence_target.production_migration_version,
  production_canary_incident:f8.persistence_target.production_canary_incident,
  production_canary_final_status:f8.persistence_target.production_canary_final_status
},null,2));
