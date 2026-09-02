'use strict';
const fs=require('fs');
const test=require('node:test');
const assert=require('node:assert/strict');
const boot=fs.readFileSync('app/public/admin-marketing-v2.js','utf8');
const core=fs.readFileSync('app/public/admin-marketing-v2-core.js','utf8');

test('preserves certified Marketing V4.2 core',()=>{
  assert.match(boot,/admin-marketing-v2-core\.js/);
  assert.match(core,/2026-08-31-v4\.2\.2-organic-paid-boundary/);
  assert.match(core,/Facturación, ROAS y CAC excluyen ORGANICO/);
});

test('single-flight and cache are scoped to Marketing reads',()=>{
  assert.match(boot,/var cache=new Map\(\)/);
  assert.match(boot,/var inflight=new Map\(\)/);
  assert.match(boot,/aos_marketing_dashboard:2500/);
  assert.match(boot,/aos_marketing_period_summary_v2:10000/);
  assert.match(boot,/aos_marketing_historico_public_v2:60000/);
  assert.match(boot,/aos_marketing_ltv_public_v2:60000/);
  assert.match(boot,/inflight\.has\(key\)/);
  assert.match(boot,/cache\.get\(key\)/);
});

test('expensive annual analytics are viewport gated',()=>{
  assert.match(boot,/aos_marketing_historico_public_v2:'#mk-hist'/);
  assert.match(boot,/aos_marketing_ltv_public_v2:'#mk-ltv'/);
  assert.match(boot,/IntersectionObserver/);
  assert.match(boot,/rootMargin:'500px 0px'/);
  assert.match(boot,/setTimeout\(finish,12000\)/);
});

test('bootstrap adds no recurrent polling and core keeps canonical RPCs',()=>{
  assert.doesNotMatch(boot,/setInterval\s*\(/);
  assert.match(core,/aos_marketing_period_summary_v2/);
  assert.match(core,/aos_marketing_historico_public_v2/);
  assert.match(core,/aos_marketing_ltv_public_v2/);
});