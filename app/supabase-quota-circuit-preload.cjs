'use strict';

const https = require('https');
const { EventEmitter } = require('events');
const { createSupabaseQuotaCircuit } = require('./supabase-quota-circuit');

if (!global.__AOS_WA_SUPABASE_QUOTA_PRELOAD__) {
  const baseRequest = https.request;
  const circuit = createSupabaseQuotaCircuit();
  let configuredHost = 'ituyqwstonmhnfshnaqz.supabase.co';
  try { configuredHost = new URL(process.env.SUPABASE_URL || ('https://' + configuredHost)).hostname; } catch (_) {}
  const userAgentRe = /^AscendaOS-(?:Phase-S|WA2|WA3|WA3V2|WA4|F17)\//i;

  function requestOptions(args) {
    const first = args[0];
    const second = args[1];
    if (first instanceof URL) return { hostname: first.hostname, headers: second && second.headers || {} };
    if (typeof first === 'string') {
      try { const u = new URL(first); return { hostname: u.hostname, headers: second && second.headers || {} }; } catch (_) { return { hostname: '', headers: second && second.headers || {} }; }
    }
    return first && typeof first === 'object' ? first : {};
  }

  function header(headers, name) {
    if (!headers) return '';
    const lower = String(name).toLowerCase();
    for (const k of Object.keys(headers)) if (String(k).toLowerCase() === lower) return String(headers[k] == null ? '' : headers[k]);
    return '';
  }

  function isTarget(args) {
    const opts = requestOptions(args);
    const host = String(opts.hostname || opts.host || '').split(':')[0].toLowerCase();
    const ua = header(opts.headers, 'user-agent');
    return host === String(configuredHost || '').toLowerCase() && userAgentRe.test(ua);
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
    snapshot: function() { return circuit.snapshot(); }
  };
}
