'use strict';

const SHA_RE=/^[0-9a-f]{7,40}$/i;
const SAFE_ID_RE=/^[A-Za-z0-9._:-]{1,160}$/;
const UUID_V4_RE=/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const TRACE_ID_RE=/^[0-9a-f]{32}$/i;
const UNKNOWN='UNKNOWN';

function safeId(value){
  const v=String(value||'').trim();
  return v&&SAFE_ID_RE.test(v)?v:UNKNOWN;
}
function normalizeEnvironment(value){
  const v=String(value||'').trim().toLowerCase();
  if(v==='production')return 'production';
  if(['zero-cost','zero_cost','staging','test'].includes(v))return 'zero-cost';
  if(v==='development')return 'development';
  return UNKNOWN;
}
function normalizeSha(value){
  const v=String(value||'').trim().toLowerCase();
  return SHA_RE.test(v)?v:UNKNOWN;
}
function parseRelease(value){
  const v=String(value||'').trim();
  const m=/^ascenda-os@([0-9a-f]{7,40})$/i.exec(v);
  return m?{release:`ascenda-os@${m[1].toLowerCase()}`,commit_sha:m[1].toLowerCase()}:null;
}
function normalizeRequestId(value){
  const v=String(value||'').trim().toLowerCase();
  return UUID_V4_RE.test(v)?v:UNKNOWN;
}
function normalizeTraceId(value){
  const v=String(value||'').trim().toLowerCase();
  return TRACE_ID_RE.test(v)&&!/^0+$/.test(v)?v:UNKNOWN;
}
function fromEnv(env=process.env,context={}){
  const commit=normalizeSha(env.RAILWAY_GIT_COMMIT_SHA||env.GITHUB_SHA);
  const release=commit!==UNKNOWN?`ascenda-os@${commit}`:'ascenda-os@unknown';
  const hasRailway=Boolean(String(env.RAILWAY_DEPLOYMENT_ID||env.RAILWAY_SERVICE_NAME||env.RAILWAY_ENVIRONMENT_NAME||'').trim());
  return {
    schema_version:'sentinel-correlation-envelope/v1',
    system:'ascenda-os',
    environment:normalizeEnvironment(env.RAILWAY_ENVIRONMENT_NAME||env.SENTRY_ENVIRONMENT),
    service_name:safeId(env.RAILWAY_SERVICE_NAME||context.service_name),
    release,
    commit_sha:commit,
    deployment_id:safeId(env.RAILWAY_DEPLOYMENT_ID),
    replica_id:safeId(env.RAILWAY_REPLICA_ID),
    request_id:normalizeRequestId(context.request_id),
    trace_id:normalizeTraceId(context.trace_id),
    observed_at:new Date(context.observed_at||Date.now()).toISOString(),
    source:hasRailway?'railway-system-env':'process-env'
  };
}

module.exports={UNKNOWN,SHA_RE,SAFE_ID_RE,UUID_V4_RE,TRACE_ID_RE,safeId,normalizeEnvironment,normalizeSha,parseRelease,normalizeRequestId,normalizeTraceId,fromEnv};
