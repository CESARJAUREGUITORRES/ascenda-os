'use strict';

const STATES=Object.freeze({
  HEALTHY:'HEALTHY',
  DEGRADED:'DEGRADED',
  INCIDENT:'INCIDENT',
  UNKNOWN:'UNKNOWN'
});

const PRIORITY=Object.freeze({HEALTHY:0,UNKNOWN:1,DEGRADED:2,INCIDENT:3});
const DOMAIN_KEYS=Object.freeze({
  call_center:new Set(['operating_window','window_age_minutes','active_advisors','eligible_leads','calls_in_window','latest_call_age_minutes']),
  sales:new Set(['scope_consistent','source_sales_count','gateway_has_data','gateway_sales_count']),
  whatsapp:new Set(['accepted_without_progress','oldest_unprogressed_age_minutes']),
  email:new Set(['feature_expected','gateway_service_configured','provider_send_configured','webhook_configured','monitoring_horizon_minutes','recent_sent_count','recent_sent_without_event','oldest_recent_without_event_age_minutes','legacy_child_privilege_warning'])
});
const FORBIDDEN_KEY_FRAGMENTS=[
  'phone','telefono','numero_limpio','dni','email_address','recipient','destinatario','patient','paciente',
  'contact_name','message_body','prompt','authorization','cookie','token','apikey','service_role','secret','password'
];

function finite(v){return typeof v==='number'&&Number.isFinite(v)?v:null;}
function nonNegative(v){const n=finite(v);return n==null?null:Math.max(0,n);}
function boolOrNull(v){return typeof v==='boolean'?v:null;}
function isoOrNow(value){
  if(typeof value==='string'&&!Number.isNaN(Date.parse(value)))return new Date(value).toISOString();
  return new Date().toISOString();
}
function keyLooksSensitive(key){
  const k=String(key||'').toLowerCase();
  return FORBIDDEN_KEY_FRAGMENTS.some(fragment=>k.includes(fragment));
}
function validateDomain(name,data){
  if(data==null)return;
  if(typeof data!=='object'||Array.isArray(data))throw new Error(`F6_INVALID_DOMAIN:${name}`);
  const allowed=DOMAIN_KEYS[name];
  if(!allowed)throw new Error(`F6_UNKNOWN_DOMAIN:${name}`);
  for(const [key,value] of Object.entries(data)){
    if(keyLooksSensitive(key))throw new Error(`F6_SENSITIVE_KEY:${name}.${key}`);
    if(!allowed.has(key))throw new Error(`F6_UNAPPROVED_KEY:${name}.${key}`);
    if(value!==null&&typeof value!=='boolean'&&typeof value!=='number')throw new Error(`F6_NON_AGGREGATE_VALUE:${name}.${key}`);
  }
}
function validateSnapshot(snapshot){
  if(!snapshot||typeof snapshot!=='object'||Array.isArray(snapshot))throw new Error('F6_SNAPSHOT_REQUIRED');
  const top=new Set(['observed_at','domains']);
  for(const key of Object.keys(snapshot)){
    if(keyLooksSensitive(key))throw new Error(`F6_SENSITIVE_KEY:${key}`);
    if(!top.has(key))throw new Error(`F6_UNAPPROVED_TOP_KEY:${key}`);
  }
  if(snapshot.observed_at!=null&&(typeof snapshot.observed_at!=='string'||Number.isNaN(Date.parse(snapshot.observed_at))))throw new Error('F6_INVALID_OBSERVED_AT');
  const domains=snapshot.domains;
  if(!domains||typeof domains!=='object'||Array.isArray(domains))throw new Error('F6_DOMAINS_REQUIRED');
  for(const name of Object.keys(domains))validateDomain(name,domains[name]);
  for(const name of Object.keys(DOMAIN_KEYS))if(!Object.prototype.hasOwnProperty.call(domains,name))validateDomain(name,null);
  return true;
}
function safeEvidence(data,keys){
  const out={};
  for(const key of keys){
    if(!Object.prototype.hasOwnProperty.call(data||{},key))continue;
    const value=data[key];
    if(value===null||typeof value==='boolean'||typeof value==='number')out[key]=value;
  }
  return out;
}
function signal(meta,state,reason,evidence,observedAt){
  return {
    domain:meta.domain,
    component:meta.component,
    capability:meta.capability,
    invariant_id:meta.invariant,
    state,
    reason,
    observed_at:observedAt,
    evidence,
    fingerprint:`business-health:${meta.domain.toLowerCase()}:${meta.invariant}`
  };
}

const META=Object.freeze({
  call_center:{domain:'CALL_CENTER',component:'lead-workflow',capability:'lead-to-call-activity',invariant:'callcenter.activity_stall'},
  sales:{domain:'SALES',component:'sales-intelligence',capability:'aggregate-sales-read',invariant:'sales.pipeline_consistency'},
  whatsapp:{domain:'WHATSAPP',component:'human-outbound',capability:'provider-status-progression',invariant:'whatsapp.outbound_receipt_stall'},
  email:{domain:'EMAIL',component:'resend-gateway',capability:'send-and-webhook-progression',invariant:'email.provider_pipeline_health'}
});

function evaluateCallCenter(data,observedAt){
  const d=data||{};
  const ev=safeEvidence(d,[...DOMAIN_KEYS.call_center]);
  if(boolOrNull(d.operating_window)!==true)return signal(META.call_center,STATES.UNKNOWN,'OUTSIDE_OR_UNKNOWN_OPERATING_WINDOW',ev,observedAt);
  const advisors=nonNegative(d.active_advisors),leads=nonNegative(d.eligible_leads),calls=nonNegative(d.calls_in_window),windowAge=nonNegative(d.window_age_minutes);
  if(advisors==null||leads==null||calls==null||windowAge==null)return signal(META.call_center,STATES.UNKNOWN,'CALLCENTER_INPUT_INCOMPLETE',ev,observedAt);
  if(advisors===0)return signal(META.call_center,STATES.UNKNOWN,'NO_ACTIVE_ADVISORS',ev,observedAt);
  if(leads===0)return signal(META.call_center,STATES.UNKNOWN,'NO_ELIGIBLE_BACKLOG',ev,observedAt);
  const lastAge=calls===0?windowAge:nonNegative(d.latest_call_age_minutes);
  if(lastAge==null)return signal(META.call_center,STATES.UNKNOWN,'LATEST_CALL_AGE_UNKNOWN',ev,observedAt);
  if(lastAge>=60)return signal(META.call_center,STATES.INCIDENT,'CORRELATED_ACTIVITY_STALL_60M',ev,observedAt);
  if(lastAge>=30)return signal(META.call_center,STATES.DEGRADED,'CORRELATED_ACTIVITY_STALL_30M',ev,observedAt);
  return signal(META.call_center,STATES.HEALTHY,'CALL_ACTIVITY_WITHIN_BASELINE',ev,observedAt);
}

function evaluateSales(data,observedAt){
  const d=data||{};
  const ev=safeEvidence(d,[...DOMAIN_KEYS.sales]);
  if(boolOrNull(d.scope_consistent)!==true)return signal(META.sales,STATES.UNKNOWN,'SALES_SCOPE_NOT_PROVEN_EQUIVALENT',ev,observedAt);
  const source=nonNegative(d.source_sales_count),gateway=nonNegative(d.gateway_sales_count),hasData=boolOrNull(d.gateway_has_data);
  if(source==null||hasData==null)return signal(META.sales,STATES.UNKNOWN,'SALES_INPUT_INCOMPLETE',ev,observedAt);
  if(source>0&&hasData!==true)return signal(META.sales,STATES.INCIDENT,'SOURCE_PRESENT_GATEWAY_EMPTY',ev,observedAt);
  if(hasData===true&&gateway==null)return signal(META.sales,STATES.UNKNOWN,'GATEWAY_COUNT_MISSING',ev,observedAt);
  if(hasData===true&&source!==gateway)return signal(META.sales,STATES.DEGRADED,'SAME_SCOPE_COUNT_DIVERGENCE',ev,observedAt);
  if(source===0&&hasData===true&&gateway>0)return signal(META.sales,STATES.DEGRADED,'SOURCE_EMPTY_GATEWAY_NONEMPTY',ev,observedAt);
  return signal(META.sales,STATES.HEALTHY,'SALES_PIPELINE_CONSISTENT',ev,observedAt);
}

function evaluateWhatsapp(data,observedAt){
  const d=data||{};
  const ev=safeEvidence(d,[...DOMAIN_KEYS.whatsapp]);
  const count=nonNegative(d.accepted_without_progress),age=nonNegative(d.oldest_unprogressed_age_minutes);
  if(count==null)return signal(META.whatsapp,STATES.UNKNOWN,'WHATSAPP_INPUT_INCOMPLETE',ev,observedAt);
  if(count===0)return signal(META.whatsapp,STATES.HEALTHY,'NO_STALLED_ACCEPTED_OUTBOUND',ev,observedAt);
  if(age==null)return signal(META.whatsapp,STATES.UNKNOWN,'WHATSAPP_STALL_AGE_UNKNOWN',ev,observedAt);
  if(age>=60)return signal(META.whatsapp,STATES.INCIDENT,'OUTBOUND_RECEIPT_STALL_60M',ev,observedAt);
  if(age>=15)return signal(META.whatsapp,STATES.DEGRADED,'OUTBOUND_RECEIPT_STALL_15M',ev,observedAt);
  return signal(META.whatsapp,STATES.HEALTHY,'OUTBOUND_PROGRESS_WITHIN_GRACE',ev,observedAt);
}

function evaluateEmail(data,observedAt){
  const d=data||{};
  const ev=safeEvidence(d,[...DOMAIN_KEYS.email]);
  if(boolOrNull(d.feature_expected)!==true)return signal(META.email,STATES.UNKNOWN,'EMAIL_FEATURE_NOT_EXPECTED_OR_UNKNOWN',ev,observedAt);
  const service=boolOrNull(d.gateway_service_configured),provider=boolOrNull(d.provider_send_configured),webhook=boolOrNull(d.webhook_configured);
  if(service==null||provider==null||webhook==null)return signal(META.email,STATES.UNKNOWN,'EMAIL_CONFIG_EVIDENCE_INCOMPLETE',ev,observedAt);
  if(!service||!provider||!webhook)return signal(META.email,STATES.INCIDENT,'GOVERNED_EMAIL_GATEWAY_NOT_READY',ev,observedAt);
  const horizon=nonNegative(d.monitoring_horizon_minutes),recentSent=nonNegative(d.recent_sent_count),unmatched=nonNegative(d.recent_sent_without_event),age=nonNegative(d.oldest_recent_without_event_age_minutes);
  if(horizon==null||horizon<=0||recentSent==null||unmatched==null)return signal(META.email,STATES.UNKNOWN,'EMAIL_PIPELINE_INPUT_INCOMPLETE',ev,observedAt);
  if(recentSent===0)return signal(META.email,STATES.UNKNOWN,'NO_RECENT_EMAIL_ACTIVITY',ev,observedAt);
  if(unmatched===0)return signal(META.email,STATES.HEALTHY,'EMAIL_RECENT_PIPELINE_HEALTHY',ev,observedAt);
  if(unmatched>recentSent)return signal(META.email,STATES.UNKNOWN,'EMAIL_AGGREGATE_INCONSISTENT',ev,observedAt);
  if(age==null)return signal(META.email,STATES.UNKNOWN,'EMAIL_RECENT_STALL_AGE_UNKNOWN',ev,observedAt);
  if(age>horizon)return signal(META.email,STATES.UNKNOWN,'EMAIL_SAMPLE_OUTSIDE_MONITORING_HORIZON',ev,observedAt);
  if(age>=60)return signal(META.email,STATES.INCIDENT,'EMAIL_PROVIDER_EVENT_STALL_60M',ev,observedAt);
  if(age>=15)return signal(META.email,STATES.DEGRADED,'EMAIL_PROVIDER_EVENT_STALL_15M',ev,observedAt);
  return signal(META.email,STATES.HEALTHY,'EMAIL_EVENT_PROGRESS_WITHIN_GRACE',ev,observedAt);
}

function aggregateState(signals){
  let state=STATES.HEALTHY;
  for(const s of signals||[]){if((PRIORITY[s.state]??-1)>PRIORITY[state])state=s.state;}
  return state;
}
function evaluateSnapshot(snapshot){
  validateSnapshot(snapshot);
  const observedAt=isoOrNow(snapshot.observed_at);
  const d=snapshot.domains;
  const signals=[
    evaluateCallCenter(d.call_center,observedAt),
    evaluateSales(d.sales,observedAt),
    evaluateWhatsapp(d.whatsapp,observedAt),
    evaluateEmail(d.email,observedAt)
  ];
  return {ok:true,phase:'F6',observed_at:observedAt,state:aggregateState(signals),signals};
}

module.exports={STATES,DOMAIN_KEYS,validateSnapshot,evaluateCallCenter,evaluateSales,evaluateWhatsapp,evaluateEmail,aggregateState,evaluateSnapshot};
