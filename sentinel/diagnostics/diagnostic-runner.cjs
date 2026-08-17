'use strict';

const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const cp=require('node:child_process');

const HERE=__dirname;
const CONTRACT=JSON.parse(fs.readFileSync(path.join(HERE,'f10-contract.json'),'utf8'));
const REQUIRED=new Set(CONTRACT.request.required_fields);
const OPTIONAL=new Set(CONTRACT.request.optional_fields);
const ALLOWED=new Set([...REQUIRED,...OPTIONAL]);
const FORBIDDEN=CONTRACT.forbidden_key_fragments.map(v=>String(v).toLowerCase());
const SEVERITIES=new Set(['P0','P1','P2','P3']);
const STATUSES=new Set(['OPEN','ACK','INVESTIGATING','MITIGATED','RESOLVED']);
const CONFIDENCE=new Set(CONTRACT.evidence.confidence);
const TECH=/^[A-Za-z0-9][A-Za-z0-9._:@/-]{0,239}$/;
const SEGMENT=/^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/;
const DOMAIN=/^[A-Z][A-Z0-9_]{0,63}$/;
const SHA=/^[0-9a-f]{40}$/;

function isObject(v){return !!v&&typeof v==='object'&&!Array.isArray(v);}
function stable(v){
  if(Array.isArray(v))return `[${v.map(stable).join(',')}]`;
  if(isObject(v))return `{${Object.keys(v).sort().map(k=>`${JSON.stringify(k)}:${stable(v[k])}`).join(',')}}`;
  return JSON.stringify(v);
}
function digest(v){return crypto.createHash('sha256').update(stable(v)).digest('hex');}
function fail(code,detail=''){const e=new Error(detail?`${code}:${detail}`:code);e.code=code;throw e;}
function normalizedKey(k){return String(k).toLowerCase().replace(/[^a-z0-9_]/g,'');}
function scanSensitiveKeys(v){
  if(Array.isArray(v)){v.forEach(scanSensitiveKeys);return;}
  if(!isObject(v))return;
  for(const [k,val] of Object.entries(v)){
    const nk=normalizedKey(k);
    if(FORBIDDEN.some(f=>nk.includes(f)))fail('F10_SENSITIVE_INPUT_KEY',k);
    scanSensitiveKeys(val);
  }
}
function technical(v,code,max=240){
  const s=String(v??'').trim();
  if(!s||s.length>max||!TECH.test(s)||s.includes('..')||s.includes('?')||s.includes('#'))fail(code);
  return s;
}
function segment(v,code){const s=String(v??'').trim();if(!s||!SEGMENT.test(s))fail(code);return s;}
function nonNegativeInt(v,code){const n=Number(v);if(!Number.isSafeInteger(n)||n<0)fail(code);return n;}
function loadJson(root,rel){return JSON.parse(fs.readFileSync(path.join(root,rel),'utf8'));}
function loadUpstream(toolingRoot){
  return {
    f6:loadJson(toolingRoot,CONTRACT.upstream_contracts.f6_business_health),
    f7:loadJson(toolingRoot,CONTRACT.upstream_contracts.f7_correlation),
    f8:loadJson(toolingRoot,CONTRACT.upstream_contracts.f8_incidents)
  };
}
function validateEvidenceRefs(refs,f8){
  if(refs===undefined)return [];
  if(!Array.isArray(refs)||refs.length>20)fail('F10_EVIDENCE_REFS_INVALID');
  const allowedKinds=new Set(f8.evidence_reference.allowed_kinds);
  return refs.map((ref,idx)=>{
    if(!isObject(ref)||Object.keys(ref).sort().join(',')!=='id,kind')fail('F10_EVIDENCE_REF_SHAPE',String(idx));
    const kind=String(ref.kind||'');
    if(!allowedKinds.has(kind))fail('F10_EVIDENCE_REF_KIND',kind);
    const id=technical(ref.id,'F10_EVIDENCE_REF_ID');
    return {kind,id};
  });
}
function normalizeRequest(input,{toolingRoot=path.resolve(HERE,'../..')}={}){
  if(!isObject(input))fail('F10_REQUEST_OBJECT_REQUIRED');
  scanSensitiveKeys(input);
  for(const k of Object.keys(input))if(!ALLOWED.has(k))fail('F10_REQUEST_UNAPPROVED_KEY',k);
  for(const k of REQUIRED)if(!(k in input))fail('F10_REQUEST_REQUIRED_FIELD',k);
  const upstream=loadUpstream(toolingRoot);
  const out={};
  out.incident_id=String(input.incident_id||'').toUpperCase();
  if(!(new RegExp(CONTRACT.request.incident_id_pattern)).test(out.incident_id))fail('F10_INCIDENT_ID_INVALID');
  out.diagnostic_revision=nonNegativeInt(input.diagnostic_revision,'F10_DIAGNOSTIC_REVISION_INVALID');
  if(out.diagnostic_revision<CONTRACT.request.diagnostic_revision_min)fail('F10_DIAGNOSTIC_REVISION_INVALID');
  out.severity=String(input.severity||'').toUpperCase();if(!SEVERITIES.has(out.severity))fail('F10_SEVERITY_INVALID');
  out.status=String(input.status||'').toUpperCase();if(!STATUSES.has(out.status))fail('F10_STATUS_INVALID');
  out.environment=segment(String(input.environment||'').toLowerCase(),'F10_ENVIRONMENT_INVALID');
  out.domain=String(input.domain||'').toUpperCase();if(!DOMAIN.test(out.domain))fail('F10_DOMAIN_INVALID');
  out.component=segment(String(input.component||'').toLowerCase(),'F10_COMPONENT_INVALID');
  out.capability=segment(String(input.capability||'').toLowerCase(),'F10_CAPABILITY_INVALID');
  out.failure_family=segment(String(input.failure_family||'').toLowerCase(),'F10_FAILURE_FAMILY_INVALID');
  out.observed_at=String(input.observed_at||'');if(!Number.isFinite(Date.parse(out.observed_at)))fail('F10_OBSERVED_AT_INVALID');
  if(input.signal_count!==undefined)out.signal_count=nonNegativeInt(input.signal_count,'F10_SIGNAL_COUNT_INVALID');
  if(input.reopened_count!==undefined)out.reopened_count=nonNegativeInt(input.reopened_count,'F10_REOPENED_COUNT_INVALID');
  if(input.commit_sha!==undefined){out.commit_sha=String(input.commit_sha).toLowerCase();if(!SHA.test(out.commit_sha))fail('F10_COMMIT_SHA_INVALID');}
  if(input.release!==undefined)out.release=technical(input.release,'F10_RELEASE_INVALID',160);
  if(input.deployment_id!==undefined)out.deployment_id=technical(input.deployment_id,'F10_DEPLOYMENT_ID_INVALID',160);
  if(input.evidence_refs!==undefined)out.evidence_refs=validateEvidenceRefs(input.evidence_refs,upstream.f8);
  return {request:out,upstream};
}
function git(repo,args){return cp.execFileSync('git',args,{cwd:repo,encoding:'utf8',stdio:['ignore','pipe','pipe'],timeout:8000}).trim();}
function tryGit(repo,args){try{return {ok:true,value:git(repo,args)};}catch{return {ok:false,value:''};}}
function domainKey(domain){return domain.toLowerCase();}
function buildPlan(request,f6){
  const invariant=(f6.invariants||[]).find(x=>x.domain===request.domain&&x.component===request.component&&x.capability===request.capability)||null;
  const source=(f6.source_contracts||{})[domainKey(request.domain)]||null;
  const runtimeFiles=source&&Array.isArray(source.runtime_files)?[...source.runtime_files].sort():[];
  return {
    domain:request.domain,
    component:request.component,
    capability:request.capability,
    invariant_id:invariant?invariant.id:null,
    runtime_files:runtimeFiles,
    steps:['VALIDATE_REQUEST','VERIFY_CORRELATION','VERIFY_DOMAIN_CONTRACT','INSPECT_AFFECTED_SHA','INSPECT_RECENT_DIFF','ASSESS_HEALTH','FORM_HYPOTHESES','RENDER_REPORT']
  };
}
function addEvidence(list,kind,source,result,confidence,ref){
  if(!CONTRACT.evidence.allowed_kinds.includes(kind)||!CONFIDENCE.has(confidence))fail('F10_INTERNAL_EVIDENCE_INVALID');
  const e={id:`E${String(list.length+1).padStart(3,'0')}`,kind,source,result,confidence};
  if(ref)e.ref=ref;
  list.push(e);return e.id;
}
function sanitizeHealth(health){
  if(!isObject(health))return null;
  const out={};
  for(const k of ['ok','service','child_alive','inner_ready'])if(k in health){
    if(k==='service')out.service=segment(health.service,'F10_HEALTH_SERVICE_INVALID');
    else out[k]=health[k]===true;
  }
  return out;
}
function collectRepo(request,repoRoot,evidence){
  if(!request.commit_sha){
    addEvidence(evidence,'MISSING_EVIDENCE','git',{code:'AFFECTED_SHA_UNKNOWN'},'UNKNOWN');
    return {shaState:'UNKNOWN',files:[]};
  }
  const exists=tryGit(repoRoot,['cat-file','-e',`${request.commit_sha}^{commit}`]);
  if(!exists.ok){
    addEvidence(evidence,'MISSING_EVIDENCE','git',{code:'AFFECTED_SHA_NOT_PRESENT'},'UNKNOWN');
    return {shaState:'UNKNOWN',files:[]};
  }
  const head=tryGit(repoRoot,['rev-parse','HEAD']);
  const exact=head.ok&&head.value.toLowerCase()===request.commit_sha;
  addEvidence(evidence,'RELEASE_CORRELATION','git',{code:exact?'AFFECTED_SHA_CHECKED_OUT':'AFFECTED_SHA_PRESENT',commit_sha:request.commit_sha},exact?'SUPPORTED':'PLAUSIBLE',`github-commit:${request.commit_sha}`);
  const changed=tryGit(repoRoot,['show','--format=','--name-only',request.commit_sha,'--']);
  const files=changed.ok?[...new Set(changed.value.split(/\r?\n/).map(s=>s.trim()).filter(Boolean))].sort().slice(0,80):[];
  addEvidence(evidence,'RECENT_DIFF','git',{code:'AFFECTED_COMMIT_FILES',file_count:files.length,files},changed.ok?'SUPPORTED':'UNKNOWN');
  return {shaState:exact?'EXACT':'PRESENT',files};
}
function correlationEvidence(request,evidence){
  if(!request.commit_sha){addEvidence(evidence,'MISSING_EVIDENCE','f7-correlation',{code:'COMMIT_SHA_UNKNOWN'},'UNKNOWN');return;}
  if(request.release===`ascenda-os@${request.commit_sha}`){
    addEvidence(evidence,'RELEASE_CORRELATION','f7-correlation',{code:'RELEASE_SHA_AGREE',release:request.release,commit_sha:request.commit_sha},'SUPPORTED');
  }else if(request.release){
    addEvidence(evidence,'RELEASE_CORRELATION','f7-correlation',{code:'RELEASE_SHA_CONTRADICT',release:request.release,commit_sha:request.commit_sha},'UNKNOWN');
  }else{
    addEvidence(evidence,'MISSING_EVIDENCE','f7-correlation',{code:'RELEASE_UNKNOWN',commit_sha:request.commit_sha},'UNKNOWN');
  }
}
function domainEvidence(plan,evidence){
  if(plan.invariant_id)addEvidence(evidence,'CONTRACT_TEST','f6-business-health',{code:'INVARIANT_MATCH',invariant_id:plan.invariant_id},'SUPPORTED',`contract:${plan.invariant_id}`);
  else addEvidence(evidence,'MISSING_EVIDENCE','f6-business-health',{code:'NO_EXACT_INVARIANT',domain:plan.domain,component:plan.component,capability:plan.capability},'UNKNOWN');
}
function buildHypotheses(request,plan,repo,health,evidence){
  const out=[];
  const recent=evidence.find(e=>e.kind==='RECENT_DIFF');
  const files=recent&&recent.result&&Array.isArray(recent.result.files)?recent.result.files:[];
  const matches=plan.runtime_files.filter(p=>files.includes(p));
  if(matches.length){
    out.push({id:'H001',statement_code:'RECENT_DOMAIN_RUNTIME_CHANGE_CANDIDATE',supporting_evidence:[recent.id],contradicting_evidence:[],confidence:'PLAUSIBLE',causality_confirmed:false,matched_paths:matches});
  }
  if(health&&health.ok===false){
    const h=evidence.find(e=>e.kind==='HEALTH_CHECK');
    out.push({id:`H${String(out.length+1).padStart(3,'0')}`,statement_code:'OUTER_RUNTIME_HEALTH_DEGRADED_CANDIDATE',supporting_evidence:h?[h.id]:[],contradicting_evidence:[],confidence:'PLAUSIBLE',causality_confirmed:false});
  }
  if(!out.length){
    const refs=evidence.filter(e=>e.confidence==='SUPPORTED').map(e=>e.id).slice(0,3);
    out.push({id:'H001',statement_code:'ROOT_CAUSE_NOT_ESTABLISHED',supporting_evidence:refs,contradicting_evidence:[],confidence:'UNKNOWN',causality_confirmed:false});
  }
  return out;
}
function assertReportInvariant(report){
  for(const h of report.hypotheses){
    if(h.causality_confirmed!==false)fail('F10_CAUSALITY_MUST_REMAIN_UNCONFIRMED');
    if(!CONFIDENCE.has(h.confidence))fail('F10_HYPOTHESIS_CONFIDENCE_INVALID');
  }
  const serialized=JSON.stringify(report);
  if(/(?:authorization|cookie|password|service_role|apikey|secret)["'=:\s]/i.test(serialized))fail('F10_REPORT_SENSITIVE_OUTPUT');
}
function renderMarkdown(report){
  const lines=[
    `# Sentinel Diagnostic ${report.incident.incident_id}`,
    '',
    `- Diagnostic ID: \`${report.diagnostic_id}\``,
    `- Revision: ${report.incident.diagnostic_revision}`,
    `- Severity / status: \`${report.incident.severity}\` / \`${report.incident.status}\``,
    `- Scope: \`${report.incident.domain}/${report.incident.component}/${report.incident.capability}\``,
    `- Affected SHA state: \`${report.affected_sha_state}\``,
    '',
    '## Evidence'
  ];
  for(const e of report.evidence)lines.push(`- **${e.id} ${e.kind}** [${e.confidence}] \`${e.source}\` — \`${e.result.code}\``);
  lines.push('','## Hypotheses');
  for(const h of report.hypotheses)lines.push(`- **${h.id}** [${h.confidence}] \`${h.statement_code}\` — causality_confirmed=false`);
  lines.push('','## Safety','- Read-only diagnostic baseline.','- No production mutation or remediation was executed.','');
  return lines.join('\n');
}
function runDiagnostic(input,{toolingRoot=path.resolve(HERE,'../..'),repoRoot=toolingRoot,health=null}={}){
  const {request,upstream}=normalizeRequest(input,{toolingRoot});
  const plan=buildPlan(request,upstream.f6);
  const evidence=[];
  addEvidence(evidence,'CONTRACT_TEST','f8-incidents',{code:'SEN_REQUEST_VALIDATED',incident_id:request.incident_id},'SUPPORTED');
  correlationEvidence(request,evidence);
  domainEvidence(plan,evidence);
  const repo=collectRepo(request,repoRoot,evidence);
  const safeHealth=sanitizeHealth(health);
  if(safeHealth)addEvidence(evidence,'HEALTH_CHECK','ascenda-health',{code:safeHealth.ok?'HEALTH_OK':'HEALTH_NOT_OK',...safeHealth},safeHealth.ok?'SUPPORTED':'WEAK');
  else addEvidence(evidence,'MISSING_EVIDENCE','ascenda-health',{code:'HEALTH_NOT_PROVIDED'},'UNKNOWN');
  const report={
    schema_version:'sentinel-diagnostic-report/v1',
    diagnostic_id:`F10-${digest(request).slice(0,20)}`,
    generated_at:request.observed_at,
    incident:request,
    affected_sha_state:repo.shaState,
    plan,
    evidence,
    hypotheses:buildHypotheses(request,plan,repo,safeHealth,evidence),
    safety:{read_only:true,production_mutation:false,automatic_remediation:false,ai_triage:false}
  };
  assertReportInvariant(report);
  return {report,markdown:renderMarkdown(report),digest:digest(report)};
}
function parseArgs(argv){const out={};for(let i=0;i<argv.length;i++){const a=argv[i];if(a.startsWith('--'))out[a.slice(2)]=argv[++i];}return out;}
if(require.main===module){
  try{
    const args=parseArgs(process.argv.slice(2));
    const toolingRoot=path.resolve(args.tooling||path.resolve(HERE,'../..'));
    const repoRoot=path.resolve(args.repo||toolingRoot);
    let input;
    if(args.request)input=JSON.parse(fs.readFileSync(path.resolve(args.request),'utf8'));
    else if(process.env.F10_REQUEST_JSON)input=JSON.parse(process.env.F10_REQUEST_JSON);
    else fail('F10_REQUEST_SOURCE_REQUIRED');
    if(args['target-sha']){
      const target=String(args['target-sha']).toLowerCase();if(!SHA.test(target))fail('F10_COMMIT_SHA_INVALID');
      if(input.commit_sha&&String(input.commit_sha).toLowerCase()!==target)fail('F10_TARGET_SHA_MISMATCH');
      input={...input,commit_sha:target};
    }
    let health=null;if(args.health)health=JSON.parse(fs.readFileSync(path.resolve(args.health),'utf8'));
    const result=runDiagnostic(input,{toolingRoot,repoRoot,health});
    const outDir=path.resolve(args.out||'.f10-report');fs.mkdirSync(outDir,{recursive:true});
    fs.writeFileSync(path.join(outDir,'diagnostic-report.json'),JSON.stringify(result.report,null,2)+'\n');
    fs.writeFileSync(path.join(outDir,'diagnostic-report.md'),result.markdown);
    console.log(JSON.stringify({ok:true,certificate:'SENTINEL_F10_DIAGNOSTIC_PASS',diagnostic_id:result.report.diagnostic_id,report_digest:result.digest,affected_sha_state:result.report.affected_sha_state,hypothesis_confidence:result.report.hypotheses.map(h=>h.confidence)}));
  }catch(err){console.error(err&&err.stack?err.stack:String(err));process.exit(1);}
}

module.exports={normalizeRequest,buildPlan,runDiagnostic,renderMarkdown,digest};
