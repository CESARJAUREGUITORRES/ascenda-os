'use strict';

const path = require('path');

const TRUE_VALUES = new Set(['1', 'true', 'yes', 'on']);
const SAFE_CODE_RE = /^[A-Z][A-Z0-9_.:-]{2,95}$/;
const SAFE_TECH_RE = /^[A-Za-z0-9_.:/@-]{1,160}$/;
const REDACTED = '[REDACTED]';
const REDACTED_MESSAGE = '[REDACTED_MESSAGE]';
const SYNTHETIC_CODE = 'SENTINEL_F4_SYNTHETIC_ERROR';
const ALLOWED_TAGS = new Set([
  'system',
  'sentinel.phase',
  'sentinel.domain',
  'sentinel.component',
  'sentinel.capability',
  'sentinel.dependency',
  'service.name'
]);
const BLOCKED_INTEGRATION_FRAGMENTS = [
  'localvariables',
  'requestdata',
  'contextlines',
  'console'
];

function flag(value) {
  return TRUE_VALUES.has(String(value || '').trim().toLowerCase());
}

function normalizeEnvironment(value) {
  const v = String(value || '').trim().toLowerCase();
  if (v === 'production') return 'production';
  if (v === 'development') return 'development';
  if (v === 'zero-cost' || v === 'zero_cost' || v === 'staging' || v === 'test') return 'zero-cost';
  return 'production';
}

function buildRelease(env = process.env) {
  const explicit = String(env.SENTRY_RELEASE || '').trim();
  if (explicit && /^ascenda-os@[0-9a-f]{7,40}$/i.test(explicit)) return explicit;
  const sha = String(env.RAILWAY_GIT_COMMIT_SHA || env.GITHUB_SHA || '').trim();
  return /^[0-9a-f]{7,40}$/i.test(sha) ? `ascenda-os@${sha}` : 'ascenda-os@unknown';
}

function hasSensitiveValue(value) {
  const s = String(value || '');
  if (!s) return false;
  return [
    /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i,
    /\bBearer\s+[A-Za-z0-9._~+\/-]+=*/i,
    /\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/,
    /\bsk-(?:proj-)?[A-Za-z0-9_-]{12,}\b/,
    /\bsb_secret_[A-Za-z0-9_-]{12,}\b/,
    /(?:\+?\d[\s().-]*){7,16}/,
    /https?:\/\/[^\s?#]+\?[^\s]+/i
  ].some(re => re.test(s));
}

function safeTechnicalValue(value, fallback = REDACTED) {
  const s = String(value == null ? '' : value).trim();
  if (!s || s.length > 160 || hasSensitiveValue(s) || !SAFE_TECH_RE.test(s)) return fallback;
  return s;
}

function sanitizeExceptionMessage(value) {
  const s = String(value == null ? '' : value).trim();
  if (!s || hasSensitiveValue(s) || !SAFE_CODE_RE.test(s)) return REDACTED_MESSAGE;
  return s;
}

function sanitizeFrame(frame) {
  if (!frame || typeof frame !== 'object') return frame;
  const out = {};
  if (frame.filename) out.filename = path.basename(String(frame.filename)).slice(0, 120);
  if (frame.module) out.module = safeTechnicalValue(frame.module, 'redacted-module');
  if (frame.function) out.function = safeTechnicalValue(frame.function, 'redacted-function');
  if (Number.isInteger(frame.lineno)) out.lineno = frame.lineno;
  if (Number.isInteger(frame.colno)) out.colno = frame.colno;
  if (typeof frame.in_app === 'boolean') out.in_app = frame.in_app;
  return out;
}

function sanitizeException(exception) {
  if (!exception || typeof exception !== 'object') return exception;
  const values = Array.isArray(exception.values) ? exception.values.map(item => {
    const clean = {
      type: safeTechnicalValue(item && item.type, 'Error'),
      value: sanitizeExceptionMessage(item && item.value)
    };
    const frames = item && item.stacktrace && Array.isArray(item.stacktrace.frames)
      ? item.stacktrace.frames.map(sanitizeFrame)
      : null;
    if (frames) clean.stacktrace = { frames };
    if (item && item.mechanism && item.mechanism.type) {
      clean.mechanism = {
        type: safeTechnicalValue(item.mechanism.type, 'generic'),
        handled: typeof item.mechanism.handled === 'boolean' ? item.mechanism.handled : undefined
      };
    }
    return clean;
  }) : [];
  return { values };
}

function sanitizeTags(tags) {
  const out = {};
  if (!tags || typeof tags !== 'object') return out;
  for (const [key, value] of Object.entries(tags)) {
    if (!ALLOWED_TAGS.has(key)) continue;
    out[key] = safeTechnicalValue(value);
  }
  return out;
}

function sanitizeEvent(input) {
  const event = input && typeof input === 'object' ? input : {};
  const out = {};

  for (const key of ['event_id', 'timestamp', 'platform', 'level']) {
    if (event[key] != null) out[key] = event[key];
  }

  if (event.environment) out.environment = normalizeEnvironment(event.environment);
  if (event.release) out.release = safeTechnicalValue(event.release, 'ascenda-os@unknown');
  if (event.exception) out.exception = sanitizeException(event.exception);
  if (event.message) out.message = sanitizeExceptionMessage(event.message);
  if (event.logentry && typeof event.logentry === 'object') {
    out.logentry = { message: sanitizeExceptionMessage(event.logentry.message) };
  }

  out.tags = sanitizeTags(event.tags);

  // Deliberate drops: user/request/query/cookies/bodies, breadcrumbs, extra,
  // contexts, transaction names, modules, source context, spans and profiles.
  // F4 prefers an incomplete safe event over a diagnostically rich leak.
  return out;
}

function filterDefaultIntegrations(defaultIntegrations) {
  return (defaultIntegrations || []).filter(integration => {
    const name = String(integration && integration.name || '').toLowerCase();
    return !BLOCKED_INTEGRATION_FRAGMENTS.some(fragment => name.includes(fragment));
  });
}

function requested(env = process.env) {
  return flag(env.SENTINEL_ENABLED) && flag(env.SENTINEL_SENTRY_ENABLED);
}

function canaryMode(env = process.env) {
  const raw = env.SENTINEL_SENTRY_CANARY_MODE;
  return raw == null || String(raw).trim() === '' ? true : flag(raw);
}

function serviceName(argv = process.argv) {
  const file = path.basename(String(argv[1] || 'node-runtime'));
  return safeTechnicalValue(file, 'node-runtime');
}

function isSyntheticEvent(event) {
  if (!event || typeof event !== 'object') return false;
  if (event.message === SYNTHETIC_CODE) return true;
  const values = event.exception && Array.isArray(event.exception.values) ? event.exception.values : [];
  return values.some(v => v && v.value === SYNTHETIC_CODE);
}

function bootstrap(env = process.env) {
  if (global.__ASCENDA_SENTINEL_SENTRY_STATUS__) return global.__ASCENDA_SENTINEL_SENTRY_STATUS__;

  const base = {
    requested: requested(env),
    active: false,
    canary_mode: canaryMode(env),
    phase: 'F4',
    service_name: serviceName(),
    environment: normalizeEnvironment(env.SENTRY_ENVIRONMENT || env.RAILWAY_ENVIRONMENT_NAME),
    release: buildRelease(env),
    reason: 'disabled'
  };

  if (!base.requested) {
    global.__ASCENDA_SENTINEL_SENTRY_STATUS__ = base;
    return base;
  }

  if (!String(env.SENTRY_DSN || '').trim()) {
    base.reason = 'missing_dsn';
    global.__ASCENDA_SENTINEL_SENTRY_STATUS__ = base;
    return base;
  }

  try {
    const Sentry = require('@sentry/node');
    Sentry.init({
      dsn: env.SENTRY_DSN,
      enabled: true,
      sendDefaultPii: false,
      tracesSampleRate: 0,
      enableLogs: false,
      maxBreadcrumbs: 0,
      includeLocalVariables: false,
      environment: base.environment,
      release: base.release,
      serverName: 'ascenda-os',
      integrations: filterDefaultIntegrations,
      beforeBreadcrumb: () => null,
      beforeSend: event => {
        const clean = sanitizeEvent(event);
        if (base.canary_mode && !isSyntheticEvent(clean)) return null;
        return clean;
      },
      initialScope: {
        tags: {
          system: 'ascenda-os',
          'sentinel.phase': 'F4',
          'service.name': base.service_name
        }
      }
    });
    base.active = true;
    base.reason = base.canary_mode ? 'active_canary' : 'active';

    if (base.canary_mode && flag(env.SENTINEL_SENTRY_SYNTHETIC_ON_BOOT) && base.service_name === 'server-phase-s.js') {
      setImmediate(() => {
        try {
          Sentry.captureException(new Error(SYNTHETIC_CODE));
          Promise.resolve(Sentry.flush(2000)).catch(() => {});
        } catch (_) {}
      });
    }
  } catch (_) {
    // Sentry must never be able to stop ASCENDA from booting.
    base.active = false;
    base.reason = 'init_failed';
  }

  global.__ASCENDA_SENTINEL_SENTRY_STATUS__ = base;
  return base;
}

const status = bootstrap();

module.exports = {
  REDACTED,
  REDACTED_MESSAGE,
  SYNTHETIC_CODE,
  ALLOWED_TAGS,
  flag,
  requested,
  canaryMode,
  normalizeEnvironment,
  buildRelease,
  hasSensitiveValue,
  sanitizeExceptionMessage,
  sanitizeEvent,
  filterDefaultIntegrations,
  isSyntheticEvent,
  bootstrap,
  status
};
