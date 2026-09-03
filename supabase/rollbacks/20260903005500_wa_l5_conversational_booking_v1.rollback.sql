-- WA-L5 recovery: structural rollback is allowed only before committed L5 lineage exists.
begin;

do $$
begin
  if to_regclass('public.aos_wa_l5_booking_events_v1') is not null and exists(
    select 1 from public.aos_wa_l5_booking_events_v1 where event_type='COMMITTED'
  ) then
    raise exception 'WA_L5_RECOVERY_BLOCKED_COMMITTED_HISTORY' using errcode='55000';
  end if;
end
$$;

drop function if exists public.aos_wa_l5_commit_confirmed_v1(uuid,uuid,text);
drop function if exists public.aos_wa_l5_mark_explicit_confirmation_v1(uuid,uuid,text);
drop function if exists public.aos_wa_l5_prepare_confirmation_v1(uuid,text,uuid,text,date,time,text,text,text,text,text,integer);
drop function if exists public.aos_wa_l5_appointment_treatment_v1(text);
drop function if exists public.aos_wa_l5_active_appointments_v1(uuid);
drop function if exists public.aos_wa_l5_verify_patient_v1(uuid,text);
drop function if exists public.aos_wa_l5_availability_v1(uuid,uuid,text,date,text,text,integer);
drop function if exists public.aos_wa_l5_status_v1(uuid);
drop function if exists public.aos_wa_l5_is_explicit_affirmative_v1(text);
drop trigger if exists trg_aos_wa_l5_booking_events_append_guard_v1 on public.aos_wa_l5_booking_events_v1;
drop function if exists public.aos_wa_l5_log_event_v1(uuid,text,text,text,bigint,text,uuid,jsonb);
drop function if exists public.aos_wa_l5_append_guard_v1();
drop table if exists public.aos_wa_l5_booking_events_v1;
drop table if exists public.aos_wa_l5_booking_memory_v1;

select pg_notify('pgrst','reload schema');
commit;
