'use strict'

const assert = require('assert')
const crypto = require('crypto')
const EventEmitter = require('events')
const gatewayLib = require('../../app/email-gateway')

function signature(secret, eventId, timestamp, raw) {
  var keyText = secret.indexOf('whsec_') === 0 ? secret.slice(6) : secret
  var key = Buffer.from(keyText, 'base64')
  return crypto.createHmac('sha256', key)
    .update(Buffer.concat([Buffer.from(eventId + '.' + timestamp + '.'), raw]))
    .digest('base64')
}

function mockRequest(body, headers) {
  var req = new EventEmitter()
  req.method = 'POST'
  req.headers = headers || {}
  req.destroy = function() {}
  process.nextTick(function() {
    if (body) req.emit('data', Buffer.from(body))
    req.emit('end')
  })
  return req
}

function mockResponse() {
  var result = { status: 0, headers: {}, body: '' }
  result.writeHead = function(status, headers) { result.status = status; result.headers = headers || {} }
  result.end = function(body) { result.body = String(body || ''); if (result.resolve) result.resolve(result) }
  result.done = new Promise(function(resolve) { result.resolve = resolve })
  return result
}

async function run() {
  var raw = Buffer.from(JSON.stringify({ type: 'email.delivered', data: { email_id: 'synthetic-provider-message' } }))
  var secret = 'whsec_' + Buffer.from('synthetic-webhook-signing-key-32bytes').toString('base64')
  var eventId = 'synthetic-event-123456'
  var now = 1900000000
  var sig = signature(secret, eventId, String(now), raw)

  var verified = gatewayLib.verifySvixSignature(raw, {
    'svix-id': eventId,
    'svix-timestamp': String(now),
    'svix-signature': 'v1,' + sig
  }, secret, now)
  assert.strictEqual(verified.ok, true, 'valid webhook signature must pass')

  var bad = gatewayLib.verifySvixSignature(raw, {
    'svix-id': eventId,
    'svix-timestamp': String(now),
    'svix-signature': 'v1,' + Buffer.from('invalid-signature').toString('base64')
  }, secret, now)
  assert.strictEqual(bad.ok, false, 'invalid webhook signature must fail')

  var stale = gatewayLib.verifySvixSignature(raw, {
    'svix-id': eventId,
    'svix-timestamp': String(now - 301),
    'svix-signature': 'v1,' + signature(secret, eventId, String(now - 301), raw)
  }, secret, now)
  assert.strictEqual(stale.ok, false, 'stale webhook timestamp must fail')
  assert.strictEqual(stale.error, 'WEBHOOK_TIMESTAMP_INVALID')

  var rendered = gatewayLib.renderTemplate('<p>{{name}}</p>', { name: '<script>x</script>' }, ['name'], true)
  assert.strictEqual(rendered.ok, true)
  assert.strictEqual(rendered.value, '<p>&lt;script&gt;x&lt;/script&gt;</p>', 'HTML context must be escaped')
  assert.strictEqual(gatewayLib.renderTemplate('{{missing}}', {}, ['missing'], false).ok, false, 'missing context must fail closed')
  assert.ok(gatewayLib.safeLegacyQuery('select=id,nombre&order=nombre') !== null, 'safe legacy query should pass')
  assert.strictEqual(gatewayLib.safeLegacyQuery('select=*&x=eq.a;drop'), null, 'SQL-like delimiters must be rejected')

  var providerCalls = 0
  var claimCalls = 0
  var recorded = []
  async function fakeRequester(url, options, body) {
    if (url.indexOf('/rpc/aos_cia_email_admin_gateway_v2') >= 0) {
      return { status: 200, body: { ok: true, state: 'QUEUED', request_id: '00000000-0000-0000-0000-000000000009' } }
    }
    if (url.indexOf('/rpc/aos_cia_email_claim_dispatch_v2') >= 0) {
      claimCalls++
      if (claimCalls === 1) {
        return { status: 200, body: {
          ok: true, request_id: '00000000-0000-0000-0000-000000000009', send_allowed: true, state: 'DISPATCHING',
          recipient_email: 'recipient@example.test', subject_template: 'Hello {{name}}', html_template: '<p>Hello {{name}}</p>',
          variable_keys: ['name'], render_context: { name: 'Synthetic' }, idempotency_key: 'synthetic-idempotency-key'
        } }
      }
      return { status: 200, body: { ok: true, request_id: '00000000-0000-0000-0000-000000000009', send_allowed: false, state: 'ACCEPTED', idempotent: true } }
    }
    if (url.indexOf('/rpc/aos_cia_email_record_dispatch_result_v2') >= 0) {
      recorded.push(body)
      return { status: 200, body: { ok: true, state: body.p_accepted ? 'ACCEPTED' : 'FAILED' } }
    }
    if (url.indexOf('api.resend.com/emails') >= 0) {
      providerCalls++
      assert.strictEqual(options.headers['Idempotency-Key'], 'f16-synthetic-idempotency-key')
      return { status: 200, body: { id: 'synthetic-provider-id' } }
    }
    throw new Error('unexpected mock URL: ' + url)
  }

  var gateway = gatewayLib.createEmailGateway({
    supabaseUrl: 'https://synthetic.supabase.test',
    serviceRoleKey: 'synthetic-service-role-key-long-enough-for-test-only',
    resendApiKey: 'synthetic-resend-key-long-enough-for-test-only',
    webhookSecret: secret,
    requestJson: fakeRequester
  })
  var first = await gateway.dispatchRequest('synthetic-admin-token-that-is-long-enough-123456', '00000000-0000-0000-0000-000000000009')
  assert.strictEqual(first.ok, true)
  assert.strictEqual(providerCalls, 1, 'first dispatch must call provider exactly once')
  assert.strictEqual(recorded.length, 1, 'provider result must be audited')

  var second = await gateway.dispatchRequest('synthetic-admin-token-that-is-long-enough-123456', '00000000-0000-0000-0000-000000000009')
  assert.strictEqual(second.send_allowed, false)
  assert.strictEqual(providerCalls, 1, 'duplicate dispatch must not call provider twice')

  var noProvider = gatewayLib.createEmailGateway({
    supabaseUrl: 'https://synthetic.supabase.test',
    serviceRoleKey: 'synthetic-service-role-key-long-enough-for-test-only',
    resendApiKey: '',
    webhookSecret: secret,
    requestJson: async function(url, options, body) {
      if (url.indexOf('/rpc/aos_cia_email_admin_gateway_v2') >= 0) return { status: 200, body: { ok: true, state: 'QUEUED' } }
      if (url.indexOf('/rpc/aos_cia_email_claim_dispatch_v2') >= 0) return { status: 200, body: {
        ok: true, send_allowed: true, state: 'DISPATCHING', recipient_email: 'recipient@example.test',
        subject_template: 'Subject', html_template: '<p>Body</p>', variable_keys: [], render_context: {}, idempotency_key: 'missing-provider-test'
      } }
      if (url.indexOf('/rpc/aos_cia_email_record_dispatch_result_v2') >= 0) return { status: 200, body: { ok: true, state: 'FAILED' } }
      throw new Error('network provider call should not occur when provider key missing')
    }
  })
  var failedClosed = await noProvider.dispatchRequest('synthetic-admin-token-that-is-long-enough-123456', '00000000-0000-0000-0000-000000000010')
  assert.strictEqual(failedClosed.ok, false)
  assert.strictEqual(failedClosed.state, 'FAILED', 'missing provider config must fail closed and audit FAILED')

  var unauthorizedGateway = gatewayLib.createEmailGateway({ serviceRoleKey: 'synthetic-service-role-key-long-enough-for-test-only', requestJson: async function() { throw new Error('must not call upstream') } })
  var req = mockRequest(JSON.stringify({ action: 'CONFIG_HEALTH', payload: {} }), {})
  var res = mockResponse()
  unauthorizedGateway.handleAdmin(req, res)
  var completed = await res.done
  assert.strictEqual(completed.status, 401, 'missing admin session must be rejected before upstream access')

  console.log('CIA_PHASE16_EMAIL_GATEWAY_UNIT=PASS')
  console.log('WEBHOOK_SIGNATURE_REPLAY_BOUNDARY=PASS')
  console.log('IDEMPOTENT_PROVIDER_DISPATCH=PASS')
  console.log('MISSING_PROVIDER_FAIL_CLOSED=PASS')
}

run().catch(function(err) {
  console.error('CIA_PHASE16_EMAIL_GATEWAY_UNIT=FAIL', err && err.message ? err.message : err)
  process.exit(1)
})
