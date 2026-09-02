'use strict';
const fs=require('fs');
const test=require('node:test');
const assert=require('node:assert/strict');
const boot=fs.readFileSync('app/public/admin-marketing-v2.js','utf8');
const core=fs.readFileSync('app/public/admin-marketing-v2-core.js','utf8');
const migration=fs.readFileSync('supabase/migrations/20260902022000_p0_marketing_confirmed_call_lookup_index.sql','utf8');

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

test('legacy LTV cohort read is suppressed only after V4.2 owns rendering',()=>{
  assert.match(boot,/aos_ltv_cohortes/);
  assert.match(boot,/fn==='aos_ltv_cohortes'&&window\.__AOS_MKT4/);
  assert.match(boot,/suppressedLegacyLtv/);
  assert.match(boot,/emptyJsonResponse/);
  assert.doesNotMatch(core,/suppressedLegacyLtv/);
});

test('monthly attribution and intent insights share one serialized lane',()=>{
  assert.match(boot,/var insightTail=Promise\.resolve\(\)/);
  assert.match(boot,/var serialInsights=\{/);
  assert.match(boot,/aos_marketing_attribution_public_v3:true/);
  assert.match(boot,/aos_marketing_intent_public_v2:true/);
  assert.match(boot,/aos_marketing_intent_detail_public_v3:true/);
  assert.match(boot,/function runSerializedInsight\(/);
  assert.match(boot,/function withoutSignal\(/);
  assert.match(boot,/baseFetch\(input,withoutSignal\(init\)\)/);
  assert.match(boot,/insightTail=queued\.then/);
  assert.match(boot,/serializedInsights/);
});

test('confirmed-call lookup index is partial and formula-neutral',()=>{
  assert.match(migration,/idx_aos_llamadas_mkt_confirmed_phone_advisor_v1/);
  assert.match(migration,/numero_limpio/);
  assert.match(migration,/upper\(coalesce\(asesor,''\)\)/);
  assert.match(migration,/where upper\(coalesce\(estado,''\)\)='CITA CONFIRMADA'/);
  assert.match(migration,/include \(id, lead_id_origen, fecha, hora_llamada, created_at, ult_ts, ts_log\)/);
  assert.doesNotMatch(migration,/statement_timeout/i);
  assert.doesNotMatch(migration,/create or replace function/i);
  assert.doesNotMatch(migration,/update\s+public\./i);
});

test('bootstrap adds no recurrent polling and core keeps canonical RPCs',()=>{
  assert.doesNotMatch(boot,/setInterval\s*\(/);
  assert.match(core,/aos_marketing_period_summary_v2/);
  assert.match(core,/aos_marketing_historico_public_v2/);
  assert.match(core,/aos_marketing_ltv_public_v2/);
});