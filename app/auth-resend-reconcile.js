'use strict'

const https = require('https')

const DEFAULT_SB_URL = 'https://ituyqwstonmhnfshnaqz.supabase.co'
const SYNC_TIMEOUT_MS = 1500
const RETRY_DELAY_MS = 30000

function requestJson(urlString, options, body) {
  return new Promise(function(resolve, reject) {
    var url = new URL(urlString)
    var payload = body == null ? null : Buffer.from(JSON.stringify(body))
    var headers = Object.assign({}, options && options.headers ? options.headers : {})
    if (payload) {
      headers['Content-Type'] = headers['Content-Type'] || 'application/json'
      headers['Content-Length'] = payload.length
    }
    var req = https.request({
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname + url.search,
      method: (options && options.method) || 'GET',
      headers: headers,
      timeout: (options && options.timeout) || SYNC_TIMEOUT_MS
    }, function(r) {
      var chunks = []
      r.on('data', function(c) { chunks.push(c) })
      r.on('end', function() {
        var text = Buffer.concat(chunks).toString('utf8')
        var parsed = null
        if (text) {
          try { parsed = JSON.parse(text) } catch (_) { parsed = null }
        }
        resolve({ status: r.statusCode || 0, body: parsed })
      })
    })
    req.on('timeout', function() { req.destroy(new Error('AUTH_RESEND_SYNC_TIMEOUT')) })
    req.on('error', reject)
    if (payload) req.write(payload)
    req.end()
  })
}

function createResendVaultReconciler(config) {
  config = config || {}
  var sbUrl = String(config.supabaseUrl || process.env.SUPABASE_URL || DEFAULT_SB_URL).replace(/\/$/, '')
  var serviceKey = String(config.serviceRoleKey != null ? config.serviceRoleKey : (process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.service_role || ''))
  var resendKey = String(config.resendApiKey != null ? config.resendApiKey : (process.env.RESEND_API_KEY || ''))
  var requester = config.requestJson || requestJson
  var retryDelayMs = Number(config.retryDelayMs || RETRY_DELAY_MS)
  var retryTimer = null

  function headers() {
    var out = {
      apikey: serviceKey,
      'Content-Type': 'application/json',
      'User-Agent': 'AscendaOS-Auth-Resend-Reconcile/1.1'
    }
    if (!/^sb_(?:secret|publishable)_/.test(serviceKey)) out.Authorization = 'Bearer ' + serviceKey
    return out
  }

  function transientStatus(status) {
    var n = Number(status || 0)
    return n === 0 || n === 408 || n === 429 || n >= 500
  }

  function scheduleRetry() {
    if (retryTimer || !Number.isFinite(retryDelayMs) || retryDelayMs <= 0) return
    retryTimer = setTimeout(function() {
      retryTimer = null
      reconcile({ background: true }).catch(function() {})
    }, retryDelayMs)
    if (retryTimer && typeof retryTimer.unref === 'function') retryTimer.unref()
  }

  function deferred(code, upstreamStatus) {
    scheduleRetry()
    return {
      ok: true,
      status: 200,
      code: 'AUTH_RESEND_SYNC_DEFERRED',
      degraded: true,
      sync_reason: code,
      upstream_status: upstreamStatus || null
    }
  }

  async function reconcile() {
    if (serviceKey.length <= 20) return { ok: false, status: 503, code: 'AUTH_SERVICE_ROLE_NOT_CONFIGURED' }
    if (resendKey.length <= 10) return { ok: false, status: 503, code: 'AUTH_RESEND_KEY_NOT_CONFIGURED' }

    var lookup
    try {
      lookup = await requester(
        sbUrl + '/rest/v1/aos_integration_secrets_v1?select=integration_id&tipo=ilike.resend&limit=2',
        { method: 'GET', headers: headers(), timeout: SYNC_TIMEOUT_MS },
        null
      )
    } catch (_) {
      return deferred('AUTH_RESEND_VAULT_LOOKUP_TRANSPORT_FAILED', null)
    }
    if (lookup.status < 200 || lookup.status >= 300) {
      if (transientStatus(lookup.status)) return deferred('AUTH_RESEND_VAULT_LOOKUP_FAILED', lookup.status)
      return { ok: false, status: 503, code: 'AUTH_RESEND_VAULT_LOOKUP_FAILED', upstream_status: lookup.status || null }
    }

    var rows = Array.isArray(lookup.body) ? lookup.body : []
    if (rows.length !== 1 || !rows[0] || !rows[0].integration_id) {
      return { ok: false, status: 503, code: rows.length > 1 ? 'AUTH_RESEND_VAULT_AMBIGUOUS' : 'AUTH_RESEND_VAULT_ROW_MISSING' }
    }

    var integrationId = String(rows[0].integration_id)
    var updated
    try {
      updated = await requester(
        sbUrl + '/rest/v1/aos_integration_secrets_v1?integration_id=eq.' + encodeURIComponent(integrationId),
        { method: 'PATCH', headers: headers(), timeout: SYNC_TIMEOUT_MS },
        { api_key: resendKey, updated_at: new Date().toISOString() }
      )
    } catch (_) {
      return deferred('AUTH_RESEND_VAULT_UPDATE_TRANSPORT_FAILED', null)
    }
    if (updated.status < 200 || updated.status >= 300) {
      if (transientStatus(updated.status)) return deferred('AUTH_RESEND_VAULT_UPDATE_FAILED', updated.status)
      return { ok: false, status: 503, code: 'AUTH_RESEND_VAULT_UPDATE_FAILED', upstream_status: updated.status || null }
    }

    return { ok: true, status: 200, code: 'AUTH_RESEND_VAULT_RECONCILED', degraded: false }
  }

  return {
    reconcile: reconcile,
    configured: function() {
      return { service_role_configured: serviceKey.length > 20, resend_key_configured: resendKey.length > 10 }
    }
  }
}

module.exports = { createResendVaultReconciler: createResendVaultReconciler }
