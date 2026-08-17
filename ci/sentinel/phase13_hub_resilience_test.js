'use strict';
const fs=require('fs');const core=require('../../sentinel/hub/hub-core.cjs');
function ok(v,m){if(!v)throw new Error(m);}
const topo=JSON.parse(fs.readFileSync('app/public/sentinel-topology.v1.json','utf8'));
const NOW=Date.parse('2099-01-01T12:00:00Z');
function cap(model,d,c){return model.domains.find(x=>x.id===d).components.flatMap(x=>x.capabilities).find(x=>x.id===c);}
let m=core.composeHub(topo,[],{}, {nowMs:NOW});ok(cap(m,'WHATSAPP','human-outbound').state==='UNKNOWN','absence must be UNKNOWN');ok(m.summary.healthy===0,'absence must never become healthy');
const p0={incident_id:'SEN-2099-9301',severity:'P0',status:'OPEN',environment:'production',domain:'WHATSAPP',component:'wa',capability:'human-outbound',failure_family:'provider',updated_at:'2099-01-01T11:59:00Z'};
m=core.composeHub(topo,[p0],{}, {nowMs:NOW});ok(cap(m,'WHATSAPP','human-outbound').state==='CRITICAL','P0 must be CRITICAL');ok(m.domains.find(x=>x.id==='WHATSAPP').state==='CRITICAL','domain must inherit CRITICAL');
const p1={...p0,incident_id:'SEN-2099-9302',severity:'P1',domain:'CALL_CENTER',capability:'lead-queue'};m=core.composeHub(topo,[p1],{}, {nowMs:NOW});ok(cap(m,'CALL_CENTER','lead-queue').state==='INCIDENT','P1 must be INCIDENT');
const p2={...p0,incident_id:'SEN-2099-9303',severity:'P2',domain:'SALES',capability:'sales-ledger'};m=core.composeHub(topo,[p2],{}, {nowMs:NOW});ok(cap(m,'SALES','sales-ledger').state==='DEGRADED','P2 must be DEGRADED');
const resolved={...p0,status:'RESOLVED',resolved_at:'2099-01-01T11:58:00Z'};m=core.composeHub(topo,[resolved],{}, {nowMs:NOW});ok(cap(m,'WHATSAPP','human-outbound').state==='UNKNOWN','resolved incident cannot prove health');
let h={'AGENDA/appointment-calendar':{state:'HEALTHY',source_state:'AVAILABLE',observed_at:'2099-01-01T11:59:00Z'}};m=core.composeHub(topo,[],h,{nowMs:NOW,ttlMs:300000});ok(cap(m,'AGENDA','appointment-calendar').state==='HEALTHY','fresh explicit health should be healthy');
h={'AGENDA/appointment-calendar':{state:'HEALTHY',source_state:'AVAILABLE',observed_at:'2099-01-01T11:40:00Z'}};m=core.composeHub(topo,[],h,{nowMs:NOW,ttlMs:300000});ok(cap(m,'AGENDA','appointment-calendar').state==='UNKNOWN','stale health must be unknown');
for(const source of ['SENTRY','KUMA','COLLECTOR','SENTINEL_CORE']){h={'AGENDA/appointment-calendar':{state:'HEALTHY',source_state:'UNAVAILABLE',source,observed_at:'2099-01-01T11:59:00Z'}};m=core.composeHub(topo,[],h,{nowMs:NOW});ok(cap(m,'AGENDA','appointment-calendar').state==='UNKNOWN',source+' outage must not false-green');}
const providerA={'EMAIL/email-send':{state:'DEGRADED',source_state:'AVAILABLE',provider:'fixture-a',observed_at:'2099-01-01T11:59:30Z'}};const providerB={'EMAIL/email-send':{state:'DEGRADED',source_state:'AVAILABLE',provider:'fixture-b',observed_at:'2099-01-01T11:59:30Z'}};const a=core.composeHub(topo,[],providerA,{nowMs:NOW}),b=core.composeHub(topo,[],providerB,{nowMs:NOW});ok(cap(a,'EMAIL','email-send').state===cap(b,'EMAIL','email-send').state,'provider portability drift');
console.log('SENTINEL_F13_NO_FALSE_GREEN=PASS');
console.log('SENTINEL_F13_RESILIENCE=PASS');
console.log('SENTINEL_F13_PORTABILITY=PASS');
