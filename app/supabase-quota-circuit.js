'use strict';

function positiveInt(value, fallback) {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : fallback;
}

function createSupabaseQuotaCircuit(options) {
  const opts = options || {};
  const now = typeof opts.now === 'function' ? opts.now : function() { return Date.now(); };
  const configured = positiveInt(opts.cooldownMs != null ? opts.cooldownMs : process.env.SUPABASE_QUOTA_COOLDOWN_MS, 15 * 60 * 1000);
  const cooldownMs = Math.max(60 * 1000, Math.min(60 * 60 * 1000, configured));

  let blockedUntil = 0;
  let openedAt = 0;
  let probeInFlight = false;
  let openCount = 0;
  let shortCircuitCount = 0;
  let probeCount = 0;

  function blockedError() {
    const remaining = Math.max(0, blockedUntil - now());
    return Object.assign(new Error('SUPABASE_QUOTA_BLOCKED'), {
      code: 'SUPABASE_QUOTA_BLOCKED',
      status: 503,
      upstreamStatus: 402,
      upstream_status: 402,
      retryAfterMs: remaining,
      retry_after_ms: remaining
    });
  }

  function beforeRequest() {
    const t = now();
    if (blockedUntil > t) {
      shortCircuitCount++;
      throw blockedError();
    }
    if (blockedUntil > 0) {
      if (probeInFlight) {
        shortCircuitCount++;
        throw blockedError();
      }
      probeInFlight = true;
      probeCount++;
      return { probe: true };
    }
    return { probe: false };
  }

  function recordStatus(status, ticket) {
    const code = Number(status || 0);
    if (code === 402) {
      openedAt = now();
      blockedUntil = openedAt + cooldownMs;
      probeInFlight = false;
      openCount++;
      return;
    }
    if (ticket && ticket.probe) {
      blockedUntil = 0;
      openedAt = 0;
      probeInFlight = false;
    }
  }

  function recordError(ticket) {
    if (ticket && ticket.probe) {
      blockedUntil = 0;
      openedAt = 0;
      probeInFlight = false;
    }
  }

  function snapshot() {
    const t = now();
    return {
      open: blockedUntil > t,
      cooldown_ms: cooldownMs,
      opened_at_ms: openedAt || null,
      blocked_until_ms: blockedUntil || null,
      retry_after_ms: Math.max(0, blockedUntil - t),
      probe_in_flight: probeInFlight,
      open_count: openCount,
      short_circuit_count: shortCircuitCount,
      probe_count: probeCount
    };
  }

  return { beforeRequest, recordStatus, recordError, snapshot };
}

module.exports = { createSupabaseQuotaCircuit };
