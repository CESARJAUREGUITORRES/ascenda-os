'use strict';

const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('fs');
const vm=require('vm');
const {EventEmitter}=require('events');

const preload=fs.readFileSync('app/business-priority-preload.js','utf8');

function boot(env){
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
  const localProcess={env:Object.assign({},env),nextTick:process.nextTick.bind(process)};
  const customRequire=function(id){return id==='https'?fakeHttps:require(id);};
  const module={exports:{}};
  vm.runInNewContext(preload,{require:customRequire,process:localProcess,console,global:localGlobal,module,exports:module.exports,URL,setTimeout,clearTimeout,Buffer},{filename:'business-priority-preload.js'});
  return {https:fakeHttps,runtime:localGlobal.__AOS_BUSINESS_PRIORITY_V1__,baseCalls:()=>baseCalls};
}

test('foreground-priority mode suppresses only classified background traffic before network IO',()=>{
  const h=boot({AOS_FOREGROUND_PRIORITY_MODE:'true'});
  const host='ituyqwstonmhnfshnaqz.supabase.co';
  assert.equal(h.runtime.foregroundPriorityMode,true);

  const background=[
    {hostname:host,path:'/rest/v1/aos_agentes?activo=eq.true&tipo_ejecucion=eq.cron'},
    {hostname:host,path:'/rest/v1/rpc/aos_notification_push_claim_v1'},
    {hostname:host,path:'/rest/v1/aos_email_plantillas?select=tipo,html_body&activo=eq.true'},
    {hostname:host,path:'/rest/v1/aos_usuarios?select=nombre,apellidos,cmp&area=eq.médica&cmp=neq.'},
    {hostname:host,path:'/rest/v1/rpc/aos_generar_snapshot'},
    {hostname:host,path:'/rest/v1/aos_configuracion?select=clave%2Cvalor'}
  ];
  background.forEach(function(opts){const r=h.https.request(opts,function(){});r.end();});
  assert.equal(h.baseCalls(),0,'incident mode must keep classified background work off Supabase');

  h.https.request({hostname:host,path:'/rest/v1/rpc/aos_login_v3'},function(){});
  h.https.request({hostname:host,path:'/rest/v1/rpc/aos_callcenter_commit_action_v1'},function(){});
  h.https.request({hostname:host,path:'/rest/v1/rpc/aos_wa3_actor_v1'},function(){});
  h.https.request({hostname:host,path:'/rest/v1/aos_integraciones?select=tipo,api_key&tipo=in.(groq,gemini)'},function(){});
  assert.equal(h.baseCalls(),4,'auth and business-critical traffic must remain on the real transport');
});

test('normal mode preserves existing shared circuit semantics',()=>{
  const h=boot({AOS_FOREGROUND_PRIORITY_MODE:'false'});
  const host='ituyqwstonmhnfshnaqz.supabase.co';
  assert.equal(h.runtime.foregroundPriorityMode,false);
  h.https.request({hostname:host,path:'/rest/v1/rpc/aos_generar_snapshot'},function(){});
  assert.equal(h.baseCalls(),1,'normal mode must not hard-suppress background traffic before a failure');
});
