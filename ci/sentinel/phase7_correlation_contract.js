'use strict';

const fs=require('fs');
const path=require('path');
const ROOT=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(ROOT,p),'utf8');
const json=p=>JSON.parse(read(p));
const ok=(v,m)=>{if(!v)throw new Error(m);};

const f6=read('docs/control/SENTINEL_F6_FINAL_CERTIFICATE_20260816.md');
const f3=json('sentinel/telemetry/contract-v1.json');
const f4=json('sentinel/sentry/f4-contract.json');
const f7=json('sentinel/correlation/f7-contract.json');
const runtime=read('sentinel/correlation/runtime-metadata.cjs');
const engine=read('sentinel/correlation/correlation-engine.cjs');

ok(f6.includes('F6 — Final Certificate'),'F6_CERTIFICATE_MISSING');
ok(f7.schema_version==='sentinel-correlation/v1'&&f7.phase==='F7','F7_CONTRACT_INVALID');
ok(f7.design.vendor_neutral===true&&f7.design.read_only===true&&f7.design.zero_phi_pii===true,'F7_DESIGN_DRIFT');
ok(f7.design.railway_api_required===false,'F7_RAILWAY_API_LOCKIN_FORBIDDEN');
ok(f7.design.github_write_required===false,'F7_GITHUB_WRITE_FORBIDDEN');
ok(f7.design.production_runtime_activation_in_f7===false,'F7_RUNTIME_ACTIVATION_FORBIDDEN');
ok(f7.design.automatic_rollback===false,'F7_AUTOMATIC_ROLLBACK_FORBIDDEN');

ok(f3.propagation.request_id_format==='uuid-v4','F7_F3_REQUEST_ID_CONTRACT_MISSING');
ok(f3.propagation.trace_id_hex_length===32,'F7_F3_TRACE_ID_CONTRACT_MISSING');
ok(f3.resource.required.includes('service.version'),'F7_F3_SERVICE_VERSION_REQUIRED');
ok(f3.resource.required.includes('deployment.environment.name'),'F7_F3_ENV_REQUIRED');
ok(f4.activation.release_variable==='RAILWAY_GIT_COMMIT_SHA','F7_F4_RELEASE_VARIABLE_DRIFT');
ok(f4.release.format==='ascenda-os@<commit_sha>','F7_F4_RELEASE_FORMAT_DRIFT');

const allowed=new Set(f7.railway_system_metadata.allowed_variables);
for(const key of ['RAILWAY_GIT_COMMIT_SHA','RAILWAY_DEPLOYMENT_ID','RAILWAY_ENVIRONMENT_NAME','RAILWAY_SERVICE_NAME','RAILWAY_REPLICA_ID'])ok(allowed.has(key),`F7_RAILWAY_METADATA_MISSING:${key}`);
const forbidden=new Set(f7.railway_system_metadata.forbidden_variables);
ok(forbidden.has('RAILWAY_GIT_AUTHOR')&&forbidden.has('RAILWAY_GIT_COMMIT_MESSAGE'),'F7_RAILWAY_FREE_TEXT_NOT_FORBIDDEN');

ok(f7.regression_window.temporal_candidate_is_causality===false,'F7_CAUSALITY_INFERENCE_GUARD_MISSING');
ok(f7.rollback_policy.never_guess===true&&f7.rollback_policy.action_authorized===false,'F7_ROLLBACK_GUARD_DRIFT');
ok(f7.rollback_policy.execution_owned_by_phase==='F12','F7_ROLLBACK_EXECUTION_SCOPE_DRIFT');
ok(f7.privacy.free_text_forbidden===true&&f7.privacy.request_body_forbidden===true&&f7.privacy.message_content_forbidden===true,'F7_PRIVACY_DRIFT');
ok(f7.privacy.patient_contact_identifiers_forbidden===true&&f7.privacy.auth_material_forbidden===true,'F7_PRIVACY_IDENTITY_DRIFT');

ok(runtime.includes('RAILWAY_GIT_COMMIT_SHA'),'F7_RUNTIME_SHA_SOURCE_MISSING');
ok(runtime.includes('RAILWAY_DEPLOYMENT_ID'),'F7_RUNTIME_DEPLOYMENT_SOURCE_MISSING');
ok(runtime.includes('RAILWAY_ENVIRONMENT_NAME'),'F7_RUNTIME_ENV_SOURCE_MISSING');
ok(!runtime.includes('RAILWAY_GIT_COMMIT_MESSAGE:'),'F7_RUNTIME_FREE_TEXT_CAPTURE');
ok(engine.includes("causality:'NOT_ESTABLISHED'"),'F7_CAUSALITY_WORDING_MISSING');
ok(engine.includes("action_authorized:false"),'F7_ROLLBACK_ACTION_GUARD_MISSING');
ok(engine.includes("NO_PRIOR_KNOWN_GOOD_DEPLOYMENT"),'F7_ROLLBACK_UNKNOWN_GUARD_MISSING');

console.log(JSON.stringify({
  ok:true,
  certificate:'SENTINEL_F7_CORRELATION_CONTRACT_PASS',
  f3_request_trace_contract:true,
  f4_release_contract:true,
  railway_system_metadata:true,
  railway_api_required:false,
  causality_not_asserted:true,
  rollback_never_guessed:true,
  production_runtime_activation:false,
  zero_phi_pii:true
},null,2));
