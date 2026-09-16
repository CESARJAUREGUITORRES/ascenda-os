const fs=require('fs');
function ok(v,m){if(!v)throw new Error(m)}
const a=fs.readFileSync('supabase/migrations/20260916053000_booking_v31_attribution.sql','utf8');
const b=fs.readFileSync('supabase/migrations/20260916053500_booking_v31_public_write_and_notifications.sql','utf8');
const c=fs.readFileSync('supabase/migrations/20260916054000_booking_v31_public_authority.sql','utf8');
const d=fs.readFileSync('supabase/migrations/20260916054500_booking_v31_notification_source.sql','utf8');
for(const x of ['source_channel','source_campaign','source_link_token']) ok(a.includes(x)&&c.includes(x),'missing '+x);
for(const x of ['WEB','EMAIL_MARKETING','ADVISOR_LINK','WHATSAPP','CALL_CENTER','MANUAL']) ok(b.includes(x),'missing channel '+x);
ok(a.includes('aos_booking_attribution_daily_v1'),'daily counter view missing');
ok(c.includes('create or replace function public.aos_agendar_publica_v2'),'public authority not preserved');
ok(c.includes('aos_booking_attribution_v1(p_token)'),'public authority does not resolve attribution');
ok(c.includes("'source_channel',v_ch")&&c.includes("'advisor_code',v_asesor"),'booking response attribution missing');
ok(d.includes("'source_label',src_label")&&d.includes("'ADMIN_APPOINTMENT_DIGEST'"),'admin notification source missing');
ok(d.includes("'APPOINTMENT_CREATED'")&&d.includes("'TEAM_APPOINTMENT_SCORE'"),'existing notification paths missing');
ok(b.includes("origen_cita='WEB-PUBLICA'")&&b.includes("origen_cita='AUTO-AGENDA'"),'legacy backfill missing');
console.log('BOOKING-V3.1 attribution contract PASS');
