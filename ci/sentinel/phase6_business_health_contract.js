'use strict';

const fs=require('fs');
const path=require('path');
const ROOT=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(ROOT,p),'utf8');
const json=p=>JSON.parse(read(p));
const ok=(v,m)=>{if(!v)throw new Error(m);};

const f5=read('docs/control/SENTINEL_F5_FINAL_CERTIFICATE_20260816.md');
const c=json('sentinel/business-health/f6-contract.json');
const engine=require(path.join(ROOT,'sentinel/business-health/invariant-engine.cjs'));
const calls=read('app/public/calls.js');
const f4=read('app/server-f4.js');
const wa2=read('app/server-wa2.js');
const wa3=read('app/server-wa3.js');
const email=read('app/email-gateway.js');

ok(f5.includes('**Status:** `100_COMPLETE`'),'F5_NOT_CLOSED');
ok(c.schema_version==='sentinel-business-health/v1'&&c.phase==='F6','F6_CONTRACT_INVALID');
ok(c.mode==='aggregate-read-only','F6_MODE_DRIFT');
ok(c.production_mutation===false&&c.new_database_objects===false&&c.automatic_remediation===false,'F6_SCOPE_MUTATION_FORBIDDEN');
ok(c.privacy.zero_phi_pii===true&&c.privacy.aggregate_only===true,'F6_PRIVACY_BASELINE_DRIFT');
ok(c.privacy.request_bodies_forbidden===true&&c.privacy.message_content_forbidden===true,'F6_CONTENT_BOUNDARY_DRIFT');
ok(c.privacy.patient_identifiers_forbidden===true&&c.privacy.contact_identifiers_forbidden===true&&c.privacy.auth_material_forbidden===true,'F6_IDENTITY_BOUNDARY_DRIFT');
ok(c.signal_contract.persistence_owned_by_phase==='F8','F6_PERSISTENCE_SCOPE_DRIFT');
ok(c.signal_contract.notifications_owned_by_phase==='F9','F6_NOTIFICATION_SCOPE_DRIFT');
ok(c.signal_contract.evidence_must_be_aggregate===true,'F6_EVIDENCE_AGGREGATE_REQUIRED');

const ids=new Set(c.invariants.map(x=>x.id));
for(const id of ['callcenter.activity_stall','sales.pipeline_consistency','whatsapp.outbound_receipt_stall','email.provider_pipeline_health'])ok(ids.has(id),`F6_INVARIANT_MISSING:${id}`);
ok(c.invariants.length===4,'F6_BASELINE_INVARIANT_COUNT_DRIFT');
ok(c.thresholds.call_center_degraded_minutes===30&&c.thresholds.call_center_incident_minutes===60,'F6_CALLCENTER_THRESHOLDS_DRIFT');
ok(c.thresholds.whatsapp_degraded_minutes===15&&c.thresholds.whatsapp_incident_minutes===60,'F6_WHATSAPP_THRESHOLDS_DRIFT');
ok(c.thresholds.email_degraded_minutes===15&&c.thresholds.email_incident_minutes===60,'F6_EMAIL_THRESHOLDS_DRIFT');

ok(calls.includes("_rpc('aos_panel_asesor'"),'F6_CALLCENTER_PANEL_SOURCE_MISSING');
ok(calls.includes("_rpc('aos_monitoreo_equipo'"),'F6_CALLCENTER_TEAM_SOURCE_MISSING');
ok(calls.includes("_rpc('aos_siguiente_lead_v2'"),'F6_CALLCENTER_BACKLOG_SOURCE_MISSING');
ok(f4.includes("rpcName='aos_sales_intelligence_gateway'"),'F6_SALES_GATEWAY_SOURCE_MISSING');
ok(wa2.includes('aos_wa_conversations_v1'),'F6_WA_CONVERSATION_SOURCE_MISSING');
ok(wa3.includes('aos_wa_outbound_requests_v1'),'F6_WA_OUTBOUND_SOURCE_MISSING');
ok(f4.includes("if(st.status==='delivered')patch.delivered_at"),'F6_WA_DELIVERY_PROGRESS_SOURCE_MISSING');
ok(f4.includes("if(st.status==='failed')patch.failed_at"),'F6_WA_FAILURE_PROGRESS_SOURCE_MISSING');
ok(email.includes("action === 'CONFIG_HEALTH'"),'F6_EMAIL_CONFIG_HEALTH_SOURCE_MISSING');
ok(email.includes("'/rest/v1/aos_email_envios'"),'F6_EMAIL_SEND_SOURCE_MISSING');
ok(email.includes('handleWebhook'),'F6_EMAIL_WEBHOOK_SOURCE_MISSING');
ok(f4.includes("delete childEnv.SUPABASE_SERVICE_ROLE_KEY"),'F6_EMAIL_LEGACY_WARNING_CONTEXT_MISSING');

const healthy={
  observed_at:'2026-08-16T22:45:00Z',
  domains:{
    call_center:{operating_window:true,window_age_minutes:120,active_advisors:2,eligible_leads:4,calls_in_window:6,latest_call_age_minutes:5},
    sales:{scope_consistent:true,source_sales_count:4,gateway_has_data:true,gateway_sales_count:4},
    whatsapp:{accepted_without_progress:0,oldest_unprogressed_age_minutes:null},
    email:{feature_expected:true,gateway_service_configured:true,provider_send_configured:true,webhook_configured:true,sent_without_event:0,oldest_sent_without_event_age_minutes:null,legacy_child_privilege_warning:true}
  }
};
const out=engine.evaluateSnapshot(healthy);
ok(out.state==='HEALTHY','F6_ENGINE_HEALTHY_BASELINE_FAILED');
ok(out.signals.length===4,'F6_SIGNAL_COUNT_DRIFT');
ok(out.signals.every(s=>['HEALTHY','DEGRADED','INCIDENT','UNKNOWN'].includes(s.state)),'F6_INVALID_SIGNAL_STATE');
ok(out.signals.every(s=>Object.values(s.evidence).every(v=>v===null||typeof v==='number'||typeof v==='boolean')),'F6_NON_AGGREGATE_EVIDENCE');

console.log(JSON.stringify({
  ok:true,
  certificate:'SENTINEL_F6_BUSINESS_HEALTH_CONTRACT_PASS',
  f5_complete:true,
  domains:['CALL_CENTER','SALES','WHATSAPP','EMAIL'],
  invariants:4,
  aggregate_only:true,
  zero_phi_pii:true,
  persistence_phase:'F8',
  notification_phase:'F9',
  production_mutation:false
},null,2));
