'use strict';
const fs=require('fs');
const assert=require('assert');

const migration=fs.readFileSync('supabase/migrations/20260904010500_p0_457_ticker_specialized_v1.sql','utf8');
const rollback=fs.readFileSync('supabase/rollbacks/20260904010500_p0_457_ticker_specialized_v1.rollback.sql','utf8');

assert(/create or replace function public\.aos_ticker_mkt\(p_mes_inicio text\)/i.test(migration));
assert(/returns jsonb/i.test(migration));
assert(!/aos_marketing_period_summary_v2\s*\(/i.test(migration),'ticker must not invoke full marketing period summary');
assert(/aos_marketing_attribution_v2_preview\s*\(v_desde,v_hasta\)/i.test(migration),'M0 revenue must stay on canonical Marketing Attribution V2');
assert(/period_seed as materialized/i.test(migration));
assert(/cohort as materialized/i.test(migration));
assert(/person_flags as materialized/i.test(migration));
assert(/l\.fecha between c\.first_lead_date and v_hasta/i.test(migration));
assert(/a\.fecha_cita between c\.first_lead_date and v_hasta/i.test(migration));
assert(!/touch_flags|aos_marketing_touchpoints_v2/i.test(migration),'ticker must not calculate discarded touchpoint metrics');
assert(!/create\s+index|create\s+materialized\s+view|refresh\s+materialized\s+view|create\s+trigger/i.test(migration));
assert(!/(?:set|alter[^;]*)\s+statement_timeout/i.test(migration));
for(const key of ['leads','contactados','con_cita','asistio','con_venta','facturacion','inversion','roas','pct_contacto']){
  assert(migration.includes(`'${key}'`),`ticker payload key missing: ${key}`);
}
assert(/aos_marketing_period_summary_v2\s*\(/i.test(rollback),'rollback must restore certified full-summary implementation');
console.log('P0_457_TICKER_SPECIALIZED_CONTRACT=PASS');
