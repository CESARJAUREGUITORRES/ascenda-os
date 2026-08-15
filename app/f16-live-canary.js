'use strict'

const https = require('https')

const DEFAULT_SB_URL = 'https://ituyqwstonmhnfshnaqz.supabase.co'
const CANARY_HEADER = 'F16_PROVIDER_CANARY_20260815'
const CANARY_CONFIRM = 'RUN_FIXED_RESEND_SIMULATOR_CANARY'
const REPLAY_CONFIRM = 'REPLAY_CAPTURED_SIGNED_WEBHOOK'
const CANARY_TO = 'delivered+ascenda-f16-20260815@resend.dev'
const CANARY_IDEMPOTENCY_KEY = 'ascenda-f16-provider-canary-20260815-v1'
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

  function supabase(path, method, body, prefer) {
    if (!serviceKey) return Promise.resolve({ status: 503, body: { error: 'SERVICE_ROLE_NOT_CONFIGURED' } })
    var headers = { apikey: serviceKey, Authorization: 'Bearer ' + serviceKey }
    if (prefer) headers.Prefer = prefer
    return requester(sbUrl + path, { method: method || 'GET', headers: headers, timeout: 15000 }, body)
  }

  function rpc(name, params) {
    return supabase('/rest/v1/rpc/' + encodeURIComponent(name), 'POST', params || {})
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
        method: 'POST', timeout: 15000,
        headers: {
          Authorization: 'Bearer ' + resendKey,
          'Content-Type': 'application/json',
          'Idempotency-Key': CANARY_IDEMPOTENCY_KEY
        }
      }, {
        from: String(process.env.RESEND_FROM_EMAIL || 'Clinica Zi Vital <info@zivital.pe>'),
        to: [CANARY_TO],
        subject: 'ASCENDA F16 governed provider canary',
        html: '<p>ASCENDA F16 provider canary. Synthetic Resend simulator only.</p>'
      })
      var providerId = provider.body && provider.body.id ? String(provider.body.id) : ''
      if (!(provider.status >= 200 && provider.status < 300 && providerId)) {
        return jsonResponse(res, 502, { ok: false, error: 'PROVIDER_CANARY_REJECTED', provider_status: provider.status || 0 })
      }

      var insert = await supabase('/rest/v1/aos_cia_email_canary_evidence_temp?on_conflict=provider_message_id', 'POST', {
        provider_message_id: providerId,
        provider_accepted_at: new Date().toISOString()
      }, 'resolution=merge-duplicates,return=minimal')
      if (insert.status >= 300) return jsonResponse(res, 500, { ok: false, error: 'CANARY_EVIDENCE_WRITE_FAILED' })

      var marked = await rpc('aos_cia_email_release_mark_v1', {
        p_gate: 'PROVIDER_CONFIGURED', p_value: true,
        p_evidence: 'Resend simulator canary accepted by provider; provider_message_id=' + providerId
      })
      if (marked.status >= 300 || !marked.body || marked.body.ok !== true) return jsonResponse(res, 500, { ok: false, error: 'CANARY_RELEASE_MARK_FAILED' })

      return jsonResponse(res, 200, { ok: true, state: 'PROVIDER_ACCEPTED', provider_message_id: providerId, recipient: CANARY_TO })
    } catch (_) {
      return jsonResponse(res, 500, { ok: false, error: 'CANARY_ERROR' })
    }
  }

  async function handleReplay(req, res) {
    if (req.method !== 'POST') return jsonResponse(res, 405, { ok: false, error: 'METHOD_NOT_ALLOWED' })
    if (String(req.headers['x-ascenda-f16-canary'] || '') !== CANARY_HEADER) return jsonResponse(res, 404, { ok: false, error: 'NOT_FOUND' })
    if (!serviceKey) return jsonResponse(res, 503, { ok: false, error: 'CANARY_NOT_CONFIGURED' })
    try {
      var raw = await readRawBody(req)
      var body
      try { body = JSON.parse(raw.toString('utf8') || '{}') } catch (_) { return jsonResponse(res, 400, { ok: false, error: 'INVALID_JSON' }) }
      if (body.confirm !== REPLAY_CONFIRM) return jsonResponse(res, 400, { ok: false, error: 'REPLAY_CONFIRMATION_REQUIRED' })

      var lookup = await supabase('/rest/v1/aos_cia_email_canary_evidence_temp?select=provider_message_id,provider_event_id,event_type,svix_timestamp,svix_signature,raw_body,replay_count&provider_event_id=not.is.null&order=webhook_seen_at.desc&limit=1', 'GET')
      var row = lookup.status < 300 && Array.isArray(lookup.body) ? lookup.body[0] : null
      if (!row || !row.provider_event_id || !row.svix_timestamp || !row.svix_signature || !row.raw_body) {
        return jsonResponse(res, 409, { ok: false, error: 'SIGNED_CANARY_NOT_CAPTURED' })
      }
      if (String(row.event_type || '') !== 'email.delivered') return jsonResponse(res, 409, { ok: false, error: 'DELIVERED_CANARY_NOT_CAPTURED' })
      var age = Math.abs(Math.floor(Date.now() / 1000) - Number(row.svix_timestamp))
      if (!Number.isFinite(age) || age > 240) return jsonResponse(res, 409, { ok: false, error: 'SIGNED_CANARY_REPLAY_WINDOW_EXPIRED' })

      var replay = await rawRequester(PROD_WEBHOOK_URL, {
        'svix-id': String(row.provider_event_id),
        'svix-timestamp': String(row.svix_timestamp),
        'svix-signature': String(row.svix_signature),
        'Content-Type': 'application/json'
      }, String(row.raw_body))
      if (replay.status !== 200 || !replay.body || replay.body.ok !== true || replay.body.idempotent !== true) {
        return jsonResponse(res, 502, { ok: false, error: 'SIGNED_WEBHOOK_REPLAY_FAILED', replay_status: replay.status || 0 })
      }
      return jsonResponse(res, 200, { ok: true, state: 'SIGNED_WEBHOOK_REPLAY_DEDUPED', provider_event_id: String(row.provider_event_id) })
    } catch (_) {
      return jsonResponse(res, 500, { ok: false, error: 'REPLAY_ERROR' })
    }
  }

  async function handleSignedWebhookCanary(ctx) {
    if (!serviceKey || !ctx || !ctx.messageId) return null
    var lookup = await supabase('/rest/v1/aos_cia_email_canary_evidence_temp?select=provider_message_id,provider_event_id,event_type,replay_count&provider_message_id=eq.' + encodeURIComponent(String(ctx.messageId)) + '&limit=1', 'GET')
    var row = lookup.status < 300 && Array.isArray(lookup.body) ? lookup.body[0] : null
    if (!row) return null

    if (String(ctx.eventType || '') !== 'email.delivered') {
      return { handled: true, status: 200, body: { ok: true, canary: true, ignored: 'WAITING_FOR_DELIVERED' } }
    }

    if (row.provider_event_id && String(row.provider_event_id) === String(ctx.eventId)) {
      var nextReplay = Number(row.replay_count || 0) + 1
      await supabase('/rest/v1/aos_cia_email_canary_evidence_temp?provider_message_id=eq.' + encodeURIComponent(String(ctx.messageId)), 'PATCH', {
        replay_count: nextReplay,
        replay_seen_at: new Date().toISOString()
      }, 'return=minimal')
      await rpc('aos_cia_email_release_mark_v1', {
        p_gate: 'CANARY_PASSED', p_value: true,
        p_evidence: 'Resend provider accepted + signed email.delivered + exact Svix replay deduplicated; provider_event_id=' + String(ctx.eventId)
      })
      return { handled: true, status: 200, body: { ok: true, canary: true, idempotent: true } }
    }

    if (row.provider_event_id) {
      return { handled: true, status: 200, body: { ok: true, canary: true, ignored: 'ADDITIONAL_CANARY_EVENT' } }
    }

    var patch = await supabase('/rest/v1/aos_cia_email_canary_evidence_temp?provider_message_id=eq.' + encodeURIComponent(String(ctx.messageId)), 'PATCH', {
      provider_event_id: String(ctx.eventId),
      event_type: String(ctx.eventType),
      svix_timestamp: String(ctx.timestamp || ''),
      svix_signature: String(ctx.signature || '').slice(0, 2000),
      raw_body: String(ctx.rawBody || '').slice(0, 20000),
      webhook_seen_at: new Date().toISOString()
    }, 'return=minimal')
    if (patch.status >= 300) return { handled: true, status: 500, body: { ok: false, error: 'CANARY_WEBHOOK_EVIDENCE_FAILED' } }

    await rpc('aos_cia_email_release_mark_v1', {
      p_gate: 'WEBHOOK_VERIFIED', p_value: true,
      p_evidence: 'Real Resend signed email.delivered accepted after Svix verification; provider_event_id=' + String(ctx.eventId)
    })
    return { handled: true, status: 200, body: { ok: true, canary: true, idempotent: false } }
  }

  return { handleCanary: handleCanary, handleReplay: handleReplay, handleSignedWebhookCanary: handleSignedWebhookCanary }
}

module.exports = {
  createLiveCanary: createLiveCanary,
  CANARY_HEADER: CANARY_HEADER,
  CANARY_CONFIRM: CANARY_CONFIRM,
  REPLAY_CONFIRM: REPLAY_CONFIRM,
  CANARY_TO: CANARY_TO
}
