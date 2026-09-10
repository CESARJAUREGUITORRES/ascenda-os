'use strict'

const assert = require('assert')
const fs = require('fs')
const { createActorResolver, createSuccessCache, shouldRemapInnerAuth } = require('../../app/wa3-stability')

const TOKEN_A = 'a'.repeat(64)
const TOKEN_B = 'b'.repeat(64)
const TOKEN_C = 'c'.repeat(64)
const ACTOR = { ok: true, actor_id: '11111111-1111-4111-8111-111111111111', is_admin: true }

async function actorContracts() {
  let okCalls = 0
  const ok = createActorResolver({ okTtlMs: 5000, denyTtlMs: 30000, verify: async function() {
    okCalls++
    await new Promise(function(resolve) { setTimeout(resolve, 3) })
    return ACTOR
  } })
  const many = await Promise.all(Array.from({ length: 100 }, function() { return ok.resolve(TOKEN_A) }))
  assert.strictEqual(okCalls, 1, '100 concurrent actor reads must coalesce to one upstream verification')
  many.forEach(function(a) { assert.strictEqual(a.actor_id, ACTOR.actor_id) })
  await ok.resolve(TOKEN_A)
  assert.strictEqual(okCalls, 1, 'positive actor verification must use the short cache')

  let denyCalls = 0
  const deny = createActorResolver({ okTtlMs: 5000, denyTtlMs: 30000, verify: async function() { denyCalls++; return null } })
  for (let i = 0; i < 50; i++) assert.strictEqual(await deny.resolve(TOKEN_B), null)
  assert.strictEqual(denyCalls, 1, 'definitive stale/invalid session must be negative-cached')

  let failCalls = 0
  const fail = createActorResolver({ verify: async function() { failCalls++; throw new Error('upstream unavailable') } })
  const firstWave = await Promise.allSettled(Array.from({ length: 50 }, function() { return fail.resolve(TOKEN_C) }))
  assert.strictEqual(failCalls, 1, 'concurrent upstream failure must still coalesce')
  firstWave.forEach(function(r) {
    assert.strictEqual(r.status, 'rejected')
    assert.strictEqual(r.reason.message, 'WA3_AUTH_UPSTREAM_UNAVAILABLE')
    assert.strictEqual(r.reason.status, 503)
  })
  await assert.rejects(fail.resolve(TOKEN_C), /WA3_AUTH_UPSTREAM_UNAVAILABLE/)
  assert.strictEqual(failCalls, 2, 'upstream failure must never be cached as an auth denial')
}

async function summaryCacheContracts() {
  let loads = 0
  const cache = createSuccessCache({ ttlMs: 10000 })
  const values = await Promise.all(Array.from({ length: 200 }, function() {
    return cache.get('team:admin', async function() { loads++; await new Promise(function(resolve) { setTimeout(resolve, 2) }); return { ok: true, agents: [] } })
  }))
  assert.strictEqual(loads, 1, '200 supervisor summary reads must coalesce to one loader')
  values.forEach(function(v) { assert.strictEqual(v.ok, true) })
  await cache.get('team:admin', async function() { loads++; return { ok: true } })
  assert.strictEqual(loads, 1, 'supervisor summary success cache must prevent immediate refetch')
}

function sourceContracts() {
  const server = fs.readFileSync('app/server-wa3-v2.js', 'utf8')
  const perf = fs.readFileSync('app/public/wa-performance-hardening.js', 'utf8')
  const lock = fs.readFileSync('docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md', 'utf8')

  for (const token of [
    "error:'WA3_AUTH_UPSTREAM_UNAVAILABLE'",
    'createActorResolver',
    "queueCache=createSuccessCache({ttlMs:10000",
    "teamCache=createSuccessCache({ttlMs:20000",
    'shouldRemapInnerAuth',
    "const limit=read?240:120",
    "if(p.startsWith('/api/wa3/'))"
  ]) assert(server.includes(token), 'server stability token missing: ' + token)

  for (const token of [
    'visible:8000,hidden:60000',
    'visible:12000,hidden:60000',
    'visible:20000,hidden:60000',
    'AUTH_BACKOFF_MS=120000',
    'Math.min(60000,15000*Math.pow(2,x.count-1))',
    'WhatsApp Hub temporalmente no disponible',
    "WA3_AUTH_UPSTREAM_UNAVAILABLE",
    'transient_auth_remaps'
  ]) assert(perf.includes(token), 'browser stability token missing: ' + token)

  assert(lock.includes('P0 #485'), 'workstream lock must point to P0 #485')
  assert(lock.includes('AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF'), 'SAFE-OFF lock missing')
  assert(lock.includes('L10 CANARY:** `NOT AUTHORIZED DURING P0`'), 'CANARY prohibition missing')

  assert.strictEqual(shouldRemapInnerAuth(403, JSON.stringify({ error: 'WA3_2FA_PANEL_REQUIRED' }), true), true)
  assert.strictEqual(shouldRemapInnerAuth(403, JSON.stringify({ error: 'WA3_ADMIN_REQUIRED' }), true), false)
  assert.strictEqual(shouldRemapInnerAuth(503, JSON.stringify({ error: 'WA3_2FA_PANEL_REQUIRED' }), true), false)
  assert.strictEqual(shouldRemapInnerAuth(403, JSON.stringify({ error: 'WA3_2FA_PANEL_REQUIRED' }), false), false)
}

async function main() {
  await actorContracts()
  await summaryCacheContracts()
  sourceContracts()
  console.log('P0_485_STABILITY_CONTRACT_PASS')
}

main().catch(function(err) { console.error(err); process.exit(1) })
