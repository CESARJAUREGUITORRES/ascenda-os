'use strict'

/*
 * ASCENDA OS · Business Priority Mode P0-A
 *
 * Scope is deliberately tiny: only known background Supabase traffic is
 * circuit-broken. Revenue-critical reads/writes, Call Center, Agenda, Sales
 * and WhatsApp routing are never classified here and therefore pass through
 * unchanged.
 *
 * This preload is composed AFTER supabase-quota-circuit-preload.cjs in
 * Railway NODE_OPTIONS. The inherited request function therefore preserves
 * the existing project-wide 402 quota breaker while this layer adds a
 * separate 5xx/timeout backoff only for background traffic.
 */

const https = require('https')
const { EventEmitter } = require('events')
const { PassThrough } = require('stream')

if (!https.__AOS_BUSINESS_PRIORITY_PRELOAD_V1__) {
  https.__AOS_BUSINESS_PRIORITY_PRELOAD_V1__ = true

  const inheritedRequest = https.request.bind(https)
  const PROJECT_HOST = String(process.env.AOS_SUPABASE_HOST || 'ituyqwstonmhnfshnaqz.supabase.co').toLowerCase()
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
    if (t.path.indexOf('/rest/v1/aos_agentes?') === 0 && t.path.indexOf('tipo_ejecucion=eq.cron') >= 0) return 'agent-cron-scan'
    if (t.path.indexOf('/rest/v1/rpc/aos_notification_push_claim_v1') === 0) return 'notification-push-claim'
    return ''
  }

  function stateFor(key) {
    if (!states.has(key)) states.set(key, { failures: 0, openUntil: 0, lastLogUntil: 0 })
    return states.get(key)
  }

  function isFailureStatus(status) {
    status = Number(status || 0)
    return status === 401 || status === 403 || status === 408 || status === 429 || status >= 500
  }

  function markSuccess(key) {
    if (!key) return
    const s = stateFor(key)
    s.failures = 0
    s.openUntil = 0
    s.lastLogUntil = 0
  }

  function markFailure(key, reason) {
    if (!key) return
    const s = stateFor(key)
    s.failures += 1
    const wait = s.failures >= 3 ? 600000 : (s.failures === 2 ? 120000 : 30000)
    s.openUntil = Math.max(s.openUntil, Date.now() + wait)
    if (Date.now() >= s.lastLogUntil) {
      s.lastLogUntil = s.openUntil
      console.warn('[BUSINESS-PRIORITY] background backoff', { key: key, wait_ms: wait, failures: s.failures, reason: String(reason || 'upstream') })
    }
  }

  function circuitOpen(key) {
    if (!key) return false
    return Date.now() < stateFor(key).openUntil
  }

  function syntheticResponse() {
    const res = new PassThrough()
    res.statusCode = 503
    res.statusMessage = 'Business Priority Backoff'
    res.headers = { 'content-type': 'application/json; charset=utf-8', 'x-ascenda-business-priority': 'backoff' }
    return res
  }

  function fakeRequest(callback) {
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
        const res = syntheticResponse()
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
    if (key && circuitOpen(key)) return fakeRequest(callbackFrom(args))

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
  // bypassing either the existing quota breaker or this background breaker.
  https.get = function aosBusinessPriorityGet() {
    const req = https.request.apply(https, arguments)
    req.end()
    return req
  }

  global.__AOS_BUSINESS_PRIORITY_V1__ = {
    version: 'p0-a-v1.1',
    states: states,
    classify: classify
  }

  console.log('[BUSINESS-PRIORITY] scoped background circuit breaker active')
}
