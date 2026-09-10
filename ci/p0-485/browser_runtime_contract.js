'use strict'

const fs = require('fs')
const vm = require('vm')
const assert = require('assert')

function boot(sequence) {
  const source = fs.readFileSync('app/public/wa-performance-hardening.js', 'utf8')
  let network = 0
  const listeners = {}
  const tokenValue = 't'.repeat(64)
  const baseFetch = async function(input) {
    network++
    const url = String(input)
    const next = sequence.shift() || { status: 200, body: { ok: true, url: url } }
    return new Response(JSON.stringify(next.body || {}), {
      status: next.status,
      headers: { 'content-type': 'application/json' }
    })
  }
  const window = {
    fetch: baseFetch,
    addEventListener: function(name, fn) { listeners['w:' + name] = fn },
    dispatchEvent: function() {}
  }
  const document = {
    hidden: false,
    addEventListener: function(name, fn) { listeners['d:' + name] = fn }
  }
  const sessionStorage = {
    getItem: function(k) { return k === 'aos_app_token' ? tokenValue : null }
  }
  const context = {
    window, document, sessionStorage,
    location: new URL('https://ascenda.test/app.html'),
    URL, Headers, Response, Map, Date, Promise, console,
    CustomEvent: class { constructor(type, opts) { this.type = type; this.detail = opts && opts.detail } }
  }
  vm.createContext(context)
  vm.runInContext(source, context)
  return { window, getNetwork: function() { return network } }
}

async function transientAuthIsServiceOutage() {
  const h = boot([
    { status: 200, body: { ok: true, rows: [] } },
    { status: 403, body: { ok: false, error: 'WA3_2FA_PANEL_REQUIRED' } }
  ])
  const ok = await h.window.fetch('/api/wa3/inbox?limit=120')
  assert.strictEqual(ok.status, 200)
  const before = h.getNetwork()
  const remapped = await h.window.fetch('/api/wa3/team-summary')
  assert.strictEqual(remapped.status, 503, '403 after a fresh verified WA call must be treated as upstream availability, not forced logout')
  const body = await remapped.json()
  assert.strictEqual(body.error, 'WA3_AUTH_UPSTREAM_UNAVAILABLE')
  assert.strictEqual(h.getNetwork(), before + 1)
  const backedOff = await h.window.fetch('/api/wa3/team-summary')
  assert.strictEqual(backedOff.status, 503)
  assert.strictEqual(h.getNetwork(), before + 1, 'retry during service backoff must not hit network')
  const stats = h.window.AOS_WA_PERF.stats()
  assert.strictEqual(stats.transient_auth_remaps, 1)
  assert(stats.backoff_hits >= 1)
}

async function definitiveAuthStopsZombieReads() {
  const h = boot([
    { status: 403, body: { ok: false, error: 'WA3_2FA_PANEL_REQUIRED' } }
  ])
  const first = await h.window.fetch('/api/wa3/inbox?limit=120')
  assert.strictEqual(first.status, 403)
  const before = h.getNetwork()
  for (let i = 0; i < 100; i++) {
    const r = await h.window.fetch('/api/wa3/team-summary')
    assert.strictEqual(r.status, 403)
  }
  assert.strictEqual(h.getNetwork(), before, 'definitive auth denial must locally back off stale/zombie GET traffic')
  assert(h.window.AOS_WA_PERF.stats().auth_backoff_hits >= 100)
}

async function main() {
  await transientAuthIsServiceOutage()
  await definitiveAuthStopsZombieReads()
  console.log('P0_485_BROWSER_RUNTIME_CONTRACT_PASS')
}

main().catch(function(err) { console.error(err); process.exit(1) })
