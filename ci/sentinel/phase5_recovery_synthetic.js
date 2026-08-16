'use strict';

const assert = require('node:assert/strict');
const sm = require('../../sentinel/availability/state-machine.cjs');

const base = { observerFresh: true, failureThreshold: 3, recoveryThreshold: 2 };

const initial = sm.classifyAvailability({ ...base, consecutiveFailures: 0, consecutiveSuccesses: 0 });
assert.equal(initial, sm.STATES.UNKNOWN);

const up = sm.classifyAvailability({ ...base, consecutiveFailures: 0, consecutiveSuccesses: 2 });
assert.equal(up, sm.STATES.UP);
assert.equal(sm.sentinelHealthState(up), 'HEALTHY');

const degraded1 = sm.classifyAvailability({ ...base, previousState: sm.STATES.UP, consecutiveFailures: 1, consecutiveSuccesses: 0 });
assert.equal(degraded1, sm.STATES.DEGRADED);

const degraded2 = sm.classifyAvailability({ ...base, previousState: degraded1, consecutiveFailures: 2, consecutiveSuccesses: 0 });
assert.equal(degraded2, sm.STATES.DEGRADED);

const down = sm.classifyAvailability({ ...base, previousState: degraded2, consecutiveFailures: 3, consecutiveSuccesses: 0 });
assert.equal(down, sm.STATES.DOWN);
assert.equal(sm.sentinelHealthState(down), 'INCIDENT');

const recovering = sm.classifyAvailability({ ...base, previousState: down, consecutiveFailures: 0, consecutiveSuccesses: 1 });
assert.equal(recovering, sm.STATES.DEGRADED, 'first recovery success after DOWN must remain DEGRADED');
assert.equal(sm.sentinelHealthState(recovering), 'DEGRADED');

const recovered = sm.classifyAvailability({ ...base, previousState: recovering, consecutiveFailures: 0, consecutiveSuccesses: 2 });
assert.equal(recovered, sm.STATES.UP);
assert.equal(sm.sentinelHealthState(recovered), 'HEALTHY');

const stale = sm.classifyAvailability({ ...base, observerFresh: false, previousState: sm.STATES.UP, consecutiveSuccesses: 99 });
assert.equal(stale, sm.STATES.UNKNOWN, 'stale observer must never produce false green');

assert.equal(sm.classifyCoverage({ cloudObserverFresh: true, localObserverFresh: true }), sm.COVERAGE.CLOUD_AND_LOCAL);
assert.equal(sm.classifyCoverage({ cloudObserverFresh: true, localObserverFresh: false }), sm.COVERAGE.CLOUD_ONLY);
assert.equal(sm.classifyCoverage({ cloudObserverFresh: false, localObserverFresh: true }), sm.COVERAGE.LOCAL_ONLY);
assert.equal(sm.classifyCoverage({ cloudObserverFresh: false, localObserverFresh: false }), sm.COVERAGE.UNKNOWN);

assert.equal(
  sm.availabilityFingerprint({ environment: 'production', monitorId: 'ascenda-production-health' }),
  'availability:production:ascenda-production-health'
);

console.log(JSON.stringify({
  ok: true,
  certificate: 'SENTINEL_F5_G11_SYNTHETIC_RECOVERY_PASS',
  sequence: ['UNKNOWN','UP','DEGRADED','DEGRADED','DOWN','DEGRADED','UP'],
  coverage: ['CLOUD_AND_LOCAL','CLOUD_ONLY','LOCAL_ONLY','UNKNOWN'],
  production_mutation: false,
  false_green_guard: true
}));
