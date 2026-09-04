-- WA-L10 autonomous bridge rollback.
-- Never erase immutable live canary evidence.

do $$
begin
  if to_regclass('public.aos_wa_l10_bridge_jobs_v1') is not null
     and exists(select 1 from public.aos_wa_l10_bridge_jobs_v1 limit 1) then
    raise exception 'WA_L10_BRIDGE_RECOVERY_BLOCKED_AUDIT_HISTORY' using errcode='55000';
  end if;
end
$$;

drop function if exists public.aos_wa_l10_bridge_status_v1(text);
drop function if exists public.aos_wa_l10_return_to_autonomous_canary_v1(uuid,text,uuid,text);
drop function if exists public.aos_wa_l10_bridge_pending_v1(integer);
drop function if exists public.aos_wa_l10_bridge_event_v1(text,uuid,text,text,uuid,text,integer);
drop function if exists public.aos_wa_l10_bridge_claim_v1(text);
drop function if exists public.aos_wa_l10_bridge_enqueue_v1(text);

drop trigger if exists trg_aos_wa_l10_bridge_events_append_guard_v1 on public.aos_wa_l10_bridge_events_v1;
drop trigger if exists trg_aos_wa_l10_bridge_attempts_append_guard_v1 on public.aos_wa_l10_bridge_attempts_v1;
drop trigger if exists trg_aos_wa_l10_bridge_jobs_append_guard_v1 on public.aos_wa_l10_bridge_jobs_v1;
drop function if exists public.aos_wa_l10_bridge_append_guard_v1();

drop table if exists public.aos_wa_l10_bridge_events_v1;
drop table if exists public.aos_wa_l10_bridge_attempts_v1;
drop table if exists public.aos_wa_l10_bridge_jobs_v1;
