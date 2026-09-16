const fs=require('fs');
function ok(v,m){if(!v)throw new Error(m)}
const m=fs.readFileSync('supabase/migrations/20260916070000_booking_v32_canonical_treatments.sql','utf8');
const n=fs.readFileSync('supabase/migrations/20260916055000_booking_v31_admin_notification_relabel.sql','utf8');
const a=fs.readFileSync('supabase/migrations/20260916071000_booking_v32_advisor_permanent_link.sql','utf8');
const u=fs.readFileSync('app/public/agendar-v2.html','utf8');
const shell=fs.readFileSync('app/public/clinic-shell-ui-v1.js','utf8');
for(const x of ['aos_cat_tratamientos','aos_booking_treatment_ref_v32','aos_booking_public_catalog_v2','aos_booking_availability_v2','aos_agendar_publica_v2']) ok(m.includes(x),'missing '+x);
ok(m.includes("md5('BOOKING-V32|'")&&m.includes("||r.role)::uuid"),'role-specific deterministic adapter missing');
ok(m.includes("'DOCTORA'")&&m.includes("'ENFERMERIA'"),'canonical roles missing');
ok(m.includes('t.tratamiento')&&m.includes('insert into public.aos_agenda_citas'),'canonical treatment is not persisted');
ok(m.includes('pg_advisory_xact_lock')&&m.includes('SLOT_NO_LONGER_AVAILABLE'),'slot concurrency/revalidation missing');
ok(m.includes('aos_booking_attribution_v1(p_token)'),'V3.1 attribution not preserved');
ok(n.includes("contenido=f->>'body'")&&!n.includes('mensaje='),'notification relabel not aligned to live schema');
ok(a.includes('aos_booking_advisor_permanent_link_v32')&&a.includes('ADVISOR_LINK'),'advisor link authority missing');
ok(u.includes('futureCount(prof)')&&u.includes('Number(AG.diasCount[p.id]||0)>0'),'future-available professional filter missing');
ok(u.includes('Usamos la misma lista de tratamientos de Agenda/Call Center'),'canonical treatment UX marker missing');
ok(shell.includes('aos_booking_advisor_permanent_link_v32')&&shell.includes('Tu link permanente de asesor'),'advisor modal auto-link missing');
console.log('BOOKING-V3.2 canonical treatment/UI contract PASS');