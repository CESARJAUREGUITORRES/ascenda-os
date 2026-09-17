'use strict'

const assert = require('assert')
const fs = require('fs')
const { EventEmitter } = require('events')
const { createBookingConnectV1, PUBLIC_TAXONOMY, PREFIX } = require('../../app/ascenda-connect-booking-v1')

const U_DOCTOR = '11111111-1111-4111-8111-111111111111'
const U_NURSE = '22222222-2222-4222-8222-222222222222'
const U_PATIENT = '33333333-3333-4333-8333-333333333333'

const catalog = [
  { id: U_DOCTOR, nombre: 'TOXINA', categoria: 'INYECTABLES', role: 'DOCTORA' },
  { id: U_NURSE, nombre: 'HIDROFACIAL', categoria: 'FACIAL', role: 'ENFERMERIA' }
]
const profiles = [
  { id: 'DOC-1', nombre_publico: 'Dra. Prueba', tipo: 'DOCTORA', visible: true, servicios: ['TOXINA'], foto_url: '', especialidad: 'Medicina estética', cmp: '00000' },
  { id: 'NURSE-1', nombre_publico: 'Equipo clínico', tipo: 'ENFERMERIA', visible: true, servicios: ['HIDROFACIAL'], foto_url: '', especialidad: '', cmp: '' }
]

function request(method, url, body, origin = 'https://zivital.pe') {
  const req = new EventEmitter()
  req.method = method
  req.url = url
  req.headers = { origin, 'x-forwarded-for': '127.0.0.1' }
  req.socket = { remoteAddress: '127.0.0.1' }
  process.nextTick(() => {
    if (body !== undefined) req.emit('data', Buffer.from(JSON.stringify(body)))
    req.emit('end')
  })
  return req
}

function response() {
  let resolve
  const done = new Promise(r => { resolve = r })
  const res = {
    statusCode: 0,
    headers: {},
    body: '',
    setHeader(k, v) { this.headers[String(k).toLowerCase()] = v },
    writeHead(status, headers) {
      this.statusCode = status
      Object.entries(headers || {}).forEach(([k, v]) => this.setHeader(k, v))
    },
    end(value) {
      if (value) this.body += String(value)
      resolve(this)
    }
  }
  res.done = done
  return res
}

async function call(handler, method, path, body, origin) {
  const req = request(method, path, body, origin)
  const res = response()
  await handler(req, res)
  return res.done
}

async function main() {
  const calls = []
  let confirmationCalled = false
  const rpc = async (name, payload) => {
    calls.push({ name, payload })
    if (name === 'aos_booking_public_catalog_v2') return catalog
    if (name === 'aos_booking_provider_days_v3') return ['2026-09-20']
    if (name === 'aos_booking_pool_days_v3') return ['2026-09-21']
    if (name === 'aos_booking_availability_v2') return { ok: true, slots: [{ hora: '11:00', disponible: true, professional_id: payload.p_profesional_id || null }] }
    if (name === 'aos_booking_patient_lookup_v3') return { ok: true, found: true, patient: { nombre: 'Ana', apellido: 'Prueba', numero: '999999999', documento: '12345678', email: 'ana@example.test', secret: 'must-not-pass' } }
    if (name === 'aos_agendar_publica_v2') return { ok: true, agenda_id: U_PATIENT, source_channel: 'WEB', advisor_code: 'ORGANICO' }
    throw new Error('UNEXPECTED_RPC_' + name)
  }
  const get = async path => {
    assert(path.includes('aos_perfiles_profesional'))
    assert(!path.includes('password'))
    return profiles
  }
  const confirmationHandler = (req, res) => {
    confirmationCalled = true
    assert.strictEqual(res.headers['access-control-allow-origin'], 'https://zivital.pe')
    res.writeHead(200, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({ ok: true }))
  }
  const handler = createBookingConnectV1({ supabaseUrl: 'https://example.supabase.co', serviceRoleKey: 'test-only', rpc, get, confirmationHandler })

  let r = await call(handler, 'GET', PREFIX + '/health')
  assert.strictEqual(r.statusCode, 200)
  assert.strictEqual(JSON.parse(r.body).service, 'ascenda-connect-booking')

  r = await call(handler, 'GET', PREFIX + '/bootstrap')
  assert.strictEqual(r.statusCode, 200)
  const boot = JSON.parse(r.body)
  assert.strictEqual(boot.site, 'SAN ISIDRO')
  assert.strictEqual(boot.attribution_default.source_channel, 'WEB')
  const facial = boot.domains.find(x => x.code === 'FACIAL')
  assert(facial)
  const skin = facial.approaches.find(x => x.code === 'FACIAL_SKIN_SIGNATURE')
  assert(skin && skin.treatments.some(x => x.capability === 'HIDROFACIAL'))
  const harmony = facial.approaches.find(x => x.code === 'FACIAL_HARMONY_DESIGN')
  const tox = harmony.treatments.find(x => x.capability === 'TOXINA')
  assert.deepStrictEqual(tox.routes, ['DOCTORA'])
  assert.strictEqual(tox.doctors[0].nombre, 'Dra. Prueba')
  assert(!JSON.stringify(boot).includes('servicios'))

  r = await call(handler, 'POST', PREFIX + '/days', { route: 'DOCTORA', treatment_id: U_DOCTOR, provider_id: 'DOC-1', year: 2026, month: 9 })
  assert.strictEqual(r.statusCode, 200)
  assert.deepStrictEqual(JSON.parse(r.body).days, ['2026-09-20'])

  r = await call(handler, 'POST', PREFIX + '/availability', { treatment_id: U_DOCTOR, provider_id: 'DOC-1', date: '2026-09-20' })
  assert.strictEqual(r.statusCode, 200)
  assert.strictEqual(JSON.parse(r.body).slots[0].hora, '11:00')
  assert(calls.some(x => x.name === 'aos_booking_availability_v2'))

  r = await call(handler, 'POST', PREFIX + '/patient-lookup', { identity: '999999999' })
  assert.strictEqual(r.statusCode, 200)
  const patient = JSON.parse(r.body).patient
  assert.strictEqual(patient.nombre, 'Ana')
  assert(!Object.prototype.hasOwnProperty.call(patient, 'secret'))

  r = await call(handler, 'POST', PREFIX + '/book', {
    treatment_id: U_DOCTOR,
    provider_id: 'DOC-1',
    date: '2026-09-20',
    time: '11:00',
    name: 'Ana',
    surname: 'Prueba',
    phone: '999999999',
    dni: '12345678',
    email: 'ana@example.test',
    context: { domain: 'FACIAL', approach: 'FACIAL_HARMONY_DESIGN', page: '/toxina' }
  })
  assert.strictEqual(r.statusCode, 200)
  const bookCall = calls.find(x => x.name === 'aos_agendar_publica_v2')
  assert(bookCall)
  assert.strictEqual(bookCall.payload.p_token, '__permanent__')
  assert(bookCall.payload.p_nota.includes('[ZIVITAL_WEB_NATIVE_V1]'))
  assert.strictEqual(JSON.parse(r.body).source_channel, 'WEB')

  r = await call(handler, 'POST', PREFIX + '/confirmation', { appointment_id: U_PATIENT })
  assert.strictEqual(r.statusCode, 200)
  assert(confirmationCalled)

  r = await call(handler, 'GET', PREFIX + '/bootstrap', undefined, 'https://evil.example')
  assert.strictEqual(r.statusCode, 403)

  r = await call(handler, 'GET', PREFIX + '/unknown')
  assert.strictEqual(r.statusCode, 404)

  const v3 = fs.readFileSync('app/public/agendar-v3.html', 'utf8')
  for (const groups of Object.values(PUBLIC_TAXONOMY)) {
    for (const group of groups) {
      assert(v3.includes(group.code), 'V3 taxonomy missing ' + group.code)
      for (const item of group.items) assert(v3.includes(item.cap), 'V3 capability missing ' + item.cap)
    }
  }
  for (const required of ['aos_booking_public_catalog_v2', 'aos_booking_availability_v2', 'aos_agendar_publica_v2', 'aos_booking_patient_lookup_v3']) assert(v3.includes(required), 'V3 authority missing ' + required)

  const connector = fs.readFileSync('app/ascenda-connect-booking-v1.js', 'utf8')
  const preload = fs.readFileSync('app/booking-v33-preload.js', 'utf8')
  assert(connector.includes('process.env.SUPABASE_SERVICE_ROLE_KEY'))
  assert(!/eyJ[a-zA-Z0-9_-]{20,}\./.test(connector), 'connector must not contain JWT/API token literals')
  assert(!connector.includes('insert into public.aos_agenda_citas'))
  assert(preload.includes("p==='/api/booking/public-confirmation-v33'") || preload.includes("p==='/api/booking/public-confirmation-v33'"))
  assert(preload.includes('BOOKING_CONNECT_PREFIX'))
  assert(preload.includes('return listener(req,res)'))

  console.log('BOOKING-CONNECT-V1 contract PASS')
}

main().catch(error => {
  console.error(error)
  process.exit(1)
})
