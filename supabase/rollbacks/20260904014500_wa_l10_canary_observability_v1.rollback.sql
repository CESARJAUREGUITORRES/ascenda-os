-- WA-L10 A3 rollback. Audit history is immutable: recovery refuses to erase evidence.
begin;

do $$
begin
  if to_regclass('public.aos_wa_l10_canary_runs_v1') is not null
     and exists(select 1 from public.aos_wa_l10_canary_runs_v1 limit 1) then
    raise exception 'WA_L10_RECOVERY_BLOCKED_AUDIT_HISTORY' using errcode='55000';
  end if;
  if to_regclass('public.aos_wa_l10_canary_scope_v1') is not null
     and exists(select 1 from public.aos_wa_l10_canary_scope_v1 limit 1) then
    raise exception 'WA_L10_RECOVERY_BLOCKED_AUDIT_HISTORY' using errcode='55000';
  end if;
end
$$;

drop function if exists public.aos_wa_l10_status_v1(text);
drop function if exists public.aos_wa_l10_attach_scope_v1(uuid,text,uuid,text,text);
drop function if exists public.aos_wa_l10_prepare_run_v1(uuid,text,jsonb,text,text,text,text,text,text,text,text,text,text,text);
drop trigger if exists trg_aos_wa_l10_scope_append_guard_v1 on public.aos_wa_l10_canary_scope_v1;
drop trigger if exists trg_aos_wa_l10_runs_append_guard_v1 on public.aos_wa_l10_canary_runs_v1;
drop function if exists public.aos_wa_l10_append_guard_v1();
drop table if exists public.aos_wa_l10_canary_scope_v1;
drop table if exists public.aos_wa_l10_canary_runs_v1;

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
