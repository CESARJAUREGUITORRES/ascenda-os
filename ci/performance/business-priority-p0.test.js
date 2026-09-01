'use strict';

const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('fs');
const vm=require('vm');
const {EventEmitter}=require('events');
const {execFileSync}=require('child_process');

const preload=fs.readFileSync('app/business-priority-preload.js','utf8');
const quotaPreload=fs.readFileSync('app/supabase-quota-circuit-preload.cjs','utf8');
const browser=fs.readFileSync('app/public/browser-business-priority-v1.js','utf8');
const f4=fs.readFileSync('app/public/f4-production-canary-hotfix.js','utf8');
const pkg=JSON.parse(fs.readFileSync('app/package.json','utf8'));
const rail=JSON.parse(fs.readFileSync('app/railway.json','utf8'));

for(const [name,src] of [['preload',preload],['quotaPreload',quotaPreload],['browser',browser],['f4',f4]]){
  test(name+' syntax',()=>assert.doesNotThrow(()=>new Function(src)));
}

test('certified production entrypoint stays unchanged and composes P0-A',()=>{
  assert.equal(pkg.scripts.start,'node server-f17.js');
  assert.match(rail.deploy.startCommand,/supabase-quota-circuit-preload\.cjs/);
  assert.match(quotaPreload,/require\('\.\/business-priority-preload\.js'\)/);
  assert.doesNotMatch(rail.deploy.startCommand,/business-priority-preload\.js/);
  const out=execFileSync(process.execPath,['-e',"require('./app/supabase-quota-circuit-preload.cjs');if(!global.__AOS_WA_SUPABASE_QUOTA_PRELOAD__||!global.__AOS_BUSINESS_PRIORITY_V1__)process.exit(2);process.stdout.write('COMPOSED')"],{cwd:process.cwd(),encoding:'utf8'});
  assert.ok(out.trim().endsWith('COMPOSED'));
});

test('server background breaker is narrowly scoped',()=>{
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
  const runtime=localGlobal.__AOS_BUSINESS_PRIORITY_V1__;
  const classify=runtime.classify;
  const host='ituyqwstonmhnfshnaqz.supabase.co';
  const bg={hostname:host,path:'/rest/v1/aos_agentes?activo=eq.true&tipo_ejecucion=eq.cron'};
  assert.equal(classify(bg),'agent-cron-scan');
  assert.equal(classify({hostname:host,path:'/rest/v1/rpc/aos_notification_push_claim_v1'}),'notification-push-claim');
  assert.equal(classify({hostname:host,path:'/rest/v1/rpc/aos_siguiente_lead'}),'');
  assert.equal(classify({hostname:host,path:'/rest/v1/rpc/aos_callcenter_commit_action_v1'}),'');
  assert.equal(classify({hostname:host,path:'/rest/v1/rpc/aos_wa3_actor_v1'}),'');

  const first=fakeHttps.request(bg,function(){});
  first.emit('response',{statusCode:524});
  assert.equal(baseCalls,1);
  assert.ok(runtime.states.get('agent-cron-scan').openUntil>Date.now());

  const second=fakeHttps.request(bg,function(){});
  second.end();
  assert.equal(baseCalls,1,'open circuit must not hit Supabase again');

  fakeHttps.request({hostname:host,path:'/rest/v1/rpc/aos_siguiente_lead'},function(){});
  assert.equal(baseCalls,2,'critical next-lead request must bypass background breaker');
});

test('browser scheduler preserves governed writes and prioritizes next lead',async()=>{
  assert.match(browser,/name==='aos_siguiente_lead'/);
  assert.match(browser,/\^aos_callcenter_\/\.test\(name\)/);
  assert.match(browser,/CALENDAR_MAX_CONCURRENCY=2/);
  assert.match(browser,/waitLeadBoundary\(5000\)/);
  assert.match(browser,/aos_panel_asesor:1/);
  assert.match(browser,/aos_monitoreo_equipo:1/);
  assert.match(browser,/aos_historico_asesor_anual:1/);
  assert.doesNotMatch(browser,/aos_callcenter_commit_action_v1\s*:/);
  assert.doesNotMatch(browser,/aos_callcenter_confirm_queue_appointment_v1\s*:/);

  const els={
    'cc-m-cita-manual':{},
    'cc-num':{textContent:'Cargando...'},
    'cc-no-lead':{style:{display:'none'}}
  };
  const calls=[];
  let calendarActive=0,maxCalendarActive=0;
  function FakeResponse(name){this.name=name;}
  FakeResponse.prototype.clone=function(){return new FakeResponse(this.name);};
  function nameOf(input){const m=String(input||'').match(/\/rpc\/([^?]+)/);return m&&m[1]||'';}
  function baseFetch(input){
    const name=nameOf(input);calls.push(name);
    if(name==='aos_horarios_semana'){
      calendarActive++;maxCalendarActive=Math.max(maxCalendarActive,calendarActive);
      return new Promise(function(resolve){setTimeout(function(){calendarActive--;resolve(new FakeResponse(name));},35);});
    }
    return Promise.resolve(new FakeResponse(name));
  }
  const context={
    window:{fetch:baseFetch},
    document:{getElementById:function(id){return els[id]||null;}},
    console:{log:function(){},error:function(){},warn:function(){}},
    setTimeout,clearTimeout,Promise,Map
  };
  vm.runInNewContext(browser,context,{filename:'browser-business-priority-v1.js'});
  const base='https://ituyqwstonmhnfshnaqz.supabase.co/rest/v1/rpc/';
  const calendar=[];
  for(let i=0;i<5;i++)calendar.push(context.window.fetch(base+'aos_horarios_semana',{body:JSON.stringify({week:i})}));
  const lead=context.window.fetch(base+'aos_siguiente_lead',{body:'{}'});
  setTimeout(function(){els['cc-num'].textContent='999999999';},25);
  await lead;
  await Promise.all(calendar);
  assert.equal(calls[0],'aos_siguiente_lead','next lead must reach transport before calendar reads');
  assert.equal(calls.filter(function(x){return x==='aos_horarios_semana';}).length,5);
  assert.ok(maxCalendarActive<=2,'calendar concurrency exceeded business-priority cap');
});

test('F4 loads priority scheduler without changing Loop6 postload authority',()=>{
  assert.match(f4,/browser-business-priority-v1\.js\?v=20260901-p0-bc-v1/);
  assert.match(f4,/calls-loop6\.js\?v=20260901-loop6-v2\.3-postload/);
  assert.match(f4,/window\.__AOS_CC_LOOP6_POSTLOAD_READY__='v2\.3-postload'/);
  assert.match(f4,/loadCallCenterPerformance\(\)/);
});

test('hosted gate mirrors governed-write Loop6 safety contract',()=>{
  const app=fs.readFileSync('app/public/app.html','utf8');
  const calls=fs.readFileSync('app/public/calls.html','utf8');
  const loop6=fs.readFileSync('app/public/calls-loop6.js','utf8');
  const guard=fs.readFileSync('supabase/migrations/20260822011500_mkt_loop6_legacy_bypass_guard_v22.sql','utf8');
  assert.ok(app.includes('AOS._capturePanelTimers = true'));
  assert.ok(app.includes('AOS._capturePanelTimers = false'));
  assert.ok(app.indexOf('if (extSrcs.length)')<app.indexOf('else if (allInline.length)'));
  assert.ok(calls.includes('/calls-loop6.js?v=20260821-loop6-v2.3'));
  assert.ok(loop6.includes("window.__AOS_CC_LOOP6_V2__='v2.3'"));
  assert.ok(loop6.includes('aos_callcenter_confirm_queue_appointment_v1'));
  assert.ok(loop6.includes('aos_callcenter_commit_action_v1'));
  assert.ok(loop6.includes('window.guardarCitaManual=function'));
  assert.ok(loop6.includes('window.ccConfirmarCita=function'));
  assert.ok(f4.includes('ensureCallCenterLoop6Postload'));
  assert.ok(f4.includes('AOS._capturePanelTimers===true'));
  assert.ok(guard.includes('AOS_LOOP6_RUNTIME_REQUIRED'));
  assert.ok(guard.includes("set_config('aos.loop6_governed_write','1',true)"));
  assert.ok(guard.includes("v_origin='CITA_MANUAL' or v_origin like 'CALL_CENTER%'"));
});
