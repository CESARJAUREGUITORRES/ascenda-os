'use strict';

const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('fs');
const vm=require('vm');

const browser=fs.readFileSync('app/public/browser-business-priority-v1.js','utf8');
const migration=fs.readFileSync('supabase/migrations/20260902202000_p0432_db_hotpath_refresh_removal_v1.sql','utf8');
const rollback=fs.readFileSync('supabase/rollbacks/20260902202000_p0432_db_hotpath_refresh_removal_v1_recovery.sql','utf8');

function rpcName(input){const m=String(input||'').match(/\/rpc\/([^?]+)/);return m&&m[1]||'';}
function FakeResponse(name,status){this.name=name;this.status=status==null?200:status;this.ok=this.status>=200&&this.status<300;}
FakeResponse.prototype.clone=function(){return new FakeResponse(this.name,this.status);};

function makeContext(baseFetch,els){
  return {
    window:{fetch:baseFetch},
    document:{hidden:false,getElementById:id=>(els&&els[id])||null},
    console:{log(){},error(){},warn(){}},
    setTimeout,clearTimeout,Promise,Map,Date,Math
  };
}

test('P0 #432 static contract keeps governed and mutable paths outside throttle',()=>{
  assert.match(browser,/version:'p0-432-v1\.0'/);
  assert.match(browser,/MAX_ANALYTICS_CONCURRENCY=1/);
  assert.match(browser,/FAILURE_COOLDOWN_MS=12000/);
  for(const name of ['aos_ticker_mkt','aos_kpi_flujo_clinico','aos_actividad_minutos','aos_actividad_benchmark','aos_historico_asesor_anual','aos_sentinel_owner_feed_v1']){
    assert.match(browser,new RegExp(name+':1'));
  }
  assert.match(browser,/name==='aos_siguiente_lead'/);
  assert.match(browser,/\^aos_callcenter_\/\.test\(name\)/);
  assert.doesNotMatch(browser,/aos_get_historial_paciente:1/);
  assert.doesNotMatch(browser,/aos_search_pacientes:1/);
});

test('P0 #432 DB hot-path migration removes only the per-insert refresh trigger',()=>{
  assert.match(migration,/drop trigger if exists trg_refresh_llammap on public\.aos_llamadas/i);
  assert.match(migration,/to_regclass\('public\.aos_llamadas_ultimo'\)/i);
  assert.match(migration,/to_regprocedure\('public\.fn_refresh_llammap\(\)'\)/i);
  assert.match(migration,/to_regprocedure\('public\.aos_refresh_llammap\(\)'\)/i);
  assert.doesNotMatch(migration,/drop\s+materialized\s+view/i);
  assert.doesNotMatch(migration,/drop\s+function/i);
  assert.doesNotMatch(migration,/statement_timeout/i);
  assert.doesNotMatch(migration,/alter\s+table/i);
});

test('P0 #432 DB hot-path rollback restores exact legacy trigger shape',()=>{
  assert.match(rollback,/create trigger trg_refresh_llammap\s+after insert on public\.aos_llamadas\s+for each statement\s+execute function public\.fn_refresh_llammap\(\)/is);
  assert.doesNotMatch(rollback,/statement_timeout/i);
  assert.doesNotMatch(rollback,/drop\s+materialized\s+view/i);
});

test('heavy cross-panel analytics are serialized even without Call Center mounted',async()=>{
  let active=0,maxActive=0;
  const calls=[];
  function baseFetch(input){
    const name=rpcName(input);calls.push(name);active++;maxActive=Math.max(maxActive,active);
    return new Promise(resolve=>setTimeout(()=>{active--;resolve(new FakeResponse(name,200));},20));
  }
  const context=makeContext(baseFetch,{});
  vm.runInNewContext(browser,context,{filename:'browser-business-priority-v1.js'});
  const base='https://ituyqwstonmhnfshnaqz.supabase.co/rest/v1/rpc/';
  await Promise.all([
    context.window.fetch(base+'aos_ticker_mkt',{body:'{}'}),
    context.window.fetch(base+'aos_kpi_flujo_clinico',{body:'{}'}),
    context.window.fetch(base+'aos_actividad_minutos',{body:'{}'}),
    context.window.fetch(base+'aos_actividad_benchmark',{body:'{}'})
  ]);
  assert.equal(calls.length,4);
  assert.equal(maxActive,1,'heavy analytics must not fan out concurrently inside one browser');
});

test('identical pressure failure is cooled so fixed +5s retry does not hit transport again',async()=>{
  let calls=0;
  function baseFetch(input){calls++;return Promise.resolve(new FakeResponse(rpcName(input),500));}
  const context=makeContext(baseFetch,{});
  vm.runInNewContext(browser,context,{filename:'browser-business-priority-v1.js'});
  const url='https://ituyqwstonmhnfshnaqz.supabase.co/rest/v1/rpc/aos_panel_admin';
  const init={body:JSON.stringify({p_hoy:'2026-09-02'})};
  const first=await context.window.fetch(url,init);
  const second=await context.window.fetch(url,init);
  assert.equal(first.status,500);
  assert.equal(second.status,500);
  assert.equal(calls,1,'same analytical 500 must be served from short cooldown, not Supabase');
});

test('governed writes and next-lead bypass cooldown and analytics queue',async()=>{
  let calls=0;
  function baseFetch(input){calls++;return Promise.resolve(new FakeResponse(rpcName(input),500));}
  const context=makeContext(baseFetch,{'cc-m-cita-manual':{},'cc-num':{textContent:'999999999'},'cc-no-lead':{style:{display:'none'}}});
  vm.runInNewContext(browser,context,{filename:'browser-business-priority-v1.js'});
  const base='https://ituyqwstonmhnfshnaqz.supabase.co/rest/v1/rpc/';
  await context.window.fetch(base+'aos_callcenter_commit_action_v1',{body:'{}'});
  await context.window.fetch(base+'aos_callcenter_commit_action_v1',{body:'{}'});
  await context.window.fetch(base+'aos_siguiente_lead',{body:'{}'});
  await context.window.fetch(base+'aos_siguiente_lead',{body:'{}'});
  assert.equal(calls,4,'critical/mutable paths must always reach transport');
});
