'use strict'

const https = require('https')

const DEFAULT_SB_URL = 'https://ituyqwstonmhnfshnaqz.supabase.co'
const CANARY_HEADER = 'F16_PROVIDER_CANARY_20260815'
const CANARY_CONFIRM = 'RUN_FIXED_RESEND_SIMULATOR_CANARY'
const CANARY_TO = 'delivered+ascenda-f16-20260815@resend.dev'
const CANARY_SUBJECT = 'ASCENDA F16 governed provider canary'
const CANARY_IDEMPOTENCY_KEY = 'ascenda-f16-provider-canary-20260815-v2'
const PROD_WEBHOOK_URL = 'https://ascenda-os-production.up.railway.app/api/resend-webhook'

function jsonResponse(res, status, body) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff'
  })
  res.end(JSON.stringify(body))
}

function readRawBody(req, maxBytes) {
  maxBytes = maxBytes || 4096
  return new Promise(function(resolve, reject) {
    var chunks = []
    var total = 0
    req.on('data', function(chunk) {
      total += chunk.length
      if (total > maxBytes) return reject(new Error('BODY_TOO_LARGE'))
      chunks.push(chunk)
    })
    req.on('end', function() { resolve(Buffer.concat(chunks)) })
    req.on('error', reject)
  })
}

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
      timeout: (options && options.timeout) || 15000
    }, function(r) {
      var chunks = []
      r.on('data', function(c) { chunks.push(c) })
      r.on('end', function() {
        var text = Buffer.concat(chunks).toString('utf8')
        var parsed = null
        if (text) {
          try { parsed = JSON.parse(text) } catch (_) { parsed = { raw: text.slice(0, 1000) } }
        }
        resolve({ status: r.statusCode || 0, body: parsed, text: text })
      })
    })
    req.on('timeout', function() { req.destroy(new Error('UPSTREAM_TIMEOUT')) })
    req.on('error', reject)
    if (payload) req.write(payload)
    req.end()
  })
}

function requestRaw(urlString, headers, rawBody) {
  return new Promise(function(resolve, reject) {
    var url = new URL(urlString)
    var payload = Buffer.from(String(rawBody || ''), 'utf8')
    var h = Object.assign({}, headers || {})
    h['Content-Type'] = h['Content-Type'] || 'application/json'
    h['Content-Length'] = payload.length
    var req = https.request({
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname + url.search,
      method: 'POST',
      headers: h,
      timeout: 15000
    }, function(r) {
      var chunks = []
      r.on('data', function(c) { chunks.push(c) })
      r.on('end', function() {
        var text = Buffer.concat(chunks).toString('utf8')
        var parsed = null
        if (text) {
          try { parsed = JSON.parse(text) } catch (_) { parsed = { raw: text.slice(0, 1000) } }
        }
        resolve({ status: r.statusCode || 0, body: parsed, text: text })
      })
    })
    req.on('timeout', function() { req.destroy(new Error('UPSTREAM_TIMEOUT')) })
    req.on('error', reject)
    req.write(payload)
    req.end()
  })
}

function createLiveCanary(config) {
  config = config || {}
  var sbUrl = String(config.supabaseUrl || process.env.SUPABASE_URL || DEFAULT_SB_URL).replace(/\/$/, '')
  var serviceKey = String(config.serviceRoleKey != null ? config.serviceRoleKey : (process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.service_role || ''))
  var resendKey = String(config.resendApiKey != null ? config.resendApiKey : (process.env.RESEND_API_KEY || ''))
  var requester = config.requestJson || requestJson
  var rawRequester = config.requestRaw || requestRaw

  function supabase(path, method, body) {
    if (!serviceKey) return Promise.resolve({ status: 503, body: { error: 'SERVICE_ROLE_NOT_CONFIGURED' } })
    return requester(sbUrl + path, {
      method: method || 'GET',
      headers: { apikey: serviceKey, Authorization: 'Bearer ' + serviceKey },
      timeout: 15000
    }, body)
  }

  function rpc(name, params) {
    return supabase('/rest/v1/rpc/' + encodeURIComponent(name), 'POST', params || {})
  }

  async function markGate(gate, evidence) {
    var out = await rpc('aos_cia_email_release_mark_v1', {
      p_gate: gate,
      p_value: true,
      p_evidence: evidence
    })
    return out.status < 300 && out.body && out.body.ok === true
  }

  async function readiness() {
    var out = await rpc('aos_cia_email_f17_readiness_v1', {})
    if (out.status >= 300 || !out.body || out.body.ok !== true || !out.body.release_gates) return null
    return out.body
  }

  function parseCanaryEvent(ctx) {
    if (!ctx || !ctx.rawBody || !ctx.messageId || !ctx.eventId) return null
    var event
    try { event = JSON.parse(String(ctx.rawBody)) } catch (_) { return null }
    var data = event && event.data && typeof event.data === 'object' ? event.data : {}
    var recipients = Array.isArray(data.to) ? data.to.map(function(v) { return String(v).toLowerCase() }) : []
    var exact = String(event.type || '') === 'email.delivered' &&
      recipients.length === 1 &&
      recipients[0] === CANARY_TO.toLowerCase() &&
      String(data.subject || '') === CANARY_SUBJECT &&
      String(data.email_id || '') === String(ctx.messageId)
    return exact ? event : null
  }

  async function handleCanary(req, res) {
    if (req.method !== 'POST') return jsonResponse(res, 405, { ok: false, error: 'METHOD_NOT_ALLOWED' })
    if (String(req.headers['x-ascenda-f16-canary'] || '') !== CANARY_HEADER) return jsonResponse(res, 404, { ok: false, error: 'NOT_FOUND' })
    if (!serviceKey || !resendKey) return jsonResponse(res, 503, { ok: false, error: 'CANARY_NOT_CONFIGURED' })
    try {
      var raw = await readRawBody(req)
      var body
      try { body = JSON.parse(raw.toString('utf8') || '{}') } catch (_) { return jsonResponse(res, 400, { ok: false, error: 'INVALID_JSON' }) }
      if (body.confirm !== CANARY_CONFIRM) return jsonResponse(res, 400, { ok: false, error: 'CANARY_CONFIRMATION_REQUIRED' })

      var provider = await requester('https://api.resend.com/emails', {
        method: 'POST',
        timeout: 15000,
        headers: {
          Authorization: 'Bearer ' + resendKey,
          'Content-Type': 'application/json',
          'Idempotency-Key': CANARY_IDEMPOTENCY_KEY
        }
      }, {
        from: String(process.env.RESEND_FROM_EMAIL || 'Clinica Zi Vital <info@zivital.pe>'),
        to: [CANARY_TO],
        subject: CANARY_SUBJECT,
        html: '<p>ASCENDA F16 provider canary. Synthetic Resend simulator only.</p>'
      })
      var providerId = provider.body && provider.body.id ? String(provider.body.id) : ''
      if (!(provider.status >= 200 && provider.status < 300 && providerId)) {
        return jsonResponse(res, 502, { ok: false, error: 'PROVIDER_CANARY_REJECTED', provider_status: provider.status || 0 })
      }

      var marked = await markGate(
        'PROVIDER_CONFIGURED',
        'Resend fixed simulator canary accepted by provider; provider_message_id=' + providerId
      )
      if (!marked) return jsonResponse(res, 500, { ok: false, error: 'PROVIDER_GATE_WRITE_FAILED' })

      return jsonResponse(res, 200, {
        ok: true,
        state: 'PROVIDER_ACCEPTED',
        provider_message_id: providerId,
        recipient: CANARY_TO
      })
    } catch (_) {
      return jsonResponse(res, 500, { ok: false, error: 'CANARY_ERROR' })
    }
  }

  async function handleReplay(req, res) {
    return jsonResponse(res, 410, { ok: false, error: 'REPLAY_ROUTE_RETIRED' })
  }

  async function handleSignedWebhookCanary(ctx) {
    var event = parseCanaryEvent(ctx)
    if (!event) return null
    if (!serviceKey) return { handled: true, status: 503, body: { ok: false, error: 'CANARY_NOT_CONFIGURED' } }

    var current = await readiness()
    if (!current) return { handled: true, status: 500, body: { ok: false, error: 'CANARY_READINESS_UNAVAILABLE' } }
    var gates = current.release_gates || {}

    if (gates.canary_passed === true) {
      return { handled: true, status: 200, body: { ok: true, canary: true, idempotent: true, state: 'CANARY_ALREADY_CERTIFIED' } }
    }

    if (gates.webhook_verified === true) {
      var replayMarked = await markGate(
        'CANARY_PASSED',
        'Exact Resend Svix-signed email.delivered replay re-verified byte-for-byte; provider_event_id=' + String(ctx.eventId)
      )
      if (!replayMarked) return { handled: true, status: 500, body: { ok: false, error: 'CANARY_GATE_WRITE_FAILED' } }
      return { handled: true, status: 200, body: { ok: true, canary: true, idempotent: true, state: 'SIGNED_WEBHOOK_REPLAY_DEDUPED' } }
    }

    var verifiedMarked = await markGate(
      'WEBHOOK_VERIFIED',
      'Real Resend Svix-signed email.delivered accepted for fixed simulator recipient; provider_event_id=' + String(ctx.eventId)
    )
    if (!verifiedMarked) return { handled: true, status: 500, body: { ok: false, error: 'WEBHOOK_GATE_WRITE_FAILED' } }

    var replay = await rawRequester(PROD_WEBHOOK_URL, {
      'svix-id': String(ctx.eventId),
      'svix-timestamp': String(ctx.timestamp || ''),
      'svix-signature': String(ctx.signature || ''),
      'Content-Type': 'application/json'
    }, String(ctx.rawBody))

    if (replay.status !== 200 || !replay.body || replay.body.ok !== true || replay.body.idempotent !== true || replay.body.state !== 'SIGNED_WEBHOOK_REPLAY_DEDUPED') {
      return { handled: true, status: 500, body: { ok: false, error: 'SIGNED_WEBHOOK_REPLAY_FAILED', replay_status: replay.status || 0 } }
    }

    return { handled: true, status: 200, body: { ok: true, canary: true, idempotent: false, state: 'SIGNED_WEBHOOK_AND_REPLAY_CERTIFIED' } }
  }

  return {
    handleCanary: handleCanary,
    handleReplay: handleReplay,
    handleSignedWebhookCanary: handleSignedWebhookCanary
  }
}

module.exports = {
  createLiveCanary: createLiveCanary,
  CANARY_HEADER: CANARY_HEADER,
  CANARY_CONFIRM: CANARY_CONFIRM,
  CANARY_TO: CANARY_TO,
  CANARY_SUBJECT: CANARY_SUBJECT
}
