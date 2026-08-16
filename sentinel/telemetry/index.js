'use strict';

const crypto = require('crypto');
const contract = require('./contract-v1.json');

const ALLOWED_RESOURCE = new Set(contract.resource.allowed);
const ALLOWED_ATTRIBUTES = new Set(contract.attributes.allowed);
const DENIED_FRAGMENTS = contract.redaction.denied_key_fragments.map(v => String(v).toLowerCase());
const REDACTED = contract.redaction.redaction_marker;
const MAX_STRING = contract.attributes.max_string_length;
const MAX_ATTRIBUTES = contract.attributes.max_attribute_count;

const sensitiveValuePatterns = [
  /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i,
  /(?:\+?\d[\s().-]*){9,}/,
  /\b\d{8}\b/,
  /\b(?:sk|sb_secret|xox[baprs]|gh[pousr])[-_][A-Za-z0-9_-]{10,}\b/i,
  /\bBearer\s+[A-Za-z0-9._~+\/-]+=*\b/i,
  /\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/
];

function hasDeniedKeyFragment(key) {
  const normalized = String(key || '').toLowerCase();
  return DENIED_FRAGMENTS.some(fragment => normalized.includes(fragment));
}

function isSensitiveValue(value) {
  if (typeof value !== 'string') return false;
  return sensitiveValuePatterns.some(re => re.test(value));
}

function sanitizeScalar(key, value) {
  if (value === null || value === undefined) return undefined;
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return Number.isFinite(value) ? value : undefined;
  if (typeof value !== 'string') return undefined;
  if (isSensitiveValue(value)) return REDACTED;
  return value.slice(0, MAX_STRING);
}

function sanitizeMap(input, allowedSet) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) return {};
  const out = {};
  for (const [key, value] of Object.entries(input)) {
    if (Object.keys(out).length >= MAX_ATTRIBUTES) break;
    if (!allowedSet.has(key)) continue;
    if (hasDeniedKeyFragment(key)) continue;
    const clean = sanitizeScalar(key, value);
    if (clean !== undefined) out[key] = clean;
  }
  return out;
}

function sanitizeResource(resource) {
  const clean = sanitizeMap(resource, ALLOWED_RESOURCE);
  clean['service.namespace'] = contract.resource.service_namespace;
  if (!contract.resource.environments.includes(clean['deployment.environment.name'])) {
    delete clean['deployment.environment.name'];
  }
  return clean;
}

function sanitizeAttributes(attributes) {
  return sanitizeMap(attributes, ALLOWED_ATTRIBUTES);
}

function createRequestId() {
  return crypto.randomUUID();
}

function randomHex(bytes) {
  let value;
  do value = crypto.randomBytes(bytes).toString('hex');
  while (/^0+$/.test(value));
  return value;
}

function createTraceId() { return randomHex(16); }
function createSpanId() { return randomHex(8); }

function parseTraceparent(value) {
  if (typeof value !== 'string') return null;
  const match = /^([0-9a-f]{2})-([0-9a-f]{32})-([0-9a-f]{16})-([0-9a-f]{2})$/i.exec(value.trim());
  if (!match) return null;
  const version = match[1].toLowerCase();
  const traceId = match[2].toLowerCase();
  const parentSpanId = match[3].toLowerCase();
  const flags = match[4].toLowerCase();
  if (version === 'ff' || /^0+$/.test(traceId) || /^0+$/.test(parentSpanId)) return null;
  return {version, trace_id: traceId, parent_span_id: parentSpanId, sampled: (parseInt(flags, 16) & 1) === 1};
}

function createTraceContext(options = {}) {
  const inbound = parseTraceparent(options.traceparent);
  return {
    request_id: typeof options.request_id === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(options.request_id)
      ? options.request_id.toLowerCase()
      : createRequestId(),
    trace_id: inbound ? inbound.trace_id : createTraceId(),
    span_id: createSpanId(),
    parent_span_id: inbound ? inbound.parent_span_id : null,
    sampled: inbound ? inbound.sampled : Boolean(options.sampled)
  };
}

function formatTraceparent(context) {
  if (!context || !/^[0-9a-f]{32}$/i.test(context.trace_id || '') || !/^[0-9a-f]{16}$/i.test(context.span_id || '')) {
    throw new Error('INVALID_TRACE_CONTEXT');
  }
  return `00-${context.trace_id.toLowerCase()}-${context.span_id.toLowerCase()}-${context.sampled ? '01' : '00'}`;
}

function defaultSampleRate(environment) {
  const configured = contract.sampling.defaults[environment];
  return typeof configured === 'number' ? configured : 0;
}

function shouldSample(traceId, rate) {
  const normalizedRate = Math.max(0, Math.min(1, Number(rate)));
  if (normalizedRate <= 0) return false;
  if (normalizedRate >= 1) return true;
  if (!/^[0-9a-f]{32}$/i.test(traceId || '')) return false;
  const bucket = parseInt(traceId.slice(0, 8), 16) / 0xffffffff;
  return bucket < normalizedRate;
}

function validateResource(resource) {
  const missing = contract.resource.required.filter(key => !(key in resource));
  if (missing.length) throw new Error(`MISSING_REQUIRED_RESOURCE:${missing.join(',')}`);
  if (resource['service.namespace'] !== contract.resource.service_namespace) throw new Error('SERVICE_NAMESPACE_INVALID');
  if (!contract.resource.environments.includes(resource['deployment.environment.name'])) throw new Error('ENVIRONMENT_INVALID');
}

function buildEnvelope(input = {}) {
  if (!contract.envelope.signals.includes(input.signal)) throw new Error('SIGNAL_INVALID');
  const resource = sanitizeResource(input.resource || {});
  validateResource(resource);
  const context = input.context || createTraceContext();
  if (!/^[0-9a-f]{32}$/i.test(context.trace_id || '')) throw new Error('TRACE_ID_INVALID');
  if (!/^[0-9a-f]{16}$/i.test(context.span_id || '')) throw new Error('SPAN_ID_INVALID');
  const environment = resource['deployment.environment.name'];
  const rate = input.sample_rate === undefined ? defaultSampleRate(environment) : Number(input.sample_rate);
  const sampled = shouldSample(context.trace_id, rate);
  return {
    schema_version: contract.envelope.schema_version,
    signal: input.signal,
    timestamp: input.timestamp || new Date().toISOString(),
    resource,
    context: {
      request_id: context.request_id,
      trace_id: context.trace_id.toLowerCase(),
      span_id: context.span_id.toLowerCase(),
      parent_span_id: context.parent_span_id || null,
      sampled
    },
    attributes: sanitizeAttributes(input.attributes || {})
  };
}

function assertExporter(exporter) {
  if (!exporter || typeof exporter.export !== 'function') throw new Error('EXPORTER_INTERFACE_INVALID');
  return exporter;
}

function createNoopExporter() {
  return Object.freeze({
    name: 'noop',
    export() { return {accepted: false, reason: 'noop'}; }
  });
}

function createMemoryExporter() {
  const records = [];
  return {
    name: 'memory-test',
    export(envelope) {
      records.push(JSON.parse(JSON.stringify(envelope)));
      return {accepted: true, count: 1};
    },
    records() { return JSON.parse(JSON.stringify(records)); },
    reset() { records.length = 0; }
  };
}

function exportEnvelope(exporter, envelope) {
  assertExporter(exporter);
  const safeEnvelope = buildEnvelope({
    signal: envelope.signal,
    timestamp: envelope.timestamp,
    resource: envelope.resource,
    context: envelope.context,
    attributes: envelope.attributes,
    sample_rate: envelope.context && envelope.context.sampled ? 1 : 0
  });
  return exporter.export(safeEnvelope);
}

module.exports = {
  contract,
  sanitizeResource,
  sanitizeAttributes,
  createRequestId,
  createTraceId,
  createSpanId,
  parseTraceparent,
  createTraceContext,
  formatTraceparent,
  defaultSampleRate,
  shouldSample,
  buildEnvelope,
  assertExporter,
  createNoopExporter,
  createMemoryExporter,
  exportEnvelope
};
