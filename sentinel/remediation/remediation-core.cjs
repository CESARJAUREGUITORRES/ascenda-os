'use strict';
const fs=require('fs');
const path=require('path');
const crypto=require('crypto');

const REQUEST_SCHEMA='sentinel.remediation-request.v1';
const PLAN_SCHEMA='sentinel.remediation-plan.v1';
const AUDIT_SCHEMA='sentinel.remediation-audit.v1';
const RISKS=new Set(['LOW','MEDIUM','HIGH','CRITICAL']);
const ALLOWED_ROOTS=['app/','sentinel/','ci/','docs/'];
const DENIED_PREFIXES=['.git/','.github/','supabase/migrations/'];
const DENIED_EXACT=new Set(['AGENTS.md','SECURITY.md','.env','.env.local','.env.production']);
const DENIED_EXT=new Set(['.pem','.key','.p12','.pfx','.crt','.cer']);
const MAX_FILES=5,MAX_PATCH_BYTES=16384,MAX_OBJECTIVE=512,MAX_EVIDENCE=24;

function sha256Hex(v){return crypto.createHash('sha256').update(v).digest('hex');}
function stableStringify(v){
  if(v===null||typeof v!=='object')return JSON.stringify(v);
  if(Array.isArray(v))return '['+v.map(stableStringify).join(',')+']';
  return '{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+stableStringify(v[k])).join(',')+'}';
}
function fail(code){const e=new Error(code);e.code=code;throw e;}
function plain(v){return !!v&&typeof v==='object'&&!Array.isArray(v)&&Object.getPrototypeOf(v)===Object.prototype;}
function exactKeys(obj,keys,code){if(!plain(obj))fail(code);const a=Object.keys(obj).sort(),b=[...keys].sort();if(a.length!==b.length||a.some((x,i)=>x!==b[i]))fail(code);}
function boundedString(v,max,code){if(typeof v!=='string'||!v.trim()||v.length>max||/\0/.test(v))fail(code);return v;}
function arrayStrings(v,max,code){if(!Array.isArray(v)||v.length<1||v.length>max)fail(code);const out=v.map(x=>boundedString(x,256,code));if(new Set(out).size!==out.length)fail(code);return out;}
function sensitiveText(v){
  const s=String(v||'');
  return /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i.test(s)||
    /\bBearer\s+[A-Za-z0-9._~+\/-]+=*/i.test(s)||
    /\b(?:sk|pk|ghp|github_pat|xox[baprs])-?[A-Za-z0-9_-]{12,}\b/i.test(s)||
    /\b(?:password|passwd|secret|api[_ -]?key|access[_ -]?token|refresh[_ -]?token|service[_ -]?role)\s*[:=]/i.test(s)||
    /(?:\+?51[\s.-]?)?9\d{8}\b/.test(s)||
    /\b(?:DNI\s*[:#-]?\s*)?\d{8}\b/i.test(s);
}
function injectionText(v){
  const s=String(v||'').toLowerCase();
  return /(ignore|disregard|override).{0,40}(previous|prior|system|security|instructions)|bypass.{0,30}(tests|security|approval|gate)|reveal.{0,30}(secret|token|credential)|disable.{0,30}(rls|security|auth)|deploy.{0,20}(without|bypass)|merge.{0,20}(without|bypass)/s.test(s);
}
function validateTargetPath(input){
  const p=boundedString(input,180,'INVALID_TARGET_PATH');
  if(p.includes('\\')||p.startsWith('/')||/^[A-Za-z]:/.test(p)||p.includes('\0'))fail('INVALID_TARGET_PATH');
  const normalized=path.posix.normalize(p);
  if(normalized!==p||normalized==='.'||normalized.startsWith('../')||normalized.includes('/../'))fail('PATH_TRAVERSAL_BLOCKED');
  if(DENIED_EXACT.has(normalized)||DENIED_PREFIXES.some(x=>normalized.startsWith(x)))fail('DENIED_TARGET_PATH');
  if(DENIED_EXT.has(path.posix.extname(normalized).toLowerCase())||/(^|\/)\.env(?:\.|$)/i.test(normalized))fail('DENIED_TARGET_PATH');
  if(!ALLOWED_ROOTS.some(root=>normalized.startsWith(root)))fail('TARGET_ROOT_NOT_ALLOWED');
  return normalized;
}
function validateApproval(a){
  exactKeys(a,['production_authorized','auto_merge','auto_deploy'],'INVALID_APPROVAL');
  if(a.production_authorized!==false||a.auto_merge!==false||a.auto_deploy!==false)fail('APPROVAL_BYPASS_BLOCKED');
  return {production_authorized:false,auto_merge:false,auto_deploy:false};
}
function validateRequest(r){
  exactKeys(r,['schema_version','incident_id','diagnostic_id','triage_audit_digest','base_sha','risk','objective','target_files','evidence_refs','approval'],'INVALID_REQUEST_SHAPE');
  if(r.schema_version!==REQUEST_SCHEMA)fail('INVALID_REQUEST_SCHEMA');
  if(!/^SEN-\d{4}-\d{4,}$/.test(r.incident_id))fail('INVALID_INCIDENT_ID');
  if(!/^F10-[a-f0-9]{20,64}$/.test(r.diagnostic_id))fail('INVALID_DIAGNOSTIC_ID');
  if(!/^[a-f0-9]{64}$/.test(r.triage_audit_digest))fail('INVALID_TRIAGE_DIGEST');
  if(!/^[a-f0-9]{40}$/.test(r.base_sha))fail('INVALID_BASE_SHA');
  if(!RISKS.has(r.risk))fail('INVALID_RISK');
  const objective=boundedString(r.objective,MAX_OBJECTIVE,'INVALID_OBJECTIVE');
  if(sensitiveText(objective))fail('SENSITIVE_TEXT_BLOCKED');
  if(injectionText(objective))fail('PROMPT_INJECTION_BLOCKED');
  const target_files=arrayStrings(r.target_files,MAX_FILES,'INVALID_TARGET_FILES').map(validateTargetPath);
  const evidence_refs=arrayStrings(r.evidence_refs,MAX_EVIDENCE,'INVALID_EVIDENCE_REFS');
  if(evidence_refs.some(x=>!/^[A-Z0-9][A-Z0-9_.:\/-]{2,255}$/i.test(x)))fail('INVALID_EVIDENCE_REFS');
  const approval=validateApproval(r.approval);
  return Object.freeze({...r,objective,target_files,evidence_refs,approval});
}
function validateChange(change,targets){
  exactKeys(change,['path','expected_before_sha256','find','replace'],'INVALID_CHANGE_SHAPE');
  const p=validateTargetPath(change.path);
  if(!targets.includes(p))fail('UNDECLARED_TARGET');
  if(!/^[a-f0-9]{64}$/.test(change.expected_before_sha256))fail('INVALID_BEFORE_DIGEST');
  const find=boundedString(change.find,MAX_PATCH_BYTES,'INVALID_FIND_TEXT');
  const replace=boundedString(change.replace,MAX_PATCH_BYTES,'INVALID_REPLACE_TEXT');
  if(Buffer.byteLength(find)+Buffer.byteLength(replace)>MAX_PATCH_BYTES)fail('PATCH_SIZE_LIMIT');
  if(sensitiveText(replace))fail('SENSITIVE_PATCH_BLOCKED');
  if(injectionText(replace))fail('PROMPT_INJECTION_BLOCKED');
  return {path:p,expected_before_sha256:change.expected_before_sha256,find,replace};
}
function buildPlan(request,changes,expectedBaseSha){
  const r=validateRequest(request);
  if(expectedBaseSha!==r.base_sha)fail('BASE_SHA_MISMATCH');
  if(!Array.isArray(changes)||changes.length<1||changes.length>MAX_FILES)fail('INVALID_CHANGES');
  const normalized=changes.map(c=>validateChange(c,r.target_files));
  if(new Set(normalized.map(x=>x.path)).size!==normalized.length)fail('DUPLICATE_CHANGE_PATH');
  const core={schema_version:PLAN_SCHEMA,incident_id:r.incident_id,diagnostic_id:r.diagnostic_id,triage_audit_digest:r.triage_audit_digest,base_sha:r.base_sha,risk:r.risk,objective:r.objective,evidence_refs:r.evidence_refs,approval:r.approval,changes:normalized};
  return Object.freeze({...core,plan_digest:sha256Hex(stableStringify(core))});
}
function ensureContained(root,target){
  const rr=fs.realpathSync(root),parent=path.dirname(target),rp=fs.realpathSync(parent);
  if(rp!==rr&&!rp.startsWith(rr+path.sep))fail('REPO_ESCAPE_BLOCKED');
  const st=fs.lstatSync(target);
  if(st.isSymbolicLink())fail('SYMLINK_ESCAPE_BLOCKED');
  const rt=fs.realpathSync(target);
  if(rt!==rr&&!rt.startsWith(rr+path.sep))fail('REPO_ESCAPE_BLOCKED');
}
function applyPlan(plan,workspaceRoot,options={}){
  if(options.enabled!==true)fail('F12_KILL_SWITCH_OFF');
  if(options.production===true)fail('PRODUCTION_MUTATION_BLOCKED');
  if(!plain(plan)||plan.schema_version!==PLAN_SCHEMA||!/^[a-f0-9]{64}$/.test(plan.plan_digest))fail('INVALID_PLAN');
  const digestCore={...plan};delete digestCore.plan_digest;
  if(sha256Hex(stableStringify(digestCore))!==plan.plan_digest)fail('PLAN_DIGEST_MISMATCH');
  const root=fs.realpathSync(workspaceRoot),backups=[];
  try{
    for(const c of plan.changes){
      const rel=validateTargetPath(c.path),target=path.resolve(root,...rel.split('/')),relative=path.relative(root,target);
      if(relative.startsWith('..')||path.isAbsolute(relative))fail('REPO_ESCAPE_BLOCKED');
      if(!fs.existsSync(target))fail('TARGET_NOT_FOUND');
      ensureContained(root,target);
      const before=fs.readFileSync(target,'utf8');
      if(sha256Hex(before)!==c.expected_before_sha256)fail('STALE_TARGET');
      const first=before.indexOf(c.find);
      if(first<0||before.indexOf(c.find,first+1)>=0)fail('FIND_NOT_UNIQUE');
      const after=before.slice(0,first)+c.replace+before.slice(first+c.find.length);
      if(Buffer.byteLength(after)>1024*1024)fail('TARGET_SIZE_LIMIT');
      backups.push({path:rel,before,before_sha256:sha256Hex(before),after_sha256:sha256Hex(after)});
      fs.writeFileSync(target,after,{encoding:'utf8',flag:'w'});
    }
  }catch(err){
    for(const b of backups.reverse())fs.writeFileSync(path.resolve(root,...b.path.split('/')),b.before,'utf8');
    throw err;
  }
  const auditCore={schema_version:AUDIT_SCHEMA,incident_id:plan.incident_id,diagnostic_id:plan.diagnostic_id,base_sha:plan.base_sha,plan_digest:plan.plan_digest,production_mutation:false,auto_merge:false,auto_deploy:false,files:backups.map(({path,before_sha256,after_sha256})=>({path,before_sha256,after_sha256}))};
  return Object.freeze({...auditCore,audit_digest:sha256Hex(stableStringify(auditCore)),_rollback:backups.map(x=>({path:x.path,before:x.before,before_sha256:x.before_sha256,after_sha256:x.after_sha256}))});
}
function rollbackAudit(audit,workspaceRoot,options={}){
  if(options.enabled!==true)fail('F12_KILL_SWITCH_OFF');
  if(options.production===true)fail('PRODUCTION_MUTATION_BLOCKED');
  if(!plain(audit)||audit.schema_version!==AUDIT_SCHEMA||!Array.isArray(audit._rollback))fail('INVALID_AUDIT');
  const root=fs.realpathSync(workspaceRoot);
  for(const b of audit._rollback){
    const rel=validateTargetPath(b.path),target=path.resolve(root,...rel.split('/'));
    ensureContained(root,target);
    const current=fs.readFileSync(target,'utf8');
    if(sha256Hex(current)!==b.after_sha256)fail('ROLLBACK_TARGET_DRIFT');
    fs.writeFileSync(target,b.before,'utf8');
    if(sha256Hex(fs.readFileSync(target,'utf8'))!==b.before_sha256)fail('ROLLBACK_VERIFY_FAILED');
  }
  return {ok:true,rolled_back:audit._rollback.length};
}
function publicAudit(audit){const x={...audit};delete x._rollback;return x;}
module.exports={REQUEST_SCHEMA,PLAN_SCHEMA,AUDIT_SCHEMA,sha256Hex,stableStringify,validateTargetPath,validateRequest,buildPlan,applyPlan,rollbackAudit,publicAudit,sensitiveText,injectionText};
