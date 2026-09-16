const fs=require('fs');
function ok(v,m){if(!v)throw new Error(m)}
const a=fs.readFileSync('supabase/migrations/20260916053000_booking_v31_attribution.sql','utf8');
const b=fs.readFileSync('supabase/migrations/20260916053500_booking_v31_public_write_and_notifications.sql','utf8');
for(const x of ['source_channel','source_campaign','source_link_token']) ok(a.includes(x),'missing '+x);
for(const x of ['WEB','EMAIL_MARKETING','ADVISOR_LINK','WHATSAPP','CALL_CENTER','MANUAL']) ok(b.includes(x),'missing channel '+x);
ok(a.includes('aos_booking_attribution_daily_v1'),'daily counter view missing');
ok(b.includes('aos_booking_apply_attribution_v1'),'attribution writer missing');
ok(b.includes("origen_cita='WEB-PUBLICA'")&&b.includes("origen_cita='AUTO-AGENDA'"),'legacy backfill missing');
console.log('BOOKING-V3.1 attribution contract PASS');
