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

const audit = read('docs/control/ASCENDA_CONVERSATIONS_L0_AUDIT_CURRENT.md')
const extraction = read('docs/control/ASCENDA_CONVERSATIONS_L0_EXTRACTION_MATRIX_CURRENT.md')
const authority = read('docs/control/ASCENDA_CONVERSATIONS_L0_AUTHORITY_MAP_CURRENT.md')
const contracts = read('docs/control/ASCENDA_CONVERSATIONS_TARGET_CONTRACTS_V1.md')
const benchmark = read('docs/control/ASCENDA_CONVERSATIONS_BENCHMARK_V1.md')

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
assert(wa3.includes("function graphSend("), 'WA3 direct provider sender evidence drifted')
assert(f4.includes("function graphSend("), 'F4 direct provider sender evidence drifted')

assert(panel.includes("setInterval(function(){heartbeat(false);},2500)"), '2.5s native inbox polling evidence drifted')

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

console.log('CONV_L0_AUDIT_CONTRACT_PASS')
