const fs=require('fs');
const sw=fs.readFileSync('app/public/phase2-service-worker.js','utf8');
const app=fs.readFileSync('app/public/app.html','utf8');
const ui=fs.readFileSync('app/public/patients-f6-v2.js','utf8');
const mig=fs.readFileSync('supabase/migrations/20260902212500_p0436_patient_360_hotpath_enrichment_split_v1.sql','utf8');
function ok(cond,msg){if(!cond){console.error('F6.1 UI CONTRACT FAIL:',msg);process.exit(1);}}

ok(sw.includes('/patients-f6-v2.js'),'Service worker must preserve Patient 360 runtime compatibility injection');
ok(app.includes('ASCENDA_CRITICAL_RUNTIME_BRIDGES_20260820'),'App shell must contain deterministic critical-runtime marker');
ok(app.includes('/patients-f6-v2.js?v=20260820-rev-f6-runtime-hotfix-v1'),'Patient runtime must load directly from app shell');
ok(ui.includes('window.__AOS_PATIENTS_360_V3__'),'Patient runtime must publish V3 idempotency state');
ok(ui.includes("window.__AOS_PATIENT_BRIDGE_GUARD__='p0436-v2-hotpath'"),'Runtime must publish P0 #436 hot-path generation');
ok(ui.includes("window.__AOS_PATIENT_FILIATION_CONTACTS__='v1'"),'Runtime must publish filiación contact-field generation');
ok(ui.includes("'aos_patient_search_v2'"),'Search must keep canonical patient discovery');
ok(ui.includes("'aos_patient_360_current_v3'"),'Selection must call canonical-current operational RPC');
ok(ui.includes('p_canonical_patient_id:cid'),'Selection must pass canonical_patient_id directly');
ok(!ui.includes("addAttempt('PHONE'"),'Current selection must not fall back through phone resolution');
ok(!ui.includes("addAttempt('DOCUMENT'"),'Current selection must not fall back through document resolution');

// Worker authority stays canonical for both operational and deferred reads.
ok(sw.includes("rm[1]==='aos_patient_360_enrichment_v1'"),'Deferred Patient enrichment must share governed worker-token bridge');
ok(sw.includes('p.p_token=t'),'Governed patient bridge must overwrite browser p_token');
ok(sw.includes('browser/sessionStorage'),'Worker contract must reject browser/sessionStorage token authority');
ok(ui.includes('reg.update()'),'Long-lived clients must retain bounded service-worker update check');
ok(!ui.includes('setInterval('),'Patient recovery/enrichment must not poll');

// P0 #436 root-cause contract: analytical work may never gate the operational record.
ok(mig.includes("'identity_confidence',jsonb_build_object('enrichment_status','DEFERRED')"),'Hot path must return identity-confidence as deferred');
ok(mig.includes("'lifecycle',jsonb_build_object('enrichment_status','DEFERRED')"),'Hot path must return lifecycle as deferred');
const hot=mig.slice(mig.indexOf('create or replace function public.aos_patient_360_current_v3'),mig.indexOf('create or replace function public.aos_patient_360_enrichment_v1'));
ok(!hot.includes('aos_rev_identity_confidence_by_patient_v1'),'Operational V3 must not execute identity-confidence synchronously');
ok(!hot.includes('aos_rev_customer_lifecycle_by_patient_v1'),'Operational V3 must not execute lifecycle synchronously');
ok(hot.includes('aos_paciente_360(v_phone)'),'Operational V3 must preserve legacy Patient 360 history core');
ok(mig.includes("v_section='IDENTITY_CONFIDENCE'"),'Deferred wrapper must allow identity-confidence section');
ok(mig.includes("v_section='LIFECYCLE'"),'Deferred wrapper must allow lifecycle section');
ok(mig.includes("'SECTION_NOT_ALLOWED'"),'Deferred wrapper must fail closed for unknown sections');
ok(ui.includes("loadDeferred(cid,seq,'IDENTITY_CONFIDENCE',function(){"),'Identity enrichment must start the serial chain');
ok(ui.includes("loadDeferred(cid,seq,'LIFECYCLE')"),'Lifecycle enrichment must run only after identity callback');
ok(!ui.includes('loadCurrent(cid,true)'),'Deterministic operational RPC failures must not trigger a duplicate heavy retry');
ok(ui.includes('activeCid!==cid||seq!==enrichmentSeq'),'Late enrichment responses must not overwrite a newly selected patient');
ok(ui.includes('el contexto analítico nunca bloquea la ficha'),'UI must state the operational/enrichment boundary');

// Owner-smoke UX correction: filiación must surface contact data already present in the canonical patient payload.
ok(ui.includes("card('Teléfono',p.telefono,'filiation-phone')"),'Filiación must explicitly render canonical phone');
ok(ui.includes("card('Correo',p.correo,'filiation-email')"),'Filiación must preserve explicit email rendering when base UI omits it');
ok(!ui.includes('ep-telefono'),'P0 contact display correction must not introduce direct phone mutation authority');

ok(ui.includes('ACTUAL RESOLVED'),'UI must distinguish resolved current patient identity');
ok(ui.includes('HISTÓRICO REVIEW'),'UI must preserve historical review visibility');
ok(ui.includes('NO_CERTIFIED_SOURCE'),'Historical revenue limitation must remain explicit');
ok(ui.includes('Selecciona la ficha por nombre'),'Shared phone compatibility must remain fail-closed');
console.log('REV-F6.1 UI contract PASS — Patient operational hot path + serial deferred enrichment + filiación contacts');