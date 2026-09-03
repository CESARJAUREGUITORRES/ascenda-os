-- WA-L4 recovery to pre-L4 structural SAFE-OFF.
-- Fail closed once any real autonomous outbound history exists; that history must never be silently discarded.

begin;

-- Always force runtime controls safe before attempting structural recovery.
update public.aos_wa_ai_control_v1 set auto_reply_enabled=false,updated_at=now() where id=1;
update public.aos_wa_routing_control_v1
set ai_send_enabled=false,auto_routing_enabled=false,human_send_enabled=true,updated_at=now()
where id=1;

update public.aos_wa_auto_authority_v1
set mode='AUTO_OFF',kill_switch_engaged=true,authorization_ref=null,authorized_by=null,authorized_at=null,updated_at=now()
where id=1;

do $$
begin
  if exists(select 1 from public.aos_wa_outbound_requests_v1 where send_origin='AUTO')
     or exists(select 1 from public.aos_wa_messages_v1 where send_origin='AUTO') then
    raise exception 'WA_L4_RECOVERY_BLOCKED_AUTO_HISTORY' using errcode='55000';
  end if;
end
$$;

-- Remove additive lineage only after proving no autonomous provider history exists.
drop index if exists public.aos_wa_outbound_requests_v1_auto_idx;
drop index if exists public.aos_wa_messages_v1_auto_idx;
alter table public.aos_wa_outbound_requests_v1 drop column if exists authority_decision_id;
alter table public.aos_wa_outbound_requests_v1 drop column if exists conversation_id;
alter table public.aos_wa_outbound_requests_v1 drop column if exists send_origin;
alter table public.aos_wa_messages_v1 drop column if exists authority_decision_id;
alter table public.aos_wa_messages_v1 drop column if exists send_origin;

drop function if exists public.aos_wa_l4_status_v1();
drop function if exists public.aos_wa_l4_authorize_autonomous_send_v1(uuid,text,text,text,text,text,text,text,text,boolean,text);
drop function if exists public.aos_wa_l4_set_control_v1(uuid,text,boolean,integer,integer,integer,integer,integer,integer,text);
drop function if exists public.aos_wa_l4_allowlist_set_v1(uuid,text,text,boolean,timestamptz,text);
drop function if exists public.aos_wa_l4_normalize_subject_v1(text,text);
drop function if exists public.aos_wa_l4_is_level1_admin_v1(uuid);

drop trigger if exists trg_aos_wa_l4_control_event_append_guard_v1 on public.aos_wa_auto_control_events_v1;
drop trigger if exists trg_aos_wa_l4_decision_append_guard_v1 on public.aos_wa_auto_decisions_v1;
drop function if exists public.aos_wa_l4_append_guard_v1();
drop table if exists public.aos_wa_auto_control_events_v1;
drop table if exists public.aos_wa_auto_allowlist_v1;
drop table if exists public.aos_wa_auto_decisions_v1;
drop table if exists public.aos_wa_auto_authority_v1;

-- Restore the pre-L4 structural prohibition after flags are known false.
alter table public.aos_wa_ai_control_v1
  drop constraint if exists aos_wa_ai_control_v1_auto_reply_enabled_check;
alter table public.aos_wa_ai_control_v1
  add constraint aos_wa_ai_control_v1_auto_reply_enabled_check check (auto_reply_enabled=false);
alter table public.aos_wa_routing_control_v1
  drop constraint if exists aos_wa_routing_control_v1_ai_send_enabled_check;
alter table public.aos_wa_routing_control_v1
  add constraint aos_wa_routing_control_v1_ai_send_enabled_check check (ai_send_enabled=false);

comment on table public.aos_wa_ai_control_v1 is 'WA-4 Groq model/control registry. Copilot defaults OFF; automatic AI reply is structurally forbidden.';
select pg_notify('pgrst','reload schema');
commit;
