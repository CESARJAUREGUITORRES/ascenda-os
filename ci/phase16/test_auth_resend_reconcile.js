'use strict'

const assert = require('assert')
const { createResendVaultReconciler } = require('../../app/auth-resend-reconcile')

async function run() {
  const syntheticResend = 'synthetic-resend-key-long-enough-for-contract'
  const syntheticService = 'synthetic-service-role-key-long-enough-for-contract'
  const integrationId = '00000000-0000-4000-8000-000000000777'
  const calls = []

  const reconciler = createResendVaultReconciler({
    supabaseUrl: 'https://synthetic.supabase.test',
    serviceRoleKey: syntheticService,
    resendApiKey: syntheticResend,
    requestJson: async function(url, options, body) {
      calls.push({ url, method: options.method, headers: options.headers, body })
      if (options.method === 'GET') {
        return { status: 200, body: [{ integration_id: integrationId }] }
      }
      if (options.method === 'PATCH') {
        return { status: 204, body: null }
      }
      throw new Error('unexpected method')
    }
  })

  const out = await reconciler.reconcile()
  assert.strictEqual(out.ok, true)
  assert.strictEqual(out.code, 'AUTH_RESEND_VAULT_RECONCILED')
  assert.strictEqual(calls.length, 2, 'reconcile must perform one lookup and one exact patch')
  assert.ok(calls.every(c => c.url.includes('/rest/v1/aos_integration_secrets_v1')), 'only private vault may be touched')
  assert.ok(calls.every(c => !c.url.includes('/rest/v1/aos_integraciones')), 'public integration catalog must never be touched')
  assert.strictEqual(calls[0].method, 'GET')
  assert.strictEqual(calls[1].method, 'PATCH')
  assert.ok(calls[1].url.includes('integration_id=eq.' + encodeURIComponent(integrationId)), 'patch must target exactly one integration id')
  assert.strictEqual(calls[1].body.api_key, syntheticResend, 'Railway/provider key must be mirrored into private vault')
  assert.ok(!JSON.stringify(out).includes(syntheticResend), 'secret must never be returned by reconciliation result')
  assert.ok(!JSON.stringify(out).includes(syntheticService), 'service role must never be returned by reconciliation result')

  let missingKeyCalls = 0
  const missingKey = createResendVaultReconciler({
    serviceRoleKey: syntheticService,
    resendApiKey: '',
    requestJson: async function() { missingKeyCalls++; return { status: 500, body: null } }
  })
  const missing = await missingKey.reconcile()
  assert.strictEqual(missing.ok, false)
  assert.strictEqual(missing.code, 'AUTH_RESEND_KEY_NOT_CONFIGURED')
  assert.strictEqual(missingKeyCalls, 0, 'missing provider key must fail before network access')

  let ambiguousPatches = 0
  const ambiguous = createResendVaultReconciler({
    serviceRoleKey: syntheticService,
    resendApiKey: syntheticResend,
    requestJson: async function(url, options) {
      if (options.method === 'GET') return { status: 200, body: [{ integration_id: integrationId }, { integration_id: '00000000-0000-4000-8000-000000000778' }] }
      ambiguousPatches++
      return { status: 204, body: null }
    }
  })
  const ambiguousOut = await ambiguous.reconcile()
  assert.strictEqual(ambiguousOut.ok, false)
  assert.strictEqual(ambiguousOut.code, 'AUTH_RESEND_VAULT_AMBIGUOUS')
  assert.strictEqual(ambiguousPatches, 0, 'ambiguous vault state must never mutate credentials')

  console.log('AUTH_RESEND_PRIVATE_VAULT_RECONCILE=PASS')
  console.log('AUTH_RESEND_PUBLIC_CATALOG_UNTOUCHED=PASS')
  console.log('AUTH_RESEND_SECRET_NON_DISCLOSURE=PASS')
  console.log('AUTH_RESEND_FAIL_CLOSED=PASS')
}

run().catch(function(err) {
  console.error('AUTH_RESEND_PRIVATE_VAULT_RECONCILE=FAIL', err && err.message ? err.message : err)
  process.exit(1)
})
