'use strict'

const crypto = require('crypto')

function tokenKey(token) {
  return crypto.createHash('sha256').update(String(token || '')).digest('hex').slice(0, 32)
}

function createActorResolver(opts) {
  opts = opts || {}
  const verify = opts.verify
  if (typeof verify !== 'function') throw new Error('WA3_VERIFY_REQUIRED')
  const okTtlMs = Math.max(1000, Number(opts.okTtlMs || 5000))
  const denyTtlMs = Math.max(1000, Number(opts.denyTtlMs || 30000))
  const maxEntries = Math.max(10, Number(opts.maxEntries || 1000))
  const cache = new Map()
  const inflight = new Map()

  function prune(now) {
    if (cache.size <= maxEntries) return
    for (const [k, v] of cache) {
      if (!v || now >= v.expiresAt) cache.delete(k)
      if (cache.size <= maxEntries) break
    }
    while (cache.size > maxEntries) cache.delete(cache.keys().next().value)
  }

  async function resolve(token) {
    const t = String(token || '').trim()
    if (t.length < 32) return null
    const key = tokenKey(t)
    const now = Date.now()
    const hit = cache.get(key)
    if (hit && now < hit.expiresAt) return hit.actor
    if (hit) cache.delete(key)
    if (inflight.has(key)) return inflight.get(key)

    const p = Promise.resolve()
      .then(function() { return verify(t) })
      .then(function(actor) {
        const good = actor && actor.ok === true && typeof actor.actor_id === 'string'
        cache.set(key, { actor: good ? actor : null, expiresAt: Date.now() + (good ? okTtlMs : denyTtlMs) })
        prune(Date.now())
        return good ? actor : null
      })
      .catch(function(err) {
        const e = new Error('WA3_AUTH_UPSTREAM_UNAVAILABLE')
        e.status = 503
        e.cause = err
        throw e
      })
      .finally(function() { inflight.delete(key) })
    inflight.set(key, p)
    return p
  }

  function invalidate(token) {
    const t = String(token || '').trim()
    if (t) cache.delete(tokenKey(t))
    else cache.clear()
  }

  return { resolve, invalidate, cache, inflight, okTtlMs, denyTtlMs }
}

function createSuccessCache(opts) {
  opts = opts || {}
  const ttlMs = Math.max(250, Number(opts.ttlMs || 5000))
  const maxEntries = Math.max(10, Number(opts.maxEntries || 1000))
  const cache = new Map()
  const inflight = new Map()

  async function get(key, loader) {
    const k = String(key || '')
    const now = Date.now()
    const hit = cache.get(k)
    if (hit && now - hit.at < ttlMs) return hit.value
    if (hit) cache.delete(k)
    if (inflight.has(k)) return inflight.get(k)
    const p = Promise.resolve()
      .then(loader)
      .then(function(value) {
        cache.set(k, { at: Date.now(), value: value })
        while (cache.size > maxEntries) cache.delete(cache.keys().next().value)
        return value
      })
      .finally(function() { inflight.delete(k) })
    inflight.set(k, p)
    return p
  }

  function clear(key) {
    if (key == null) cache.clear()
    else cache.delete(String(key))
  }

  return { get, clear, cache, inflight, ttlMs }
}

function shouldRemapInnerAuth(status, body, prevalidated) {
  if (!prevalidated || Number(status) !== 403) return false
  let data = body
  if (Buffer.isBuffer(data)) data = data.toString('utf8')
  if (typeof data === 'string') {
    try { data = JSON.parse(data) } catch (_) { return false }
  }
  return !!(data && data.error === 'WA3_2FA_PANEL_REQUIRED')
}

module.exports = { tokenKey, createActorResolver, createSuccessCache, shouldRemapInnerAuth }
