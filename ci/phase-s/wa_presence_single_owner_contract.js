'use strict';
const fs=require('fs');
const assert=require('assert');

const shell=fs.readFileSync('app/public/wa-shell-integration.js','utf8');
const alerts=fs.readFileSync('app/public/wa-human-alerts.js','utf8');
const server=fs.readFileSync('app/server-wa3-v2.js','utf8');
const migration=fs.readFileSync('supabase/migrations/20260822224500_wa3_presence_handoff_final_v3.sql','utf8');

// Client singleton + 30s heartbeat remains within the DB's 60s freshness window.
assert(shell.includes('window.__AOS_WA_SHELL_INTEGRATION_V2__'), 'WA shell singleton missing');
assert(shell.includes('PRESENCE_HEARTBEAT_MS=30000'), 'WA presence heartbeat must be 30s');
assert(shell.includes('PRESENCE_BURST_GUARD_MS=10000'), 'WA client burst guard missing');
assert(shell.includes('presenceBusy'), 'WA presence in-flight guard missing');
assert(shell.includes('PRESENCE_AUTH_BACKOFF_MS=120000'), 'WA denied presence must back off');
assert(shell.includes('presenceDeniedUntil'), 'WA presence denied cooldown state missing');
assert(/now\(\)-interval '60 seconds'/.test(migration), 'DB presence freshness must remain 60s');

// Human alerts reuse native inbox in the WA panel. Outside WA, Web Push owns
// delivery so Call Center/Agenda never poll the full WhatsApp inbox in background.
assert(alerts.includes('var TICK_MS=5000'), 'human-alert local tick missing');
assert(alerts.includes("window.addEventListener('aos:wa3-inbox',consumeNativeInbox)"), 'human alerts must consume native inbox snapshots');
assert(alerts.includes('if(!isWaView())return;'), 'human alerts must be network-idle outside WA view');
assert(!alerts.includes("api('/api/wa3/inbox?limit=120')"), 'background full-inbox polling must remain disabled');
assert(alerts.includes("d.type!=='AOS_PUSH_EVENT'"), 'open-app Web Push event bridge missing');
assert(alerts.includes("toUpperCase()!=='WHATSAPP'"), 'Web Push sound bridge must stay WhatsApp-scoped');
assert(alerts.includes('AUTH_DENIED_BACKOFF_MS=120000'), 'WA alert bootstrap denied backoff missing');
assert(alerts.includes('authDeniedUntil'), 'WA alert auth cooldown state missing');

// Server keeps auth validation per request, but coalesces the expensive touch work.
assert(server.includes('const PRESENCE_COALESCE_MS=10000'), 'server presence coalescing window missing');
assert(server.includes('const presenceHeartbeats=new Map()'), 'server presence coalescing store missing');
assert(server.includes("const a=await requireActor(req,res,false)"), 'presence must retain strong actor validation');
assert(server.includes("serviceRpc('aos_wa3_agent_presence_touch_v1'"), 'presence touch authority missing');

const start=server.indexOf('async function presence(req,res)');
const end=server.indexOf('async function claimNext(req,res)');
assert(start>=0&&end>start, 'presence function boundaries missing');
const presenceBody=server.slice(start,end);
assert(!presenceBody.includes('queueSummary(a)'), 'presence heartbeat must not calculate redundant queue summary');
assert(presenceBody.includes('coalesced:true'), 'server must expose coalesced heartbeat result');

console.log('WA presence single-owner/perf contract: PASS');
