-- WA-L9 recovery. Recovery is permitted only before durable demo audit history exists.

begin;

do $$
begin
  if to_regclass('public.aos_wa_l9_demo_runs_v1') is not null
     and exists(select 1 from public.aos_wa_l9_demo_runs_v1 limit 1) then
    raise exception 'WA_L9_RECOVERY_BLOCKED_AUDIT_HISTORY' using errcode='55000';
  end if;
end $$;

drop trigger if exists trg_aos_wa_l9_demo_runs_append_guard_v1 on public.aos_wa_l9_demo_runs_v1;
drop function if exists public.aos_wa_l9_status_v1();
drop function if exists public.aos_wa_l9_demo_record_v1(text,uuid,text,text,text,text,jsonb);
drop function if exists public.aos_wa_l9_shadow_authorize_v1(uuid,text,text,text,text,text,text,text,text,boolean,text);
drop function if exists public.aos_wa_l9_append_guard_v1();
drop table if exists public.aos_wa_l9_demo_runs_v1;

select pg_catalog.pg_notify('pgrst','reload schema');
commit;