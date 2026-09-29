'use strict'

/*
 * ASCENDA OS · Business Priority Mode P0-A
 *
 * Classified Supabase background traffic must always yield to Auth, Call Center,
 * Agenda, Patients and governed commercial writes. Normal mode allows background
 * work while the database is healthy, but gives every classified background
 * request a strict transport budget. A slow/failed background request opens a
 * shared circuit so more cron/push/cache work cannot pile up behind it.
 *
 * AOS_FOREGROUND_PRIORITY_MODE=true remains the emergency kill-switch: every
 * classified background call is rejected locally before network I/O. No reminder
 * cron exception is retained during an active DB-recovery incident; Auth wins.
 *
 * This preload is composed AFTER supabase-quota-circuit-preload.cjs in Railway
 * NODE_OPTIONS. Critical traffic remains outside classify() and therefore never
 * passes through this background budget/circuit.
 */

const https = require('https')
const { EventEmitter } = require('events')
const { PassThrough } = require('stream')

if (!https.__AOS_BUSINESS_PRIORITY_PRELOAD_V1__) {
  https.__AOS_BUSINESS_PRIORITY_PRELOAD_V1__ = true

  const inheritedRequest = https.request.bind(https)
  const PROJECT_HOST = String(process.env.AOS_SUPABASE_HOST || 'ituyqwstonmhnfshnaqz.supabase.co').toLowerCase()
  const FOREGROUND_PRIORITY_MODE = /^(1|true|yes|on)$/i.test(String(process.env.AOS_FOREGROUND_PRIORITY_MODE || 'false'))
  const rawBudget = Number(process.env.AOS_BACKGROUND_REQUEST_BUDGET_MS || 1800)
  const BACKGROUND_REQUEST_BUDGET_MS = Number.isFinite(rawBudget) ? Math.max(500, Math.min(5000, Math.round(rawBudget))) : 1800
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
    if (p.indexOf('/rest/v1/rpc/aos_push_vapid_config_v1') === 0) return 'notification-vapid-config'
    if (p.indexOf('/rest/v1/rpc/aos_push_vapid_store_v1') === 0) return 'notification-vapid-store'
    if (p.indexOf('/rest/v1/rpc/aos_push_vapid_runtime_config_v2') === 0) return 'notification-vapid-runtime-config'
    if (p.indexOf('/rest/v1/rpc/aos_google_claim_sync_v1') === 0) return 'google-sync-claim'
    if (p.indexOf('/rest/v1/aos_f5_private_file_transport_tmp?') === 0 && p.indexOf('status=in.(READY,PROCESSING)') >= 0) return 'f5-recovery-scan'
    if (p.indexOf('/rest/v1/aos_email_plantillas?') === 0 && p.indexOf('activo=eq.true') >= 0) return 'email-template-cache'
    if (p.indexOf('/rest/v1/aos_usuarios?') === 0 && p.indexOf('select=nombre,apellidos,cmp') >= 0 && p.indexOf('cmp=neq.') >= 0) return 'medical-cmp-cache'
    if (p.indexOf('/rest/v1/rpc/aos_generar_snapshot') === 0) return 'global-snapshot'
    if (p.indexOf('/rest/v1/aos_configuracion?') === 0 && (p.indexOf('select=clave%2Cvalor') >= 0 || p.indexOf('select=clave,valor') >= 0)) return 'brand-config-cache'

    // WA4 provider/bootstrap reads are optional while Auth/REST is recovering.
    // They previously continued every startup/retry cycle and were observed as
    // repeated 504s immediately alongside login failures. Match only read-shaped
    // catalog/secret lookups; governed WA writes and conversation RPCs stay live.
    if (p.indexOf('/rest/v1/aos_integration_secrets_v1?') === 0) return 'wa4-provider-secret-cache'
    if (p.indexOf('/rest/v1/aos_integraciones?') === 0 && p.indexOf('select=api_key') >= 0) return 'wa4-provider-fallback-cache'
    if (p.indexOf('/rest/v1/aos_wa_auto_authority_v1?select=mode') === 0) return 'wa4-authority-bootstrap'
    if (p.indexOf('/rest/v1/aos_wa_ai_control_v1?select=copilot_enabled') === 0) return 'wa4-ai-bootstrap'
    if (p.indexOf('/rest/v1/aos_wa_routing_control_v1?select=ai_send_enabled') === 0) return 'wa4-routing-bootstrap'
    return ''
  }

  function limaHour() {
    const forced = Number(process.env.AOS_TEST_LIMA_HOUR)
    if (Number.isInteger(forced) && forced >= 0 && forced <= 23) return forced
    return (new Date().getUTCHours() + 19) % 24
  }

  function isReminderWindow(hour) {
    return (hour >= 8 && hour <= 11) || (hour >= 20 && hour <= 23)
  }

  function isForegroundEssential() {
    return false
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
    return status === 408 || status === 429 || status >= 500
  }

  function markSuccess(key) {
    if (!key) return
    const k = keyState(key)
    k.failures = 0
    k.lastSuccessAt = Date.now()
  }

  function markFailure(key, reason) {
    if (!key) return
    const now = Date.now()
    const s = shieldState()
    const k = keyState(key)
    k.failures += 1
    k.lastFailureAt = now
    const wait = k.failures >= 2 ? 1800000 : 600000
    s.lastKey = key
    s.openUntil = Math.max(s.openUntil, now + wait)
    if (now >= s.lastLogUntil) {
      s.lastLogUntil = s.openUntil
      console.warn('[BUSINESS-PRIORITY] background shield open', { source: key, wait_ms: wait, failures: k.failures, reason: String(reason || 'upstream') })
    }
  }

  function circuitOpen(key) {
    return !!key && Date.now() < shieldState().openUntil
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
    if (key && FOREGROUND_PRIORITY_MODE) return fakeRequest(callbackFrom(args))

    const req = inheritedRequest.apply(https, args)
    if (key && req && typeof req.once === 'function') {
      let failedByTransport = false
      let budgetTimer = null
      function clearBudget() {
        if (budgetTimer) {
          clearTimeout(budgetTimer)
          budgetTimer = null
        }
      }
      function failOnce(reason) {
        if (failedByTransport) return
        failedByTransport = true
        markFailure(key, reason)
      }
      budgetTimer = setTimeout(function() {
        failOnce('BACKGROUND_BUDGET_EXCEEDED')
        try { req.destroy(Object.assign(new Error('AOS_BACKGROUND_BUDGET_EXCEEDED'), { code: 'AOS_BACKGROUND_BUDGET_EXCEEDED' })) } catch (_) {}
      }, BACKGROUND_REQUEST_BUDGET_MS)
      if (budgetTimer && typeof budgetTimer.unref === 'function') budgetTimer.unref()

      req.once('response', function(res) {
        clearBudget()
        const status = Number(res && res.statusCode || 0)
        if (isFailureStatus(status)) markFailure(key, 'HTTP_' + status)
        else if (status >= 200 && status < 500) markSuccess(key)
      })
      req.once('timeout', function() { clearBudget(); failOnce('TIMEOUT') })
      req.once('error', function(e) { clearBudget(); failOnce(e && e.code || e && e.message || 'ERROR') })
      req.once('close', clearBudget)
    }
    return req
  }

  https.get = function aosBusinessPriorityGet() {
    const req = https.request.apply(https, arguments)
    req.end()
    return req
  }

  global.__AOS_BUSINESS_PRIORITY_V1__ = {
    version: 'p0-a-v2.1-auth-first-wa-bootstrap-shed',
    states: states,
    shieldKey: SHIELD_KEY,
    classify: classify,
    circuitOpen: circuitOpen,
    foregroundPriorityMode: FOREGROUND_PRIORITY_MODE,
    backgroundRequestBudgetMs: BACKGROUND_REQUEST_BUDGET_MS,
    isForegroundEssential: isForegroundEssential,
    isReminderWindow: isReminderWindow,
    limaHour: limaHour
  }

  console.log('[BUSINESS-PRIORITY] auth-first background shield active', {
    foregroundPriorityMode: FOREGROUND_PRIORITY_MODE,
    backgroundRequestBudgetMs: BACKGROUND_REQUEST_BUDGET_MS,
    emergencyBackgroundLane: 'NONE',
    notificationPump: FOREGROUND_PRIORITY_MODE ? 'PAUSED' : 'BUDGETED',
    reminderCron: FOREGROUND_PRIORITY_MODE ? 'PAUSED' : 'BUDGETED',
    waBootstrap: FOREGROUND_PRIORITY_MODE ? 'PAUSED' : 'BUDGETED'
  })
}
