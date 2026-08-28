'use strict';

function requestOptions(args) {
  const first = args && args[0];
  const second = args && args[1];
  if (first instanceof URL) return { hostname: first.hostname, headers: second && second.headers || {} };
  if (typeof first === 'string') {
    try { const u = new URL(first); return { hostname: u.hostname, headers: second && second.headers || {} }; }
    catch (_) { return { hostname: '', headers: second && second.headers || {} }; }
  }
  return first && typeof first === 'object' ? first : {};
}

function isConfiguredSupabaseRequest(args, configuredHost) {
  const opts = requestOptions(args || []);
  const host = String(opts.hostname || opts.host || '').split(':')[0].toLowerCase();
  return !!host && host === String(configuredHost || '').toLowerCase();
}

module.exports = { requestOptions, isConfiguredSupabaseRequest };
