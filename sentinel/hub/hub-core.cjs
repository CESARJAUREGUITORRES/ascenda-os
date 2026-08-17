'use strict';
const STATES=['HEALTHY','UNKNOWN','DEGRADED','INCIDENT','CRITICAL'];
const ACTIVE=new Set(['OPEN','ACK','INVESTIGATING','MITIGATED']);
const SEVERITY_STATE={P0:'CRITICAL',P1:'INCIDENT',P2:'DEGRADED',P3:'DEGRADED'};
const RANK={HEALTHY:0,UNKNOWN:1,DEGRADED:2,INCIDENT:3,CRITICAL:4};
const SAFE_TOPOLOGY_KEYS=new Set(['schema_version','source_registry_id','projection','default_state','domains']);
const FORBIDDEN_TOPOLOGY_KEYS=new Set(['db_relations','rpc_refs','dependencies','evidence','surfaces','file','files','host','url','token','secret','sensitivity']);
function fail(code){const e=new Error(code);e.code=code;throw e;}
function isObj(v){return !!v&&typeof v==='object'&&!Array.isArray(v);}
function assertKeys(obj,allowed,code){if(!isObj(obj))fail(code);for(const k of Object.keys(obj))if(!allowed.has(k))fail(code+':'+k);}
function safeId(v,re){if(typeof v!=='string'||!re.test(v))fail('INVALID_ID');return v;}
function validateTopology(t){
  assertKeys(t,SAFE_TOPOLOGY_KEYS,'UNSAFE_TOPOLOGY_ROOT');
  if(t.schema_version!=='sentinel-hub-topology/v1'||t.source_registry_id!=='ASCENDA-SENTINEL-REGISTRY-V1'||t.projection!=='owner-ui-safe'||t.default_state!=='UNKNOWN')fail('TOPOLOGY_CONTRACT_MISMATCH');
  if(!Array.isArray(t.domains)||t.domains.length<1)fail('TOPOLOGY_DOMAINS_REQUIRED');
  const seenD=new Set(),seenC=new Set();
  for(const d of t.domains){
    assertKeys(d,new Set(['id','name','criticality','components']),'UNSAFE_DOMAIN_KEY');
    safeId(d.id,/^[A-Z][A-Z0-9_]{0,63}$/); if(seenD.has(d.id))fail('DUPLICATE_DOMAIN');seenD.add(d.id);
    if(typeof d.name!=='string'||!d.name.trim()||!['critical','high','medium','low'].includes(d.criticality))fail('INVALID_DOMAIN');
    if(!Array.isArray(d.components)||!d.components.length)fail('COMPONENT_REQUIRED');
    for(const c of d.components){
      assertKeys(c,new Set(['id','name','capabilities']),'UNSAFE_COMPONENT_KEY');
      safeId(c.id,/^[a-z0-9][a-z0-9-]{0,63}$/);if(typeof c.name!=='string'||!c.name.trim())fail('INVALID_COMPONENT');
      if(!Array.isArray(c.capabilities)||!c.capabilities.length)fail('CAPABILITY_REQUIRED');
      for(const cap of c.capabilities){
        assertKeys(cap,new Set(['id','criticality']),'UNSAFE_CAPABILITY_KEY');
        safeId(cap.id,/^[a-z0-9][a-z0-9._:-]{0,199}$/);if(!['critical','high','medium','low'].includes(cap.criticality))fail('INVALID_CAPABILITY');
        const key=d.id+'/'+cap.id;if(seenC.has(key))fail('DUPLICATE_CAPABILITY');seenC.add(key);
      }
    }
  }
  scanForbiddenKeys(t);
  return t;
}
function scanForbiddenKeys(v){
  if(Array.isArray(v)){v.forEach(scanForbiddenKeys);return;}
  if(!isObj(v))return;
  for(const [k,x] of Object.entries(v)){if(FORBIDDEN_TOPOLOGY_KEYS.has(k))fail('FORBIDDEN_TOPOLOGY_KEY:'+k);scanForbiddenKeys(x);}
}
function incidentState(i){if(!isObj(i)||!ACTIVE.has(String(i.status||'').toUpperCase()))return null;return SEVERITY_STATE[String(i.severity||'').toUpperCase()]||'UNKNOWN';}
function healthState(h,nowMs,ttlMs){
  if(!isObj(h))return 'UNKNOWN';
  if(String(h.source_state||'').toUpperCase()==='UNAVAILABLE')return 'UNKNOWN';
  const s=String(h.state||'').toUpperCase(); if(!STATES.includes(s))return 'UNKNOWN';
  const ts=Date.parse(h.observed_at||''); if(!Number.isFinite(ts)||nowMs-ts<0||nowMs-ts>ttlMs)return 'UNKNOWN';
  return s;
}
function worst(states){return states.reduce((a,b)=>RANK[b]>RANK[a]?b:a,'HEALTHY');}
function safeIncident(i){
  const out={};
  for(const k of ['incident_id','severity','status','environment','domain','component','capability','failure_family','opened_at','updated_at','last_signal_at','resolved_at','signal_count','reopened_count','evidence_refs','correlation','timeline'])if(i&&i[k]!==undefined)out[k]=i[k];
  return out;
}
function composeHub(topology,incidents=[],health={},opts={}){
  validateTopology(topology);
  const nowMs=opts.nowMs||Date.now(),ttlMs=opts.ttlMs||300000;
  const sanitized=(Array.isArray(incidents)?incidents:[]).map(safeIncident);
  const domains=topology.domains.map(d=>{
    const components=d.components.map(c=>{
      const capabilities=c.capabilities.map(cap=>{
        const matches=sanitized.filter(i=>i.domain===d.id&&i.capability===cap.id);
        const activeStates=matches.map(incidentState).filter(Boolean);
        const key=d.id+'/'+cap.id;
        const state=activeStates.length?worst(activeStates):healthState(health[key],nowMs,ttlMs);
        return {id:cap.id,criticality:cap.criticality,state,active_incidents:matches.filter(i=>incidentState(i)).map(i=>i.incident_id),last_health_at:health[key]&&health[key].observed_at||null};
      });
      return {id:c.id,name:c.name,state:worst(capabilities.map(x=>x.state)),capabilities};
    });
    return {id:d.id,name:d.name,criticality:d.criticality,state:worst(components.map(x=>x.state)),components};
  });
  return {schema_version:'sentinel-hub-model/v1',generated_at:new Date(nowMs).toISOString(),domains,incidents:sanitized,summary:{domains:domains.length,capabilities:domains.reduce((n,d)=>n+d.components.reduce((m,c)=>m+c.capabilities.length,0),0),critical:domains.filter(d=>d.state==='CRITICAL').length,incident:domains.filter(d=>d.state==='INCIDENT').length,degraded:domains.filter(d=>d.state==='DEGRADED').length,unknown:domains.filter(d=>d.state==='UNKNOWN').length,healthy:domains.filter(d=>d.state==='HEALTHY').length}};
}
module.exports={STATES,ACTIVE,SEVERITY_STATE,RANK,validateTopology,incidentState,healthState,worst,safeIncident,composeHub};
