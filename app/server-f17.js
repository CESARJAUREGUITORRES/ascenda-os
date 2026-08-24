'use strict'

const http = require('http')
const https = require('https')
const { spawn } = require('child_process')
const wa = require('./wa-gateway')
const { createLegacyWhatsAppGateway } = require('./f17-whatsapp-legacy-gateway')
const { createF17WaAdapter } = require('./f17-wa-adapter')
const { createPushService } = require('./push-notifications-s14')

const EXTERNAL_PORT = parseInt(process.env.PORT || '4173', 10)
const INNER_PORT = EXTERNAL_PORT === 4217 ? 4218 : 4217
const SB_URL = String(process.env.SUPABASE_URL || 'https://ituyqwstonmhnfshnaqz.supabase.co').replace(/\/$/, '')
const SB_ANON_KEY = String(process.env.SUPABASE_ANON_KEY || '')
const SB_SERVICE_KEY = String(process.env.SUPABASE_SERVICE_ROLE_KEY || '')
const WA_CANARY_MODE = String(process.env.WA_CANARY_MODE || 'true')
const WA_CANARY_ALLOW_TO = String(process.env.WA_CANARY_ALLOW_TO || '')
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
let child = null
let notificationPumpTimer = null
let notificationPumpBusy = false
let notificationPumpIdleLevel = 0
const NOTIFICATION_PUMP_ACTIVE_MS = 4000
const NOTIFICATION_PUMP_IDLE_MS = [8000, 15000]

function parseJson(text) { try { return text ? JSON.parse(text) : null } catch (_) { return null } }
function writeJson(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'X-Ascenda-F17': 'multichannel-v1' })
  res.end(JSON.stringify(body))
}
function readRaw(req, maxBytes) {
  return new Promise(function(resolve, reject) {
    const chunks = []; let total = 0; let overflow = false
    req.on('data', function(c) { if (overflow) return; total += c.length; if (total > maxBytes) { overflow = true; return } chunks.push(Buffer.from(c)) })
    req.on('end', function() { if (overflow) return reject(Object.assign(new Error('PAYLOAD_TOO_LARGE'), { status: 413 })); resolve(Buffer.concat(chunks)) })
    req.on('error', reject)
  })
}

function requestSupabase(name, payload, service) {
  return new Promise(function(resolve, reject) {
    const key = service ? SB_SERVICE_KEY : SB_ANON_KEY
    if (!key) return reject(new Error(service ? 'SUPABASE_SERVICE_ROLE_NOT_CONFIGURED' : 'SUPABASE_ANON_KEY_NOT_CONFIGURED'))
    let url; try { url = new URL(SB_URL) } catch (e) { return reject(e) }
    const body = JSON.stringify(payload || {})
    const headers = { apikey: key, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body), 'User-Agent': 'AscendaOS-F17/1.4' }
    if (!/^sb_(?:secret|publishable)_/i.test(key)) headers.Authorization = 'Bearer ' + key
    const req = https.request({ hostname: url.hostname, port: url.port || 443, path: '/rest/v1/rpc/' + encodeURIComponent(name), method: 'POST', headers: headers, timeout: 12000 }, function(res) {
      let raw = ''
      res.on('data', function(chunk) { raw += chunk })
      res.on('end', function() {
        if ((res.statusCode || 500) < 200 || (res.statusCode || 500) >= 300) return reject(Object.assign(new Error('F17_RPC_UNAVAILABLE'), { status: 503, upstream_status: res.statusCode }))
        resolve(parseJson(raw))
      })
    })
    req.on('timeout', function() { req.destroy(new Error('F17_RPC_TIMEOUT')) })
    req.on('error', reject)
    req.write(body); req.end()
  })
}
const rpc = function(name, payload) { return requestSupabase(name, payload, false) }
const serviceRpc = function(name, payload) { return requestSupabase(name, payload, true) }

async function verifyApp(token, strong) {
  const t = String(token || '').trim()
  if (t.length < 32) return { ok: false, status: 401 }
  try {
    const actorId = await rpc('aos_app_actor_v3', { p_token: t, p_required_panel: strong ? 'admin-chats' : null, p_require_2fa: strong === true })
    return UUID_RE.test(String(actorId || '')) ? { ok: true, actor_id: actorId } : { ok: false, status: 403 }
  } catch (_) { return { ok: false, status: 503 } }
}

const gateway = createLegacyWhatsAppGateway({ supabaseUrl: SB_URL, serviceRoleKey: SB_SERVICE_KEY, verifyApp: function(token) { return verifyApp(token, false) } })
const f17wa = createF17WaAdapter({ serviceRpc: serviceRpc, canaryMode: WA_CANARY_MODE })
const push = createPushService({
  serviceRpc: serviceRpc,
  vapidSubject: process.env.AOS_PUSH_VAPID_SUBJECT || 'mailto:notifications@ascenda.local',
  logger: console
})

async function runNotificationPump() {
  if (notificationPumpBusy) return { busy: true }
  notificationPumpBusy = true
  try {
    const r = await push.dispatchPendingNotifications(25)
    if (r && (r.delivered || r.failed || r.partial)) console.log('[S15] notification push', r)
    return r || { ok: true, claimed: 0 }
  } catch (e) {
    console.error('[S15] notification pump fail-open', e && e.message || e)
    return { ok: false, error: true, claimed: 0 }
  } finally {
    notificationPumpBusy = false
  }
}
function notificationPumpDelay(result) {
  const didWork = !!(result && (Number(result.claimed || 0) > 0 || Number(result.delivered || 0) > 0 || Number(result.failed || 0) > 0 || Number(result.partial || 0) > 0))
  if (didWork) { notificationPumpIdleLevel = 0; return NOTIFICATION_PUMP_ACTIVE_MS }
  notificationPumpIdleLevel = Math.min(notificationPumpIdleLevel + 1, NOTIFICATION_PUMP_IDLE_MS.length)
  return NOTIFICATION_PUMP_IDLE_MS[notificationPumpIdleLevel - 1]
}
function scheduleNotificationPump(delay) {
  if (notificationPumpTimer) clearTimeout(notificationPumpTimer)
  notificationPumpTimer = setTimeout(function tick() {
    notificationPumpTimer = null
    runNotificationPump().then(function(result) {
      scheduleNotificationPump(notificationPumpDelay(result))
    }).catch(function() { scheduleNotificationPump(NOTIFICATION_PUMP_IDLE_MS[0]) })
  }, Math.max(1000, Number(delay || NOTIFICATION_PUMP_ACTIVE_MS)))
  if (notificationPumpTimer.unref) notificationPumpTimer.unref()
}
function startNotificationPump() {
  if (notificationPumpTimer || notificationPumpBusy) return
  setImmediate(function() {
    runNotificationPump().then(function(result) { scheduleNotificationPump(notificationPumpDelay(result)) }).catch(function() { scheduleNotificationPump(NOTIFICATION_PUMP_IDLE_MS[0]) })
  })
}
function stopNotificationPump() {
  if (notificationPumpTimer) clearTimeout(notificationPumpTimer)
  notificationPumpTimer = null
  notificationPumpIdleLevel = 0
}

function proxy(req, res) {
  const q = http.request({ hostname: '127.0.0.1', port: INNER_PORT, path: req.url, method: req.method, headers: Object.assign({}, req.headers, { host: '127.0.0.1:' + INNER_PORT }) }, function(upstream) {
    res.writeHead(upstream.statusCode || 502, upstream.headers); upstream.pipe(res)
  })
  q.on('error', function() { if (!res.headersSent) res.writeHead(502, { 'Content-Type': 'application/json; charset=utf-8' }); res.end(JSON.stringify({ ok: false, error: 'F17_UPSTREAM_UNAVAILABLE' })) })
  req.pipe(q)
}

function bufferedProxyHeaders(req, raw) {
  const headers = Object.assign({}, req.headers)
  const connectionTokens = String(headers.connection || '').split(',').map(function(v) { return v.trim().toLowerCase() }).filter(Boolean)
  connectionTokens.forEach(function(name) { delete headers[name] })
  ;['connection', 'keep-alive', 'proxy-authenticate', 'proxy-authorization', 'te', 'trailer', 'transfer-encoding', 'upgrade'].forEach(function(name) { delete headers[name] })
  headers.host = '127.0.0.1:' + INNER_PORT
  headers['content-length'] = Buffer.byteLength(raw)
  return headers
}

function proxyBuffered(req, raw, callback) {
  const headers = bufferedProxyHeaders(req, raw)
  const q = http.request({ hostname: '127.0.0.1', port: INNER_PORT, path: req.url, method: req.method, headers: headers }, function(upstream) {
    const chunks = []
    upstream.on('data', function(c) { chunks.push(Buffer.from(c)) })
    upstream.on('end', function() { callback(null, upstream, Buffer.concat(chunks)) })
  })
  q.on('error', function(e) { callback(e) })
  q.write(raw); q.end()
}

async function handleNotificationInbox(req, res, url) {
  const actor = await verifyApp(req.headers['x-aos-app-token'], false)
  if (!actor.ok) return writeJson(res, actor.status || 403, { ok: false, error: 'NOTIFICATION_APP_SESSION_REQUIRED' })
  const limit = Math.max(1, Math.min(100, Number(url.searchParams.get('limit') || 50)))
  try {
    const out = await serviceRpc('aos_notification_inbox_actor_v1', { p_payload: { actor_id: actor.actor_id, limit: limit } })
    return writeJson(res, 200, out || { ok: true, unreadNotifs: 0, unreadMsgs: 0, items: [], rows: [] })
  } catch (e) {
    console.error('[S15.1] notification inbox', e.message)
    return writeJson(res, 503, { ok: false, error: 'NOTIFICATION_INBOX_UNAVAILABLE' })
  }
}

async function handleNotificationRead(req, res) {
  let raw; try { raw = await readRaw(req, 16 * 1024) } catch (e) { return writeJson(res, e.status || 400, { ok: false, error: e.message }) }
  const body = parseJson(raw.toString('utf8'))
  if (!body || !UUID_RE.test(String(body.id || ''))) return writeJson(res, 400, { ok: false, error: 'NOTIFICATION_ID_REQUIRED' })
  const actor = await verifyApp(req.headers['x-aos-app-token'], false)
  if (!actor.ok) return writeJson(res, actor.status || 403, { ok: false, error: 'NOTIFICATION_APP_SESSION_REQUIRED' })
  try {
    const out = await serviceRpc('aos_notification_mark_read_actor_v1', { p_payload: { actor_id: actor.actor_id, notification_id: body.id } })
    if (!out || out.ok !== true) return writeJson(res, 403, out || { ok: false, error: 'NOTIFICATION_READ_REJECTED' })
    return writeJson(res, 200, out)
  } catch (e) {
    console.error('[S15.1] notification read', e.message)
    return writeJson(res, 503, { ok: false, error: 'NOTIFICATION_READ_UNAVAILABLE' })
  }
}

async function handlePushConfig(req, res) {
  const actor = await verifyApp(req.headers['x-aos-app-token'], false)
  if (!actor.ok) return writeJson(res, actor.status || 403, { ok: false, error: 'PUSH_APP_SESSION_REQUIRED' })
  try { return writeJson(res, 200, await push.publicConfig()) }
  catch (e) { console.error('[S14] config', e.message); return writeJson(res, 503, { ok: false, error: 'PUSH_CONFIG_UNAVAILABLE' }) }
}

async function handlePushSubscribe(req, res) {
  let raw; try { raw = await readRaw(req, 96 * 1024) } catch (e) { return writeJson(res, e.status || 400, { ok: false, error: e.message }) }
  const body = parseJson(raw.toString('utf8'))
  if (!body) return writeJson(res, 400, { ok: false, error: 'INVALID_JSON' })
  const actor = await verifyApp(req.headers['x-aos-app-token'], false)
  if (!actor.ok) return writeJson(res, actor.status || 403, { ok: false, error: 'PUSH_APP_SESSION_REQUIRED' })
  try {
    const out = await push.subscribe(actor.actor_id, body, req.headers['user-agent'])
    return writeJson(res, 200, Object.assign({ version: 'AOS_PUSH_V1' }, out))
  } catch (e) {
    console.error('[S14] subscribe', e.message)
    return writeJson(res, e.status || 503, { ok: false, error: e.message === 'INVALID_PUSH_SUBSCRIPTION' ? e.message : 'PUSH_SUBSCRIBE_UNAVAILABLE' })
  }
}

async function handlePushUnsubscribe(req, res) {
  let raw; try { raw = await readRaw(req, 32 * 1024) } catch (e) { return writeJson(res, e.status || 400, { ok: false, error: e.message }) }
  const body = parseJson(raw.toString('utf8'))
  if (!body) return writeJson(res, 400, { ok: false, error: 'INVALID_JSON' })
  const actor = await verifyApp(req.headers['x-aos-app-token'], false)
  if (!actor.ok) return writeJson(res, actor.status || 403, { ok: false, error: 'PUSH_APP_SESSION_REQUIRED' })
  try { return writeJson(res, 200, await push.unsubscribe(actor.actor_id, body)) }
  catch (e) { console.error('[S14] unsubscribe', e.message); return writeJson(res, e.status || 503, { ok: false, error: 'PUSH_UNSUBSCRIBE_UNAVAILABLE' }) }
}

async function handleGovernedSend(req, res) {
  let raw; try { raw = await readRaw(req, 256 * 1024) } catch (e) { return writeJson(res, e.status || 400, { ok: false, error: e.message }) }
  const body = parseJson(raw.toString('utf8'))
  if (!body) return writeJson(res, 400, { ok: false, error: 'INVALID_JSON' })
  const actor = await verifyApp(req.headers['x-aos-app-token'], true)
  if (!actor.ok) return writeJson(res, actor.status || 403, { ok: false, error: 'WA_ADMIN_2FA_REQUIRED' })
  if (!wa.validIdempotencyKey(body.idempotency_key)) return writeJson(res, 400, { ok: false, error: 'IDEMPOTENCY_KEY_REQUIRED' })
  let payload; try { payload = wa.buildOutboundPayload(body) } catch (e) { return writeJson(res, e.status || 400, { ok: false, error: e.message }) }
  if (!wa.canaryAllows(payload.to, WA_CANARY_MODE, WA_CANARY_ALLOW_TO)) return writeJson(res, 403, { ok: false, error: 'WA_CANARY_RECIPIENT_BLOCKED' })

  let governed
  try {
    governed = await f17wa.prepareOutbound({ actor: actor.actor_id, idempotencyKey: body.idempotency_key, payload: payload })
    if (!governed || governed.dispatch_allowed !== true) return writeJson(res, 403, { ok: false, error: 'F17_CHANNEL_POLICY_BLOCKED', state: governed && governed.state || 'BLOCKED' })
  } catch (e) { return writeJson(res, e.status || 503, { ok: false, error: 'F17_CHANNEL_POLICY_UNAVAILABLE' }) }

  proxyBuffered(req, raw, async function(err, upstream, responseBody) {
    if (err) return writeJson(res, 502, { ok: false, error: 'F17_UPSTREAM_UNAVAILABLE' })
    const data = parseJson(responseBody.toString('utf8'))
    try {
      if ((upstream.statusCode || 500) >= 200 && (upstream.statusCode || 500) < 300 && data && data.message_id) await f17wa.markAccepted(governed.request_id, data.message_id)
      else if (data && data.status === 'FAILED') await f17wa.markFailed(governed.request_id, data.error || 'WA_SEND_FAILED')
    } catch (e) { return writeJson(res, 503, { ok: false, error: 'F17_DISPATCH_RECONCILIATION_FAILED' }) }
    const headers = Object.assign({}, upstream.headers, { 'x-ascenda-f17': 'governed-wa-v1' })
    delete headers['content-length']
    res.writeHead(upstream.statusCode || 502, headers); res.end(responseBody)
  })
}

async function handleGovernedWebhook(req, res) {
  let raw; try { raw = await readRaw(req, 1024 * 1024) } catch (e) { return writeJson(res, e.status || 400, { ok: false, error: e.message }) }
  proxyBuffered(req, raw, async function(err, upstream, responseBody) {
    if (err) return writeJson(res, 502, { ok: false, error: 'F17_UPSTREAM_UNAVAILABLE' })
    let envelope = null
    if ((upstream.statusCode || 500) >= 200 && (upstream.statusCode || 500) < 300) {
      const payload = parseJson(raw.toString('utf8'))
      if (payload) {
        envelope = wa.extractWebhook(payload)
        try { await f17wa.ingestEnvelope(envelope) } catch (_) { return writeJson(res, 503, { ok: false, error: 'F17_WEBHOOK_RECONCILIATION_FAILED' }) }
      }
    }
    const headers = Object.assign({}, upstream.headers, { 'x-ascenda-f17': 'governed-wa-v1' })
    delete headers['content-length']
    res.writeHead(upstream.statusCode || 502, headers); res.end(responseBody)
    if (envelope && Array.isArray(envelope.messages) && envelope.messages.length) {
      setImmediate(function() {
        push.dispatchWhatsAppEnvelope(envelope).then(function(r) {
          if (r && (r.delivered || r.failed)) console.log('[S14] WA push', r)
        }).catch(function(e) { console.error('[S14] WA push fail-open', e.message) })
      })
    }
  })
}

const server = http.createServer(async function(req, res) {
  let url; try { url = new URL(req.url, 'http://localhost') } catch (_) { return writeJson(res, 400, { ok: false, error: 'INVALID_URL' }) }
  if (url.pathname === '/api/notifications/health' && req.method === 'GET') return writeJson(res, 200, { ok: true, version: 'S15.1', auth: 'actor-bound' })
  if (url.pathname === '/api/notifications/inbox' && req.method === 'GET') return handleNotificationInbox(req, res, url)
  if (url.pathname === '/api/notifications/read' && req.method === 'POST') return handleNotificationRead(req, res)
  if (url.pathname === '/api/push/config' && req.method === 'GET') return handlePushConfig(req, res)
  if (url.pathname === '/api/push/subscribe' && req.method === 'POST') return handlePushSubscribe(req, res)
  if (url.pathname === '/api/push/unsubscribe' && req.method === 'POST') return handlePushUnsubscribe(req, res)
  if (url.pathname === '/api/f17/whatsapp/templates') return gateway.handle(req, res)
  if (url.pathname === '/api/wa/send' && req.method === 'POST') return handleGovernedSend(req, res)
  if ((url.pathname === '/webhook' || url.pathname === '/webhook/') && req.method === 'POST') return handleGovernedWebhook(req, res)
  return proxy(req, res)
})

server.on('clientError', function(_, socket) { socket.end('HTTP/1.1 400 Bad Request\r\n\r\n') })
function shutdown(signal) { stopNotificationPump(); server.close(function() { process.exit(0) }); if (child && !child.killed) child.kill(signal); setTimeout(function() { process.exit(1) }, 5000).unref() }
process.on('SIGTERM', function() { shutdown('SIGTERM') }); process.on('SIGINT', function() { shutdown('SIGINT') })

function start() {
  child = spawn(process.execPath, ['server-f5.js'], { cwd: __dirname, env: Object.assign({}, process.env, { PORT: String(INNER_PORT) }), stdio: ['ignore', 'inherit', 'inherit'] })
  child.on('exit', function(code) { process.exit(code == null ? 1 : code) })
  server.listen(EXTERNAL_PORT, '0.0.0.0', function() {
    console.log('[F17] listening', { external: EXTERNAL_PORT, inner: INNER_PORT, gatewayConfigured: gateway.configured(), whatsappGoverned: true, pushVersion: 'AOS_PUSH_V1', notificationEvents: 'S15.1' })
    push.ensureVapid().then(function() { console.log('[S14] VAPID ready'); startNotificationPump() }).catch(function(e) { console.error('[S14] VAPID deferred', e.message); startNotificationPump() })
  })
}
if (require.main === module) start()
module.exports = { verifyApp: verifyApp, gateway: gateway, f17wa: f17wa, push: push, server: server, start: start, runNotificationPump: runNotificationPump, handleNotificationInbox: handleNotificationInbox, handleNotificationRead: handleNotificationRead, bufferedProxyHeaders: bufferedProxyHeaders }
