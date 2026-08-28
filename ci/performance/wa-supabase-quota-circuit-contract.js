'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { EventEmitter } = require('events');
const { createSupabaseQuotaCircuit } = require('../../app/supabase-quota-circuit');

async function coreContract() {
  let now = 1000;
  const circuit = createSupabaseQuotaCircuit({ cooldownMs: 60000, now: function() { return now; } });

  assert.deepStrictEqual(circuit.beforeRequest(), { probe: false });
  circuit.recordStatus(401, { probe: false });
  assert.strictEqual(circuit.snapshot().open, false, '401 must not open quota circuit');
  circuit.recordStatus(403, { probe: false });
  assert.strictEqual(circuit.snapshot().open, false, '403 must not open quota circuit');
  circuit.recordStatus(429, { probe: false });
  assert.strictEqual(circuit.snapshot().open, false, '429 must not open quota circuit');
  circuit.recordStatus(500, { probe: false });
  assert.strictEqual(circuit.snapshot().open, false, '5xx must not open quota circuit');

  circuit.recordStatus(402, { probe: false });
  assert.strictEqual(circuit.snapshot().open, true, '402 must open quota circuit');
  assert.throws(function() { circuit.beforeRequest(); }, function(e) {
    return e && e.code === 'SUPABASE_QUOTA_BLOCKED' && e.upstreamStatus === 402;
  }, 'open circuit must fail locally with 402 compatibility metadata');

  now += 60000;
  const probe = circuit.beforeRequest();
  assert.strictEqual(probe.probe, true, 'cooldown expiry must allow exactly one probe');
  assert.throws(function() { circuit.beforeRequest(); }, /SUPABASE_QUOTA_BLOCKED/, 'parallel probe must be suppressed');
  circuit.recordStatus(500, probe);
  assert.strictEqual(circuit.snapshot().open, false, 'non-402 probe result must release quota circuit');
  assert.strictEqual(circuit.beforeRequest().probe, false, 'normal traffic must resume after non-402 probe');

  circuit.recordStatus(402, { probe: false });
  now += 60000;
  const successProbe = circuit.beforeRequest();
  circuit.recordStatus(200, successProbe);
  const final = circuit.snapshot();
  assert.strictEqual(final.open, false, 'successful probe must close circuit');
  assert(final.open_count >= 2, 'open counter missing');
  assert(final.short_circuit_count >= 2, 'short-circuit counter missing');
  assert(final.probe_count >= 2, 'probe counter missing');
}

async function preloadContract() {
  const https = require('https');
  const original = https.request;
  let network = 0;
  let status = 402;

  https.request = function fakeRequest(options, callback) {
    network++;
    const req = new EventEmitter();
    if (typeof callback === 'function') req.on('response', callback);
    req.write = function() { return true; };
    req.setTimeout = function() { return req; };
    req.destroy = function(err) { setImmediate(function() { req.emit('error', err || new Error('DESTROYED')); }); return req; };
    req.end = function() {
      setImmediate(function() {
        const res = new EventEmitter();
        res.statusCode = status;
        req.emit('response', res);
        setImmediate(function() { res.emit('end'); });
      });
      return req;
    };
    return req;
  };

  delete global.__AOS_WA_SUPABASE_QUOTA_PRELOAD__;
  delete require.cache[require.resolve('../../app/supabase-quota-circuit-preload.cjs')];
  require('../../app/supabase-quota-circuit-preload.cjs');

  function call(userAgent, hostname) {
    return new Promise(function(resolve) {
      const req = https.request({
        hostname: hostname || 'ituyqwstonmhnfshnaqz.supabase.co',
        path: '/rest/v1/rpc/aos_wa3_actor_v1',
        method: 'POST',
        headers: { 'User-Agent': userAgent }
      }, function(res) {
        res.on('end', function() { resolve({ status: res.statusCode }); });
      });
      req.on('error', function(e) { resolve({ error: e }); });
      req.write('{}');
      req.end();
    });
  }

  const first = await call('AscendaOS-Phase-S/1.0');
  assert.strictEqual(first.status, 402, 'first upstream 402 must be observable by caller');
  assert.strictEqual(network, 1, 'first Supabase call must reach network');
  assert.strictEqual(global.__AOS_WA_SUPABASE_QUOTA_PRELOAD__.snapshot().open, true, 'preload circuit did not open');

  const supabaseAgents = [
    'AscendaOS-Phase-S/1.0',
    'AscendaOS-WA2/1.0',
    'AscendaOS-WA3/1.0',
    'AscendaOS-WA3V2/1.0',
    'AscendaOS-WA4/1.0',
    'AscendaOS-WA-Gateway/1.0',
    'AscendaOS-F17/1.4',
    'AscendaOS-F4-RevenueProxy/1.0',
    'legacy-no-tag'
  ];
  for (const ua of supabaseAgents) {
    const blocked = await call(ua);
    assert(blocked.error && blocked.error.code === 'SUPABASE_QUOTA_BLOCKED', ua + ' must short-circuit against the restricted Supabase project');
  }
  assert.strictEqual(network, 1, 'blocked Supabase calls escaped to network');

  const external = await call('AscendaOS-WA-Gateway/1.0', 'graph.facebook.com');
  assert.strictEqual(external.status, 402, 'non-Supabase host must preserve base transport behavior');
  assert.strictEqual(network, 2, 'external host was incorrectly intercepted by Supabase quota circuit');

  https.request = original;
}

function staticContract() {
  const railway = fs.readFileSync(path.join(process.cwd(), 'app/railway.json'), 'utf8');
  const preload = fs.readFileSync(path.join(process.cwd(), 'app/supabase-quota-circuit-preload.cjs'), 'utf8');
  const target = fs.readFileSync(path.join(process.cwd(), 'app/supabase-quota-target.cjs'), 'utf8');
  assert(railway.includes('--require ./supabase-quota-circuit-preload.cjs'), 'Railway quota preload missing');
  assert(preload.includes("scope: 'ALL_CONFIGURED_SUPABASE_RUNTIME_REQUESTS'"), 'project-wide Supabase quota scope missing');
  assert(preload.includes('isConfiguredSupabaseRequest(args, configuredHost)'), 'Supabase host classifier missing');
  assert(target.includes("host === String(configuredHost || '').toLowerCase()"), 'quota circuit must remain scoped to the configured Supabase host');
  assert(!preload.includes('userAgentRe'), 'quota circuit must not depend on runtime User-Agent');
  assert(preload.includes('configuredHost'), 'Supabase host scoping missing');
  assert(!preload.includes('SUPABASE_SERVICE_ROLE_KEY'), 'preload must not inspect service-role credentials');
}

(async function main() {
  await coreContract();
  await preloadContract();
  staticContract();
  console.log('WA_SUPABASE_QUOTA_CIRCUIT_CONTRACT_PASS');
})().catch(function(err) {
  console.error(err);
  process.exit(1);
});