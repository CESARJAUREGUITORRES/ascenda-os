'use strict';

const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('fs');
const vm=require('vm');
const {EventEmitter}=require('events');

const preload=fs.readFileSync('app/business-priority-preload.js','utf8');

function harness(){
  const fakeHttps={};
  let baseCalls=0;
  fakeHttps.request=function(){
    baseCalls++;
    const req=new EventEmitter();
    req.write=function(){return true;};
    req.end=function(){return req;};
    req.setTimeout=function(){return req;};
    req.abort=function(){return req;};
    req.destroy=function(){return req;};
    return req;
  };
  fakeHttps.get=function(){const req=fakeHttps.request.apply(fakeHttps,arguments);req.end();return req;};
  const localGlobal={};
  const customRequire=function(id){return id==='https'?fakeHttps:require(id);};
  const module={exports:{}};
  vm.runInNewContext(preload,{require:customRequire,process,console,global:localGlobal,module,exports:module.exports,URL,setTimeout,clearTimeout,Buffer},{filename:'business-priority-preload.js'});
  return {fakeHttps,localGlobal,getBaseCalls:()=>baseCalls};
}

test('sibling success cannot close a shield opened by another background failure',()=>{
  const h=harness();
  const runtime=h.localGlobal.__AOS_BUSINESS_PRIORITY_V1__;
  const host='ituyqwstonmhnfshnaqz.supabase.co';
  const agent={hostname:host,path:'/rest/v1/aos_agentes?select=id&activo=eq.true&tipo_ejecucion=eq.cron'};
  const push={hostname:host,path:'/rest/v1/rpc/aos_notification_push_claim_v1'};

  // Reproduce the PROD race: a sibling request is already in flight when the
  // cron scan fails and opens the shared shield.
  const sibling=h.fakeHttps.request(push,function(){});
  const failing=h.fakeHttps.request(agent,function(){});
  assert.equal(h.getBaseCalls(),2);
  failing.emit('response',{statusCode:524});

  const shield=runtime.states.get(runtime.shieldKey);
  const openedUntil=shield.openUntil;
  assert.ok(openedUntil>Date.now());
  assert.equal(shield.lastKey,'agent-cron-scan');
  assert.equal(runtime.states.get('source:agent-cron-scan').failures,1);

  // The sibling succeeds after the failure. This used to clear openUntil and
  // allowed the next minute cron tick to hit Supabase again.
  sibling.emit('response',{statusCode:200});
  assert.equal(shield.openUntil,openedUntil,'unrelated success closed the shared cooldown');
  assert.equal(runtime.states.get('source:notification-push-claim').failures,0);

  const suppressed=h.fakeHttps.request(agent,function(){});
  suppressed.end();
  assert.equal(h.getBaseCalls(),2,'cron retry escaped an active shared cooldown');

  h.fakeHttps.request({hostname:host,path:'/rest/v1/rpc/aos_siguiente_lead'},function(){});
  h.fakeHttps.request({hostname:host,path:'/rest/v1/rpc/aos_callcenter_commit_action_v1'},function(){});
  h.fakeHttps.request({hostname:host,path:'/rest/v1/rpc/aos_wa3_actor_v1'},function(){});
  assert.equal(h.getBaseCalls(),5,'critical business traffic must remain outside the shield');
});
