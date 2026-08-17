'use strict'

// F17 outer boundary: authenticated, server-authoritative reads for legacy
// WhatsApp templates. Everything else is proxied unchanged to the certified
// F5 -> WA4 -> WA3 -> WA2 -> F4 chain.
const http = require('http')
const https = require('https')
const { spawn } = require('child_process')
const { createLegacyWhatsAppGateway } = require('./f17-whatsapp-legacy-gateway')

const EXTERNAL_PORT = parseInt(process.env.PORT || '4173', 10)
const INNER_PORT = EXTERNAL_PORT === 4217 ? 4218 : 4217
const SB_URL = String(process.env.SUPABASE_URL || 'https://ituyqwstonmhnfshnaqz.supabase.co').replace(/\/$/, '')
const SB_ANON_KEY = String(process.env.SUPABASE_ANON_KEY || '')
const SB_SERVICE_KEY = String(process.env.SUPABASE_SERVICE_ROLE_KEY || '')
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
let child = null

function parseJson(text) {
  try { return text ? JSON.parse(text) : null } catch (_) { return null }
}

function rpc(name, payload) {
  return new Promise(function(resolve, reject) {
    if (!SB_ANON_KEY) return reject(new Error('SUPABASE_ANON_KEY_NOT_CONFIGURED'))
    let url
    try { url = new URL(SB_URL) } catch (e) { return reject(e) }
    const body = JSON.stringify(payload || {})
    const req = https.request({
      hostname: url.hostname,
      port: url.port || 443,
      path: '/rest/v1/rpc/' + encodeURIComponent(name),
      method: 'POST',
      headers: {
        apikey: SB_ANON_KEY,
        Authorization: 'Bearer ' + SB_ANON_KEY,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
        'User-Agent': 'AscendaOS-F17/1.0'
      },
      timeout: 12000
    }, function(res) {
      let raw = ''
      res.on('data', function(chunk) { raw += chunk })
      res.on('end', function() {
        if ((res.statusCode || 500) < 200 || (res.statusCode || 500) >= 300) {
          return reject(new Error('F17_AUTH_UNAVAILABLE'))
        }
        resolve(parseJson(raw))
      })
    })
    req.on('timeout', function() { req.destroy(new Error('F17_AUTH_TIMEOUT')) })
    req.on('error', reject)
    req.write(body)
    req.end()
  })
}

async function verifyApp(token) {
  const t = String(token || '').trim()
  if (t.length < 32) return { ok: false, status: 401 }
  try {
    const actorId = await rpc('aos_app_actor_v3', {
      p_token: t,
      p_required_panel: null,
      p_require_2fa: false
    })
    return UUID_RE.test(String(actorId || ''))
      ? { ok: true, actor_id: actorId }
      : { ok: false, status: 403 }
  } catch (_) {
    return { ok: false, status: 503 }
  }
}

const gateway = createLegacyWhatsAppGateway({
  supabaseUrl: SB_URL,
  serviceRoleKey: SB_SERVICE_KEY,
  verifyApp: verifyApp
})

function proxy(req, res) {
  const q = http.request({
    hostname: '127.0.0.1',
    port: INNER_PORT,
    path: req.url,
    method: req.method,
    headers: Object.assign({}, req.headers, { host: '127.0.0.1:' + INNER_PORT })
  }, function(upstream) {
    res.writeHead(upstream.statusCode || 502, upstream.headers)
    upstream.pipe(res)
  })
  q.on('error', function() {
    if (!res.headersSent) res.writeHead(502, { 'Content-Type': 'application/json; charset=utf-8' })
    res.end(JSON.stringify({ ok: false, error: 'F17_UPSTREAM_UNAVAILABLE' }))
  })
  req.pipe(q)
}

const server = http.createServer(async function(req, res) {
  let url
  try { url = new URL(req.url, 'http://localhost') } catch (_) {
    res.writeHead(400, { 'Content-Type': 'application/json; charset=utf-8' })
    return res.end(JSON.stringify({ ok: false, error: 'INVALID_URL' }))
  }
  if (url.pathname === '/api/f17/whatsapp/templates') return gateway.handle(req, res)
  return proxy(req, res)
})

server.on('clientError', function(_, socket) {
  socket.end('HTTP/1.1 400 Bad Request\r\n\r\n')
})

function shutdown(signal) {
  server.close(function() { process.exit(0) })
  if (child && !child.killed) child.kill(signal)
  setTimeout(function() { process.exit(1) }, 5000).unref()
}

process.on('SIGTERM', function() { shutdown('SIGTERM') })
process.on('SIGINT', function() { shutdown('SIGINT') })

function start() {
  child = spawn(process.execPath, ['server-f5.js'], {
    cwd: __dirname,
    env: Object.assign({}, process.env, { PORT: String(INNER_PORT) }),
    stdio: ['ignore', 'inherit', 'inherit']
  })
  child.on('exit', function(code) { process.exit(code == null ? 1 : code) })
  server.listen(EXTERNAL_PORT, '0.0.0.0', function() {
    console.log('[F17] listening', {
      external: EXTERNAL_PORT,
      inner: INNER_PORT,
      gatewayConfigured: gateway.configured()
    })
  })
}

if (require.main === module) start()

module.exports = {
  verifyApp: verifyApp,
  gateway: gateway,
  server: server,
  start: start
}
