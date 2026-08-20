-- REV-F6.2 recovery — remove lifecycle read-models and restore certified F6.1 gateway.
begin;

drop function if exists public.aos_patient_commercial_360_v2(text,text,text);

do $$
begin
  if to_regprocedure('public.aos_patient_commercial_360_v2_f6_1_base(text,text,text)') is not null then
    alter function public.aos_patient_commercial_360_v2_f6_1_base(text,text,text) rename to aos_patient_commercial_360_v2;
  end if;
end $$;

revoke all on function public.aos_patient_commercial_360_v2(text,text,text) from public;
grant execute on function public.aos_patient_commercial_360_v2(text,text,text) to anon,authenticated,service_role;

drop function if exists public.aos_rev_customer_lifecycle_summary_v1(date);
drop function if exists public.aos_rev_customer_lifecycle_v1(text,text,date);
drop function if exists public.aos_rev_customer_lifecycle_by_patient_v1(text,date);
drop view if exists public.aos_rev_customer_lifecycle_events_v1;
drop view if exists public.aos_rev_customer_agenda_identity_v1;

select pg_notify('pgrst','reload schema');
commit;
