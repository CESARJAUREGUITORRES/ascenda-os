'use strict';

const fs = require('fs');
const vm = require('vm');
const assert = require('assert');

const source = fs.readFileSync('app/public/sentinel-inapp-notifications.js', 'utf8');
const storage = new Map([
  ['aos_app_token', 'a'.repeat(40)],
  ['sentinel_inapp_last_seen', '0']
]);
let fetchCalls = 0;
let intervals = [];
let focusHandlers = [];
let capturedAuth = '';

const sessionStorage = {
  getItem(k){ return storage.has(k) ? storage.get(k) : null; },
  setItem(k,v){ storage.set(k, String(v)); }
};

function element(){
  return {
    style:{}, classList:{remove(){}},
    setAttribute(){}, appendChild(){}, addEventListener(){},
    textContent:'', className:'', src:'', async:false, onerror:null
  };
}

const document = {
  readyState:'complete',
  head:{appendChild(){}},
  getElementById(){ return null; },
  querySelector(){ return null; },
  querySelectorAll(){ return []; },
  createElement(){ return element(); },
  addEventListener(){}
};

const window = {
  AOS_getCtx(){ return {role:'ADMIN', nivel:1}; },
  addEventListener(type, fn){ if(type === 'focus') focusHandlers.push(fn); }
};

async function fetchMock(_url, opts){
  fetchCalls++;
  capturedAuth = String(opts && opts.headers && opts.headers.Authorization || '');
  if(fetchCalls === 1){
    return {status:401, json:async()=>({ok:false,error:'jwt_rejected'})};
  }
  return {status:200, json:async()=>({ok:true,items:[],unread:0})};
}

const context = vm.createContext({
  window, document, sessionStorage,
  fetch:fetchMock,
  setInterval(fn, ms){ intervals.push({fn,ms}); return {fn,ms}; },
  setTimeout(fn){ fn(); return 1; },
  clearInterval(){},
  Promise, Array, Object, Number, String, Math, Date, JSON, console
});

function flush(){ return new Promise(resolve => setImmediate(resolve)); }

(async()=>{
  vm.runInContext(source, context, {filename:'sentinel-inapp-notifications.js'});
  await flush(); await flush();

  assert.strictEqual(fetchCalls, 1, 'initial poll must execute exactly once');
  assert.strictEqual(intervals.length, 1, 'only one recurrent poller may be registered');
  assert.strictEqual(intervals[0].ms, 15000, 'poll cadence contract changed unexpectedly');
  assert.strictEqual(focusHandlers.length, 1, 'only one focus listener may be registered');

  const bearer = capturedAuth.replace(/^Bearer\s+/,'');
  const parts = bearer.split('.');
  assert.strictEqual(parts.length, 3, 'Supabase bearer must be a JWT');
  const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  assert.strictEqual(payload.iss, 'supabase', 'Sentinel must use canonical Supabase JWT issuer');
  assert.strictEqual(payload.ref, 'ituyqwstonmhnfshnaqz', 'Sentinel JWT must target ASCENDA project');

  intervals[0].fn();
  focusHandlers[0]();
  await flush(); await flush();
  assert.strictEqual(fetchCalls, 1, '401/403 must open a no-network auth circuit');

  storage.set('aos_app_token', 'b'.repeat(40));
  intervals[0].fn();
  await flush(); await flush();
  assert.strictEqual(fetchCalls, 2, 'session change must re-arm the auth circuit');

  vm.runInContext(source, context, {filename:'sentinel-inapp-notifications-second-load.js'});
  await flush();
  assert.strictEqual(intervals.length, 1, 'duplicate script load must not create a second poller');
  assert.strictEqual(focusHandlers.length, 1, 'duplicate script load must not create a second focus listener');

  console.log('SENTINEL IN-APP CLIENT CONTRACT PASS');
})().catch(err=>{ console.error(err); process.exit(1); });
