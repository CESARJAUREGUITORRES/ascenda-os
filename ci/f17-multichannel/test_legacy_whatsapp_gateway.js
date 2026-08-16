'use strict'

const assert = require('assert')
const { createLegacyWhatsAppGateway } = require('../../app/f17-whatsapp-legacy-gateway')

async function run() {
  var calls = []
  var gateway = createLegacyWhatsAppGateway({
    supabaseUrl: 'https://example.invalid',
    serviceRoleKey: 'service-role-test-value-long-enough',
    verifyApp: async function(token) {
      return token === 'valid-session-token-that-is-long-enough'
        ? { ok: true, user_id: 'synthetic-user', rol: 'ASESOR' }
        : { ok: false, status: 401, error: 'UNAUTHORIZED' }
    },
    requestJson: async function(url, options) {
      calls.push({ url: url, options: options })
      return {
        status: 200,
        body: [{ id: 'tpl-1', nombre: 'Synthetic', icono: 'x', color: '#fff', contexto: 'NO_CONTESTA', mensaje: 'synthetic-template-body', orden: 1 }]
      }
    }
  })

  var denied = await gateway.listTemplates('invalid')
  assert.strictEqual(denied.ok, false)
  assert.strictEqual(denied.status, 401)
  assert.strictEqual(calls.length, 0, 'unauthorized request must not touch Supabase')

  var allowed = await gateway.listTemplates('valid-session-token-that-is-long-enough')
  assert.strictEqual(allowed.ok, true)
  assert.strictEqual(allowed.templates.length, 1)
  assert.strictEqual(calls.length, 1)
  assert.ok(calls[0].url.includes('/rest/v1/aos_plantillas_whatsapp?'))
  assert.ok(calls[0].url.includes('activo=eq.true'))
  assert.ok(calls[0].url.includes('select=id,nombre,icono,color,contexto,mensaje,orden'))
  assert.strictEqual(calls[0].options.headers.apikey, 'service-role-test-value-long-enough')
  assert.strictEqual(allowed.templates[0].mensaje, 'synthetic-template-body')

  var missingConfig = createLegacyWhatsAppGateway({
    serviceRoleKey: '',
    verifyApp: async function() { return { ok: true, user_id: 'synthetic-user' } },
    requestJson: async function() { throw new Error('must not be called') }
  })
  var unavailable = await missingConfig.listTemplates('valid-session-token-that-is-long-enough')
  assert.strictEqual(unavailable.ok, false)
  assert.strictEqual(unavailable.status, 503)

  var upstreamFailure = createLegacyWhatsAppGateway({
    serviceRoleKey: 'service-role-test-value-long-enough',
    verifyApp: async function() { return { ok: true, user_id: 'synthetic-user' } },
    requestJson: async function() { return { status: 500, body: { error: 'synthetic' } }
  })
  var failed = await upstreamFailure.listTemplates('valid-session-token-that-is-long-enough')
  assert.strictEqual(failed.ok, false)
  assert.strictEqual(failed.status, 502)

  console.log('F17 legacy WhatsApp gateway contract: PASS')
}

run().catch(function(err) {
  console.error(err && err.stack ? err.stack : err)
  process.exit(1)
})
