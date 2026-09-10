'use strict'

const BASE = process.env.ASCENDA_PROD_BASE || 'https://ascenda-os-production.up.railway.app'
const FAKE_TOKEN = 'p0'.repeat(32)

function percentile(values, p) {
  if (!values.length) return 0
  const s = values.slice().sort((a,b)=>a-b)
  return s[Math.min(s.length-1, Math.floor((s.length-1)*p))]
}

async function request(path, init, timeoutMs=10000) {
  const started = Date.now()
  try {
    const res = await fetch(BASE + path, Object.assign({}, init || {}, { signal: AbortSignal.timeout(timeoutMs) }))
    const body = await res.text()
    return { ok: true, status: res.status, ms: Date.now()-started, body: body.slice(0,500) }
  } catch (err) {
    return { ok: false, status: 0, ms: Date.now()-started, error: String(err && err.message || err) }
  }
}

function assertNoTransportFailures(label, rows, allowedStatuses) {
  const transport = rows.filter(r=>!r.ok || r.status === 0)
  const server5xx = rows.filter(r=>r.status >= 500)
  const unexpected = rows.filter(r=>r.ok && !allowedStatuses.includes(r.status))
  if (transport.length) throw new Error(label + ' transport failures=' + JSON.stringify(transport.slice(0,3)))
  if (server5xx.length) throw new Error(label + ' 5xx=' + JSON.stringify(server5xx.slice(0,3)))
  if (unexpected.length) throw new Error(label + ' unexpected statuses=' + JSON.stringify(unexpected.slice(0,5)))
}

function summary(label, rows) {
  const ms = rows.map(r=>r.ms)
  const statuses = {}
  rows.forEach(r=>{statuses[r.status]=(statuses[r.status]||0)+1})
  const out = { label, n: rows.length, statuses, p50_ms: percentile(ms,.50), p95_ms: percentile(ms,.95), max_ms: Math.max(...ms) }
  console.log(JSON.stringify(out))
  return out
}

async function parallel(n, fn) {
  return Promise.all(Array.from({length:n}, (_,i)=>fn(i)))
}

async function sleep(ms){ return new Promise(r=>setTimeout(r,ms)) }

async function main() {
  console.log('P0_485_PROD_VALIDATION_START', { base: BASE, at: new Date().toISOString() })

  const root = await parallel(12, ()=>request('/', { method:'GET', headers:{'Cache-Control':'no-cache'} }, 10000))
  assertNoTransportFailures('root', root, [200,301,302,304])
  const rootSummary = summary('root-shell', root)
  if (rootSummary.p95_ms > 5000) throw new Error('root p95 too slow: '+rootSummary.p95_ms)

  const login = []
  for (let i=0;i<6;i++) {
    login.push(await request('/api/auth/v3/login', {
      method:'POST',
      headers:{'Content-Type':'application/json','Cache-Control':'no-store'},
      body:JSON.stringify({p_usuario:'p0-485-probe.invalid',p_password:'not-a-real-password'})
    }, 12000))
    await sleep(300)
  }
  assertNoTransportFailures('auth-login', login, [200,400,401,403,404,409,422,429])
  const loginSummary = summary('auth-v3-invalid-credential-path', login)
  if (loginSummary.max_ms >= 12000) throw new Error('login reached transport boundary')

  const waveSummaries = []
  for (let wave=1; wave<=3; wave++) {
    const rows = await parallel(50, ()=>request('/api/wa3/inbox?limit=1', {
      method:'GET',
      headers:{'X-AOS-App-Token':FAKE_TOKEN,'Cache-Control':'no-store'}
    }, 10000))
    assertNoTransportFailures('wa-wave-'+wave, rows, [403,429])
    const s = summary('wa-invalid-session-wave-'+wave, rows)
    if (s.p95_ms > 5000) throw new Error('WA wave '+wave+' p95 too slow: '+s.p95_ms)
    waveSummaries.push(s)
    await sleep(4000)
  }

  console.log('P0_485_RECURRENCE_OBSERVATION_WINDOW_MS', 35000)
  await sleep(35000)

  const finalWave = await parallel(50, ()=>request('/api/wa3/inbox?limit=1', {
    method:'GET',
    headers:{'X-AOS-App-Token':FAKE_TOKEN,'Cache-Control':'no-store'}
  }, 10000))
  assertNoTransportFailures('wa-final-wave', finalWave, [403,429])
  const finalSummary = summary('wa-post-negative-cache-expiry-wave', finalWave)
  if (finalSummary.p95_ms > 5000) throw new Error('WA final p95 too slow: '+finalSummary.p95_ms)

  const allWa = waveSummaries.concat([finalSummary])
  if (allWa.some(x=>Object.keys(x.statuses).some(s=>Number(s)>=500))) throw new Error('WA emitted 5xx')

  console.log('P0_485_PROD_VALIDATION_PASS', {
    at: new Date().toISOString(),
    auth_max_ms: loginSummary.max_ms,
    wa_waves: allWa,
    autonomous_dispatch_exercised: false,
    valid_human_session_used: false
  })
}

main().catch(err=>{console.error('P0_485_PROD_VALIDATION_FAIL', err);process.exit(1)})
