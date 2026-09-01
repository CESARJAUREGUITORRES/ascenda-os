'use strict';

const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('fs');
const vm=require('vm');

const preload=fs.readFileSync('app/business-priority-preload.js','utf8');
const bootstrap=fs.readFileSync('app/bootstrap-business-priority.js','utf8');
const browser=fs.readFileSync('app/public/browser-business-priority-v1.js','utf8');
const f4=fs.readFileSync('app/public/f4-production-canary-hotfix.js','utf8');
const pkg=JSON.parse(fs.readFileSync('app/package.json','utf8'));

for(const [name,src] of [['preload',preload],['bootstrap',bootstrap],['browser',browser],['f4',f4]]){
  test(name+' syntax',()=>assert.doesNotThrow(()=>new Function(src)));
}

test('Railway starts through inherited priority bootstrap',()=>{
  assert.equal(pkg.scripts.start,'node bootstrap-business-priority.js');
  assert.match(bootstrap,/process\.env\.NODE_OPTIONS/);
  assert.match(bootstrap,/require\('\.\/server-f17\.js'\)/);
});

test('server background breaker is narrowly scoped',()=>{
  const https=require('https');
  const oldReq=https.request,oldGet=https.get,oldFlag=https.__AOS_BUSINESS_PRIORITY_PRELOAD_V1__;
  delete https.__AOS_BUSINESS_PRIORITY_PRELOAD_V1__;
  delete global.__AOS_BUSINESS_PRIORITY_V1__;
  const module={exports:{}};
  vm.runInNewContext(preload,{require,process,console,global,module,exports:module.exports,URL,setTimeout,clearTimeout,Buffer},{filename:'business-priority-preload.js'});
  const classify=global.__AOS_BUSINESS_PRIORITY_V1__.classify;
  assert.equal(classify({hostname:'ituyqwstonmhnfshnaqz.supabase.co',path:'/rest/v1/aos_agentes?activo=eq.true&tipo_ejecucion=eq.cron'}),'agent-cron-scan');
  assert.equal(classify({hostname:'ituyqwstonmhnfshnaqz.supabase.co',path:'/rest/v1/rpc/aos_notification_push_claim_v1'}),'notification-push-claim');
  assert.equal(classify({hostname:'ituyqwstonmhnfshnaqz.supabase.co',path:'/rest/v1/rpc/aos_siguiente_lead'}),'');
  assert.equal(classify({hostname:'ituyqwstonmhnfshnaqz.supabase.co',path:'/rest/v1/rpc/aos_callcenter_commit_action_v1'}),'');
  assert.equal(classify({hostname:'ituyqwstonmhnfshnaqz.supabase.co',path:'/rest/v1/rpc/aos_wa3_actor_v1'}),'');
  https.request=oldReq;https.get=oldGet;
  if(oldFlag)https.__AOS_BUSINESS_PRIORITY_PRELOAD_V1__=oldFlag;else delete https.__AOS_BUSINESS_PRIORITY_PRELOAD_V1__;
  delete global.__AOS_BUSINESS_PRIORITY_V1__;
});

test('browser scheduler preserves governed writes and prioritizes next lead',()=>{
  assert.match(browser,/name==='aos_siguiente_lead'/);
  assert.match(browser,/\^aos_callcenter_\/\.test\(name\)/);
  assert.match(browser,/CALENDAR_MAX_CONCURRENCY=2/);
  assert.match(browser,/waitLeadBoundary\(5000\)/);
  assert.match(browser,/aos_panel_asesor:1/);
  assert.match(browser,/aos_monitoreo_equipo:1/);
  assert.match(browser,/aos_historico_asesor_anual:1/);
  assert.doesNotMatch(browser,/aos_callcenter_commit_action_v1\s*:/);
  assert.doesNotMatch(browser,/aos_callcenter_confirm_queue_appointment_v1\s*:/);
});

test('F4 loads priority scheduler without changing Loop6 postload authority',()=>{
  assert.match(f4,/browser-business-priority-v1\.js\?v=20260901-p0-bc-v1/);
  assert.match(f4,/calls-loop6\.js\?v=20260901-loop6-v2\.3-postload/);
  assert.match(f4,/window\.__AOS_CC_LOOP6_POSTLOAD_READY__='v2\.3-postload'/);
  assert.match(f4,/loadCallCenterPerformance\(\)/);
});
