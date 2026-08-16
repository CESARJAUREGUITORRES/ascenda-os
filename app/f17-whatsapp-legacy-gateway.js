'use strict'

const https = require('https')

const DEFAULT_SB_URL = 'https://ituyqwstonmhnfshnaqz.supabase.co'

function jsonResponse(res, status, body) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff'
  })
  res.end(JSON.stringify(body))
}

function requestJson(urlString, options) {
  return new Promise(function(resolve, reject) {
    var url = new URL(urlString)
    var req = https.request({
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname + url.search,
      method: (options && options.method) || 'GET',
      headers: (options && options.headers) || {},
      timeout: (options && options.timeout) || 15000
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
    req.on('timeout', function() { req.destroy(new Error('UPSTREAM_TIMEOUT')) })
    req.on('error', reject)
    req.end()
  })
}

function createLegacyWhatsAppGateway(config) {
  config = config || {}
  var sbUrl = String(config.supabaseUrl || process.env.SUPABASE_URL || DEFAULT_SB_URL).replace(/\/$/, '')
  var serviceKey = String(config.serviceRoleKey != null ? config.serviceRoleKey : (process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.service_role || ''))
  var verifyApp = config.verifyApp
  var requester = config.requestJson || requestJson

  function configured() {
    return serviceKey.length > 20 && typeof verifyApp === 'function'
  }

  async function listTemplates(token) {
    if (!configured()) return { ok: false, status: 503, error: 'WHATSAPP_GATEWAY_NOT_CONFIGURED' }
    var actor = await verifyApp(String(token || ''))
    if (!actor || actor.ok !== true) return { ok: false, status: actor && actor.status ? actor.status : 401, error: 'UNAUTHORIZED' }

    var headers = { apikey: serviceKey }
    if (!/^sb_(?:secret|publishable)_/.test(serviceKey)) headers.Authorization = 'Bearer ' + serviceKey
    var query = '/rest/v1/aos_plantillas_whatsapp?select=id,nombre,icono,color,contexto,mensaje,orden&activo=eq.true&order=orden.asc'
    var result = await requester(sbUrl + query, { method: 'GET', headers: headers, timeout: 15000 })
    if (!result || result.status < 200 || result.status >= 300 || !Array.isArray(result.body)) {
      return { ok: false, status: 502, error: 'WHATSAPP_TEMPLATE_READ_FAILED' }
    }

    var templates = result.body.map(function(row) {
      return {
        id: row.id,
        nombre: row.nombre || '',
        icono: row.icono || '',
        color: row.color || '',
        contexto: row.contexto || '',
        mensaje: row.mensaje || '',
        orden: Number.isFinite(Number(row.orden)) ? Number(row.orden) : 0
      }
    })
    return { ok: true, templates: templates }
  }

  async function handle(req, res) {
    if (req.method !== 'GET') return jsonResponse(res, 405, { ok: false, error: 'METHOD_NOT_ALLOWED' })
    try {
      var token = String(req.headers['x-ascenda-session'] || '')
      var out = await listTemplates(token)
      return jsonResponse(res, out.ok ? 200 : (out.status || 400), out)
    } catch (_) {
      return jsonResponse(res, 500, { ok: false, error: 'WHATSAPP_GATEWAY_ERROR' })
    }
  }

  return {
    configured: configured,
    listTemplates: listTemplates,
    handle: handle
  }
}

module.exports = {
  createLegacyWhatsAppGateway: createLegacyWhatsAppGateway
}
