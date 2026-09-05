'use strict'

/*
 * ASCENDA OS · Business Priority Mode P0-A
 *
 * Only known non-critical Supabase background traffic is circuit-broken.
 * Revenue-critical reads/writes, auth, Call Center, Agenda, Sales, WhatsApp
 * routing/human paths and AI-key bootstrap remain outside this shield and
 * always use the normal transport path.
 *
 * AOS_BACKGROUND_SHED=true is an explicit P0 brownout switch. When enabled,
 * classified background work is rejected locally before it can consume a
 * Supabase/PostgREST connection. This is load shedding, not timeout inflation.
 *
 * This preload is composed AFTER supabase-quota-circuit-preload.cjs in
 * Railway NODE_OPTIONS. The inherited request function therefore preserves
 * the existing project-wide 402 quota breaker while this layer adds a shared
 * 5xx/timeout shield for background work.
 */

const https = require('https')
const { EventEmitter } = require('events')
const { PassThrough } = require('stream')

if (!https.__AOS_BUSINESS_PRIORITY_PRELOAD_V1__) {
  https.__AOS_BUSINESS_PRIORITY_PRELOAD_V1__ = true

  const inheritedRequest = https.request.bind(https)
  const PROJECT_HOST = String(process.env.AOS_SUPABASE_HOST || 'ituyqwstonmhnfshnaqz.supabase.co').toLowerCase()
  const EMERGENCY_SHED = /^(1|true|yes|on)$/i.test(String(process.env.AOS_BACKGROUND_SHED || '').trim())
  const SHIELD_KEY = 'background-shield'
  const states = new Map()

  function targetOf(first) {
    if (!first) return null
    if (typeof first === 'string' || first instanceof URL) {
      try {
        const u = new URL(first)
        return { host: String(u.hostname || '').toLowerCase(), path: u.pathname + u.search }
      } catch (_) { return null }
    }
    if (typeof first !== 'object') return null
    return {
      host: String(first.hostname || first.host || '').split(':')[0].toLowerCase(),
      path: String(first.path || first.pathname || '')
    }
  }

  function classify(first) {
    const t = targetOf(first)
    if (!t || t.host !== PROJECT_HOST) return ''
    const p = t.path
    if (p.indexOf('/rest/v1/aos_agentes?') === 0 && p.indexOf('tipo_ejecucion=eq.cron') >= 0) return 'agent-cron-scan'
    if (p.indexOf('/rest/v1/rpc/aos_notification_push_claim_v1') === 0) return 'notification-push-claim'
    if (p.indexOf('/rest/v1/rpc/aos_generar_snapshot') === 0) return 'snapshot-refresh'
    if (p.indexOf('/rest/v1/aos_configuracion?') === 0 && p.indexOf('select=clave') >= 0) return 'configuration-cache'
    if (p.indexOf('/rest/v1/aos_email_plantillas?') === 0 && p.indexOf('activo=eq.true') >= 0) return 'email-template-cache'
    if (p.indexOf('/rest/v1/aos_usuarios?') === 0 && p.indexOf('select=nombre,apellidos,cmp') >= 0 && p.indexOf('cmp=neq.') >= 0) return 'medical-cmp-cache'
    return ''
  }

  function shieldState() {
    if (!states.has(SHIELD_KEY)) states.set(SHIELD_KEY, { openUntil: 0, lastLogUntil: 0, lastKey: '' })
    return states.get(SHIELD_KEY)
  }

  function keyState(key) {
    const stateKey = 'source:' + key
    if (!states.has(stateKey)) states.set(stateKey, { failures: 0, lastFailureAt: 0, lastSuccessAt: 0 })
    return states.get(stateKey)
  }

  function isFailureStatus(status) {
    status = Number(status || 0)
    return status === 401 || status === 403 || status === 408 || status === 429 || status >= 500
  }

  function markSuccess(key) {
    if (!key) return
    const k = keyState(key)
    k.failures = 0
    k.lastSuccessAt = Date.now()
    // A successful sibling request must never close a shield opened by another
    // background source. The shared cooldown expires only by time.
  }

  function markFailure(key, reason) {
    if (!key) return
    const now = Date.now()
    const s = shieldState()
    const k = keyState(key)
    k.failures += 1
    k.lastFailureAt = now
    const wait = k.failures >= 3 ? 600000 : (k.failures === 2 ? 120000 : 30000)
    s.lastKey = key
    s.openUntil = Math.max(s.openUntil, now + wait)
    if (now >= s.lastLogUntil) {
      s.lastLogUntil = s.openUntil
      console.warn('[BUSINESS-PRIORITY] background shield open', { source: key, wait_ms: wait, failures: k.failures, reason: String(reason || 'upstream') })
    }
  }

  function circuitOpen(key) {
    return !!key && (EMERGENCY_SHED || Date.now() < shieldState().openUntil)
  }

  function syntheticResponse(reason) {
    const res = new PassThrough()
    res.statusCode = 503
    res.statusMessage = 'Business Priority Backoff'
    res.headers = {
      'content-type': 'application/json; charset=utf-8',
      'x-ascenda-business-priority': reason || 'backoff'
    }
    return res
  }

  function fakeRequest(callback, reason) {
    const req = new EventEmitter()
    let ended = false
    if (typeof callback === 'function') req.once('response', callback)
    req.write = function() { return true }
    req.setHeader = function() {}
    req.getHeader = function() { return undefined }
    req.removeHeader = function() {}
    req.setTimeout = function() { return req }
    req.flushHeaders = function() {}
    req.abort = function() { return req.destroy() }
    req.destroy = function(err) {
      if (err) process.nextTick(function() { req.emit('error', err) })
      return req
    }
    req.end = function() {
      if (ended) return req
      ended = true
      process.nextTick(function() {
        const res = syntheticResponse(reason)
        req.emit('response', res)
        res.end('{"ok":false,"error":"BUSINESS_PRIORITY_BACKOFF"}')
      })
      return req
    }
    return req
  }

  function callbackFrom(args) {
    for (let i = args.length - 1; i >= 0; i--) if (typeof args[i] === 'function') return args[i]
    return null
  }

  https.request = function aosBusinessPriorityRequest() {
    const args = Array.prototype.slice.call(arguments)
    const key = classify(args[0])
    if (key && circuitOpen(key)) return fakeRequest(callbackFrom(args), EMERGENCY_SHED ? 'emergency-shed' : 'backoff')

    const req = inheritedRequest.apply(https, args)
    if (key && req && typeof req.once === 'function') {
      let failedByTransport = false
      req.once('response', function(res) {
        const status = Number(res && res.statusCode || 0)
        if (isFailureStatus(status)) markFailure(key, 'HTTP_' + status)
        else if (status >= 200 && status < 500) markSuccess(key)
      })
      function failOnce(reason) {
        if (failedByTransport) return
        failedByTransport = true
        markFailure(key, reason)
      }
      req.once('timeout', function() { failOnce('TIMEOUT') })
      req.once('error', function(e) { failOnce(e && e.code || e && e.message || 'ERROR') })
    }
    return req
  }

  // Route get() through the composed request export exactly once. This avoids
  // bypassing either the existing quota breaker or this background shield.
  https.get = function aosBusinessPriorityGet() {
    const req = https.request.apply(https, arguments)
    req.end()
    return req
  }

  global.__AOS_BUSINESS_PRIORITY_V1__ = {
    version: 'p0-a-v1.4',
    states: states,
    shieldKey: SHIELD_KEY,
    emergencyShed: EMERGENCY_SHED,
    classify: classify
  }

  console.log('[BUSINESS-PRIORITY] race-safe shared background shield active', { emergency_shed: EMERGENCY_SHED })
}
