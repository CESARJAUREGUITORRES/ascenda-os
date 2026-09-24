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

test('foreground-priority hard recovery suppresses generic push and ordinary background traffic',()=>{
  const h=boot({AOS_FOREGROUND_PRIORITY_MODE:'true',AOS_TEST_LIMA_HOUR:'18'});
  const host='ituyqwstonmhnfshnaqz.supabase.co';
  assert.equal(h.runtime.foregroundPriorityMode,true);

  const blocked=[
    {hostname:host,path:'/rest/v1/aos_agentes?activo=eq.true&tipo_ejecucion=eq.cron'},
    {hostname:host,path:'/rest/v1/rpc/aos_notification_push_claim_v1'},
    {hostname:host,path:'/rest/v1/rpc/aos_push_vapid_config_v1'},
    {hostname:host,path:'/rest/v1/rpc/aos_push_vapid_store_v1'},
    {hostname:host,path:'/rest/v1/rpc/aos_google_claim_sync_v1'},
    {hostname:host,path:'/rest/v1/aos_f5_private_file_transport_tmp?status=in.(READY,PROCESSING)&select=source_filename,source_sha256,content_base64&order=source_filename.asc'},
    {hostname:host,path:'/rest/v1/aos_email_plantillas?select=tipo,html_body&activo=eq.true'},
    {hostname:host,path:'/rest/v1/aos_usuarios?select=nombre,apellidos,cmp&area=eq.médica&cmp=neq.'},
    {hostname:host,path:'/rest/v1/rpc/aos_generar_snapshot'},
    {hostname:host,path:'/rest/v1/aos_configuracion?select=clave%2Cvalor'}
  ];
  blocked.forEach(function(opts){const r=h.https.request(opts,function(){});r.end();});
  assert.equal(h.baseCalls(),0,'incident mode must keep background work off Supabase');

  h.https.request({hostname:host,path:'/rest/v1/rpc/aos_login_v3'},function(){});
  h.https.request({hostname:host,path:'/rest/v1/rpc/aos_callcenter_commit_action_v1'},function(){});
  h.https.request({hostname:host,path:'/rest/v1/rpc/aos_wa3_actor_v1'},function(){});
  h.https.request({hostname:host,path:'/rest/v1/aos_integraciones?select=tipo,api_key&tipo=in.(groq,gemini)'},function(){});
  assert.equal(h.baseCalls(),4,'auth/business and AI-key traffic must remain on the real transport');
});

test('foreground-priority reminder windows retain Elena cron but keep generic push paused',()=>{
  const host='ituyqwstonmhnfshnaqz.supabase.co';
  const cron={hostname:host,path:'/rest/v1/aos_agentes?activo=eq.true&tipo_ejecucion=eq.cron'};
  const push={hostname:host,path:'/rest/v1/rpc/aos_notification_push_claim_v1'};

  const morning=boot({AOS_FOREGROUND_PRIORITY_MODE:'true',AOS_TEST_LIMA_HOUR:'9'});
  morning.https.request(cron,function(){});
  const morningPush=morning.https.request(push,function(){});morningPush.end();
  assert.equal(morning.baseCalls(),1,'morning reminder window must keep only Elena/Cartero cron reachable');

  const night=boot({AOS_FOREGROUND_PRIORITY_MODE:'true',AOS_TEST_LIMA_HOUR:'22'});
  night.https.request(cron,function(){});
  const nightPush=night.https.request(push,function(){});nightPush.end();
  assert.equal(night.baseCalls(),1,'night reminder window must keep only Elena/Cartero cron reachable');

  const midday=boot({AOS_FOREGROUND_PRIORITY_MODE:'true',AOS_TEST_LIMA_HOUR:'15'});
  const req=midday.https.request(cron,function(){});req.end();
  assert.equal(midday.baseCalls(),0,'outside reminder windows cron must remain suppressed during incident mode');
});

test('normal mode preserves existing shared circuit semantics',()=>{
  const h=boot({AOS_FOREGROUND_PRIORITY_MODE:'false'});
  const host='ituyqwstonmhnfshnaqz.supabase.co';
  assert.equal(h.runtime.foregroundPriorityMode,false);
  h.https.request({hostname:host,path:'/rest/v1/rpc/aos_generar_snapshot'},function(){});
  h.https.request({hostname:host,path:'/rest/v1/rpc/aos_notification_push_claim_v1'},function(){});
  assert.equal(h.baseCalls(),2,'normal mode must not hard-suppress background traffic before a failure');
});
