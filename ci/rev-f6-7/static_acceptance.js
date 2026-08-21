'use strict';
const fs=require('fs');
function read(p){return fs.readFileSync(p,'utf8')}
function ok(v,m){if(!v)throw new Error(m)}
const page=read('app/public/admin-sales-intelligence.html');
const patient=read('app/public/patients-f6-v2.js');
const gateway=read('supabase/migrations/20260821011000_rev_f6_7_ui_acceptance_gateway_v1.sql');
const legacyIds=['si-fact','si-meta','si-pct','si-gap','si-ticket','si-sales','si-best','si-avg','si-chart','si-proj','si-mtd','si-prev','si-delta','si-tbody','si-year','si-sede'];
for(const id of legacyIds)ok(page.includes(`id="${id}"`),`known workflow id missing: ${id}`);
for(const marker of ['Sales Intelligence V3','ACTIVO · SOLO LECTURA','COBERTURA / CONFIANZA / FRESCURA / MUESTRA','si-state-loading','si-state-empty','si-state-error','@media(max-width:760px)','NO_CERTIFIED_SOURCE significa dato no certificado, no S/0.'])ok(page.includes(marker),`F6.7 UI marker missing: ${marker}`);
ok((page.match(/fetch\('\/api\/f4\/sales-intelligence-read'/g)||[]).length===1,'Sales Intelligence must use one bounded same-origin read request');
ok(!page.includes('.supabase.co'),'browser must not regress to direct PostgREST transport');
ok(page.includes("sessionStorage.getItem('aos_si_token')"),'strong SI token recovery missing');
ok(page.includes("sessionStorage.getItem('aos_app_token')"),'app token recovery missing');
ok(page.includes("caches.open('aos-phase2-auth')"),'cached strong-token recovery missing');
ok(!/INSERT INTO aos_ventas|UPDATE aos_ventas|DELETE FROM aos_ventas|TRUNCATE aos_ventas/i.test(page),'UI contains forbidden business write');
ok(gateway.includes('aos_sales_intelligence_gateway_v2_f6_7_base'),'private legacy auth base missing');
ok(gateway.includes("'api_version','V3'"),'V3 API marker missing');
ok(gateway.includes("'legacy_compatibility',true"),'legacy compatibility marker missing');
ok(gateway.includes("'transport','SAME_ORIGIN_F4_PROXY'"),'same-origin transport marker missing');
ok(!gateway.includes('phone_only'),'gateway must not add phone-only attribution semantics');
// Patient 360 is not redesigned in F6.7; preserve the certified identity-aware consumer implementation.
for(const marker of ['canonical_patient_id','identity_status','confidence','lifecycle'])ok(patient.includes(marker),`Patient 360 certified marker missing: ${marker}`);
console.log('REV_F6_7_STATIC_ACCEPTANCE=PASS');
