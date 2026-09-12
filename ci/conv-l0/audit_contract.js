'use strict'

const assert = require('assert')
const fs = require('fs')

function read(path) {
  return fs.readFileSync(path, 'utf8')
}

const railway = read('app/railway.json')
const outer = read('app/server-phase-s-f17.js')
const phaseS = read('app/server-phase-s.js')
const f17 = read('app/server-f17.js')
const wa4 = read('app/server-wa4.js')
const wa3v2 = read('app/server-wa3-v2.js')
const wa3 = read('app/server-wa3.js')
const wa2 = read('app/server-wa2.js')
const f4 = read('app/server-f4.js')
const panel = read('app/public/wa-native-panel.js')
const meta = read('app/meta-cloud-adapter.js')

const audit = read('docs/control/ASCENDA_CONVERSATIONS_L0_AUDIT_CURRENT.md')
const extraction = read('docs/control/ASCENDA_CONVERSATIONS_L0_EXTRACTION_MATRIX_CURRENT.md')
const authority = read('docs/control/ASCENDA_CONVERSATIONS_L0_AUTHORITY_MAP_CURRENT.md')
const contracts = read('docs/control/ASCENDA_CONVERSATIONS_TARGET_CONTRACTS_V1.md')
const benchmark = read('docs/control/ASCENDA_CONVERSATIONS_BENCHMARK_V1.md')
const lock = read('docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md')
const readiness = read('docs/control/ASCENDA_CONVERSATIONS_L0_READINESS_CURRENT.md')

assert(railway.includes('server-phase-s-f17.js'), 'Railway outer runtime evidence drifted')
assert(outer.includes("server-f5.js") && outer.includes("server-f17.js"), 'F17 spawn rewrite evidence drifted')
assert(phaseS.includes("['server-f5.js']"), 'Phase S child evidence drifted')
assert(f17.includes("['server-f5.js']"), 'F17 child evidence drifted')
assert(wa4.includes("['server-wa3-v2.js']"), 'WA4 child evidence drifted')
assert(wa3v2.includes("['server-wa3.js']"), 'WA3-v2 child evidence drifted')
assert(wa3.includes("['server-wa2.js']"), 'WA3 child evidence drifted')
assert(wa2.includes("['server-f4.js']"), 'WA2 child evidence drifted')
assert(f4.includes("['server-phase2.js']"), 'F4 child evidence drifted')

assert(f17.includes("url.pathname === '/api/wa/send'"), 'F17 WA send overlay evidence drifted')
assert(f17.includes("url.pathname === '/webhook'"), 'F17 webhook overlay evidence drifted')
assert(wa4.includes("p==='/webhook'"), 'WA4 webhook bridge evidence drifted')
assert(f4.includes("pathname==='/webhook'"), 'F4 webhook owner evidence drifted')
assert(!wa3.includes('graph.facebook.com'), 'WA3 must no longer own direct Meta transport after L1')
assert(!f4.includes('graph.facebook.com'), 'F4 must delegate Meta HTTPS to MetaCloudAdapter after L1')
assert(meta.includes('graph.facebook.com'), 'MetaCloudAdapter must own the Graph API transport')
assert(wa3.includes('/api/wa/meta/dispatch-internal'), 'WA3 compatibility send must route inward to MetaCloudAdapter boundary')
assert(f4.includes('/api/wa/meta/dispatch-internal'), 'F4 must expose the internal MetaCloudAdapter dispatch boundary')

assert(panel.includes("fetch('/api/wa3/events'") && panel.includes('scheduleFallback(30000)'), 'L2 event-driven replacement of audited polling is missing')

for (const token of ['REPLACE', 'PORT', 'RETIRE', 'KEEP']) {
  assert(extraction.includes(token), 'Extraction classification missing: ' + token)
}
assert(extraction.includes('No component above is deleted'), 'L0 destructive-delete prohibition missing')
assert(authority.includes('MetaCloudAdapter only'), 'Provider target authority missing')
assert(contracts.includes('interface ChannelAdapter'), 'ChannelAdapter contract missing')
assert(contracts.includes('interface ConversationCore'), 'ConversationCore contract missing')
assert(contracts.includes('interface AgentRuntime'), 'AgentRuntime contract missing')
assert(contracts.includes('interface OutboundPolicy'), 'OutboundPolicy contract missing')
assert(contracts.includes('interface ConversationJob'), 'JobOutbox contract missing')
assert(benchmark.includes('FROZEN V1 BY CONV-L0'), '40-case benchmark is not frozen')
assert(audit.includes('RC-1 — Deep proxy/process chain'), 'Root-cause audit missing')
assert(lock.includes('**ACTIVE HIGH/CRITICAL LOCK:**') && lock.includes('INT-GOOGLE-001') && lock.includes('GC-0/GC-1'), 'current sole HIGH/CRITICAL Google lock missing')
assert(lock.includes('CONV-001') && /PAUSED/i.test(lock), 'CONV-001 paused-lane evidence missing during Google lock')
assert(lock.includes('RUN UNTIL BLOCKED'), 'owner execution mode missing')
assert(readiness.includes('TECHNICAL PASS / CLOSED'), 'L0 technical closeout marker missing')
assert(readiness.includes('L1 OWNER AUTHORIZATION RECEIVED / ACTIVE'), 'L1 authorization transition missing')

console.log('CONV_L0_AUDIT_CONTRACT_PASS')
