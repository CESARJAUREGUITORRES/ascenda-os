'use strict';

const SEVERITY_RANK={P0:0,P1:1,P2:2,P3:3};
const STATUS=new Set(['OPEN','ACK','INVESTIGATING','MITIGATED','RESOLVED']);
const SLUG=/^[a-z0-9][a-z0-9._:-]{0,199}$/;
const DOMAIN=/^[A-Z][A-Z0-9_]{0,63}$/;
const SEN=/^SEN-[0-9]{4}-[0-9]{4,}$/;
const SHA=/^[0-9a-f]{7,40}$/;
const TECH=/^[A-Za-z0-9._:@/-]{1,200}$/;
const SENSITIVE_KEY=/(phone|telefono|dni|email|patient|paciente|nombre|message|mensaje|body|payload|cookie|token|authorization|password|wa_id|recipient)/i;

const POLICY={
  P0:{mode:'IMMEDIATE',cooldown:60,maintenance:false},
  P1:{mode:'IMMEDIATE',cooldown:300,maintenance:true},
  P2:{mode:'DIGEST',digest:900,maintenance:true},
  P3:{mode:'PANEL_ONLY',maintenance:true}
};

function iso(v,label){
  const d=new Date(v);
  if(Number.isNaN(d.getTime()))throw new Error(`F9_${label}_INVALID_TIMESTAMP`);
  return d.toISOString();
}
function cleanSlug(v,label){
  const x=String(v||'').toLowerCase();
  if(!SLUG.test(x))throw new Error(`F9_${label}_INVALID`);
  return x;
}
function cleanTech(v,label){
  if(v==null||v==='')return null;
  const x=String(v);
  if(!TECH.test(x)||/[?#]/.test(x)||x.includes('..'))throw new Error(`F9_${label}_INVALID`);
  return x;
}
function scanSensitiveKeys(obj,path='root'){
  if(!obj||typeof obj!=='object')return;
  for(const [k,v] of Object.entries(obj)){
    if(SENSITIVE_KEY.test(k))throw new Error(`F9_SENSITIVE_INPUT_KEY:${path}.${k}`);
    if(v&&typeof v==='object')scanSensitiveKeys(v,`${path}.${k}`);
  }
}

function sanitizeIncident(incident){
  if(!incident||typeof incident!=='object'||Array.isArray(incident))throw new Error('F9_INCIDENT_OBJECT_REQUIRED');
  scanSensitiveKeys(incident);
  const incidentId=String(incident.incident_id||'');
  if(!SEN.test(incidentId))throw new Error('F9_INCIDENT_ID_INVALID');
  const severity=String(incident.severity||'').toUpperCase();
  if(!(severity in SEVERITY_RANK))throw new Error('F9_SEVERITY_INVALID');
  const status=String(incident.status||'').toUpperCase();
  if(!STATUS.has(status))throw new Error('F9_STATUS_INVALID');
  const environment=cleanSlug(incident.environment,'ENVIRONMENT');
  const domain=String(incident.domain||'').toUpperCase();
  if(!DOMAIN.test(domain))throw new Error('F9_DOMAIN_INVALID');
  const correlation=incident.correlation&&typeof incident.correlation==='object'?incident.correlation:{};
  const release=correlation.release==null?null:String(correlation.release);
  if(release!==null&&!(release==='ascenda-os@unknown'||/^ascenda-os@[0-9a-f]{7,40}$/.test(release)))throw new Error('F9_RELEASE_INVALID');
  const commit=correlation.commit_sha==null?null:String(correlation.commit_sha);
  if(commit!==null&&!SHA.test(commit))throw new Error('F9_COMMIT_SHA_INVALID');
  return {
    incident_id:incidentId,
    severity,
    status,
    environment,
    domain,
    component:cleanSlug(incident.component,'COMPONENT'),
    capability:cleanSlug(incident.capability,'CAPABILITY'),
    failure_family:cleanSlug(incident.failure_family,'FAILURE_FAMILY'),
    release,
    commit_sha:commit,
    deployment_id:cleanTech(correlation.deployment_id,'DEPLOYMENT_ID'),
    signal_count:Number.isInteger(incident.signal_count)&&incident.signal_count>=0?incident.signal_count:0,
    reopened_count:Number.isInteger(incident.reopened_count)&&incident.reopened_count>=0?incident.reopened_count:0,
    observed_at:iso(incident.updated_at||incident.last_signal_at||incident.opened_at,'INCIDENT')
  };
}

function maintenanceMatch(safe,window,nowMs){
  if(!window||typeof window!=='object')return false;
  const start=new Date(window.starts_at).getTime();
  const end=new Date(window.ends_at).getTime();
  if(!Number.isFinite(start)||!Number.isFinite(end)||end<=start)return false;
  if(nowMs<start||nowMs>end)return false;
  for(const key of ['environment','domain','component','capability']){
    if(window[key]!=null&&String(window[key]).toLowerCase()!==String(safe[key]).toLowerCase())return false;
  }
  return true;
}

class AlertRouter {
  constructor({state,clock=()=>new Date().toISOString()}={}){
    if(!state)throw new Error('F9_STATE_REQUIRED');
    this.state=state;
    this.clock=clock;
  }

  route(incident,{maintenance_windows=[]}={}){
    const safe=sanitizeIncident(incident);
    const now=iso(this.clock(),'CLOCK');
    const nowMs=new Date(now).getTime();
    const prior=this.state.getIncident(safe.incident_id)||{
      last_status:null,last_severity:null,status_changes:[],had_notifiable_route:false,flap_until:null,flap_summary_until:null
    };

    const changed=prior.last_status!==null&&prior.last_status!==safe.status;
    let changes=(prior.status_changes||[]).filter(x=>nowMs-new Date(x).getTime()<=600000);
    if(changed)changes.push(now);
    const p0=safe.severity==='P0';
    const flapActive=prior.flap_until&&nowMs<new Date(prior.flap_until).getTime();
    const flapThreshold=changes.length>=4;

    const next={...prior,last_status:safe.status,last_severity:safe.severity,status_changes:changes};

    if(!p0&&(flapActive||flapThreshold)){
      if(flapThreshold&&!flapActive){
        next.flap_until=new Date(nowMs+900000).toISOString();
        next.flap_summary_until=next.flap_until;
        next.had_notifiable_route=true;
        this.state.saveIncident(safe.incident_id,next);
        return this._decision('FLAPPING_SUMMARY',safe,now,{channel:'telegram-owner',reason:'STATUS_FLAPPING',cooldown_seconds:900});
      }
      this.state.saveIncident(safe.incident_id,next);
      return this._decision('SUPPRESSED_FLAPPING',safe,now,{channel:null,reason:'FLAPPING_WINDOW'});
    }

    const maintained=maintenance_windows.some(w=>maintenanceMatch(safe,w,nowMs));
    if(maintained&&safe.severity!=='P0'){
      this.state.saveIncident(safe.incident_id,next);
      return this._decision('SUPPRESSED_MAINTENANCE',safe,now,{channel:null,reason:'ACTIVE_MAINTENANCE'});
    }

    if(safe.status==='RESOLVED'){
      this.state.saveIncident(safe.incident_id,next);
      if(!prior.had_notifiable_route||safe.severity==='P3')return this._decision('PANEL_ONLY',safe,now,{channel:null,reason:'NO_PRIOR_NOTIFIABLE_ROUTE'});
      const key=this._dedupKey(safe,'RECOVERY');
      const last=this.state.getLastDispatch(key);
      if(last)return this._decision('SUPPRESSED_COOLDOWN',safe,now,{channel:null,reason:'RECOVERY_ALREADY_DELIVERED',dedup_key:key});
      return this._decision('RECOVERY',safe,now,{channel:'telegram-owner',reason:'INCIDENT_RESOLVED',dedup_key:key,cooldown_seconds:0});
    }

    const policy=POLICY[safe.severity];
    if(policy.mode==='PANEL_ONLY'){
      this.state.saveIncident(safe.incident_id,next);
      return this._decision('PANEL_ONLY',safe,now,{channel:null,reason:'P3_POLICY'});
    }

    next.had_notifiable_route=true;
    this.state.saveIncident(safe.incident_id,next);

    if(policy.mode==='DIGEST'){
      const bucketStart=Math.floor(nowMs/(policy.digest*1000))*policy.digest*1000;
      const key=`${safe.environment}:${safe.domain}:${bucketStart}`;
      const queued=this.state.enqueueDigest(key,{...safe,queued_at:now});
      return this._decision('DIGEST_QUEUED',safe,now,{channel:null,reason:'P2_GROUP_POLICY',digest_key:key,queued_count:queued,window_end:new Date(bucketStart+policy.digest*1000).toISOString()});
    }

    const key=this._dedupKey(safe,'INCIDENT');
    const last=this.state.getLastDispatch(key);
    if(last&&nowMs-new Date(last).getTime()<policy.cooldown*1000){
      return this._decision('SUPPRESSED_COOLDOWN',safe,now,{channel:null,reason:'COOLDOWN',dedup_key:key,cooldown_seconds:policy.cooldown});
    }
    return this._decision('IMMEDIATE',safe,now,{channel:'telegram-owner',reason:'SEVERITY_POLICY',dedup_key:key,cooldown_seconds:policy.cooldown});
  }

  flushDueDigests(at=this.clock()){
    const now=iso(at,'DIGEST_FLUSH');
    const nowMs=new Date(now).getTime();
    const out=[];
    for(const key of this.state.listDigestKeys()){
      const parts=key.split(':');
      const bucketStart=Number(parts.at(-1));
      if(!Number.isFinite(bucketStart)||nowMs<bucketStart+900000)continue;
      const items=this.state.flushDigest(key);
      if(!items.length)continue;
      out.push({
        action:'DIGEST',channel:'telegram-owner',notification_kind:'DIGEST',severity:'P2',status:'OPEN',
        environment:items[0].environment,domain:items[0].domain,
        incident_ids:items.map(x=>x.incident_id).sort(),count:items.length,
        window_start:new Date(bucketStart).toISOString(),window_end:new Date(bucketStart+900000).toISOString(),
        routed_at:now,dedup_key:`digest:${key}`
      });
    }
    return out;
  }

  recordDelivered(decision,at=this.clock()){
    if(!decision||!decision.dedup_key)return;
    this.state.recordDispatch(decision.dedup_key,iso(at,'DELIVERY'));
  }

  _dedupKey(safe,kind){return `${safe.incident_id}:${kind}:${safe.severity}:${safe.status}`;}
  _decision(action,safe,now,extra){return {action,notification_kind:action,...safe,routed_at:now,...extra};}
}

module.exports={AlertRouter,sanitizeIncident,maintenanceMatch,SEVERITY_RANK};
