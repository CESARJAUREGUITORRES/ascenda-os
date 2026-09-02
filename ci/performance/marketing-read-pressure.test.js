'use strict';
const fs=require('fs');
const test=require('node:test');
const assert=require('node:assert/strict');
const boot=fs.readFileSync('app/public/admin-marketing-v2.js','utf8');
const core=fs.readFileSync('app/public/admin-marketing-v2-core.js','utf8');
const indexMigration=fs.readFileSync('supabase/migrations/20260902022000_p0_marketing_confirmed_call_lookup_index.sql','utf8');
const callLeadMigration=fs.readFileSync('supabase/migrations/20260902024000_p0_marketing_call_lead_single_pass_v4.sql','utf8');

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

test('legacy LTV cohort read is suppressed from bootstrap start',()=>{
  assert.match(boot,/aos_ltv_cohortes/);
  assert.match(boot,/fn==='aos_ltv_cohortes'/);
  assert.doesNotMatch(boot,/fn==='aos_ltv_cohortes'&&window\.__AOS_MKT4/);
  assert.match(boot,/suppressedLegacyLtv/);
  assert.match(boot,/emptyJsonResponse/);
  assert.doesNotMatch(core,/suppressedLegacyLtv/);
});

test('new bootstrap release replaces older SPA fetch wrapper',()=>{
  assert.match(boot,/p0-marketing-read-pressure-v1\.3/);
  assert.match(boot,/G&&G\.release!==RELEASE&&typeof G\.baseFetch==='function'/);
  assert.match(boot,/window\.fetch=G\.baseFetch/);
  assert.match(boot,/delete window\.__AOS_MKT_PERF_V1/);
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
  assert.match(indexMigration,/idx_aos_llamadas_mkt_confirmed_phone_advisor_v1/);
  assert.match(indexMigration,/numero_limpio/);
  assert.match(indexMigration,/upper\(coalesce\(asesor,''\)\)/);
  assert.match(indexMigration,/where upper\(coalesce\(estado,''\)\)='CITA CONFIRMADA'/);
  assert.match(indexMigration,/include \(id, lead_id_origen, fecha, hora_llamada, created_at, ult_ts, ts_log\)/);
  assert.doesNotMatch(indexMigration,/statement_timeout/i);
  assert.doesNotMatch(indexMigration,/create or replace function/i);
  assert.doesNotMatch(indexMigration,/update\s+public\./i);
});

test('call-lead P0.4 preserves canonical match states and removes global touchpoint function scan',()=>{
  assert.match(callLeadMigration,/create or replace function public\.aos_marketing_call_lead_match_v2/);
  assert.match(callLeadMigration,/DIRECT_LEAD_ID/);
  assert.match(callLeadMigration,/UNIQUE_PRIOR_LEAD/);
  assert.match(callLeadMigration,/UNIQUE_PRIOR_BY_TREATMENT/);
  assert.match(callLeadMigration,/NO_PRIOR_MARKETING_LEAD/);
  assert.match(callLeadMigration,/AMBIGUOUS_PRIOR_LEAD/);
  assert.match(callLeadMigration,/when r\.lead_id_origen is not null then 100/);
  assert.match(callLeadMigration,/when r\.n_prior=1 then 90/);
  assert.match(callLeadMigration,/when r\.n_prior>1 and r\.n_trat=1 then 85/);
  assert.match(callLeadMigration,/row_number\(\) over/);
  assert.match(callLeadMigration,/join phones p on p\.numero_limpio=l\.numero_limpio/);
  assert.doesNotMatch(callLeadMigration,/aos_marketing_touchpoints_v2\(null,null\)/i);
  assert.doesNotMatch(callLeadMigration,/statement_timeout/i);
  assert.doesNotMatch(callLeadMigration,/update\s+public\./i);
});

test('bootstrap adds no recurrent polling and core keeps canonical RPCs',()=>{
  assert.doesNotMatch(boot,/setInterval\s*\(/);
  assert.match(core,/aos_marketing_period_summary_v2/);
  assert.match(core,/aos_marketing_historico_public_v2/);
  assert.match(core,/aos_marketing_ltv_public_v2/);
});