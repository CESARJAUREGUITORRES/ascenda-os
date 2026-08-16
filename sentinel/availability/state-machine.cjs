'use strict';

const STATES=Object.freeze({
  UP:'UP',
  DEGRADED:'DEGRADED',
  DOWN:'DOWN',
  UNKNOWN:'UNKNOWN'
});

const COVERAGE=Object.freeze({
  CLOUD_AND_LOCAL:'CLOUD_AND_LOCAL',
  CLOUD_ONLY:'CLOUD_ONLY',
  LOCAL_ONLY:'LOCAL_ONLY',
  UNKNOWN:'UNKNOWN'
});

function classifyAvailability(input={}){
  const observerFresh=input.observerFresh===true;
  const consecutiveFailures=Number.isInteger(input.consecutiveFailures)?Math.max(0,input.consecutiveFailures):0;
  const consecutiveSuccesses=Number.isInteger(input.consecutiveSuccesses)?Math.max(0,input.consecutiveSuccesses):0;
  const failureThreshold=Number.isInteger(input.failureThreshold)?Math.max(1,input.failureThreshold):3;
  const recoveryThreshold=Number.isInteger(input.recoveryThreshold)?Math.max(1,input.recoveryThreshold):2;
  const previousState=Object.values(STATES).includes(input.previousState)?input.previousState:STATES.UNKNOWN;

  if(!observerFresh)return STATES.UNKNOWN;
  if(consecutiveFailures>=failureThreshold)return STATES.DOWN;
  if(consecutiveFailures>0)return STATES.DEGRADED;
  if(consecutiveSuccesses>=recoveryThreshold)return STATES.UP;

  // Preserve incident context while recovery is not yet proven.
  // One isolated success after DOWN/DEGRADED must never become a false green
  // and should not erase the known degraded condition as UNKNOWN.
  if(consecutiveSuccesses>0&&(previousState===STATES.DOWN||previousState===STATES.DEGRADED)){
    return STATES.DEGRADED;
  }

  return STATES.UNKNOWN;
}

function classifyCoverage(input={}){
  const cloudFresh=input.cloudObserverFresh===true;
  const localFresh=input.localObserverFresh===true;
  if(cloudFresh&&localFresh)return COVERAGE.CLOUD_AND_LOCAL;
  if(cloudFresh)return COVERAGE.CLOUD_ONLY;
  if(localFresh)return COVERAGE.LOCAL_ONLY;
  return COVERAGE.UNKNOWN;
}

function sentinelHealthState(availabilityState){
  switch(availabilityState){
    case STATES.UP:return 'HEALTHY';
    case STATES.DEGRADED:return 'DEGRADED';
    case STATES.DOWN:return 'INCIDENT';
    default:return 'UNKNOWN';
  }
}

function availabilityFingerprint({environment='unknown',monitorId='unknown'}={}){
  const safe=s=>String(s||'unknown').toLowerCase().replace(/[^a-z0-9._-]+/g,'-').replace(/^-+|-+$/g,'')||'unknown';
  return `availability:${safe(environment)}:${safe(monitorId)}`;
}

module.exports={STATES,COVERAGE,classifyAvailability,classifyCoverage,sentinelHealthState,availabilityFingerprint};
