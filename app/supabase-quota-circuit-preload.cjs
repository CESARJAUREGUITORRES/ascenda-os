'use strict';

const https = require('https');
const { EventEmitter } = require('events');
const { createSupabaseQuotaCircuit } = require('./supabase-quota-circuit');
const { isConfiguredSupabaseRequest } = require('./supabase-quota-target.cjs');

if (!global.__AOS_WA_SUPABASE_QUOTA_PRELOAD__) {
  const baseRequest = https.request;
  const circuit = createSupabaseQuotaCircuit();
  let configuredHost = 'ituyqwstonmhnfshnaqz.supabase.co';
  try { configuredHost = new URL(process.env.SUPABASE_URL || ('https://' + configuredHost)).hostname; } catch (_) {}

  // Supabase Fair Use 402 is project-wide, not endpoint- or user-agent-specific.
  // Therefore every request from this Railway process to the configured Supabase
  // host participates in the same breaker. During a quota block, user-driven
  // requests would fail upstream too; short-circuiting them prevents pointless
  // egress/API churn and allows a single controlled probe after cooldown.
  function isTarget(args) {
    return isConfiguredSupabaseRequest(args, configuredHost);
  }

  class BlockedRequest extends EventEmitter {
    constructor(err) { super(); this.err = err; this.finished = false; }
    write() { return true; }
    setTimeout() { return this; }
    abort() { return this.destroy(this.err); }
    destroy(err) {
      if (this.finished) return this;
      this.finished = true;
      const e = err || this.err;
      setImmediate(() => this.emit('error', e));
      return this;
    }
    end() {
      if (!this.finished) {
        this.finished = true;
        setImmediate(() => this.emit('error', this.err));
      }
      return this;
    }
  }

  https.request = function aosQuotaAwareRequest() {
    const args = Array.prototype.slice.call(arguments);
    if (!isTarget(args)) return baseRequest.apply(https, args);

    let ticket;
    try { ticket = circuit.beforeRequest(); }
    catch (e) { return new BlockedRequest(e); }

    const req = baseRequest.apply(https, args);
    req.once('response', function(res) { circuit.recordStatus(res && res.statusCode, ticket); });
    req.once('error', function() { circuit.recordError(ticket); });
    return req;
  };

  global.__AOS_WA_SUPABASE_QUOTA_PRELOAD__ = {
    installed: true,
    host: configuredHost,
    scope: 'ALL_CONFIGURED_SUPABASE_RUNTIME_REQUESTS',
    snapshot: function() { return circuit.snapshot(); }
  };
}
