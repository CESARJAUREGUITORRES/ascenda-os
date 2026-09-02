const fs=require('fs');
function read(p){return fs.readFileSync(p,'utf8');}
function must(v,msg){if(!v)throw new Error(msg);}
const sql=read('supabase/migrations/20260820034000_rev_f6_2_customer_lifecycle_v1.sql');
const fix=read('supabase/migrations/20260820035500_rev_f6_2_lima_date_active_subject_fix.sql');
const ui=read('app/public/patients-f6-v2.js');
const states=['UNRESOLVED_IDENTITY','HISTORICAL_REACTIVATED','NEW_PATIENT','ACTIVE_REPEAT','RETURNING_PATIENT','DORMANT'];
states.forEach(s=>must(sql.includes(s)||fix.includes(s),'missing lifecycle state '+s));
must(sql.includes("'active_days',90"),'90-day active threshold missing');
must(sql.includes("'dormant_gap_days',180"),'180-day dormant threshold missing');
must(sql.includes("'reactivation_window_days',30"),'30-day reactivation window missing');
must(sql.includes("'registration_is_not_qualifying',true")||fix.includes("'registration_is_not_qualifying',true"),'registration safety rule missing');
must(sql.includes('INSUFFICIENT_ACTIVITY_EVIDENCE')&&fix.includes('INSUFFICIENT_ACTIVITY_EVIDENCE'),'fail-closed insufficient-evidence state missing');
must(sql.includes('NO_CERTIFIED_SOURCE')&&fix.includes('NO_CERTIFIED_SOURCE'),'historical no-source warning missing');
must(sql.includes("revoke all on function public.aos_patient_commercial_360_v2_f6_1_base"),'F6.1 base browser bypass not closed');
must(fix.includes("America/Lima"),'Lima business-date boundary missing');
must(fix.includes("aos_rev_business_date_lima_v1"),'business-date helper missing');
must(fix.includes("coalesce(p.\"ESTADO_PACIENTE\",'')<>'FUSIONADO'"),'active canonical subject filter missing');
must(fix.includes("grant execute on function public.aos_patient_commercial_360_v2(text,text,text) to anon,authenticated,service_role"),'governed browser gateway missing after hotfix');
// P0 #436 split Patient 360 into operational core + serial deferred enrichment.
// Lifecycle is now rendered from `life.lifecycle_state`, populated only by the governed
// LIFECYCLE section of aos_patient_360_enrichment_v1. Accept the legacy direct path only
// for backward compatibility, but require the governed deferred path in the current V3 UI.
const legacyLifecyclePath=ui.includes('cs.lifecycle_state');
const deferredLifecyclePath=ui.includes('life.lifecycle_state')&&ui.includes("section==='LIFECYCLE'")&&ui.includes("aos_patient_360_enrichment_v1");
must(legacyLifecyclePath||deferredLifecyclePath,'Patient 360 has no lifecycle display path');
must(deferredLifecyclePath,'Patient 360 current V3 must use governed deferred lifecycle enrichment');
must(!fix.includes("lifecycle_state','PENDING_REV_F6_2"),'F6.2 hotfix still emits pending lifecycle');
console.log('REV-F6.2 FAST static contract PASS');
