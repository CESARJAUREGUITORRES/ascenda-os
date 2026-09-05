'use strict';

const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('fs');
const vm=require('vm');
const {EventEmitter}=require('events');

const preload=fs.readFileSync('app/business-priority-preload.js','utf8');

function harness(shed){
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
  const env=Object.assign({},process.env,{AOS_BACKGROUND_SHED:shed?'true':'false'});
  const localProcess=Object.create(process);localProcess.env=env;
  const localGlobal={};
  const customRequire=id=>id==='https'?fakeHttps:require(id);
  const module={exports:{}};
  vm.runInNewContext(preload,{require:customRequire,process:localProcess,console,global:localGlobal,module,exports:module.exports,URL,setTimeout,clearTimeout,Buffer},{filename:'business-priority-preload.js'});
  return {fakeHttps,localGlobal,get baseCalls(){return baseCalls;}};
}

test('classifier includes recurring snapshot/config work but never auth/business',()=>{
  const h=harness(false);
  const c=h.localGlobal.__AOS_BUSINESS_PRIORITY_V1__.classify;
  const host='ituyqwstonmhnfshnaqz.supabase.co';
  assert.equal(c({hostname:host,path:'/rest/v1/rpc/aos_generar_snapshot'}),'snapshot-refresh');
  assert.equal(c({hostname:host,path:'/rest/v1/aos_configuracion?select=clave%2Cvalor'}),'configuration-cache');
  assert.equal(c({hostname:host,path:'/rest/v1/aos_agentes?select=id&activo=eq.true&tipo_ejecucion=eq.cron'}),'agent-cron-scan');
  assert.equal(c({hostname:host,path:'/rest/v1/rpc/aos_login_v3'}),'');
  assert.equal(c({hostname:host,path:'/rest/v1/rpc/aos_siguiente_lead'}),'');
  assert.equal(c({hostname:host,path:'/rest/v1/rpc/aos_callcenter_commit_action_v1'}),'');
  assert.equal(c({hostname:host,path:'/rest/v1/rpc/aos_wa3_actor_v1'}),'');
});

test('emergency shed rejects classified background locally and preserves auth',async()=>{
  const h=harness(true);
  const host='ituyqwstonmhnfshnaqz.supabase.co';
  const runtime=h.localGlobal.__AOS_BUSINESS_PRIORITY_V1__;
  assert.equal(runtime.emergencyShed,true);

  let status=0,header='';
  const bg=h.fakeHttps.request({hostname:host,path:'/rest/v1/rpc/aos_generar_snapshot'},res=>{status=res.statusCode;header=res.headers['x-ascenda-business-priority'];});
  bg.end();
  await new Promise(r=>setTimeout(r,10));
  assert.equal(status,503);
  assert.equal(header,'emergency-shed');
  assert.equal(h.baseCalls,0,'shed background request must never reach Supabase transport');

  h.fakeHttps.request({hostname:host,path:'/rest/v1/rpc/aos_login_v3'},function(){});
  h.fakeHttps.request({hostname:host,path:'/rest/v1/rpc/aos_siguiente_lead'},function(){});
  assert.equal(h.baseCalls,2,'auth/business requests must bypass emergency shed');
});
