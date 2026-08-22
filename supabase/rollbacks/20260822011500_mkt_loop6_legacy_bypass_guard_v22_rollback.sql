drop trigger if exists trg_000_aos_loop6_governed_call_v22 on public.aos_llamadas;
drop trigger if exists trg_000_aos_loop6_governed_agenda_v22 on public.aos_agenda_citas;
drop function if exists public.aos_loop6_require_governed_call_v22();
drop function if exists public.aos_loop6_require_governed_agenda_v22();

do $rollback$
declare v_def text;
begin
  select definition into v_def
  from public.aos_loop6_function_backups_v1
  where backup_key='20260821_legacy_bypass_guard_v22'
    and function_name='aos_callcenter_commit_action_core_v1'
  order by captured_at desc limit 1;
  if v_def is null then raise exception 'Missing Loop6 core backup'; end if;
  execute v_def;
end
$rollback$;
