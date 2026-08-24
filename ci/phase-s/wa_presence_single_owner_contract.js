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
assert(/now\(\)-interval '60 seconds'/.test(migration), 'DB presence freshness must remain 60s');

// Human alerts reuse the native inbox while the WA panel owns freshness.
assert(alerts.includes('var TICK_MS=5000'), 'human-alert fallback tick must be 5s');
assert(alerts.includes("window.addEventListener('aos:wa3-inbox',consumeNativeInbox)"), 'human alerts must consume native inbox snapshots');
assert(alerts.includes('if(isWaView())'), 'human alerts must suppress duplicate inbox polling in WA view');
assert(alerts.includes("api('/api/wa3/inbox?limit=120')"), 'fallback inbox polling must remain available outside WA view');

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
