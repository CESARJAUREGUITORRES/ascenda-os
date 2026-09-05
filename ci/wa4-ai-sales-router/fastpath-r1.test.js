'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const ai = require('../../app/ai-router');
const booking = require('../../app/wa4-booking-resolver');

test('FASTPATH simple commercial turn stays on 20B even with many catalog matches', () => {
  assert.equal(
    ai.chooseModel('Hola, quiero más información sobre toxina', { catalogMatches: 12 }),
    ai.MODELS.fast
  );
});

test('FASTPATH explicit comparison still escalates to reasoning model', () => {
  assert.equal(
    ai.chooseModel('¿Cuál es la diferencia entre HIFU y bioestimulador y cuál me conviene más?', { catalogMatches: 2 }),
    ai.MODELS.reasoning
  );
});

test('FASTPATH non-booking turn performs zero booking authority calls', async () => {
  let getCalls = 0;
  let rpcCalls = 0;
  const resolver = booking.createBookingResolver({
    serviceGet: async () => { getCalls += 1; throw new Error('UNEXPECTED_BOOKING_GET'); },
    serviceRpc: async () => { rpcCalls += 1; throw new Error('UNEXPECTED_BOOKING_RPC'); }
  });
  const out = await resolver.resolve({
    runtime: { booking_readiness: 'LOW', intents: ['INFO'], state: {} },
    processContexts: []
  });
  assert.equal(out.status, 'NOT_REQUESTED');
  assert.equal(out.prompt_context.status, 'NOT_REQUESTED');
  assert.equal(out.prompt_context.confirmation_allowed, false);
  assert.equal(getCalls, 0);
  assert.equal(rpcCalls, 0);
});

test('FASTPATH safety knowledge removes FAQ bulk while preserving governed commercial facts', () => {
  const items = Array.from({ length: 12 }, (_, i) => ({
    knowledge_id: `catalog-${i}`,
    domain: 'CATALOG',
    title: `Toxina ${i}`,
    authority_tier: 1,
    freshness_state: 'CURRENT',
    facts: {
      nombre: `Toxina ${i}`,
      categoria: 'Toxina',
      precio_base: 500 + i,
      precio_oferta: 450 + i,
      moneda: 'PEN',
      descripcion_comercial: 'Descripción aprobada '.repeat(30),
      beneficios: Array.from({ length: 20 }, (_, n) => `Beneficio ${n} `.repeat(10)),
      faqs: Array.from({ length: 80 }, (_, n) => ({ q: `Pregunta ${n} `.repeat(20), a: `Respuesta ${n} `.repeat(80) }))
    }
  }));
  const original = { version: 'WA4A1-KNOWLEDGE-V2', audience: 'PUBLIC_CLIENT', authority: 'GOVERNED_SOURCE_ONLY', generic_llm_authority: false, items };
  const compact = ai.compactSafetyKnowledge(original);
  assert.equal(compact.items.length, ai.SAFETY_MAX_KNOWLEDGE_ITEMS);
  assert.equal(compact.items[0].facts.precio_oferta, 450);
  assert.equal(compact.items[0].facts.moneda, 'PEN');
  assert.equal(Object.hasOwn(compact.items[0].facts, 'faqs'), false);
  assert.ok(JSON.stringify(compact).length < 30000);
  assert.ok(JSON.stringify(compact).length < JSON.stringify(original).length / 10);
});

test('FASTPATH safety pass has a hard small completion budget', () => {
  assert.equal(ai.SAFETY_MAX_COMPLETION_TOKENS, 180);
});
