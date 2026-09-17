'use strict'
const fs=require('fs')
function read(p){return fs.readFileSync(p,'utf8')}
function ok(v,m){if(!v){console.error('CIA PACK-B CONTRACT FAIL:',m);process.exit(1)}}
const shell=read('app/public/clinic-shell-ui-v1.js')
const center=read('app/public/cia-audience-control-center-v1.js')
const perf=read('app/public/calls-performance-v1.js')
const q=read('app/public/cia-queue-gateway-v1.js')
ok(shell.includes('/cia-audience-control-center-v1.js?v=20260917-1'),'Audience Control Center loader missing')
ok(center.includes("rpc('COUNT'")&&center.includes("rpc('PREVIEW'")&&center.includes('limit:25'),'explicit bounded resolver UX missing')
ok(center.includes("rpc('CREATE_AUDIENCE'")&&center.includes("rpc('LIST_AUDIENCES'"),'Audience Library path missing')
ok(center.includes("rpc('START_CANARY_ASSIGNMENT'")&&center.includes('source_limit:1'),'one-contact human canary guard missing')
ok(perf.includes("fn==='aos_siguiente_lead_v2'?'aos_siguiente_lead_v3':fn"),'advisor selector does not route through V3')
ok(perf.includes("var coalesceOnly=actual==='aos_siguiente_lead_v3'"),'V3 selector single-flight missing')
ok(q.includes("h.delete('Prefer')"),'queue RPC compatibility must strip legacy Prefer header')
ok(!center.includes('setInterval('),'Audience Control Center must not poll')
console.log('CIA PACK-B canary readiness contract: PASS')
