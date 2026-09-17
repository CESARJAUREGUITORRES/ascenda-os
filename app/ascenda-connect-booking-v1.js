'use strict'

const https = require('https')

const VERSION = '1.0.1'
const SITE = 'SAN ISIDRO'
const PREFIX = '/api/ascenda-connect/booking/v1'
const ALLOWED_ORIGINS = new Set(['https://zivital.pe', 'https://www.zivital.pe'])
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/
const TIME_RE = /^\d{2}:\d{2}(?::\d{2})?$/

const PUBLIC_TAXONOMY = {
  FACIAL: [
    { code: 'FACIAL_SKIN_SIGNATURE', title: 'Skin Signature', alias: 'Calidad cutánea · Salud · Glow consciente', summary: 'Calidad de piel, hidratación, estabilidad, luminosidad y cuidado de la barrera cutánea.', items: [
      { cap: 'HIDROFACIAL', label: 'Hidrofacial' },
      { cap: 'PEELINGS', label: 'Peelings' },
      { cap: 'MESOTERAPIA FACIAL', label: 'Mesoterapia' },
      { cap: 'BIOREVITALIZACION FACIAL', label: 'Biorevitalización' },
      { cap: 'RADIOFRECUENCIA FRACCIONADA', label: 'Radiofrecuencia fraccionada' }
    ] },
    { code: 'FACIAL_HARMONY_DESIGN', title: 'Harmony Design', alias: 'Equilibrio estructural · Expresión · Soporte', summary: 'Enfoque orientado a equilibrio estructural y expresión, buscando cambios moderados y naturales.', items: [
      { cap: 'ACIDO HIALURONICO', label: 'Ácido hialurónico' },
      { cap: 'TOXINA', label: 'Toxina' },
      { cap: 'HIFU', label: 'HIFU · Zi Frozen' },
      { cap: 'ENZIMAS FACIALES', label: 'Enzimas faciales' }
    ] },
    { code: 'FACIAL_BIOREGEN_FACE', title: 'BioRegen Face', alias: 'Regeneración · Longevidad · Sostén biológico', summary: 'Regeneración progresiva y sostén biológico, priorizando resultados naturales y de largo plazo.', items: [
      { cap: 'BIOESTIMULADOR', label: 'Bioestimuladores' },
      { cap: 'EXOSOMAS', label: 'Exosomas' },
      { cap: 'PRP FACIAL', label: 'PRP facial' }
    ] }
  ],
  CORPORAL: [
    { code: 'CORPORAL_BODY_RESET', title: 'Body Reset', alias: 'Preparación · Descarga · Inicio del proceso', summary: 'Enfoque de preparación corporal antes de procesos de reducción o remodelación.', items: [
      { cap: 'DETOX', label: 'Detox' },
      { cap: 'VITAMINAS', label: 'Vitaminas' }
    ] },
    { code: 'CORPORAL_SCULPT_BODY', title: 'Sculpt Body', alias: 'Reducción · Definición · Contorno', summary: 'Reducción localizada y definición de contorno dentro de un plan progresivo.', items: [
      { cap: 'APARATOLOGIA CORPORAL', label: 'Aparatología corporal' },
      { cap: 'CRIOLIPOLISIS', label: 'Criolipólisis' },
      { cap: 'ENZIMAS CORPORALES', label: 'Enzimas corporales' },
      { cap: 'MESOTERAPIA CORPORAL', label: 'Mesoterapia corporal' },
      { cap: 'CARBOXITERAPIA', label: 'Carboxiterapia' },
      { cap: 'HIDROENZIMAS', label: 'Hidroenzimas' }
    ] },
    { code: 'CORPORAL_SCULPT_BOOTY', title: 'Sculpt Booty', alias: 'Proyección · Firmeza · Calidad de tejido', summary: 'Enfoque corporal orientado a proyección, firmeza y calidad del tejido.', items: [
      { cap: 'GLUTEOS', label: 'Glúteos' }
    ] }
  ],
  CAPILAR: [
    { code: 'CAPILAR_ACTIVACION_REGENERACION', title: 'Activación & Regeneración', alias: 'Hair Revival', summary: 'Para procesos que buscan trabajar caída activa, adelgazamiento o pérdida de densidad; el protocolo se define en evaluación.', items: [
      { cap: 'MESOTERAPIA CAPILAR', label: 'Mesoterapia capilar' },
      { cap: 'PRP CAPILAR', label: 'PRP capilar' },
      { cap: 'EXOSOMAS CAPILARES', label: 'Exosomas capilares' }
    ] },
    { code: 'CAPILAR_MANTENIMIENTO_PREVENCION', title: 'Mantenimiento & Prevención', alias: 'Hair Guard', summary: 'Para proteger resultados y sostener mantenimiento o prevención capilar a largo plazo.', items: [
      { cap: 'CAPILAR', label: 'Evaluación / plan capilar' }
    ] }
  ]
}

function normalize(v) {
  return String(v || '').trim().toUpperCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '')
}

function cleanText(v, max) {
  return String(v == null ? '' : v).trim().replace(/[\u0000-\u001f\u007f]/g, ' ').slice(0, max)
}

function roleOfProfile(p) {
  return normalize(p && p.tipo).includes('ENFER') ? 'ENFERMERIA' : 'DOCTORA'
}

function profileServices(p) {
  return Array.isArray(p && p.servicios) ? p.servicios.map(normalize) : []
}

function profileSupports(p, treatmentName) {
  return profileServices(p).includes(normalize(treatmentName))
}

function publicProvider(p) {
  return {
    id: cleanText(p && p.id, 80),
    nombre: cleanText(p && p.nombre_publico, 100),
    foto_url: cleanText(p && p.foto_url, 500),
    especialidad: cleanText(p && p.especialidad, 120),
    cmp: cleanText(p && p.cmp, 30),
    role: roleOfProfile(p)
  }
}

function consolidateCatalog(raw) {
  const map = {}
  ;(raw || []).forEach(x => {
    const key = normalize(x && x.nombre)
    if (!key || !x || !UUID_RE.test(String(x.id || ''))) return
    if (!map[key]) map[key] = { nombre: cleanText(x.nombre, 160), categoria: cleanText(x.categoria || 'GENERAL', 80), entries: [], roles: [] }
    const role = normalize(x.role)
    map[key].entries.push({ id: String(x.id), role, nombre: cleanText(x.nombre, 160), categoria: cleanText(x.categoria, 80) })
    if (role && !map[key].roles.includes(role)) map[key].roles.push(role)
  })
  return Object.values(map)
}

function resolveRoutes(treatment, profiles) {
  const docs = (profiles || []).filter(p => roleOfProfile(p) === 'DOCTORA' && profileSupports(p, treatment.nombre))
  const nurses = (profiles || []).filter(p => roleOfProfile(p) === 'ENFERMERIA' && profileSupports(p, treatment.nombre))
  const routes = []
  if (docs.length) routes.push('DOCTORA')
  if (nurses.length) routes.push('ENFERMERIA')
  if (!routes.length) {
    if (treatment.roles.includes('DOCTORA')) routes.push('DOCTORA')
    if (treatment.roles.includes('ENFERMERIA')) routes.push('ENFERMERIA')
  }
  return { routes, doctors: docs.map(publicProvider) }
}

function buildBootstrap(catalogRaw, profiles) {
  const catalog = consolidateCatalog(catalogRaw)
  const byName = new Map(catalog.map(t => [normalize(t.nombre), t]))
  const domains = ['FACIAL', 'CORPORAL', 'CAPILAR'].map(domain => ({
    code: domain,
    label: domain === 'FACIAL' ? 'Facial' : domain === 'CORPORAL' ? 'Corporal' : 'Capilar',
    approaches: (PUBLIC_TAXONOMY[domain] || []).map(approach => ({
      code: approach.code,
      title: approach.title,
      alias: approach.alias,
      summary: approach.summary,
      treatments: approach.items.map(item => {
        const t = byName.get(normalize(item.cap))
        if (!t) return null
        const resolved = resolveRoutes(t, profiles)
        return {
          capability: item.cap,
          label: item.label,
          canonical_name: t.nombre,
          category: t.categoria,
          routes: resolved.routes,
          entries: t.entries.map(e => ({ id: e.id, role: e.role })),
          doctors: resolved.doctors
        }
      }).filter(Boolean)
    })).filter(a => a.treatments.length)
  }))
  return {
    ok: true,
    version: VERSION,
    site: SITE,
    attribution_default: { source_channel: 'WEB', advisor_code: 'ORGANICO' },
    domains
  }
}

function corsHeaders(origin) {
  if (!origin || !ALLOWED_ORIGINS.has(origin)) return {}
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    Vary: 'Origin'
  }
}

function applyCors(res, origin) {
  const headers = corsHeaders(origin)
  Object.keys(headers).forEach(k => res.setHeader(k, headers[k]))
}

function json(res, status, payload, origin) {
  const headers = Object.assign({
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff'
  }, corsHeaders(origin))
  res.writeHead(status, headers)
  if (status === 204) return res.end()
  res.end(JSON.stringify(payload))
}

function supabaseRequest(baseUrl, key, path, method, payload) {
  return new Promise((resolve, reject) => {
    const u = new URL(baseUrl)
    const body = payload === undefined ? null : JSON.stringify(payload)
    const headers = { apikey: key, Authorization: 'Bearer ' + key, Accept: 'application/json' }
    if (body !== null) {
      headers['Content-Type'] = 'application/json'
      headers['Content-Length'] = Buffer.byteLength(body)
    }
    const req = https.request({ hostname: u.hostname, port: 443, path, method, timeout: 12000, headers }, r => {
      let data = '', settled = false
      r.on('data', c => {
        if (settled) return
        data += c
        if (Buffer.byteLength(data) > 1024 * 1024) {
          settled = true
          req.destroy(new Error('UPSTREAM_TOO_LARGE'))
        }
      })
      r.on('end', () => {
        if (settled) return
        settled = true
        let parsed = null
        try { parsed = data ? JSON.parse(data) : null } catch (_) { return reject(new Error('UPSTREAM_INVALID_JSON')) }
        if (r.statusCode >= 300) return reject(new Error('UPSTREAM_' + r.statusCode))
        resolve(parsed)
      })
    })
    req.on('timeout', () => req.destroy(new Error('UPSTREAM_TIMEOUT')))
    req.on('error', reject)
    if (body !== null) req.write(body)
    req.end()
  })
}

function readBody(req, maxBytes) {
  return new Promise((resolve, reject) => {
    let body = '', settled = false
    function fail(error) {
      if (settled) return
      settled = true
      reject(error)
    }
    req.on('data', c => {
      if (settled) return
      body += c
      if (Buffer.byteLength(body) > maxBytes) fail(new Error('PAYLOAD_TOO_LARGE'))
    })
    req.on('end', () => {
      if (settled) return
      settled = true
      try { resolve(body ? JSON.parse(body) : {}) } catch (_) { reject(new Error('INVALID_JSON')) }
    })
    req.on('error', fail)
  })
}

const buckets = new Map()
function clientIp(req) {
  return cleanText(String(req.headers['x-forwarded-for'] || (req.socket && req.socket.remoteAddress) || '').split(',')[0], 80)
}
function rateAllowed(req, bucketName, limit, windowMs) {
  const now = Date.now(), key = bucketName + ':' + clientIp(req)
  let row = buckets.get(key)
  if (!row || now - row.start >= windowMs) row = { start: now, count: 0 }
  row.count += 1
  buckets.set(key, row)
  if (buckets.size > 5000) {
    for (const [k, v] of buckets) if (now - v.start > Math.max(windowMs, 10 * 60 * 1000)) buckets.delete(k)
  }
  return row.count <= limit
}

function validYearMonth(year, month) {
  const y = Number(year), m = Number(month), now = new Date().getFullYear()
  return Number.isInteger(y) && Number.isInteger(m) && y >= now && y <= now + 2 && m >= 1 && m <= 12
}

function createBookingConnectV1(opts) {
  opts = opts || {}
  const sb = opts.supabaseUrl || process.env.SUPABASE_URL
  const key = opts.serviceRoleKey || process.env.SUPABASE_SERVICE_ROLE_KEY
  const confirmationHandler = typeof opts.confirmationHandler === 'function' ? opts.confirmationHandler : null
  const rpc = opts.rpc || ((name, payload) => supabaseRequest(sb, key, '/rest/v1/rpc/' + encodeURIComponent(name), 'POST', payload || {}))
  const get = opts.get || (path => supabaseRequest(sb, key, '/rest/v1/' + path, 'GET'))

  async function loadCatalog() { return rpc('aos_booking_public_catalog_v2', {}) }
  async function loadProfiles() {
    const rows = await get('aos_perfiles_profesional?visible=eq.true&order=orden&select=id,nombre_publico,foto_url,especialidad,cmp,tipo,servicios,orden,visible')
    return Array.isArray(rows) ? rows : []
  }
  async function findEntry(id) {
    const raw = await loadCatalog()
    return (Array.isArray(raw) ? raw : []).find(x => String(x.id) === String(id)) || null
  }
  async function findProfile(id) {
    const profiles = await loadProfiles()
    return profiles.find(p => String(p.id) === String(id)) || null
  }

  return async function handle(req, res) {
    const origin = String(req.headers.origin || '')
    if (origin && !ALLOWED_ORIGINS.has(origin)) return json(res, 403, { ok: false, error: 'ORIGIN_NOT_ALLOWED' })
    if (req.method === 'OPTIONS') return json(res, 204, null, origin)

    let path = '/'
    try { path = new URL(req.url, 'http://localhost').pathname } catch (_) {}
    const op = path.startsWith(PREFIX) ? path.slice(PREFIX.length) || '/' : '/'

    if (op === '/health' && req.method === 'GET') {
      return json(res, 200, { ok: true, service: 'ascenda-connect-booking', version: VERSION }, origin)
    }
    if (!sb || !key) return json(res, 503, { ok: false, error: 'CONNECTOR_NOT_CONFIGURED' }, origin)

    try {
      if (op === '/bootstrap' && req.method === 'GET') {
        if (!rateAllowed(req, 'bootstrap', 90, 60 * 1000)) return json(res, 429, { ok: false, error: 'RATE_LIMIT' }, origin)
        const [catalog, profiles] = await Promise.all([loadCatalog(), loadProfiles()])
        return json(res, 200, buildBootstrap(Array.isArray(catalog) ? catalog : [], profiles), origin)
      }

      if (op === '/days' && req.method === 'POST') {
        if (!rateAllowed(req, 'days', 120, 60 * 1000)) return json(res, 429, { ok: false, error: 'RATE_LIMIT' }, origin)
        const d = await readBody(req, 12000)
        const route = normalize(d.route), treatmentId = cleanText(d.treatment_id, 60), providerId = cleanText(d.provider_id, 80)
        if (!['DOCTORA', 'ENFERMERIA'].includes(route) || !UUID_RE.test(treatmentId) || !validYearMonth(d.year, d.month)) return json(res, 400, { ok: false, error: 'INVALID_REQUEST' }, origin)
        const entry = await findEntry(treatmentId)
        if (!entry || normalize(entry.role) !== route) return json(res, 409, { ok: false, error: 'TREATMENT_ROUTE_MISMATCH' }, origin)
        let days
        if (route === 'DOCTORA') {
          if (!providerId) return json(res, 400, { ok: false, error: 'PROVIDER_REQUIRED' }, origin)
          const p = await findProfile(providerId)
          if (!p || roleOfProfile(p) !== 'DOCTORA' || !profileSupports(p, entry.nombre)) return json(res, 409, { ok: false, error: 'PROVIDER_NOT_ELIGIBLE' }, origin)
          days = await rpc('aos_booking_provider_days_v3', { p_profesional_id: providerId, p_anio: Number(d.year), p_mes: Number(d.month), p_sede: SITE })
        } else {
          days = await rpc('aos_booking_pool_days_v3', { p_role: 'ENFERMERIA', p_anio: Number(d.year), p_mes: Number(d.month), p_sede: SITE })
        }
        return json(res, 200, { ok: true, days: Array.isArray(days) ? days.map(x => String(x).slice(0, 10)) : [] }, origin)
      }

      if (op === '/availability' && req.method === 'POST') {
        if (!rateAllowed(req, 'availability', 120, 60 * 1000)) return json(res, 429, { ok: false, error: 'RATE_LIMIT' }, origin)
        const d = await readBody(req, 12000)
        const treatmentId = cleanText(d.treatment_id, 60), date = cleanText(d.date, 10), providerId = cleanText(d.provider_id, 80)
        if (!UUID_RE.test(treatmentId) || !DATE_RE.test(date)) return json(res, 400, { ok: false, error: 'INVALID_REQUEST' }, origin)
        const entry = await findEntry(treatmentId)
        if (!entry) return json(res, 404, { ok: false, error: 'TREATMENT_NOT_FOUND' }, origin)
        const role = normalize(entry.role)
        if (role === 'DOCTORA') {
          if (!providerId) return json(res, 400, { ok: false, error: 'PROVIDER_REQUIRED' }, origin)
          const p = await findProfile(providerId)
          if (!p || roleOfProfile(p) !== 'DOCTORA' || !profileSupports(p, entry.nombre)) return json(res, 409, { ok: false, error: 'PROVIDER_NOT_ELIGIBLE' }, origin)
        }
        const a = await rpc('aos_booking_availability_v2', { p_treatment_id: treatmentId, p_fecha: date, p_sede: SITE, p_profesional_id: role === 'DOCTORA' ? providerId : null })
        let slots = a && Array.isArray(a.slots) ? a.slots.filter(s => s && s.disponible !== false).map(s => ({ hora: cleanText(s.hora, 12), professional_id: cleanText(s.professional_id, 80) })) : []
        if (role === 'DOCTORA' && providerId) slots = slots.filter(s => String(s.professional_id) === providerId)
        return json(res, 200, { ok: !!(a && a.ok), role, slots }, origin)
      }

      if (op === '/patient-lookup' && req.method === 'POST') {
        if (!rateAllowed(req, 'patient', 18, 60 * 1000)) return json(res, 429, { ok: false, error: 'RATE_LIMIT' }, origin)
        const d = await readBody(req, 6000), identity = cleanText(d.identity, 32)
        if (!identity || identity.replace(/\D/g, '').length < 7) return json(res, 400, { ok: false, error: 'IDENTITY_REQUIRED' }, origin)
        const r = await rpc('aos_booking_patient_lookup_v3', { p_identity: identity })
        if (!r || !r.ok || !r.found || !r.patient) return json(res, 200, { ok: true, found: false }, origin)
        const p = r.patient || {}
        return json(res, 200, { ok: true, found: true, patient: { nombre: cleanText(p.nombre, 80), apellido: cleanText(p.apellido, 120), numero: cleanText(p.numero, 32), documento: cleanText(p.documento, 32), email: cleanText(p.email, 160) } }, origin)
      }

      if (op === '/book' && req.method === 'POST') {
        if (!rateAllowed(req, 'book', 6, 10 * 60 * 1000)) return json(res, 429, { ok: false, error: 'RATE_LIMIT' }, origin)
        const d = await readBody(req, 24000)
        const treatmentId = cleanText(d.treatment_id, 60), date = cleanText(d.date, 10), time = cleanText(d.time, 12), providerId = cleanText(d.provider_id, 80)
        const name = cleanText(d.name, 80), surname = cleanText(d.surname, 120), phone = cleanText(d.phone, 32), dni = cleanText(d.dni, 32), email = cleanText(d.email, 160)
        const appointmentType = cleanText(d.appointment_type || 'CONSULTA NUEVA', 40), token = cleanText(d.token || '__permanent__', 160)
        if (!UUID_RE.test(treatmentId) || !DATE_RE.test(date) || !TIME_RE.test(time) || !name || phone.replace(/\D/g, '').length < 7) return json(res, 400, { ok: false, error: 'INVALID_REQUEST' }, origin)
        const entry = await findEntry(treatmentId)
        if (!entry) return json(res, 404, { ok: false, error: 'TREATMENT_NOT_FOUND' }, origin)
        const role = normalize(entry.role)
        if (role === 'DOCTORA') {
          if (!providerId) return json(res, 400, { ok: false, error: 'PROVIDER_REQUIRED' }, origin)
          const p = await findProfile(providerId)
          if (!p || roleOfProfile(p) !== 'DOCTORA' || !profileSupports(p, entry.nombre)) return json(res, 409, { ok: false, error: 'PROVIDER_NOT_ELIGIBLE' }, origin)
        }
        const context = d.context && typeof d.context === 'object' ? d.context : {}
        const contextParts = [
          'domain=' + cleanText(context.domain, 30),
          'approach=' + cleanText(context.approach, 80),
          'page=' + cleanText(context.page, 180)
        ].filter(x => !x.endsWith('='))
        let note = cleanText(d.note, 500)
        if (note) note += '\n'
        note += '[ZIVITAL_WEB_NATIVE_V1]'
        if (contextParts.length) note += ' ' + contextParts.join(';')
        const r = await rpc('aos_agendar_publica_v2', {
          p_token: token || '__permanent__',
          p_nombre: name,
          p_apellido: surname,
          p_telefono: phone,
          p_treatment_id: treatmentId,
          p_fecha: date,
          p_hora: time,
          p_sede: SITE,
          p_profesional_id: role === 'DOCTORA' ? providerId : null,
          p_dni: dni,
          p_email: email,
          p_nota: note,
          p_tipo_cita: appointmentType
        })
        if (!r || !r.ok) return json(res, 409, { ok: false, error: cleanText((r && r.error) || 'BOOKING_REJECTED', 120) }, origin)
        return json(res, 200, { ok: true, agenda_id: cleanText(r.agenda_id, 80), source_channel: cleanText(r.source_channel, 40), source_campaign: cleanText(r.source_campaign, 100), advisor_code: cleanText(r.advisor_code, 100) }, origin)
      }

      if (op === '/confirmation' && req.method === 'POST') {
        if (!confirmationHandler) return json(res, 503, { ok: false, error: 'CONFIRMATION_NOT_CONFIGURED' }, origin)
        if (!rateAllowed(req, 'confirmation', 12, 10 * 60 * 1000)) return json(res, 429, { ok: false, error: 'RATE_LIMIT' }, origin)
        applyCors(res, origin)
        return confirmationHandler(req, res)
      }

      return json(res, 404, { ok: false, error: 'CONNECTOR_ROUTE_NOT_FOUND' }, origin)
    } catch (e) {
      const code = String((e && e.message) || 'CONNECTOR_ERROR')
      if (code === 'PAYLOAD_TOO_LARGE') return json(res, 413, { ok: false, error: code }, origin)
      if (code === 'INVALID_JSON') return json(res, 400, { ok: false, error: code }, origin)
      console.error('[ascenda-connect-booking-v1]', code)
      return json(res, 502, { ok: false, error: 'CONNECTOR_UPSTREAM_ERROR' }, origin)
    }
  }
}

module.exports = { createBookingConnectV1, buildBootstrap, consolidateCatalog, resolveRoutes, PUBLIC_TAXONOMY, PREFIX }
