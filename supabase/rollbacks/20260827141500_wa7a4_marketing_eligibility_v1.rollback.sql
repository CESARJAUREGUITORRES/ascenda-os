-- WA-7A.4 rollback — fail closed once eligibility evidence exists.

begin;

do $$
begin
  if to_regclass('public.aos_wa_marketing_eligibility_events_v1') is not null
     and exists(select 1 from public.aos_wa_marketing_eligibility_events_v1 limit 1) then
    raise exception 'WA7A4_ROLLBACK_BLOCKED_ELIGIBILITY_EVIDENCE_EXISTS' using errcode='55000';
  end if;
end
$$;

drop function if exists public.aos_wa_marketing_eligibility_check_v1(uuid,text);
drop view if exists public.aos_wa_marketing_eligibility_v1;
drop function if exists public.aos_wa_marketing_eligibility_record_v1(jsonb);
drop trigger if exists trg_aos_wa7a4_eligibility_immutable_guard_v1 on public.aos_wa_marketing_eligibility_events_v1;
drop function if exists public.aos_wa7a4_eligibility_immutable_guard_v1();
drop table if exists public.aos_wa_marketing_eligibility_events_v1;

select pg_notify('pgrst','reload schema');
commit;
