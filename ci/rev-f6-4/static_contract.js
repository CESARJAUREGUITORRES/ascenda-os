'use strict';
const fs=require('fs');
const migration=fs.readFileSync('supabase/migrations/20260820190000_rev_f6_4_sales_intelligence_3_v1.sql','utf8');
const rollback=fs.readFileSync('supabase/rollbacks/20260820190000_rev_f6_4_sales_intelligence_3_v1_recovery.sql','utf8');
function must(x,msg){if(!x)throw new Error(msg)}
[
 'aos_rev_si_sales_fact_v1','aos_rev_si_monthly_v1','aos_rev_si_patient_value_v1','aos_rev_si_cohort_month_v1',
 'aos_rev_si_product_transition_v1','aos_rev_si_acquisition_fact_v1','aos_rev_sales_intelligence_v3','aos_rev_f6_4_contract_v1',
 'aos_rev_si_refresh_v1','aos_rev_sales_intelligence_v3_gateway','REV-F6.4_PATIENT_COMMERCIAL_360_V2'
].forEach(s=>must(migration.includes(s),'missing F6.4 contract: '+s));
[
 'OBSERVED_VALUE_NOT_LIFETIME_PREDICTION','NO_CERTIFIED_SOURCE_NE_ZERO_REVENUE',
 'F4_LINKED_IS_EVIDENCE_COVERAGE_NOT_COLLECTED_CASH','NO_DEFENDABLE_ATTRIBUTION',
 'EXPLICIT_AGENDA_VENTA_ID_MATCH_PLUS_LEAD_LINEAGE','MATERIALIZED_READ_MODELS_PLUS_SET_BASED_AGGREGATION',
 "'live_rpc_target_ms',1000","'demographic_coverage_threshold_pct',70","'demographic_minimum_cell_size',5"
].forEach(s=>must(migration.includes(s),'missing semantic/performance guard: '+s));
must(/revoke all on public\.aos_rev_si_sales_fact_v1 from public,anon,authenticated/i.test(migration),'sales fact must be browser-closed');
must(/grant select on public\.aos_rev_si_sales_fact_v1 to service_role/i.test(migration),'sales fact service grant missing');
must(!/phone_nearness_authority[^\n]*true/i.test(migration),'phone-nearness authority prohibited');
must(!/phone_only_acquisition_attribution[^\n]*true/i.test(migration),'phone-only acquisition attribution prohibited');
must(rollback.includes('aos_patient_commercial_360_v2_f6_3_base'),'rollback must restore F6.3 Patient 360');
must(rollback.includes('drop materialized view if exists public.aos_rev_si_sales_fact_v1'),'rollback must drop F6.4 derived fact');
console.log('REV-F6.4 FAST static contract PASS');
