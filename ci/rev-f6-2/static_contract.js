const fs=require('fs');
function read(p){return fs.readFileSync(p,'utf8');}
function must(v,msg){if(!v)throw new Error(msg);}
const sql=read('supabase/migrations/20260820034000_rev_f6_2_customer_lifecycle_v1.sql');
const ui=read('app/public/patients-f6-v2.js');
const states=['UNRESOLVED_IDENTITY','HISTORICAL_REACTIVATED','NEW_PATIENT','ACTIVE_REPEAT','RETURNING_PATIENT','DORMANT'];
states.forEach(s=>must(sql.includes(s),'missing lifecycle state '+s));
must(sql.includes("'active_days',90"),'90-day active threshold missing');
must(sql.includes("'dormant_gap_days',180"),'180-day dormant threshold missing');
must(sql.includes("'reactivation_window_days',30"),'30-day reactivation window missing');
must(sql.includes("'registration_is_not_qualifying',true"),'registration safety rule missing');
must(sql.includes('INSUFFICIENT_ACTIVITY_EVIDENCE'),'fail-closed insufficient-evidence state missing');
must(sql.includes('NO_CERTIFIED_SOURCE'),'historical no-source warning missing');
must(sql.includes("revoke all on function public.aos_patient_commercial_360_v2_f6_1_base"),'F6.1 base browser bypass not closed');
must(sql.includes("grant execute on function public.aos_patient_commercial_360_v2(text,text,text) to anon,authenticated,service_role"),'governed browser gateway missing');
must(ui.includes('cs.lifecycle_state'),'Patient 360 has no lifecycle display path');
must(!sql.includes("lifecycle_state','PENDING_REV_F6_2"),'F6.2 migration still emits pending lifecycle');
console.log('REV-F6.2 FAST static contract PASS');
