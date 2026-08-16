'use strict';

const STATES=Object.freeze({
  UP:'UP',
  DEGRADED:'DEGRADED',
  DOWN:'DOWN',
  UNKNOWN:'UNKNOWN'
});

function classifyAvailability(input={}){
  const observerFresh=input.observerFresh===true;
  const consecutiveFailures=Number.isInteger(input.consecutiveFailures)?Math.max(0,input.consecutiveFailures):0;
  const consecutiveSuccesses=Number.isInteger(input.consecutiveSuccesses)?Math.max(0,input.consecutiveSuccesses):0;
  const failureThreshold=Number.isInteger(input.failureThreshold)?Math.max(1,input.failureThreshold):3;
  const recoveryThreshold=Number.isInteger(input.recoveryThreshold)?Math.max(1,input.recoveryThreshold):2;

  if(!observerFresh)return STATES.UNKNOWN;
  if(consecutiveFailures>=failureThreshold)return STATES.DOWN;
  if(consecutiveFailures>0)return STATES.DEGRADED;
  if(consecutiveSuccesses>=recoveryThreshold)return STATES.UP;
  return STATES.UNKNOWN;
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

module.exports={STATES,classifyAvailability,sentinelHealthState,availabilityFingerprint};
