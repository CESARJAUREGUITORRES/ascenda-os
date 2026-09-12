'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');

function read(p){return fs.readFileSync(p,'utf8');}
const runtime=read('app/conversation-agent-runtime.js');
const lock=read('docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md');
const l2=read('docs/control/ASCENDA_CONVERSATIONS_L2_READINESS_CURRENT.md');
const l3=read('docs/control/ASCENDA_CONVERSATIONS_L3_READINESS_CURRENT.md');
const contracts=read('docs/control/ASCENDA_CONVERSATIONS_TARGET_CONTRACTS_V1.md');
const benchmark=read('docs/control/ASCENDA_CONVERSATIONS_BENCHMARK_V1.md');

assert(runtime.includes("VERSION='CONV-L3-V1'"),'L3 runtime version missing');
assert(runtime.includes('createAgentRuntime'),'AgentRuntime implementation missing');
assert(runtime.includes('createToolGateway'),'typed ToolGateway boundary missing');
assert(runtime.includes('MAX_TOOL_CALLS=2'),'0-2 tool budget missing');
assert(runtime.includes('SINGLE_FLIGHT_BUSY'),'single-flight suppression missing');
assert(runtime.includes('STALE_TURN'),'stale turn suppression missing');
assert(runtime.includes('HUMAN_TAKEOVER_RACE'),'human takeover race suppression missing');
assert(runtime.includes('STOP_OBSERVED'),'STOP gate missing');
assert(runtime.includes('PERSONALIZED_CLINICAL'),'clinical handoff missing');
assert(runtime.includes('providerDispatch:false'),'provider dispatch must remain structurally disabled');
for(const forbidden of ['graph.facebook.com','WHATSAPP_ACCESS_TOKEN','execute_sql','child_process','supabase.co/rest/v1']){
  assert(!runtime.includes(forbidden),'forbidden L3 authority: '+forbidden);
}
assert(lock.includes('CONV-L3 #507 — SALES AGENT RUNTIME'),'L3 active lock missing');
assert(lock.includes('RUN UNTIL BLOCKED'),'owner execution mode missing');
assert(lock.includes('AUTO_OFF · KILL SWITCH ENGAGED · SAFE-OFF'),'SAFE-OFF marker missing');
assert(lock.includes('**LAST CLOSED:** `CONV-L2 #506'),'L2 closeout marker missing');
assert(l2.includes('CLOSED'),'L2 readiness must be closed before L3');
assert(l3.includes('ACTIVE · RUN UNTIL BLOCKED · SHADOW/OFFLINE ONLY'),'L3 shadow-only state missing');
assert(l3.includes('Autonomous provider send:** NOT AUTHORIZED'),'L3 provider boundary missing');
assert(contracts.includes('interface AgentRuntime'),'frozen AgentRuntime target contract missing');
assert(contracts.includes('get_prices')&&contracts.includes('create_hot_lead_signal'),'typed tool target contract missing');
assert(benchmark.includes('FROZEN V1 BY CONV-L0'),'benchmark freeze missing');
console.log('CONV_L3_CONTROL_CONTRACT_PASS');
