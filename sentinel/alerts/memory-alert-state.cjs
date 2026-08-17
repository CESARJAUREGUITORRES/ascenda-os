'use strict';

class MemoryAlertState {
  constructor(){
    this.incidents=new Map();
    this.dispatches=new Map();
    this.digests=new Map();
  }

  getIncident(incidentId){
    const v=this.incidents.get(incidentId);
    return v?structuredClone(v):null;
  }

  saveIncident(incidentId,state){
    this.incidents.set(incidentId,structuredClone(state));
    return this.getIncident(incidentId);
  }

  getLastDispatch(key){
    return this.dispatches.get(key)||null;
  }

  recordDispatch(key,at){
    this.dispatches.set(key,new Date(at).toISOString());
  }

  enqueueDigest(key,item){
    const current=this.digests.get(key)||[];
    const withoutReplay=current.filter(x=>x.incident_id!==item.incident_id);
    withoutReplay.push(structuredClone(item));
    this.digests.set(key,withoutReplay);
    return withoutReplay.length;
  }

  getDigest(key){
    return (this.digests.get(key)||[]).map(x=>structuredClone(x));
  }

  listDigestKeys(){
    return [...this.digests.keys()].sort();
  }

  flushDigest(key){
    const items=this.getDigest(key);
    this.digests.delete(key);
    return items;
  }
}

module.exports={MemoryAlertState};
