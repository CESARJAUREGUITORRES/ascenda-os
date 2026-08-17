'use strict';

const SIGNAL_CLASSES=new Set(['ERROR','AVAILABILITY','BUSINESS_HEALTH','DEPENDENCY','DEPLOYMENT_CHANGE','SECURITY','USER_REPORTED']);
const SEVERITIES=['P0','P1','P2','P3'];
const STATUSES=new Set(['OPEN','ACK','INVESTIGATING','MITIGATED','RESOLVED']);
const TRANSITIONS=Object.freeze({
  OPEN:new Set(['ACK','INVESTIGATING','MITIGATED','RESOLVED']),
  ACK:new Set(['INVESTIGATING','MITIGATED','RESOLVED']),
  INVESTIGATING:new Set(['MITIGATED','RESOLVED']),
  MITIGATED:new Set(['INVESTIGATING','RESOLVED']),
  RESOLVED:new Set([])
});
const ALLOWED_SIGNAL_KEYS=new Set([
  'event_id','signal_class','environment','domain','component','capability','failure_family',
  'signal_fingerprint','incident_fingerprint','severity','observed_at','evidence_refs','correlation'
]);
const ALLOWED_EVIDENCE_KINDS=new Set(['sentinel-signal','sentry-issue','github-commit','github-pr','railway-deployment','uptime-monitor','ci-run','trace']);
const ALLOWED_CORRELATION_KEYS=new Set(['release','commit_sha','deployment_id','request_id','trace_id','confidence']);
const CORRELATION_CONFIDENCE=new Set(['EXACT','STRONG','WEAK','UNKNOWN']);
const TECH_ID=/^[A-Za-z0-9._:@/-]{1,200}$/;
const SLUG=/^[a-z0-9][a-z0-9._:-]{0,199}$/;
const ENV=/^(production|zero-cost|development)$/;
const TAXONOMY=/^[A-Z][A-Z0-9_]{0,63}$/;
const UUID_V4=/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const TRACE=/^[0-9a-f]{32}$/i;
const SHA=/^[0-9a-f]{7,40}$/i;

function iso(value,label){
  if(typeof value!=='string'||Number.isNaN(Date.parse(value)))throw new Error(`${label}_INVALID_TIMESTAMP`);
  return new Date(value).toISOString();
}
function safeTechnical(value,label){
  const v=String(value||'').trim();
  if(!TECH_ID.test(v)||v.includes('?')||v.includes('#')||v.includes('..'))throw new Error(`${label}_INVALID_TECHNICAL_ID`);
  return v;
}
function safeSlug(value,label){
  const v=String(value||'').trim().toLowerCase();
  if(!SLUG.test(v))throw new Error(`${label}_INVALID_SLUG`);
  return v;
}
function safeTaxonomy(value,label){
  const v=String(value||'').trim().toUpperCase();
  if(!TAXONOMY.test(v))throw new Error(`${label}_INVALID_TAXONOMY`);
  return v;
}
function normalizeSeverity(value){
  const v=String(value||'').trim().toUpperCase();
  if(!SEVERITIES.includes(v))throw new Error('F8_INVALID_SEVERITY');
  return v;
}
function severityRank(value){return SEVERITIES.indexOf(value);}
function moreSevere(a,b){return severityRank(a)<=severityRank(b)?a:b;}
function ensureOnly(obj,allowed,label){
  if(!obj||typeof obj!=='object'||Array.isArray(obj))throw new Error(`${label}_OBJECT_REQUIRED`);
  for(const key of Object.keys(obj))if(!allowed.has(key))throw new Error(`${label}_UNAPPROVED_KEY:${key}`);
}
function normalizeEvidenceRefs(refs=[]){
  if(refs==null)return [];
  if(!Array.isArray(refs))throw new Error('F8_EVIDENCE_REFS_ARRAY_REQUIRED');
  const out=[]; const seen=new Set();
  for(const ref of refs){
    ensureOnly(ref,new Set(['kind','id']),'F8_EVIDENCE_REF');
    const kind=String(ref.kind||'').trim().toLowerCase();
    if(!ALLOWED_EVIDENCE_KINDS.has(kind))throw new Error('F8_EVIDENCE_KIND_NOT_ALLOWED');
    const id=safeTechnical(ref.id,'F8_EVIDENCE_REF');
    const k=`${kind}:${id}`;
    if(!seen.has(k)){seen.add(k);out.push({kind,id});}
  }
  return out;
}
function normalizeCorrelation(input){
  if(input==null)return null;
  ensureOnly(input,ALLOWED_CORRELATION_KEYS,'F8_CORRELATION');
  const out={};
  if(input.release!=null){
    const release=String(input.release).trim().toLowerCase();
    if(!/^ascenda-os@[0-9a-f]{7,40}$/.test(release)&&release!=='ascenda-os@unknown')throw new Error('F8_CORRELATION_RELEASE_INVALID');
    out.release=release;
  }
  if(input.commit_sha!=null){const v=String(input.commit_sha).trim().toLowerCase();if(!SHA.test(v))throw new Error('F8_CORRELATION_SHA_INVALID');out.commit_sha=v;}
  if(input.deployment_id!=null)out.deployment_id=safeTechnical(input.deployment_id,'F8_CORRELATION_DEPLOYMENT');
  if(input.request_id!=null){const v=String(input.request_id).trim().toLowerCase();if(!UUID_V4.test(v))throw new Error('F8_CORRELATION_REQUEST_ID_INVALID');out.request_id=v;}
  if(input.trace_id!=null){const v=String(input.trace_id).trim().toLowerCase();if(!TRACE.test(v)||/^0+$/.test(v))throw new Error('F8_CORRELATION_TRACE_ID_INVALID');out.trace_id=v;}
  if(input.confidence!=null){const v=String(input.confidence).trim().toUpperCase();if(!CORRELATION_CONFIDENCE.has(v))throw new Error('F8_CORRELATION_CONFIDENCE_INVALID');out.confidence=v;}
  return Object.keys(out).length?out:null;
}
function normalizeSignal(input){
  ensureOnly(input,ALLOWED_SIGNAL_KEYS,'F8_SIGNAL');
  const signalClass=String(input.signal_class||'').trim().toUpperCase();
  if(!SIGNAL_CLASSES.has(signalClass))throw new Error('F8_SIGNAL_CLASS_INVALID');
  const environment=String(input.environment||'').trim().toLowerCase();
  if(!ENV.test(environment))throw new Error('F8_ENVIRONMENT_INVALID');
  return {
    event_id:safeTechnical(input.event_id,'F8_EVENT_ID'),
    signal_class:signalClass,
    environment,
    domain:safeTaxonomy(input.domain,'F8_DOMAIN'),
    component:safeSlug(input.component,'F8_COMPONENT'),
    capability:safeSlug(input.capability,'F8_CAPABILITY'),
    failure_family:safeSlug(input.failure_family,'F8_FAILURE_FAMILY'),
    signal_fingerprint:safeSlug(input.signal_fingerprint,'F8_SIGNAL_FINGERPRINT'),
    incident_fingerprint:safeSlug(input.incident_fingerprint,'F8_INCIDENT_FINGERPRINT'),
    severity:normalizeSeverity(input.severity),
    observed_at:iso(input.observed_at,'F8_SIGNAL'),
    evidence_refs:normalizeEvidenceRefs(input.evidence_refs),
    correlation:normalizeCorrelation(input.correlation)
  };
}
function unionEvidence(existing=[],incoming=[]){
  const out=[];const seen=new Set();
  for(const ref of [...existing,...incoming]){
    const k=`${ref.kind}:${ref.id}`;
    if(!seen.has(k)){seen.add(k);out.push({kind:ref.kind,id:ref.id});}
  }
  return out;
}
function unionStrings(a=[],b=[]){return [...new Set([...a,...b])].sort();}
function timeline(type,at,details={}){return {type,at,...details};}

class IncidentEngine{
  constructor({repository,clock=()=>new Date().toISOString(),reopenWindowMinutes=60}={}){
    if(!repository)throw new Error('F8_REPOSITORY_REQUIRED');
    this.repository=repository;
    this.clock=clock;
    this.reopenWindowMinutes=Math.max(1,Number(reopenWindowMinutes)||60);
  }

  ingest(rawSignal){
    const signal=normalizeSignal(rawSignal);
    const replay=this.repository.findEvent(signal.event_id);
    if(replay){
      return {ok:true,replay:true,mutated:false,incident:this.repository.getIncident(replay.incident_id)};
    }

    let incident=this.repository.findActiveByFingerprint(signal.environment,signal.incident_fingerprint);
    let reopened=false;
    if(!incident){
      const resolved=this.repository.findLatestResolvedByFingerprint(signal.environment,signal.incident_fingerprint);
      if(resolved&&resolved.resolved_at){
        const delta=Date.parse(signal.observed_at)-Date.parse(resolved.resolved_at);
        if(delta>=0&&delta<=this.reopenWindowMinutes*60000){
          incident=resolved;
          incident.status='OPEN';
          incident.resolved_at=null;
          incident.reopened_count=(incident.reopened_count||0)+1;
          incident.updated_at=this.clockIso();
          incident.timeline.push(timeline('INCIDENT_REOPENED',incident.updated_at,{event_id:signal.event_id}));
          reopened=true;
        }
      }
    }

    if(!incident){
      incident=this.openIncident(signal);
    } else {
      this.attachSignal(incident,signal);
    }

    this.repository.saveIncident(incident);
    this.repository.recordEvent(signal.event_id,{incident_id:incident.incident_id,observed_at:signal.observed_at,signal_fingerprint:signal.signal_fingerprint});
    return {ok:true,replay:false,mutated:true,reopened,incident:this.repository.getIncident(incident.incident_id)};
  }

  openIncident(signal){
    const now=this.clockIso();
    const year=new Date(signal.observed_at).getUTCFullYear();
    const incidentId=this.repository.allocateIncidentId(year);
    return {
      schema_version:'sentinel-incident/v1',
      incident_id:incidentId,
      incident_fingerprint:signal.incident_fingerprint,
      environment:signal.environment,
      domain:signal.domain,
      component:signal.component,
      capability:signal.capability,
      failure_family:signal.failure_family,
      severity:signal.severity,
      status:'OPEN',
      opened_at:signal.observed_at,
      updated_at:now,
      last_signal_at:signal.observed_at,
      resolved_at:null,
      signal_count:1,
      signal_classes:[signal.signal_class],
      signal_fingerprints:[signal.signal_fingerprint],
      evidence_refs:signal.evidence_refs,
      correlation:signal.correlation,
      reopened_count:0,
      timeline:[
        timeline('INCIDENT_OPENED',now,{event_id:signal.event_id,signal_class:signal.signal_class,severity:signal.severity}),
        timeline('SIGNAL_ATTACHED',now,{event_id:signal.event_id,signal_fingerprint:signal.signal_fingerprint})
      ]
    };
  }

  attachSignal(incident,signal){
    this.assertCompatibleIncident(incident,signal);
    const now=this.clockIso();
    const oldSeverity=incident.severity;
    const nextSeverity=moreSevere(oldSeverity,signal.severity);
    incident.signal_count+=1;
    incident.signal_classes=unionStrings(incident.signal_classes,[signal.signal_class]);
    incident.signal_fingerprints=unionStrings(incident.signal_fingerprints,[signal.signal_fingerprint]);
    incident.evidence_refs=unionEvidence(incident.evidence_refs,signal.evidence_refs);
    incident.last_signal_at=new Date(Math.max(Date.parse(incident.last_signal_at),Date.parse(signal.observed_at))).toISOString();
    incident.updated_at=now;
    if(signal.correlation)incident.correlation=signal.correlation;
    incident.timeline.push(timeline('SIGNAL_ATTACHED',now,{event_id:signal.event_id,signal_fingerprint:signal.signal_fingerprint}));
    if(nextSeverity!==oldSeverity){
      incident.severity=nextSeverity;
      incident.timeline.push(timeline('SEVERITY_ESCALATED',now,{from:oldSeverity,to:nextSeverity,event_id:signal.event_id}));
    }
  }

  transition(incidentId,targetStatus,at){
    const incident=this.repository.getIncident(incidentId);
    if(!incident)throw new Error('F8_INCIDENT_NOT_FOUND');
    const target=String(targetStatus||'').trim().toUpperCase();
    if(!STATUSES.has(target))throw new Error('F8_STATUS_INVALID');
    if(target===incident.status)return {ok:true,mutated:false,incident};
    if(!TRANSITIONS[incident.status]||!TRANSITIONS[incident.status].has(target))throw new Error(`F8_STATUS_TRANSITION_INVALID:${incident.status}->${target}`);
    const timestamp=at?iso(at,'F8_STATUS'):this.clockIso();
    const from=incident.status;
    incident.status=target;
    incident.updated_at=timestamp;
    if(target==='RESOLVED')incident.resolved_at=timestamp;
    incident.timeline.push(timeline('STATUS_CHANGED',timestamp,{from,to:target}));
    this.repository.saveIncident(incident);
    return {ok:true,mutated:true,incident:this.repository.getIncident(incidentId)};
  }

  assertCompatibleIncident(incident,signal){
    for(const key of ['environment','domain','component','capability','failure_family']){
      if(incident[key]!==signal[key])throw new Error(`F8_INCIDENT_FINGERPRINT_SCOPE_CONTRADICTION:${key}`);
    }
    if(incident.incident_fingerprint!==signal.incident_fingerprint)throw new Error('F8_INCIDENT_FINGERPRINT_CONTRADICTION');
  }

  clockIso(){
    const value=typeof this.clock==='function'?this.clock():this.clock;
    return iso(String(value),'F8_CLOCK');
  }
}

module.exports={SIGNAL_CLASSES,SEVERITIES,STATUSES,TRANSITIONS,normalizeSignal,normalizeEvidenceRefs,normalizeCorrelation,IncidentEngine};
