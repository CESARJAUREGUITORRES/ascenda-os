'use strict'

const crypto = require('crypto')
const https = require('https')

const DEFAULT_SB_URL = 'https://ituyqwstonmhnfshnaqz.supabase.co'
const MAX_BODY_BYTES = 1024 * 1024
const WEBHOOK_MAX_SKEW_SECONDS = 300

function jsonResponse(res, status, body) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff'
  })
  res.end(JSON.stringify(body))
}

function readRawBody(req, maxBytes) {
  maxBytes = maxBytes || MAX_BODY_BYTES
  return new Promise(function(resolve, reject) {
    var chunks = []
    var total = 0
    req.on('data', function(chunk) {
      total += chunk.length
      if (total > maxBytes) {
        reject(new Error('BODY_TOO_LARGE'))
        try { req.destroy() } catch (_) {}
        return
      }
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
        resolve({ status: r.statusCode || 0, headers: r.headers, body: parsed, text: text })
      })
    })
    req.on('timeout', function() { req.destroy(new Error('UPSTREAM_TIMEOUT')) })
    req.on('error', reject)
    if (payload) req.write(payload)
    req.end()
  })
}

function base64Secret(secret) {
  var s = String(secret || '')
  if (s.indexOf('whsec_') === 0) s = s.slice(6)
  try { return Buffer.from(s, 'base64') } catch (_) { return Buffer.from('') }
}

function timingSafeBase64Equal(a, b) {
  try {
    var aa = Buffer.from(String(a || ''), 'base64')
    var bb = Buffer.from(String(b || ''), 'base64')
    return aa.length > 0 && aa.length === bb.length && crypto.timingSafeEqual(aa, bb)
  } catch (_) { return false }
}

function verifySvixSignature(rawBody, headers, secret, nowSeconds) {
  var eventId = String(headers['svix-id'] || headers['Svix-Id'] || '')
  var timestamp = String(headers['svix-timestamp'] || headers['Svix-Timestamp'] || '')
  var signatureHeader = String(headers['svix-signature'] || headers['Svix-Signature'] || '')
  if (!eventId || !timestamp || !signatureHeader || !secret) return { ok: false, error: 'WEBHOOK_SIGNATURE_REQUIRED' }

  var ts = Number(timestamp)
  var now = Number(nowSeconds == null ? Math.floor(Date.now() / 1000) : nowSeconds)
  if (!Number.isFinite(ts) || Math.abs(now - ts) > WEBHOOK_MAX_SKEW_SECONDS) return { ok: false, error: 'WEBHOOK_TIMESTAMP_INVALID' }

  var key = base64Secret(secret)
  if (!key.length) return { ok: false, error: 'WEBHOOK_SECRET_INVALID' }
  var signed = Buffer.concat([Buffer.from(eventId + '.' + timestamp + '.'), Buffer.isBuffer(rawBody) ? rawBody : Buffer.from(rawBody || '')])
  var expected = crypto.createHmac('sha256', key).update(signed).digest('base64')
  var candidates = signatureHeader.split(/\s+/).map(function(v) {
    var parts = v.split(',')
    return parts.length === 2 && parts[0] === 'v1' ? parts[1] : ''
  }).filter(Boolean)
  var valid = candidates.some(function(candidate) { return timingSafeBase64Equal(candidate, expected) })
  return valid ? { ok: true, eventId: eventId, timestamp: ts } : { ok: false, error: 'WEBHOOK_SIGNATURE_INVALID' }
}

function htmlEscape(value) {
  return String(value == null ? '' : value)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;')
}

function renderTemplate(template, context, keys, htmlMode) {
  var out = String(template || '')
  var ctx = context && typeof context === 'object' && !Array.isArray(context) ? context : {}
  var required = Array.isArray(keys) ? keys : []
  for (var i = 0; i < required.length; i++) {
    var key = String(required[i] || '')
    if (!key || !Object.prototype.hasOwnProperty.call(ctx, key)) return { ok: false, error: 'RENDER_CONTEXT_MISSING', key: key }
    var value = htmlMode ? htmlEscape(ctx[key]) : String(ctx[key] == null ? '' : ctx[key]).replace(/[\r\n]+/g, ' ')
    out = out.split('{{' + key + '}}').join(value)
  }
  if (/\{\{[A-Za-z0-9_]+\}\}/.test(out)) return { ok: false, error: 'UNRESOLVED_TEMPLATE_VARIABLE' }
  return { ok: true, value: out }
}

function sha256(value) {
  return crypto.createHash('sha256').update(String(value || '')).digest('hex')
}

function validEmail(email) {
  var v = String(email || '').trim()
  return v.length <= 320 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v)
}

function safeLegacyQuery(query) {
  query = String(query || '')
  if (query.length > 2500 || /[\r\n\0]/.test(query)) return null
  var params = new URLSearchParams(query)
  var allowedControl = { select: true, order: true, limit: true, offset: true }
  for (const pair of params.entries()) {
    var name = pair[0]
    var value = pair[1]
    if (!allowedControl[name] && !/^[A-Za-z][A-Za-z0-9_]*$/.test(name)) return null
    if (value.length > 1500 || /(?:;|--|\/\*)/.test(value)) return null
  }
  return params.toString()
}

function createEmailGateway(config) {
  config = config || {}
  var sbUrl = String(config.supabaseUrl || process.env.SUPABASE_URL || DEFAULT_SB_URL).replace(/\/$/, '')
  var serviceKey = String(config.serviceRoleKey != null ? config.serviceRoleKey : (process.env.SUPABASE_SERVICE_ROLE_KEY || ''))
  var resendKey = String(config.resendApiKey != null ? config.resendApiKey : (process.env.RESEND_API_KEY || ''))
  var webhookSecret = String(config.webhookSecret != null ? config.webhookSecret : (process.env.RESEND_WEBHOOK_SECRET || ''))
  var requester = config.requestJson || requestJson

  function configured() {
    return {
      service_role_configured: serviceKey.length > 20,
      resend_key_configured: resendKey.length > 10,
      webhook_secret_configured: webhookSecret.length > 10
    }
  }

  function supabase(path, method, body, prefer) {
    if (!serviceKey) return Promise.resolve({ status: 503, body: { error: 'SERVICE_ROLE_NOT_CONFIGURED' } })
    var headers = { apikey: serviceKey, Authorization: 'Bearer ' + serviceKey }
    if (prefer) headers.Prefer = prefer
    return requester(sbUrl + path, { method: method || 'GET', headers: headers, timeout: 15000 }, body)
  }

  function rpc(name, params) {
    return supabase('/rest/v1/rpc/' + encodeURIComponent(name), 'POST', params || {})
  }

  async function verifyAdmin(token) {
    if (!serviceKey) return { ok: false, status: 503, error: 'SERVICE_ROLE_NOT_CONFIGURED' }
    if (!token || String(token).length < 32) return { ok: false, status: 401, error: 'UNAUTHORIZED' }
    var result = await rpc('aos_cia_verify_admin_session_v1', { p_token: String(token) })
    var body = result.body
    if (result.status >= 300 || !body || body.ok !== true || !body.user_id) return { ok: false, status: 401, error: 'UNAUTHORIZED' }
    return { ok: true, user_id: body.user_id, usuario: body.usuario || '' }
  }

  async function governed(token, action, payload) {
    var result = await rpc('aos_cia_email_admin_gateway_v2', { p_token: String(token), p_action: String(action || ''), p_payload: payload || {} })
    if (result.status >= 300) return { ok: false, error: 'GOVERNED_RPC_FAILED', status: result.status }
    return result.body || { ok: false, error: 'EMPTY_GOVERNED_RESPONSE' }
  }

  async function sendResend(payload, idempotencyKey) {
    if (!resendKey) return { ok: false, status: 503, error: 'PROVIDER_NOT_CONFIGURED' }
    var result = await requester('https://api.resend.com/emails', {
      method: 'POST',
      timeout: 15000,
      headers: {
        Authorization: 'Bearer ' + resendKey,
        'Content-Type': 'application/json',
        'Idempotency-Key': String(idempotencyKey || '').slice(0, 256)
      }
    }, payload)
    var id = result.body && result.body.id ? String(result.body.id) : ''
    if (result.status >= 200 && result.status < 300 && id) return { ok: true, status: result.status, id: id }
    return { ok: false, status: result.status || 502, error: 'PROVIDER_REJECTED', provider_code: result.body && (result.body.name || result.body.statusCode) ? String(result.body.name || result.body.statusCode).slice(0, 100) : '' }
  }

  var legacyReadTables = new Set(['aos_configuracion','aos_email_plantillas','aos_email_flujos','aos_plantillas_mensajes','aos_email_envios'])
  var legacyRpcNames = new Set(['aos_email_buscar_paciente','aos_email_historial_paciente','aos_email_dashboard'])
  var legacyPatchFields = {
    aos_email_flujos: new Set(['activo','updated_at']),
    aos_email_plantillas: new Set(['nombre','asunto','html_body','updated_at']),
    aos_plantillas_mensajes: new Set(['nombre','cuerpo','sede','updated_at'])
  }

  async function legacyRead(table, query) {
    if (!legacyReadTables.has(table)) return { ok: false, status: 403, error: 'LEGACY_TABLE_NOT_ALLOWED' }
    var clean = safeLegacyQuery(query)
    if (clean == null) return { ok: false, status: 400, error: 'INVALID_LEGACY_QUERY' }
    var result = await supabase('/rest/v1/' + table + (clean ? '?' + clean : ''), 'GET')
    return result.status < 300 ? { ok: true, data: result.body || [] } : { ok: false, status: result.status, error: 'LEGACY_READ_FAILED' }
  }

  async function legacyRpc(name, params) {
    if (!legacyRpcNames.has(name)) return { ok: false, status: 403, error: 'LEGACY_RPC_NOT_ALLOWED' }
    var result = await rpc(name, params || {})
    return result.status < 300 ? { ok: true, data: result.body } : { ok: false, status: result.status, error: 'LEGACY_RPC_FAILED' }
  }

  async function legacyPatch(table, id, changes) {
    var allowed = legacyPatchFields[table]
    if (!allowed || !id) return { ok: false, status: 403, error: 'LEGACY_PATCH_NOT_ALLOWED' }
    var clean = {}
    Object.keys(changes || {}).forEach(function(k) { if (allowed.has(k)) clean[k] = changes[k] })
    if (!Object.keys(clean).length || Object.keys(clean).length !== Object.keys(changes || {}).length) return { ok: false, status: 400, error: 'INVALID_PATCH_FIELDS' }
    var result = await supabase('/rest/v1/' + table + '?id=eq.' + encodeURIComponent(String(id)), 'PATCH', clean, 'return=minimal')
    return result.status < 300 ? { ok: true } : { ok: false, status: result.status, error: 'LEGACY_PATCH_FAILED' }
  }

  async function legacySend(actor, payload) {
    var to = Array.isArray(payload.to) ? payload.to[0] : payload.to
    var subject = String(payload.subject || '').trim()
    var html = String(payload.html || '')
    var clientRequestId = String(payload.client_request_id || '')
    if (!validEmail(to) || !subject || subject.length > 998 || !html || html.length > 500000 || clientRequestId.length < 8) {
      return { ok: false, status: 400, error: 'INVALID_SEND_INTENT' }
    }
    var idempotencyKey = 'f16-legacy-' + sha256([actor.user_id,to,subject,payload.plantilla_id || '',clientRequestId].join('|'))
    var provider = await sendResend({
      from: String(process.env.RESEND_FROM_EMAIL || 'Clinica Zi Vital <info@zivital.pe>'),
      to: [String(to).trim()],
      subject: subject.replace(/[\r\n]+/g, ' '),
      html: html
    }, idempotencyKey)

    var log = {
      destinatario_email: String(to).trim(),
      destinatario_nombre: String(payload.nombre || '').slice(0, 200),
      destinatario_numero: String(payload.numero || '').slice(0, 80),
      plantilla_id: payload.plantilla_id || null,
      campania_id: payload.campania_id || null,
      flujo_id: payload.flujo_id || null,
      flujo_paso: payload.flujo_paso || null,
      asunto: subject,
      variables_usadas: payload.variables && typeof payload.variables === 'object' ? payload.variables : {},
      estado: provider.ok ? 'enviado' : 'error',
      resend_id: provider.ok ? provider.id : null,
      error_msg: provider.ok ? null : provider.error,
      enviado_at: provider.ok ? new Date().toISOString() : null
    }
    await supabase('/rest/v1/aos_email_envios', 'POST', log, 'return=minimal').catch(function() {})
    return provider.ok ? { ok: true, id: provider.id, idempotency_key: idempotencyKey } : { ok: false, status: provider.status, error: provider.error }
  }

  async function dispatchRequest(token, requestId) {
    var queued = await governed(token, 'QUEUE_REQUEST', { request_id: requestId })
    if (!queued || queued.ok !== true) return queued || { ok: false, error: 'QUEUE_FAILED' }

    var claimResult = await rpc('aos_cia_email_claim_dispatch_v2', { p_request_id: requestId })
    var claim = claimResult.body
    if (claimResult.status >= 300 || !claim || claim.ok !== true) return claim || { ok: false, error: 'DISPATCH_CLAIM_FAILED' }
    if (claim.send_allowed !== true) return claim

    var subject = renderTemplate(claim.subject_template, claim.render_context, claim.variable_keys, false)
    var html = renderTemplate(claim.html_template, claim.render_context, claim.variable_keys, true)
    if (!subject.ok || !html.ok) {
      await rpc('aos_cia_email_record_dispatch_result_v2', {
        p_request_id: requestId, p_accepted: false, p_provider: 'RESEND', p_provider_message_id: null,
        p_error_code: subject.error || html.error || 'RENDER_FAILED', p_payload: { stage: 'render' }
      })
      return { ok: false, error: subject.error || html.error || 'RENDER_FAILED' }
    }

    var provider = await sendResend({
      from: String(process.env.RESEND_FROM_EMAIL || 'Clinica Zi Vital <info@zivital.pe>'),
      to: [claim.recipient_email],
      subject: subject.value,
      html: html.value
    }, 'f16-' + claim.idempotency_key)

    var recorded = await rpc('aos_cia_email_record_dispatch_result_v2', {
      p_request_id: requestId,
      p_accepted: provider.ok,
      p_provider: 'RESEND',
      p_provider_message_id: provider.ok ? provider.id : null,
      p_error_code: provider.ok ? null : provider.error,
      p_payload: { provider_status: provider.status || null }
    })
    if (recorded.status >= 300 || !recorded.body || recorded.body.ok !== true) return { ok: false, error: 'DISPATCH_AUDIT_FAILED' }
    return provider.ok ? { ok: true, request_id: requestId, state: 'ACCEPTED', provider_message_id: provider.id } : { ok: false, error: provider.error || 'PROVIDER_REJECTED', state: 'FAILED' }
  }

  async function handleAdmin(req, res) {
    if (req.method === 'OPTIONS') return jsonResponse(res, 405, { ok: false, error: 'METHOD_NOT_ALLOWED' })
    if (req.method !== 'POST') return jsonResponse(res, 405, { ok: false, error: 'METHOD_NOT_ALLOWED' })
    try {
      var raw = await readRawBody(req)
      var body
      try { body = JSON.parse(raw.toString('utf8') || '{}') } catch (_) { return jsonResponse(res, 400, { ok: false, error: 'INVALID_JSON' }) }
      var token = String(req.headers['x-ascenda-session'] || body.token || '')
      var actor = await verifyAdmin(token)
      if (!actor.ok) return jsonResponse(res, actor.status || 401, { ok: false, error: actor.error })
      var action = String(body.action || '').toUpperCase()
      var payload = body.payload && typeof body.payload === 'object' ? body.payload : {}
      var out
      if (action === 'CONFIG_HEALTH') out = { ok: true, config: configured() }
      else if (action === 'GOVERNED') out = await governed(token, payload.action, payload.payload || {})
      else if (action === 'DISPATCH_REQUEST') out = await dispatchRequest(token, payload.request_id)
      else if (action === 'LEGACY_READ') out = await legacyRead(String(payload.table || ''), String(payload.query || ''))
      else if (action === 'LEGACY_RPC') out = await legacyRpc(String(payload.name || ''), payload.params || {})
      else if (action === 'LEGACY_PATCH') out = await legacyPatch(String(payload.table || ''), payload.id, payload.changes || {})
      else if (action === 'LEGACY_SEND') out = await legacySend(actor, payload)
      else out = { ok: false, status: 400, error: 'UNSUPPORTED_ACTION' }
      return jsonResponse(res, out && out.ok ? 200 : (out && out.status ? out.status : 400), out || { ok: false, error: 'EMPTY_RESPONSE' })
    } catch (e) {
      var code = e && e.message === 'BODY_TOO_LARGE' ? 413 : 500
      return jsonResponse(res, code, { ok: false, error: code === 413 ? 'BODY_TOO_LARGE' : 'EMAIL_GATEWAY_ERROR' })
    }
  }

  async function handleWebhook(req, res) {
    if (req.method !== 'POST') return jsonResponse(res, 405, { ok: false, error: 'METHOD_NOT_ALLOWED' })
    if (!webhookSecret || !serviceKey) return jsonResponse(res, 503, { ok: false, error: 'WEBHOOK_NOT_CONFIGURED' })
    try {
      var raw = await readRawBody(req)
      var verified = verifySvixSignature(raw, req.headers || {}, webhookSecret)
      if (!verified.ok) return jsonResponse(res, 401, { ok: false, error: verified.error })
      var event
      try { event = JSON.parse(raw.toString('utf8')) } catch (_) { return jsonResponse(res, 400, { ok: false, error: 'INVALID_JSON' }) }
      var data = event && event.data && typeof event.data === 'object' ? event.data : {}
      var messageId = String(data.email_id || data.id || '')
      var eventType = String(event.type || '')
      var occurredAt = event.created_at || new Date().toISOString()
      var ingest = await rpc('aos_cia_email_ingest_provider_event_v2', {
        p_provider_event_id: verified.eventId,
        p_provider_message_id: messageId,
        p_event_type: eventType,
        p_occurred_at: occurredAt,
        p_payload: { provider: 'RESEND', type: eventType }
      })
      if (ingest.status >= 300 || !ingest.body || ingest.body.ok !== true) {
        if (ingest.body && ingest.body.error === 'PROVIDER_MESSAGE_NOT_FOUND') return jsonResponse(res, 202, { ok: true, ignored: 'UNKNOWN_PROVIDER_MESSAGE' })
        return jsonResponse(res, 400, { ok: false, error: ingest.body && ingest.body.error ? ingest.body.error : 'WEBHOOK_INGEST_FAILED' })
      }
      return jsonResponse(res, 200, { ok: true, idempotent: ingest.body.idempotent === true })
    } catch (_) {
      return jsonResponse(res, 500, { ok: false, error: 'WEBHOOK_ERROR' })
    }
  }

  return {
    handleAdmin: handleAdmin,
    handleWebhook: handleWebhook,
    verifyAdmin: verifyAdmin,
    dispatchRequest: dispatchRequest,
    configured: configured
  }
}

module.exports = {
  createEmailGateway: createEmailGateway,
  verifySvixSignature: verifySvixSignature,
  renderTemplate: renderTemplate,
  safeLegacyQuery: safeLegacyQuery,
  htmlEscape: htmlEscape,
  sha256: sha256
}
