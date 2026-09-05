'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const ai = require('../../app/ai-router');
const hook = require('../../app/legacy-groq-model-hook');

test('WA4 canonical Groq models are current GPT-OSS IDs', () => {
  assert.equal(ai.MODELS.fast, 'openai/gpt-oss-20b');
  assert.equal(ai.MODELS.reasoning, 'openai/gpt-oss-120b');
  assert.equal(ai.MODELS.safety, 'openai/gpt-oss-safeguard-20b');
});

test('legacy hook replaces both retired Llama IDs and patches cost telemetry', () => {
  const src = "var TOKEN_COSTS = {\n  'llama-3.3-70b-versatile':   { input: 0, output: 0, motor: 'groq' }\n};\nvar a='llama-3.1-8b-instant'; var b='llama-3.3-70b-versatile';";
  const out = hook.transform(src);
  assert.ok(!out.includes('llama-3.1-8b-instant'));
  assert.ok(!out.includes('llama-3.3-70b-versatile'));
  assert.ok(out.includes('openai/gpt-oss-20b'));
  assert.ok(out.includes('openai/gpt-oss-120b'));
  assert.ok(out.includes('input: 0.15'));
});

test('legacy hook redirects provider secret reads to server-only env', () => {
  const src = `
function getKey(tipo, cb) {
  https.get({ hostname: 'ituyqwstonmhnfshnaqz.supabase.co', path: '/rest/v1/aos_integraciones?tipo=eq.' + tipo + '&estado=eq.conectado&select=api_key&limit=1' }, function(r){})
}
sbGet('/rest/v1/aos_integraciones?tipo=eq.groq&estado=eq.conectado&select=api_key&limit=1').then(function(rows){})
sbFetch('/rest/v1/aos_integraciones?select=tipo,api_key&tipo=in.(groq,gemini)').then(function(rows){})
https.get({
  hostname: 'ituyqwstonmhnfshnaqz.supabase.co',
  path: '/rest/v1/aos_integraciones?tipo=eq.groq&estado=eq.conectado&select=api_key&limit=1',
  headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }
}, function(r) {})
var RESEND_KEY = process.env.RESEND_API_KEY || 're_FAKE_SECRET_123456789';
`;
  const out = hook.transform(src);
  assert.ok(out.includes("process.env.GROQ_API_KEY"));
  assert.ok(out.includes("process.env.GEMINI_API_KEY"));
  assert.ok(out.includes("__ascendaLegacyKeyResponse"));
  assert.ok(!out.includes("sbGet('/rest/v1/aos_integraciones?tipo=eq.groq"));
  assert.ok(!out.includes("sbFetch('/rest/v1/aos_integraciones?select=tipo,api_key&tipo=in.(groq,gemini)')"));
  assert.ok(!out.includes('re_FAKE_SECRET_123456789'));
});

test('PII redaction removes email, long phone and DNI-like document', () => {
  const out = ai.redactPII('mi correo foo.bar@example.com telefono +51 999 888 777 dni 12345678');
  assert.ok(!out.includes('foo.bar@example.com'));
  assert.ok(out.includes('[EMAIL]'));
  assert.ok(out.includes('[TEL]'));
  assert.ok(out.includes('[DOC]'));
});

test('router uses fast model for simple sales question', () => {
  assert.equal(ai.chooseModel('¿Cuánto cuesta el hidrofacial?', { catalogMatches: 1 }), ai.MODELS.fast);
});

test('router escalates comparisons and complex plans to reasoning model', () => {
  assert.equal(ai.chooseModel('¿Cuál es la diferencia y qué plan me recomiendas entre HIFU y bioestimulador?', { catalogMatches: 2 }), ai.MODELS.reasoning);
});

test('personalized clinical risk is fail-closed', () => {
  assert.equal(ai.personalizedClinicalRisk('Estoy embarazada, ¿me puedo hacer el tratamiento?'), true);
  assert.equal(ai.personalizedClinicalRisk('Quiero saber el precio del tratamiento'), false);
});

test('grounded suggestion accepts approved citation and price', () => {
  const r = ai.validateSuggestion({ reply: 'La promoción está en S/ 199.', next_action: 'OFFER_BOOKING', cited_catalog_ids: ['svc1'] }, ['svc1'], [199]);
  assert.equal(r.ok, true);
});

test('invented price is rejected', () => {
  const r = ai.validateSuggestion({ reply: 'Te lo dejo en S/ 150.', next_action: 'REPLY', cited_catalog_ids: ['svc1'] }, ['svc1'], [199]);
  assert.equal(r.ok, false);
  assert.equal(r.error, 'WA4_UNGROUNDED_PRICE');
});

test('invented catalog citation is rejected', () => {
  const r = ai.validateSuggestion({ reply: 'Tenemos esa opción.', next_action: 'REPLY', cited_catalog_ids: ['fake'] }, ['svc1'], []);
  assert.equal(r.ok, false);
  assert.equal(r.error, 'WA4_UNGROUNDED_CITATION');
});

test('cost estimator uses current Groq prices', () => {
  assert.equal(ai.estimateCost('openai/gpt-oss-20b', { prompt_tokens: 1000000, completion_tokens: 1000000 }), 0.375);
  assert.equal(ai.estimateCost('openai/gpt-oss-120b', { prompt_tokens: 1000000, completion_tokens: 1000000 }), 0.75);
});

// Keep production-scale payload and FASTPATH regressions in the canonical WA4 test entrypoint.
require('./knowledge-bounds.test.js');
require('./fastpath-r1.test.js');
require('./fastpath-r1-resilience.test.js');
require('./fastpath-r1-benchmark.test.js');
require('./retrieval-grounding-r3.test.js');
require('./r4-continuity-presentation.test.js');
