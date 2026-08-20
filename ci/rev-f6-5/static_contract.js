'use strict';
const fs=require('fs');
const migration=fs.readFileSync('supabase/migrations/20260820195500_rev_f6_5_historical_sales_plugin_v1.sql','utf8');
const rollback=fs.readFileSync('supabase/rollbacks/20260820195500_rev_f6_5_historical_sales_plugin_v1_recovery.sql','utf8');
const fixtures=fs.readFileSync('ci/rev-f6-5/fixtures_A_J.sql','utf8');
const isolation=fs.readFileSync('supabase/migrations/20260820204500_rev_f6_5_rev_f6_0_fingerprint_isolation_v1.sql','utf8');
const isolationRollback=fs.readFileSync('supabase/rollbacks/20260820204500_rev_f6_5_rev_f6_0_fingerprint_isolation_v1_recovery.sql','utf8');
const isolationTest=fs.readFileSync('ci/rev-f6-5/tests/002_cross_workstream_fingerprint_isolation.sql','utf8');
function must(x,msg){if(!x)throw new Error(msg)}
[
 'aos_rev_historical_source_manifest_v1','aos_rev_historical_source_register_v1','aos_rev_historical_source_certify_v1',
 'aos_rev_historical_year_coverage_v1','aos_rev_historical_coverage_v1','aos_rev_historical_status_map_v1',
 'aos_rev_historical_detailed_status_v1','aos_rev_sales_intelligence_v3_f6_4_runtime_base','aos_rev_f6_5_contract_v1',
 'aos_rev_historical_recompute_v1','REV-F6.5_HISTORICAL_COVERAGE_V1','REV-F6.5_HISTORICAL_SALES_PLUGIN_V1'
].forEach(s=>must(migration.includes(s),'missing F6.5 contract: '+s));
[
 'SOURCE_COVERAGE_NOT_REVENUE_VALUE','NO_CERTIFIED_SOURCE_NE_ZERO_REVENUE','SOURCE_PRESENT_NOT_CERTIFIED_NE_REVENUE',
 'CERTIFIED_PARTIAL_SOURCE_SET','CERTIFIED_PARTIAL_COVERAGE','CERTIFIED_COMPLETE','COVERAGE_MANIFEST_IS_NOT_REVENUE',
 'CANONICAL_READ_MODEL_REQUIRED_FOR_REVENUE','SAME_SHA_SAME_METADATA_IDEMPOTENT; SAME_SHA_DIFFERENT_METADATA_FAIL_CLOSED',
 "'hardcoded_2024_2025_runtime_status',false","'live_rpc_target_ms',1000","'timeout_increase_is_solution',false"
].forEach(s=>must(migration.includes(s),'missing historical semantic/performance guard: '+s));
must(/alter function public\.aos_rev_sales_intelligence_v3\(integer,text,text\) rename to aos_rev_sales_intelligence_v3_f6_4_runtime_base/i.test(migration),'F6.4 runtime must be frozen as internal base');
must(/revoke all on public\.aos_rev_historical_source_manifest_v1 from public,anon,authenticated/i.test(migration),'manifest must be browser-closed');
must(/grant execute on function public\.aos_rev_historical_source_register_v1\(jsonb\) to service_role/i.test(migration),'register function service grant missing');
must(/grant execute on function public\.aos_rev_historical_recompute_v1\(\) to service_role/i.test(migration),'recompute service grant missing');
must(!/(insert\s+into|update|delete\s+from)\s+public\.aos_ventas/i.test(migration),'F6.5 migration must not mutate aos_ventas');
must(!/(insert\s+into|update|delete\s+from)\s+public\.aos_pacientes/i.test(migration),'F6.5 migration must not mutate aos_pacientes');
must(rollback.includes('rename to aos_rev_sales_intelligence_v3'),'recovery must restore F6.4 runtime name');
must(rollback.includes('drop table if exists public.aos_rev_historical_source_manifest_v1'),'recovery must remove F6.5 manifest');
for(const l of 'ABCDEFGHIJ') must(fixtures.includes('FIXTURE '+l+' —'),'missing fixture '+l);

[
 'aos_rev_f6_data_contract_fingerprint_isolated_v1',
 'aos_rev_f6_data_contract_v1_legacy_dynamic_fp',
 'REVENUE_TRUTH_EXCLUDES_MUTABLE_CIA_COMPATIBILITY_CARDINALITY',
 "array['compatibility_identity','rows']",
 "array['compatibility_identity','with_canonical_patient']",
 "array['compatibility_identity','identity_conflicts']",
 "array['freshness_sources','cia_identity_updated_at']"
].forEach(s=>must(isolation.includes(s),'missing fingerprint-isolation contract: '+s));
must(/revoke all on function public\.aos_rev_f6_data_contract_v1\(\) from public,anon,authenticated/i.test(isolation),'isolated F6.0 wrapper must stay browser-closed');
must(!/(insert\s+into|update|delete\s+from)\s+public\.(aos_ventas|aos_pacientes|aos_leads|aos_llamadas|aos_agenda_citas)/i.test(isolation),'fingerprint isolation must not mutate business rows');
must(isolationRollback.includes('rename to aos_rev_f6_data_contract_v1'),'isolation recovery must restore original F6.0 name');
must(isolationTest.includes('legacy fingerprint did not react to synthetic CIA churn'),'isolation test must prove old coupling');
must(isolationTest.includes('Revenue fingerprint still coupled to mutable CIA compatibility state'),'isolation test must prove new decoupling');
must(isolationTest.includes('F6.5 chain fingerprint unstable'),'isolation test must cover terminal chain determinism');
console.log('REV-F6.5 FAST static contract PASS');
