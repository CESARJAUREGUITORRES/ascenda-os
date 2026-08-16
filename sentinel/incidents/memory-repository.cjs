'use strict';

function clone(value){return value==null?value:JSON.parse(JSON.stringify(value));}

class MemoryIncidentRepository{
  constructor(){
    this.incidents=new Map();
    this.events=new Map();
    this.yearSequences=new Map();
  }

  allocateIncidentId(year){
    const y=Number(year);
    if(!Number.isInteger(y)||y<2000||y>9999)throw new Error('F8_INVALID_INCIDENT_YEAR');
    const next=(this.yearSequences.get(y)||0)+1;
    this.yearSequences.set(y,next);
    return `SEN-${y}-${String(next).padStart(4,'0')}`;
  }

  getIncident(incidentId){
    return clone(this.incidents.get(incidentId)||null);
  }

  saveIncident(incident){
    if(!incident||typeof incident!=='object'||!incident.incident_id)throw new Error('F8_INCIDENT_REQUIRED');
    this.incidents.set(incident.incident_id,clone(incident));
    return this.getIncident(incident.incident_id);
  }

  findEvent(eventId){
    return clone(this.events.get(eventId)||null);
  }

  recordEvent(eventId,record){
    if(this.events.has(eventId))throw new Error('F8_EVENT_ALREADY_RECORDED');
    this.events.set(eventId,clone(record));
    return this.findEvent(eventId);
  }

  findActiveByFingerprint(environment,incidentFingerprint){
    const rows=[...this.incidents.values()]
      .filter(i=>i.environment===environment&&i.incident_fingerprint===incidentFingerprint&&i.status!=='RESOLVED')
      .sort((a,b)=>Date.parse(b.updated_at)-Date.parse(a.updated_at));
    if(rows.length>1)throw new Error('F8_ACTIVE_INCIDENT_UNIQUENESS_BROKEN');
    return clone(rows[0]||null);
  }

  findLatestResolvedByFingerprint(environment,incidentFingerprint){
    const rows=[...this.incidents.values()]
      .filter(i=>i.environment===environment&&i.incident_fingerprint===incidentFingerprint&&i.status==='RESOLVED')
      .sort((a,b)=>Date.parse(b.resolved_at||b.updated_at)-Date.parse(a.resolved_at||a.updated_at));
    return clone(rows[0]||null);
  }

  listIncidents(){
    return [...this.incidents.values()].map(clone).sort((a,b)=>a.incident_id.localeCompare(b.incident_id));
  }

  eventCount(){return this.events.size;}
}

module.exports={MemoryIncidentRepository};
