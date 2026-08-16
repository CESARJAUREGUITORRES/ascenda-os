'use strict';

const meta=require('./runtime-metadata.cjs');
const {UNKNOWN}=meta;

const CONFIDENCE=Object.freeze({EXACT:'EXACT',STRONG:'STRONG',WEAK:'WEAK',UNKNOWN:'UNKNOWN'});
const SAFE_STATES=new Set(['SUCCESS','FAILED','CRASHED','REMOVED','UNKNOWN']);
const SAFE_HEALTH=new Set(['HEALTHY','DEGRADED','INCIDENT','CRITICAL','UNKNOWN']);
const ALLOWED_SIGNAL_KEYS=new Set(['observed_at','environment','service_name','release','commit_sha','deployment_id','replica_id','request_id','trace_id']);
const ALLOWED_DEPLOY_KEYS=new Set(['deployment_id','commit_sha','environment','service_name','started_at','status','health_state']);
const ALLOWED_CHANGE_KEYS=new Set(['commit_sha','pull_request','merged_at']);

function iso(value){
  if(typeof value!=='string'||Number.isNaN(Date.parse(value)))return null;
  return new Date(value).toISOString();
}
function safeTechnical(value){
  const v=String(value||'').trim();
  return v&&/^[A-Za-z0-9._:@/-]{1,160}$/.test(v)?v:UNKNOWN;
}
function ensureOnly(obj,allowed,label){
  if(!obj||typeof obj!=='object'||Array.isArray(obj))throw new Error(`${label}_OBJECT_REQUIRED`);
  for(const key of Object.keys(obj))if(!allowed.has(key))throw new Error(`${label}_UNAPPROVED_KEY:${key}`);
}
function normalizeSignal(signal={}){
  ensureOnly(signal,ALLOWED_SIGNAL_KEYS,'F7_SIGNAL');
  const releaseParsed=meta.parseRelease(signal.release);
  const explicitSha=meta.normalizeSha(signal.commit_sha);
  const releaseSha=releaseParsed?releaseParsed.commit_sha:UNKNOWN;
  let commit=explicitSha!==UNKNOWN?explicitSha:releaseSha;
  let contradiction=false;
  if(explicitSha!==UNKNOWN&&releaseSha!==UNKNOWN&&explicitSha!==releaseSha){commit=UNKNOWN;contradiction=true;}
  const observed=iso(signal.observed_at);
  if(!observed)throw new Error('F7_SIGNAL_OBSERVED_AT_INVALID');
  return {
    system:'ascenda-os',
    environment:meta.normalizeEnvironment(signal.environment),
    service_name:meta.safeId(signal.service_name),
    release:releaseParsed?releaseParsed.release:(commit!==UNKNOWN?`ascenda-os@${commit}`:'ascenda-os@unknown'),
    commit_sha:commit,
    deployment_id:meta.safeId(signal.deployment_id),
    replica_id:meta.safeId(signal.replica_id),
    request_id:meta.normalizeRequestId(signal.request_id),
    trace_id:meta.normalizeTraceId(signal.trace_id),
    observed_at:observed,
    contradiction
  };
}
function normalizeDeployment(input){
  ensureOnly(input,ALLOWED_DEPLOY_KEYS,'F7_DEPLOYMENT');
  const started=iso(input.started_at);
  if(!started)throw new Error('F7_DEPLOYMENT_STARTED_AT_INVALID');
  const state=String(input.status||'UNKNOWN').toUpperCase();
  const health=String(input.health_state||'UNKNOWN').toUpperCase();
  return {
    deployment_id:meta.safeId(input.deployment_id),
    commit_sha:meta.normalizeSha(input.commit_sha),
    environment:meta.normalizeEnvironment(input.environment),
    service_name:meta.safeId(input.service_name),
    started_at:started,
    status:SAFE_STATES.has(state)?state:'UNKNOWN',
    health_state:SAFE_HEALTH.has(health)?health:'UNKNOWN'
  };
}
function normalizeChange(input){
  ensureOnly(input,ALLOWED_CHANGE_KEYS,'F7_CHANGE');
  const pr=Number.isInteger(input.pull_request)&&input.pull_request>0?input.pull_request:null;
  return {commit_sha:meta.normalizeSha(input.commit_sha),pull_request:pr,merged_at:iso(input.merged_at)};
}
function sameScope(a,b){
  return a.environment!==UNKNOWN&&b.environment===a.environment&&a.service_name!==UNKNOWN&&b.service_name===a.service_name;
}
function findDeployment(signal,deployments,windowMinutes=60){
  if(signal.contradiction)return {deployment:null,confidence:CONFIDENCE.UNKNOWN,reason:'CONTRADICTORY_RELEASE_AND_COMMIT'};
  const rows=deployments.map(normalizeDeployment).filter(d=>sameScope(signal,d));
  if(signal.deployment_id!==UNKNOWN){
    const matches=rows.filter(d=>d.deployment_id===signal.deployment_id);
    if(matches.length!==1)return {deployment:null,confidence:CONFIDENCE.UNKNOWN,reason:matches.length?'AMBIGUOUS_DEPLOYMENT_ID':'DEPLOYMENT_ID_NOT_FOUND'};
    const d=matches[0];
    if(signal.commit_sha!==UNKNOWN&&d.commit_sha!==UNKNOWN&&d.commit_sha!==signal.commit_sha)return {deployment:null,confidence:CONFIDENCE.UNKNOWN,reason:'DEPLOYMENT_COMMIT_CONTRADICTION'};
    return {deployment:d,confidence:signal.commit_sha!==UNKNOWN&&d.commit_sha===signal.commit_sha?CONFIDENCE.EXACT:CONFIDENCE.STRONG,reason:'DEPLOYMENT_ID_MATCH'};
  }
  if(signal.commit_sha!==UNKNOWN){
    const matches=rows.filter(d=>d.commit_sha===signal.commit_sha).sort((a,b)=>Date.parse(b.started_at)-Date.parse(a.started_at));
    if(matches.length)return {deployment:matches[0],confidence:CONFIDENCE.STRONG,reason:'COMMIT_SHA_MATCH'};
  }
  const observedMs=Date.parse(signal.observed_at);
  const maxAge=Math.max(1,Number(windowMinutes)||60)*60000;
  const candidates=rows.filter(d=>Date.parse(d.started_at)<=observedMs&&observedMs-Date.parse(d.started_at)<=maxAge).sort((a,b)=>Date.parse(b.started_at)-Date.parse(a.started_at));
  if(candidates.length)return {deployment:candidates[0],confidence:CONFIDENCE.WEAK,reason:'TEMPORAL_REGRESSION_WINDOW'};
  return {deployment:null,confidence:CONFIDENCE.UNKNOWN,reason:'NO_CORRELATED_DEPLOYMENT'};
}
function findChange(commitSha,changes=[]){
  if(commitSha===UNKNOWN)return null;
  const rows=changes.map(normalizeChange).filter(c=>c.commit_sha===commitSha);
  if(rows.length!==1)return null;
  return rows[0];
}
function chooseRollbackTarget(suspect,deployments=[]){
  if(!suspect||suspect.started_at==null)return {status:'UNKNOWN',reason:'SUSPECT_DEPLOYMENT_UNKNOWN',target:null,action_authorized:false};
  const rows=deployments.map(normalizeDeployment)
    .filter(d=>d.environment===suspect.environment&&d.service_name===suspect.service_name)
    .filter(d=>Date.parse(d.started_at)<Date.parse(suspect.started_at))
    .filter(d=>d.status==='SUCCESS'&&d.health_state==='HEALTHY'&&d.commit_sha!==UNKNOWN)
    .sort((a,b)=>Date.parse(b.started_at)-Date.parse(a.started_at));
  if(!rows.length)return {status:'UNKNOWN',reason:'NO_PRIOR_KNOWN_GOOD_DEPLOYMENT',target:null,action_authorized:false};
  const target=rows[0];
  return {status:'EXACT_TARGET',reason:'LATEST_PRIOR_KNOWN_GOOD',target:{deployment_id:target.deployment_id,commit_sha:target.commit_sha,environment:target.environment,service_name:target.service_name,started_at:target.started_at},action_authorized:false};
}
function correlate(input={}){
  const signal=normalizeSignal(input.signal||{});
  const deployments=Array.isArray(input.deployments)?input.deployments:[];
  const changes=Array.isArray(input.changes)?input.changes:[];
  const match=findDeployment(signal,deployments,input.regression_window_minutes||60);
  const deployment=match.deployment;
  const effectiveCommit=deployment&&deployment.commit_sha!==UNKNOWN?deployment.commit_sha:signal.commit_sha;
  const change=findChange(effectiveCommit,changes);
  const rollback=chooseRollbackTarget(deployment,deployments);
  const temporal=match.confidence===CONFIDENCE.WEAK;
  return {
    ok:true,
    schema_version:'sentinel-correlation-result/v1',
    observed_at:signal.observed_at,
    environment:signal.environment,
    service_name:signal.service_name,
    release:signal.release,
    commit_sha:effectiveCommit,
    deployment_id:deployment?deployment.deployment_id:signal.deployment_id,
    request_id:signal.request_id,
    trace_id:signal.trace_id,
    confidence:match.confidence,
    correlation_reason:match.reason,
    deployment:deployment||null,
    github_change:change,
    suspect_change:deployment?{
      commit_sha:effectiveCommit,
      deployment_id:deployment.deployment_id,
      pull_request:change?change.pull_request:null,
      basis:temporal?'TEMPORAL_CANDIDATE':'EXACT_OR_STRONG_CORRELATION',
      causality:'NOT_ESTABLISHED'
    }:null,
    rollback,
    automatic_action_authorized:false
  };
}

module.exports={CONFIDENCE,normalizeSignal,normalizeDeployment,normalizeChange,findDeployment,findChange,chooseRollbackTarget,correlate};
