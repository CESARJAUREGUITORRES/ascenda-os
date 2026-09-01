-- Rollback AGV2-2 additive transactional contract V1.
begin;

drop function if exists public.aos_wa4_rebook_booking_v2(uuid,text,uuid,text,jsonb);
drop function if exists public.aos_wa4_commit_booking_v2(uuid,text,uuid,jsonb);
drop function if exists public.aos_agenda_rebook_v2(text,text,text,jsonb);
drop function if exists public.aos_agenda_commit_booking_v2(text,text,jsonb);
drop function if exists public.aos_booking_rebook_core_v2(jsonb,text,text,jsonb);
drop function if exists public.aos_booking_commit_core_v2(jsonb,text,jsonb);
drop function if exists public.aos_booking_resolve_selected_slot_v2(uuid,date,text,time,text,text);
drop trigger if exists trg_aos_agenda_events_v2_append_only on public.aos_agenda_events_v2;
drop function if exists public.aos_agenda_events_v2_append_only_guard();
drop table if exists public.aos_agenda_events_v2;
drop table if exists public.aos_booking_operations_v2;

commit;
