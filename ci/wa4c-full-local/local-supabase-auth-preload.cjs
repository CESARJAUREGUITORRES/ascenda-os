'use strict';

// TEST-ONLY compatibility bridge for Supabase CLI modern local API keys.
// Legacy WA/F4 code still emits Authorization: Bearer <service key>. Modern
// sb_secret_/sb_publishable_ keys are API keys, not JWTs, so the local Kong
// gateway must receive them through apikey only. This preload is never used in
// Railway/PROD and only mutates requests to localhost in the FULL LOCAL lane.
const http = require('http');

if (!global.__ASCENDA_WA4C_LOCAL_SUPABASE_AUTH__) {
  const baseRequest = http.request;

  function hostOf(value) {
    try {
      if (typeof value === 'string' || value instanceof URL) return new URL(value).hostname.toLowerCase();
    } catch (_) {}
    if (value && typeof value === 'object') return String(value.hostname || value.host || '').split(':')[0].toLowerCase();
    return '';
  }

  function isLocal(host) {
    return host === '127.0.0.1' || host === 'localhost' || host === '::1';
  }

  function sanitizeHeaders(headers) {
    const out = Object.assign({}, headers || {});
    for (const key of Object.keys(out)) {
      if (key.toLowerCase() !== 'authorization') continue;
      const value = String(out[key] || '').trim();
      if (/^Bearer\s+sb_(?:secret|publishable)_/i.test(value)) delete out[key];
    }
    return out;
  }

  function sanitizeArgs(input) {
    const args = Array.prototype.slice.call(input || []);
    const first = args[0];
    const host = hostOf(first);
    if (!isLocal(host)) return args;

    if (first && typeof first === 'object' && !(first instanceof URL)) {
      args[0] = Object.assign({}, first, { headers: sanitizeHeaders(first.headers) });
      return args;
    }

    if (args[1] && typeof args[1] === 'object' && !(args[1] instanceof URL)) {
      args[1] = Object.assign({}, args[1], { headers: sanitizeHeaders(args[1].headers) });
    }
    return args;
  }

  http.request = function ascendaFullLocalSupabaseAuthRequest() {
    return baseRequest.apply(http, sanitizeArgs(arguments));
  };

  http.get = function ascendaFullLocalSupabaseAuthGet() {
    const req = http.request.apply(http, arguments);
    req.end();
    return req;
  };

  global.__ASCENDA_WA4C_LOCAL_SUPABASE_AUTH__ = {
    installed: true,
    local_only: true,
    modern_api_key_bearer_removed: true,
    apikey_preserved: true,
    production_network_mutation: false
  };
}
