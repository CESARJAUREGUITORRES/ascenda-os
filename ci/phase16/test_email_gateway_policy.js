'use strict'

const assert = require('assert')
const fs = require('fs')
const path = require('path')
const EventEmitter = require('events')
const gatewayLib = require('../../app/email-gateway')

function mockRequest(body, headers) {
  var req = new EventEmitter()
  req.method = 'POST'
  req.headers = headers || {}
  req.destroy = function() {}
  process.nextTick(function() {
    req.emit('data', Buffer.from(body || ''))
    req.emit('end')
  })
  return req
}

function mockResponse() {
  var out = { status: 0, headers: {}, body: '' }
  out.writeHead = function(status, headers) { out.status = status; out.headers = headers || {} }
  out.end = function(body) { out.body = String(body || ''); if (out.resolve) out.resolve(out) }
  out.done = new Promise(function(resolve) { out.resolve = resolve })
  return out
}

async function run() {
  var providerCalls = 0
  var currentTemplateType = 'reactivacion'
  async function requester(url, options, body) {
    if (url.indexOf('/rpc/aos_cia_verify_admin_session_v1') >= 0) {
      return { status: 200, body: { ok: true, user_id: '00000000-0000-0000-0000-000000000001', usuario: 'synthetic-admin' } }
    }
    if (url.indexOf('/rpc/aos_cia_verify_app_session_v1') >= 0) {
      if (body && body.p_token === 'synthetic-app-token-valid-000000000000000001') {
        return { status: 200, body: { ok: true, user_id: '00000000-0000-0000-0000-000000000002', rol: 'ASESOR', assurance_level: 'PASSWORD' } }
      }
      return { status: 200, body: { ok: false, error: 'UNAUTHORIZED' } }
    }
    if (url.indexOf('/rest/v1/aos_email_plantillas?') >= 0) {
      return { status: 200, body: [{ id: '20000000-0000-0000-0000-000000000001', tipo: currentTemplateType, activo: true }] }
    }
    if (url.indexOf('api.resend.com/emails') >= 0) {
      providerCalls++
      return { status: 200, body: { id: 'synthetic-provider-id' } }
    }
    if (url.indexOf('/rest/v1/aos_email_envios') >= 0) return { status: 201, body: null }
    throw new Error('unexpected request ' + url)
  }

  var gateway = gatewayLib.createEmailGateway({
    supabaseUrl: 'https://synthetic.supabase.test',
    serviceRoleKey: 'synthetic-service-role-key-long-enough-for-test-only',
    resendApiKey: 'synthetic-resend-key-long-enough-for-test-only',
    webhookSecret: 'whsec_' + Buffer.from('synthetic-webhook-key-32bytes-long').toString('base64'),
    requestJson: requester
  })

  var appOk = await gateway.verifyApp('synthetic-app-token-valid-000000000000000001')
  assert.strictEqual(appOk.ok, true, 'current Auth V3 app session should verify')
  var appBad = await gateway.verifyApp('synthetic-app-token-invalid-00000000000000001')
  assert.strictEqual(appBad.ok, false, 'invalid Auth V3 app session must fail')

  var marketingReq = mockRequest(JSON.stringify({
    action: 'LEGACY_SEND',
    payload: {
      to: 'recipient@example.test', subject: 'Synthetic marketing', html: '<p>test</p>',
      plantilla_id: '20000000-0000-0000-0000-000000000001', client_request_id: 'synthetic-request-001'
    }
  }), { 'x-ascenda-session': 'synthetic-admin-token-that-is-long-enough-123456' })
  var marketingRes = mockResponse()
  gateway.handleAdmin(marketingReq, marketingRes)
  var blocked = await marketingRes.done
  var blockedBody = JSON.parse(blocked.body)
  assert.strictEqual(blocked.status, 403, 'legacy marketing must be blocked')
  assert.strictEqual(blockedBody.error, 'GOVERNED_ACTIVATION_REQUIRED')
  assert.strictEqual(providerCalls, 0, 'blocked marketing must not call provider')

  currentTemplateType = 'confirmacion_cita'
  var txnReq = mockRequest(JSON.stringify({
    action: 'LEGACY_SEND',
    payload: {
      to: 'recipient@example.test', subject: 'Synthetic confirmation', html: '<p>test</p>',
      plantilla_id: '20000000-0000-0000-0000-000000000001', client_request_id: 'synthetic-request-002'
    }
  }), { 'x-ascenda-session': 'synthetic-admin-token-that-is-long-enough-123456' })
  var txnRes = mockResponse()
  gateway.handleAdmin(txnReq, txnRes)
  var sent = await txnRes.done
  assert.strictEqual(sent.status, 200, 'transactional manual email should remain operational')
  assert.strictEqual(providerCalls, 1, 'transactional email should call provider exactly once')

  var server = fs.readFileSync(path.join(__dirname, '../../app/server.js'), 'utf8')
  var gatewaySource = fs.readFileSync(path.join(__dirname, '../../app/email-gateway.js'), 'utf8')
  assert.ok(server.includes("EMAIL_GATEWAY.verifyApp(templateToken)"), 'send-template must verify current app session')
  assert.ok(server.includes('LEGACY_2FA_RETIRED'), 'legacy public 2FA provider route must be retired')
  assert.ok(server.includes('F16_MARKETING_GOVERNED_ACTIVATION_REQUIRED'), 'agent marketing bypass must be closed')
  assert.ok(gatewaySource.includes("process.env.RESEND_API_KEY || ''"), 'Resend API key must come from environment')
  assert.ok(gatewaySource.includes("process.env.RESEND_WEBHOOK_SECRET || ''"), 'Resend webhook secret must come from environment')
  assert.strictEqual(/['\"]re_[A-Za-z0-9_-]{20,}['\"]/.test(gatewaySource), false, 'provider API key must not be hardcoded in gateway source')
  var sendTemplateStart = server.indexOf("if (p === '/api/send-template' && req.method === 'POST')")
  assert.ok(sendTemplateStart >= 0)
  var sendTemplateWindow = server.slice(sendTemplateStart, sendTemplateStart + 700)
  assert.strictEqual(sendTemplateWindow.includes("Access-Control-Allow-Origin', '*'"), false, 'transactional email endpoint must not use wildcard CORS')

  console.log('CIA_PHASE16_GATEWAY_POLICY=PASS')
  console.log('AUTH_V3_TRANSACTIONAL_EMAIL=PASS')
  console.log('UNGOVERNED_MARKETING_PROVIDER_CALLS=0')
  console.log('LEGACY_2FA_PUBLIC_PROVIDER_PATH=RETIRED')
  console.log('PROVIDER_SECRETS_ENV_ONLY=PASS')
}

run().catch(function(err) {
  console.error('CIA_PHASE16_GATEWAY_POLICY=FAIL', err && err.message ? err.message : err)
  process.exit(1)
})
