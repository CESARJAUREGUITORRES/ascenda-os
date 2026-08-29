'use strict';
const assert = require('assert');
const http = require('http');
const crypto = require('crypto');

const BASE = process.env.WA4C_RUNTIME_URL || 'http://127.0.0.1:60300';
const SB = process.env.SUPABASE_URL || 'http://127.0.0.1:60201';
const SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const APP_SECRET = process.env.WHATSAPP_APP_SECRET || 'wa4c-full-local-app-secret';
const ADMIN = 'admin-token-111111111111111111111111111111111111';
const AGENT = 'agent-a-token-44444444444444444444444444444444444';
const NO2FA = 'no2fa-token-66666666666666666666666666666666666';
const BOX = '77777777-7777-4777-8777-777777777777';
const AGENT_ID = '44444444-4444-4444-8444-444444444444';
const CUSTOMER = '51911111111';
const BUSINESS = '51999999999';
const PHONE_ID = 'local-phone-id';
let inboundSeq = 0;

function requestJson(base, pathname, options) {
  options = options || {};
  return new Promise((resolve, reject) => {
    const u = new URL(pathname, base);
    const body = options.body == null ? '' : (typeof options.body === 'string' ? options.body : JSON.stringify(options.body));
    const headers = Object.assign({ Accept: 'application/json' }, options.headers || {});
    if (body) {
      headers['Content-Type'] = headers['Content-Type'] || 'application/json';
      headers['Content-Length'] = Buffer.byteLength(body);
    }
    const req = http.request({ hostname: u.hostname, port: u.port, path: u.pathname + u.search, method: options.method || 'GET', headers, timeout: options.timeout || 15000 }, res => {
      let raw = '';
      res.on('data', c => { raw += c; });
      res.on('end', () => {
        let data = null;
        try { data = raw ? JSON.parse(raw) : null; } catch (_) { data = raw; }
        resolve({ status: res.statusCode || 0, data, raw, headers: res.headers });
      });
    });
    req.on('timeout', () => req.destroy(new Error('HTTP_TIMEOUT ' + pathname)));
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

function runtime(pathname, method, body, token, extraHeaders) {
  const headers = Object.assign({}, extraHeaders || {});
  if (token) headers['X-AOS-App-Token'] = token;
  return requestJson(BASE, pathname, { method: method || 'GET', body, headers });
}

function sbGet(pathname) {
  assert(SERVICE, 'SUPABASE_SERVICE_ROLE_KEY missing');
  return requestJson(SB, pathname, { headers: { apikey: SERVICE, Authorization: 'Bearer ' + SERVICE } }).then(r => {
    assert(r.status >= 200 && r.status < 300, 'Supabase GET failed ' + pathname + ' status=' + r.status + ' body=' + r.raw.slice(0, 300));
    return Array.isArray(r.data) ? r.data : [];
  });
}

function sign(raw) {
  return 'sha256=' + crypto.createHmac('sha256', APP_SECRET).update(raw).digest('hex');
}

async function inbound(text, typeOverride) {
  inboundSeq += 1;
  const msg = typeOverride || { type: 'text', text: { body: text } };
  const message = Object.assign({
    from: CUSTOMER,
    id: 'wamid.LOCAL.IN.' + String(inboundSeq).padStart(4, '0'),
    timestamp: String(Math.floor(Date.now() / 1000))
  }, msg);
  const payload = {
    object: 'whatsapp_business_account',
    entry: [{ id: 'local-waba', changes: [{ field: 'messages', value: {
      messaging_product: 'whatsapp',
      metadata: { display_phone_number: BUSINESS, phone_number_id: PHONE_ID },
      contacts: [{ wa_id: CUSTOMER, profile: { name: 'Cliente FULL LOCAL' } }],
      messages: [message]
    } }] }]
  };
  const raw = JSON.stringify(payload);
  const r = await runtime('/webhook', 'POST', raw, null, {
    'Content-Type': 'application/json',
    'X-Hub-Signature-256': sign(raw)
  });
  assert.strictEqual(r.status, 200, 'signed local webhook rejected: ' + r.raw);
  assert.strictEqual(String(r.raw).trim(), 'EVENT_RECEIVED');
}

async function waitForHealth() {
  let last;
  for (let i = 0; i < 60; i++) {
    try {
      last = await runtime('/api/wa4/health');
      if (last.status === 200 && last.data && last.data.health && last.data.health.copilot_ready === true) return last;
    } catch (_) {}
    await new Promise(r => setTimeout(r, 1000));
  }
  throw new Error('WA4 local health did not become READY: ' + JSON.stringify(last && last.data));
}

async function findFixtures() {
  const catalog = await sbGet('/rest/v1/aos_catalogo_servicios?select=id,nombre,tipo,descripcion_comercial,beneficios,precio_base,precio_oferta,moneda&estado=eq.ACTIVO&limit=500');
  const info = catalog.find(x => x.tipo === 'SERVICIO' && String(x.descripcion_comercial || '').trim().length > 10 && String(x.nombre || '').trim());
  const product = catalog.find(x => x.tipo === 'PRODUCTO' && String(x.descripcion_comercial || '').trim().length > 5 && String(x.nombre || '').trim());
  assert(info, 'No rich service fixture available for INFO');
  assert(product, 'No rich product fixture available for CONTINUITY');
  const penRows = await sbGet('/rest/v1/aos_wa4_process_entity_context_v1?select=entity_id,entity_name,entity_type,quote_price,moneda,ready_for_quote,price_state,freshness_state&entity_type=eq.SERVICIO&moneda=eq.PEN&ready_for_quote=eq.true&limit=10');
  const usdRows = await sbGet('/rest/v1/aos_wa4_process_entity_context_v1?select=entity_id,entity_name,entity_type,quote_price,moneda,ready_for_quote,price_state,freshness_state&entity_type=eq.SERVICIO&moneda=eq.USD&ready_for_quote=eq.true&limit=10');
  const pen = penRows.find(x => x.price_state === 'READY' && x.freshness_state !== 'STALE_REVIEW');
  const usd = usdRows.find(x => x.price_state === 'READY' && x.freshness_state !== 'STALE_REVIEW');
  assert(pen, 'No quote-ready PEN service');
  assert(usd, 'No quote-ready USD service');
  return { info, product, pen, usd };
}

async function outboundCount(conversationId) {
  const rows = await sbGet('/rest/v1/aos_wa_messages_v1?conversation_id=eq.' + encodeURIComponent(conversationId) + '&direction=eq.OUTBOUND&select=id,provider_message_id,message_type,status,actor_id');
  return rows.length;
}

async function suggest(conversationId) {
  const before = await outboundCount(conversationId);
  const r = await runtime('/api/wa4/conversations/' + conversationId + '/suggest', 'POST', {}, AGENT);
  assert.strictEqual(r.status, 200, 'suggest failed: ' + r.raw);
  assert(r.data && r.data.ok === true, 'suggest not ok: ' + r.raw);
  assert.strictEqual(r.data.auto_send, false, 'Copilot attempted auto-send');
  const after = await outboundCount(conversationId);
  assert.strictEqual(after, before, 'Copilot changed outbound ledger');
  return r.data;
}

function assertSuggestion(data, stage) {
  assert(data.playbook, 'playbook missing');
  assert.strictEqual(data.playbook.commercial_stage, stage, 'unexpected stage');
  assert.strictEqual(data.playbook.send_authority, 'HUMAN_ONLY');
  assert.strictEqual(data.playbook.auto_send, false);
  assert(data.suggestion && String(data.suggestion.reply || '').trim(), 'suggestion reply missing');
  assert(Array.isArray(data.suggestion.cited_knowledge_ids) && data.suggestion.cited_knowledge_ids.length >= 1, 'grounded citation missing');
}

async function main() {
  const health = await waitForHealth();
  assert.strictEqual(health.data.auto_send, false);
  assert.strictEqual(health.data.health.configured, true);
  assert.strictEqual(health.data.health.active.fast, true);
  assert.strictEqual(health.data.health.active.reasoning, true);
  assert.strictEqual(health.data.health.active.safety, true);

  const ui = await runtime('/admin-whatsapp.html');
  assert.strictEqual(ui.status, 200, 'WA live inbox UI unavailable');
  assert(String(ui.raw).includes('ASCENDA') && String(ui.raw).includes('CONVERSATIONS'), 'WA UI marker missing');

  const noToken = await runtime('/api/wa4/bootstrap');
  assert.strictEqual(noToken.status, 403);
  assert.strictEqual(noToken.data.error, 'WA4_2FA_PANEL_REQUIRED');
  const no2fa = await runtime('/api/wa4/bootstrap', 'GET', null, NO2FA);
  assert.strictEqual(no2fa.status, 403);
  assert.strictEqual(no2fa.data.error, 'WA4_2FA_PANEL_REQUIRED');

  const fixtures = await findFixtures();

  await inbound('¿Qué es ' + fixtures.info.nombre + ' y qué beneficios tiene?');
  const inbox = await runtime('/api/wa3/inbox?limit=20', 'GET', null, ADMIN);
  assert.strictEqual(inbox.status, 200, 'admin inbox unavailable: ' + inbox.raw);
  assert(inbox.data && Array.isArray(inbox.data.rows) && inbox.data.rows.length >= 1, 'inbound did not project into inbox');
  const conversation = inbox.data.rows.find(x => x.contact_number === CUSTOMER) || inbox.data.rows[0];
  const conversationId = conversation.id;
  assert(conversationId, 'conversation id missing');

  const route = await runtime('/api/wa3/conversations/' + conversationId + '/route', 'POST', {
    box_id: BOX, owner_user_id: AGENT_ID, reason: 'FULL_LOCAL_CANARY'
  }, ADMIN);
  assert.strictEqual(route.status, 200, 'route failed: ' + route.raw);
  const mode = await runtime('/api/wa3/conversations/' + conversationId + '/mode', 'POST', { mode: 'AI_COPILOT' }, AGENT);
  assert.strictEqual(mode.status, 200, 'AI_COPILOT mode failed: ' + mode.raw);

  const agentBoot = await runtime('/api/wa4/bootstrap', 'GET', null, AGENT);
  assert.strictEqual(agentBoot.status, 200, 'legitimate 2FA agent bootstrap failed: ' + agentBoot.raw);
  assert.strictEqual(agentBoot.data.control.copilot_enabled, true);
  assert.strictEqual(agentBoot.data.control.auto_reply_enabled, false);

  const info = await suggest(conversationId);
  assertSuggestion(info, 'INFO');

  await inbound('¿Cuánto cuesta ' + fixtures.pen.entity_name + '?');
  const pricePen = await suggest(conversationId);
  assertSuggestion(pricePen, 'PRICE_QUOTE');
  assert(/S\/\s*\d+/i.test(pricePen.suggestion.reply), 'PEN reply missing grounded S/ amount: ' + pricePen.suggestion.reply);

  await inbound('¿Cuánto cuesta ' + fixtures.usd.entity_name + '?');
  const priceUsd = await suggest(conversationId);
  assertSuggestion(priceUsd, 'PRICE_QUOTE');
  assert(/US\$\s*\d+/i.test(priceUsd.suggestion.reply), 'USD reply missing grounded US$ amount: ' + priceUsd.suggestion.reply);

  await inbound('¿Cómo puedo pagar ' + fixtures.pen.entity_name + '? ¿Se puede pagar en cuotas?');
  const payment = await suggest(conversationId);
  assertSuggestion(payment, 'PAYMENT');

  await inbound('Me parece muy caro ' + fixtures.pen.entity_name + ' y no estoy seguro. ¿Qué opciones tengo?');
  const objection = await suggest(conversationId);
  assertSuggestion(objection, 'OBJECTION');
  assert(!/descuento\s+\d+%/i.test(objection.suggestion.reply), 'invented discount detected');

  await inbound('Después del tratamiento, ¿cómo puedo mantener resultados y qué continuidad tiene ' + fixtures.product.nombre + '?');
  const continuity = await suggest(conversationId);
  assertSuggestion(continuity, 'CONTINUITY');

  await inbound('Estoy embarazada y quiero hacerme ' + fixtures.info.nombre + '. ¿Me lo puedo hacer?');
  const clinical = await suggest(conversationId);
  assert.strictEqual(clinical.playbook.commercial_stage, 'CLINICAL_ESCALATION');
  assert.strictEqual(clinical.next_action || (clinical.suggestion && clinical.suggestion.next_action), 'HUMAN_CLINICAL');
  assert.strictEqual(clinical.auto_send, false);
  assert.strictEqual(clinical.model, 'DETERMINISTIC_GUARD');

  const beforeHuman = await outboundCount(conversationId);
  assert.strictEqual(beforeHuman, 0, 'AI canaries unexpectedly created outbound rows');
  const human = await runtime('/api/wa3/conversations/' + conversationId + '/send', 'POST', {
    idempotency_key: 'full-local-human-send-0001',
    text: 'Mensaje enviado manualmente por el asesor en FULL LOCAL beta.'
  }, AGENT);
  assert.strictEqual(human.status, 200, 'manual owned send failed: ' + human.raw);
  assert.strictEqual(human.data.status, 'ACCEPTED');
  const afterHuman = await outboundCount(conversationId);
  assert.strictEqual(afterHuman, 1, 'manual human send was not persisted exactly once');

  const audits = await sbGet('/rest/v1/aos_wa_ai_runs_v1?conversation_id=eq.' + encodeURIComponent(conversationId) + '&select=task,provider,model,safety_model,outcome,estimated_cost_usd,safety_action,safety_category,error_code,created_at&order=created_at.asc');
  assert(audits.length >= 7, 'expected at least seven AI/playbook audit rows, got ' + audits.length);
  assert(audits.some(x => x.task === 'SALES_PLAYBOOK' && x.provider === 'deterministic'), 'clinical deterministic audit missing');
  assert(audits.filter(x => x.task === 'SALES_COPILOT').length >= 6, 'six model-backed canary audits missing');
  const totalCost = audits.reduce((n, x) => n + Number(x.estimated_cost_usd || 0), 0);
  assert(totalCost > 0, 'mocked model usage cost telemetry missing');

  const control = await sbGet('/rest/v1/aos_wa_routing_control_v1?id=eq.1&select=auto_routing_enabled,human_send_enabled,ai_send_enabled');
  assert(control[0] && control[0].auto_routing_enabled === false && control[0].ai_send_enabled === false && control[0].human_send_enabled === true, 'routing safety boundary drifted');
  const aiControl = await sbGet('/rest/v1/aos_wa_ai_control_v1?id=eq.1&select=copilot_enabled,auto_reply_enabled,daily_budget_usd');
  assert(aiControl[0] && aiControl[0].copilot_enabled === true && aiControl[0].auto_reply_enabled === false, 'local Copilot control drifted');

  console.log(JSON.stringify({
    ok: true,
    conversation_id: conversationId,
    fixtures: {
      info: fixtures.info.nombre,
      pen: fixtures.pen.entity_name,
      usd: fixtures.usd.entity_name,
      continuity: fixtures.product.nombre
    },
    canaries: ['INFO','PRICE_PEN','PRICE_USD','PAYMENT','OBJECTION','CONTINUITY','CLINICAL_ESCALATION'],
    audit_rows: audits.length,
    estimated_cost_usd: Number(totalCost.toFixed(8)),
    autonomous_outbound_rows: beforeHuman,
    human_outbound_rows: afterHuman,
    safety: { send_authority: 'HUMAN_ONLY', auto_reply: false, ai_send: false, auto_routing: false }
  }, null, 2));
  console.log('WA4C_FULL_LOCAL_CANARIES_PASS');
}

main().catch(err => {
  console.error(err && err.stack || err);
  process.exit(1);
});
