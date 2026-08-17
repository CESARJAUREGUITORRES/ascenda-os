'use strict';

const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');

const CONTRACT=JSON.parse(fs.readFileSync(path.join(__dirname,'f11-contract.json'),'utf8'));
const CONF=new Set(CONTRACT.confidence);
const CLAIM_TYPES=new Set(CONTRACT.claim_types);
const NEXT_STEPS=new Set(CONTRACT.allowed_next_steps);
const FORBIDDEN=CONTRACT.forbidden_key_fragments.map(v=>String(v).toLowerCase());
const RESPONSE_ALLOWED=new Set([...CONTRACT.response.required_fields,...CONTRACT.response.optional_fields]);
const TECH=/^[A-Za-z0-9][A-Za-z0-9._:@/-]{0,239}$/;
const INCIDENT=/^SEN-[0-9]{4}-[0-9]{4,}$/;
const DIAG=/^F10-[0-9a-f]{20}$/;
const EVID=/^E[0-9]{3,}$/;
const CLAIM=/^C[0-9]{3,}$/;

function isObject(v){return !!v&&typeof v==='object'&&!Array.isArray(v);}
function stable(v){if(Array.isArray(v))return `[${v.map(stable).join(',')}]`;if(isObject(v))return `{${Object.keys(v).sort().map(k=>`${JSON.stringify(k)}:${stable(v[k])}`).join(',')}}`;return JSON.stringify(v);}
function digest(v){return crypto.createHash('sha256').update(stable(v)).digest('hex');}
function fail(code,detail=''){const e=new Error(detail?`${code}:${detail}`:code);e.code=code;throw e;}
function normalizedKey(k){return String(k).toLowerCase().replace(/[^a-z0-9_]/g,'');}
function scanKeys(v){
  if(Array.isArray(v)){v.forEach(scanKeys);return;}
  if(!isObject(v))return;
  for(const [k,val] of Object.entries(v)){
    const nk=normalizedKey(k);
    if(FORBIDDEN.some(f=>nk.includes(f)))fail('F11_SENSITIVE_KEY',k);
    scanKeys(val);
  }
}
function privacyCheckString(s,code='F11_SENSITIVE_OUTPUT'){
  const text=String(s??'');
  if(text.length>4000)fail('F11_TEXT_TOO_LONG');
  for(const [name,pattern] of Object.entries(CONTRACT.output_privacy_patterns)){
    const rx=new RegExp(pattern,'i');
    if(rx.test(text))fail(code,name);
  }
  if(/https?:\/\/[^\s]*\?/i.test(text))fail(code,'query-url');
  if(/(?:authorization|cookie|password|service[_ -]?role|api[_ -]?key|secret)\s*[:=]/i.test(text))fail(code,'credential-label');
  return text;
}
function safeText(v,code,max=1200){const s=privacyCheckString(v,code).trim();if(!s||s.length>max)fail(code);return s;}
function safeTech(v,code){const s=String(v??'').trim();if(!s||!TECH.test(s)||s.includes('..')||s.includes('?')||s.includes('#'))fail(code);return s;}
function assertDiagnostic(report){
  if(!isObject(report)||report.schema_version!=='sentinel-diagnostic-report/v1')fail('F11_F10_REPORT_SCHEMA');
  scanKeys(report);
  if(!isObject(report.incident)||!INCIDENT.test(String(report.incident.incident_id||'')))fail('F11_INCIDENT_INVALID');
  if(!DIAG.test(String(report.diagnostic_id||'')))fail('F11_DIAGNOSTIC_ID_INVALID');
  if(!isObject(report.safety)||report.safety.read_only!==true||report.safety.production_mutation!==false||report.safety.automatic_remediation!==false)fail('F11_F10_SAFETY_BOUNDARY');
  if(!Array.isArray(report.evidence)||!Array.isArray(report.hypotheses))fail('F11_F10_EVIDENCE_REQUIRED');
  const ids=new Set();
  for(const e of report.evidence){
    if(!isObject(e)||!EVID.test(String(e.id||''))||ids.has(e.id)||!CONF.has(String(e.confidence||'')))fail('F11_EVIDENCE_INVALID');
    ids.add(e.id); privacyCheckString(JSON.stringify(e));
  }
  for(const h of report.hypotheses){
    if(!isObject(h)||h.causality_confirmed!==false||!CONF.has(String(h.confidence||'')))fail('F11_HYPOTHESIS_INVALID');
    for(const r of [...(h.supporting_evidence||[]),...(h.contradicting_evidence||[])])if(!ids.has(r))fail('F11_HYPOTHESIS_UNKNOWN_EVIDENCE',String(r));
  }
  return ids;
}
function correlationFrom(report){
  const i=report.incident||{};
  return {
    release:i.release||null,
    commit_sha:i.commit_sha||null,
    deployment_id:i.deployment_id||null,
    affected_sha_state:report.affected_sha_state||'UNKNOWN'
  };
}
function buildPacket(report){
  assertDiagnostic(report);
  const incident=report.incident;
  const evidence=report.evidence.map(e=>({id:e.id,kind:e.kind,source:e.source,result:e.result,confidence:e.confidence,...(e.ref?{ref:e.ref}:{})}));
  const hypotheses=report.hypotheses.map(h=>({id:h.id,statement_code:h.statement_code,supporting_evidence:[...(h.supporting_evidence||[])],contradicting_evidence:[...(h.contradicting_evidence||[])],confidence:h.confidence,causality_confirmed:false}));
  const packet={
    schema_version:'sentinel-triage-packet/v1',
    incident:{
      incident_id:incident.incident_id,severity:incident.severity,status:incident.status,environment:incident.environment,
      domain:incident.domain,component:incident.component,capability:incident.capability,failure_family:incident.failure_family,
      signal_count:Number.isInteger(incident.signal_count)?incident.signal_count:null,reopened_count:Number.isInteger(incident.reopened_count)?incident.reopened_count:null
    },
    diagnostic:{diagnostic_id:report.diagnostic_id,generated_at:report.generated_at,affected_sha_state:report.affected_sha_state||'UNKNOWN'},
    correlation:correlationFrom(report),
    evidence,
    hypotheses,
    allowed_next_steps:[...CONTRACT.allowed_next_steps],
    guardrails:['CITE_EXISTING_EVIDENCE','NO_CAUSALITY_INVENTION','NO_PHI_PII_SECRETS','READ_ONLY_NEXT_STEPS_ONLY','DECLARE_UNKNOWN_WHEN_EVIDENCE_MISSING'],
    mcp_tools:[...CONTRACT.mcp_tools],
    safety:{read_only:true,production_mutation:false,automatic_remediation:false,vendor_neutral:true}
  };
  privacyCheckString(JSON.stringify(packet));
  packet.packet_digest=digest(packet);
  return packet;
}
function packetEvidenceMap(packet){const map=new Map();for(const e of packet.evidence||[])map.set(e.id,e);return map;}
function validateResponse(response,packet){
  if(!isObject(response))fail('F11_RESPONSE_OBJECT_REQUIRED');
  scanKeys(response);
  for(const k of Object.keys(response))if(!RESPONSE_ALLOWED.has(k))fail('F11_RESPONSE_UNAPPROVED_KEY',k);
  for(const k of CONTRACT.response.required_fields)if(!(k in response))fail('F11_RESPONSE_REQUIRED_FIELD',k);
  if(response.schema_version!==CONTRACT.response.schema)fail('F11_RESPONSE_SCHEMA');
  if(response.incident_id!==packet.incident.incident_id||response.diagnostic_id!==packet.diagnostic.diagnostic_id)fail('F11_RESPONSE_SCOPE_MISMATCH');
  if(response.causality_confirmed!==false)fail('F11_CAUSALITY_FORBIDDEN');
  const assessment=safeText(response.assessment,'F11_ASSESSMENT_INVALID',1200);
  if(!Array.isArray(response.claims)||response.claims.length<1||response.claims.length>CONTRACT.response.max_claims)fail('F11_CLAIMS_INVALID');
  if(!Array.isArray(response.next_steps)||response.next_steps.length>CONTRACT.response.max_next_steps)fail('F11_NEXT_STEPS_INVALID');
  const evidenceMap=packetEvidenceMap(packet),seen=new Set();
  const claims=response.claims.map((c,idx)=>{
    if(!isObject(c))fail('F11_CLAIM_OBJECT',String(idx));
    const keys=Object.keys(c).sort();
    const allowed=['claim_id','confidence','evidence_refs','statement','type'];
    if(keys.some(k=>!allowed.includes(k)))fail('F11_CLAIM_UNAPPROVED_KEY',String(idx));
    const id=String(c.claim_id||'');if(!CLAIM.test(id)||seen.has(id))fail('F11_CLAIM_ID',id);seen.add(id);
    const type=String(c.type||'');if(!CLAIM_TYPES.has(type))fail('F11_CLAIM_TYPE',type);
    const confidence=String(c.confidence||'');if(!CONF.has(confidence))fail('F11_CLAIM_CONFIDENCE',confidence);
    const statement=safeText(c.statement,'F11_CLAIM_STATEMENT',800);
    if(!Array.isArray(c.evidence_refs)||c.evidence_refs.length<1||c.evidence_refs.length>12)fail('F11_CLAIM_EVIDENCE_REQUIRED',id);
    const refs=[...new Set(c.evidence_refs.map(String))];
    for(const r of refs)if(!evidenceMap.has(r))fail('F11_UNKNOWN_EVIDENCE_REF',r);
    if(confidence==='SUPPORTED'&&!refs.some(r=>evidenceMap.get(r).confidence==='SUPPORTED'))fail('F11_SUPPORTED_WITHOUT_SUPPORTED_EVIDENCE',id);
    return {claim_id:id,type,statement,evidence_refs:refs,confidence};
  });
  const nextSteps=[...new Set(response.next_steps.map(String))];
  for(const n of nextSteps)if(!NEXT_STEPS.has(n))fail('F11_NEXT_STEP_FORBIDDEN',n);
  const provider=response.provider===undefined?null:safeTech(response.provider,'F11_PROVIDER_INVALID');
  const model=response.model===undefined?null:safeTech(response.model,'F11_MODEL_INVALID');
  const validated={schema_version:'sentinel-triage-validated/v1',incident_id:response.incident_id,diagnostic_id:response.diagnostic_id,assessment,claims,next_steps:nextSteps,causality_confirmed:false,...(provider?{provider}:{}),...(model?{model}:{})};
  privacyCheckString(JSON.stringify(validated));
  const audit={
    schema_version:'sentinel-triage-audit/v1',incident_id:response.incident_id,diagnostic_id:response.diagnostic_id,
    packet_digest:packet.packet_digest,response_digest:digest(validated),evidence_refs:[...new Set(claims.flatMap(c=>c.evidence_refs))].sort(),
    validation:'PASS',...(provider?{provider}:{}),...(model?{model}:{})
  };
  audit.audit_digest=digest(audit);
  return {validated,audit};
}

module.exports={CONTRACT,buildPacket,validateResponse,digest,privacyCheckString};
