'use strict';

const assert=require('node:assert/strict');
const engine=require('../../sentinel/business-health/invariant-engine.cjs');

const observed='2026-08-16T22:45:00Z';
const healthy=()=>({
  observed_at:observed,
  domains:{
    call_center:{operating_window:true,window_age_minutes:180,active_advisors:4,eligible_leads:25,calls_in_window:18,latest_call_age_minutes:4},
    sales:{scope_consistent:true,source_sales_count:125,gateway_has_data:true,gateway_sales_count:125},
    whatsapp:{accepted_without_progress:0,oldest_unprogressed_age_minutes:null},
    email:{feature_expected:true,gateway_service_configured:true,provider_send_configured:true,webhook_configured:true,sent_without_event:0,oldest_sent_without_event_age_minutes:null,legacy_child_privilege_warning:false}
  }
});

const baseline=engine.evaluateSnapshot(healthy());
assert.equal(baseline.state,'HEALTHY');
assert.deepEqual(baseline.signals.map(s=>s.state),['HEALTHY','HEALTHY','HEALTHY','HEALTHY']);

const cc=healthy();
cc.domains.call_center={operating_window:true,window_age_minutes:75,active_advisors:4,eligible_leads:25,calls_in_window:0,latest_call_age_minutes:null};
const ccOut=engine.evaluateSnapshot(cc);
assert.equal(ccOut.state,'INCIDENT');
assert.equal(ccOut.signals[0].state,'INCIDENT');
assert.equal(ccOut.signals[0].reason,'CORRELATED_ACTIVITY_STALL_60M');
assert.deepEqual(ccOut.signals.slice(1).map(s=>s.state),['HEALTHY','HEALTHY','HEALTHY']);

const sales=healthy();
sales.domains.sales={scope_consistent:true,source_sales_count:125,gateway_has_data:false,gateway_sales_count:0};
const salesOut=engine.evaluateSnapshot(sales);
assert.equal(salesOut.signals[1].state,'INCIDENT');
assert.equal(salesOut.signals[1].reason,'SOURCE_PRESENT_GATEWAY_EMPTY');

const wa=healthy();
wa.domains.whatsapp={accepted_without_progress:3,oldest_unprogressed_age_minutes:72};
const waOut=engine.evaluateSnapshot(wa);
assert.equal(waOut.signals[2].state,'INCIDENT');
assert.equal(waOut.signals[2].reason,'OUTBOUND_RECEIPT_STALL_60M');

const email=healthy();
email.domains.email={feature_expected:true,gateway_service_configured:true,provider_send_configured:true,webhook_configured:true,sent_without_event:4,oldest_sent_without_event_age_minutes:75,legacy_child_privilege_warning:false};
const emailOut=engine.evaluateSnapshot(email);
assert.equal(emailOut.signals[3].state,'INCIDENT');
assert.equal(emailOut.signals[3].reason,'EMAIL_PROVIDER_EVENT_STALL_60M');

const emailConfig=healthy();
emailConfig.domains.email={feature_expected:true,gateway_service_configured:false,provider_send_configured:true,webhook_configured:true,sent_without_event:0,oldest_sent_without_event_age_minutes:null,legacy_child_privilege_warning:false};
assert.equal(engine.evaluateSnapshot(emailConfig).signals[3].reason,'GOVERNED_EMAIL_GATEWAY_NOT_READY');

const legacyNoise=healthy();
legacyNoise.domains.email.legacy_child_privilege_warning=true;
const legacyNoiseOut=engine.evaluateSnapshot(legacyNoise);
assert.equal(legacyNoiseOut.signals[3].state,'HEALTHY','legacy child privilege warning alone must not create an incident');

const ccGrace=healthy();
ccGrace.domains.call_center={operating_window:true,window_age_minutes:35,active_advisors:3,eligible_leads:10,calls_in_window:0,latest_call_age_minutes:null};
assert.equal(engine.evaluateSnapshot(ccGrace).signals[0].state,'DEGRADED');

const waGrace=healthy();
waGrace.domains.whatsapp={accepted_without_progress:1,oldest_unprogressed_age_minutes:20};
assert.equal(engine.evaluateSnapshot(waGrace).signals[2].state,'DEGRADED');

const outside=healthy();
outside.domains.call_center.operating_window=false;
assert.equal(engine.evaluateSnapshot(outside).signals[0].state,'UNKNOWN');

const emptySales=healthy();
emptySales.domains.sales={scope_consistent:true,source_sales_count:0,gateway_has_data:false,gateway_sales_count:0};
assert.equal(engine.evaluateSnapshot(emptySales).signals[1].state,'HEALTHY','valid empty sales scope must not be treated as an incident');

const unsafe=healthy();
unsafe.domains.whatsapp.to_number=51999999999;
assert.throws(()=>engine.evaluateSnapshot(unsafe),/F6_UNAPPROVED_KEY|F6_SENSITIVE_KEY/);

for(const signal of baseline.signals){
  assert.match(signal.fingerprint,/^business-health:[a-z_]+:[a-z0-9_.-]+$/);
  for(const value of Object.values(signal.evidence))assert.ok(value===null||typeof value==='number'||typeof value==='boolean');
}

console.log(JSON.stringify({
  ok:true,
  certificate:'SENTINEL_F6_SYNTHETIC_INVARIANTS_PASS',
  domains:['CALL_CENTER','SALES','WHATSAPP','EMAIL'],
  silent_failures:4,
  zero_phi_pii:true,
  valid_empty_not_incident:true,
  legacy_email_child_warning_not_incident:true,
  production_mutation:false
}));
