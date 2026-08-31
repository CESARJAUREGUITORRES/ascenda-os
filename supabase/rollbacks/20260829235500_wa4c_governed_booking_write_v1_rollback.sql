begin;
drop trigger if exists trg_001_aos_wa4_governed_booking_v1 on public.aos_agenda_citas;
drop function if exists public.aos_wa4_require_governed_booking_v1();
drop function if exists public.aos_wa4_commit_booking_v1(uuid,text,uuid,jsonb);
drop table if exists public.aos_wa4_booking_actions_v1;
commit;
