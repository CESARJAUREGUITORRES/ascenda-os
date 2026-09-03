-- WA-L4 hardening V1: close direct table mutation routes and make AUTO_OFF imply kill=true.
begin;

-- Deployment remains dormant even if an unrelated routing flag drifted before L4.
update public.aos_wa_ai_control_v1
set auto_reply_enabled=false,updated_at=now()
where id=1;
update public.aos_wa_routing_control_v1
set ai_send_enabled=false,auto_routing_enabled=false,human_send_enabled=true,updated_at=now()
where id=1;
update public.aos_wa_auto_authority_v1
set mode='AUTO_OFF',kill_switch_engaged=true,authorization_ref=null,authorized_by=null,authorized_at=null,updated_at=now()
where id=1;

-- Runtime may inspect authority state, but all mutations must pass governed SECURITY DEFINER RPCs.
revoke all on table public.aos_wa_auto_authority_v1 from service_role;
grant select on table public.aos_wa_auto_authority_v1 to service_role;
revoke all on table public.aos_wa_auto_allowlist_v1 from service_role;
grant select on table public.aos_wa_auto_allowlist_v1 to service_role;
revoke all on table public.aos_wa_auto_decisions_v1 from service_role;
grant select on table public.aos_wa_auto_decisions_v1 to service_role;
revoke all on table public.aos_wa_auto_control_events_v1 from service_role;
grant select on table public.aos_wa_auto_control_events_v1 to service_role;

create or replace function public.aos_wa_l4_set_control_v1(
  p_actor_id uuid,
  p_mode text default null,
  p_kill_switch_engaged boolean default null,
  p_daily_message_limit integer default null,
  p_max_turns_per_conversation integer default null,
  p_global_rate_per_minute integer default null,
  p_conversation_rate_per_minute integer default null,
  p_cooldown_seconds integer default null,
  p_duplicate_window_seconds integer default null,
  p_authorization_ref text default null
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_current public.aos_wa_auto_authority_v1%rowtype;
  v_mode text;
  v_kill boolean;
  v_auth text:=nullif(btrim(coalesce(p_authorization_ref,'')),'');
  v_row public.aos_wa_auto_authority_v1%rowtype;
  v_effective_on boolean;
begin
  if not public.aos_wa_l4_is_level1_admin_v1(p_actor_id) then
    return jsonb_build_object('ok',false,'error','WA_L4_LEVEL1_ADMIN_REQUIRED');
  end if;

  select * into v_current
  from public.aos_wa_auto_authority_v1
  where id=1
  for update;
  if v_current.id is null then return jsonb_build_object('ok',false,'error','WA_L4_CONTROL_MISSING'); end if;

  v_mode:=upper(coalesce(nullif(btrim(p_mode),''),v_current.mode));
  if v_mode not in ('AUTO_OFF','CANARY','PROD') then return jsonb_build_object('ok',false,'error','WA_L4_INVALID_MODE'); end if;
  -- AUTO_OFF is semantically SAFE-OFF: kill cannot be disengaged while mode is OFF.
  v_kill:=case when v_mode='AUTO_OFF' then true else coalesce(p_kill_switch_engaged,v_current.kill_switch_engaged) end;

  if p_daily_message_limit is not null and p_daily_message_limit not between 1 and 500 then return jsonb_build_object('ok',false,'error','WA_L4_INVALID_DAILY_LIMIT'); end if;
  if p_max_turns_per_conversation is not null and p_max_turns_per_conversation not between 1 and 50 then return jsonb_build_object('ok',false,'error','WA_L4_INVALID_MAX_TURNS'); end if;
  if p_global_rate_per_minute is not null and p_global_rate_per_minute not between 1 and 120 then return jsonb_build_object('ok',false,'error','WA_L4_INVALID_GLOBAL_RATE'); end if;
  if p_conversation_rate_per_minute is not null and p_conversation_rate_per_minute not between 1 and 30 then return jsonb_build_object('ok',false,'error','WA_L4_INVALID_CONVERSATION_RATE'); end if;
  if p_cooldown_seconds is not null and p_cooldown_seconds not between 0 and 3600 then return jsonb_build_object('ok',false,'error','WA_L4_INVALID_COOLDOWN'); end if;
  if p_duplicate_window_seconds is not null and p_duplicate_window_seconds not between 0 and 86400 then return jsonb_build_object('ok',false,'error','WA_L4_INVALID_DUPLICATE_WINDOW'); end if;

  if v_mode in ('CANARY','PROD') then
    if v_auth is null or char_length(v_auth)<12 then return jsonb_build_object('ok',false,'error','WA_L4_EXPLICIT_AUTHORIZATION_REF_REQUIRED'); end if;
    if v_mode='CANARY' and not exists(
      select 1 from public.aos_wa_auto_allowlist_v1 a
      where a.active is true and (a.expires_at is null or a.expires_at>now())
    ) then return jsonb_build_object('ok',false,'error','WA_L4_CANARY_ALLOWLIST_REQUIRED'); end if;
    if v_mode='PROD' and v_current.mode<>'CANARY' then return jsonb_build_object('ok',false,'error','WA_L4_PROD_REQUIRES_CANARY_STATE'); end if;
  end if;

  update public.aos_wa_auto_authority_v1
  set mode=v_mode,
      kill_switch_engaged=v_kill,
      daily_message_limit=coalesce(p_daily_message_limit,daily_message_limit),
      max_turns_per_conversation=coalesce(p_max_turns_per_conversation,max_turns_per_conversation),
      global_rate_per_minute=coalesce(p_global_rate_per_minute,global_rate_per_minute),
      conversation_rate_per_minute=coalesce(p_conversation_rate_per_minute,conversation_rate_per_minute),
      cooldown_seconds=coalesce(p_cooldown_seconds,cooldown_seconds),
      duplicate_window_seconds=coalesce(p_duplicate_window_seconds,duplicate_window_seconds),
      authorization_ref=case when v_mode='AUTO_OFF' then null else v_auth end,
      authorized_by=case when v_mode='AUTO_OFF' then null else p_actor_id end,
      authorized_at=case when v_mode='AUTO_OFF' then null else now() end,
      updated_by=p_actor_id,
      updated_at=now()
  where id=1
  returning * into v_row;

  v_effective_on:=(v_row.mode in ('CANARY','PROD') and v_row.kill_switch_engaged is false);

  update public.aos_wa_ai_control_v1
  set auto_reply_enabled=v_effective_on,updated_by=p_actor_id,updated_at=now()
  where id=1;
  update public.aos_wa_routing_control_v1
  set ai_send_enabled=v_effective_on,
      auto_routing_enabled=false,
      human_send_enabled=true,
      updated_by=p_actor_id,
      updated_at=now()
  where id=1;

  insert into public.aos_wa_auto_control_events_v1(event_type,actor_id,payload)
  values('CONTROL_SET',p_actor_id,jsonb_build_object(
    'mode',v_row.mode,
    'kill_switch_engaged',v_row.kill_switch_engaged,
    'effective_autonomous_send',v_effective_on,
    'daily_message_limit',v_row.daily_message_limit,
    'max_turns_per_conversation',v_row.max_turns_per_conversation,
    'global_rate_per_minute',v_row.global_rate_per_minute,
    'conversation_rate_per_minute',v_row.conversation_rate_per_minute,
    'cooldown_seconds',v_row.cooldown_seconds,
    'duplicate_window_seconds',v_row.duplicate_window_seconds,
    'authorization_ref_present',v_row.authorization_ref is not null));

  return jsonb_build_object(
    'ok',true,
    'mode',v_row.mode,
    'kill_switch_engaged',v_row.kill_switch_engaged,
    'effective_autonomous_send',v_effective_on,
    'auto_reply_enabled',v_effective_on,
    'ai_send_enabled',v_effective_on,
    'auto_routing_enabled',false,
    'human_send_enabled',true
  );
end
$$;

revoke all on function public.aos_wa_l4_set_control_v1(uuid,text,boolean,integer,integer,integer,integer,integer,integer,text) from public,anon,authenticated;
grant execute on function public.aos_wa_l4_set_control_v1(uuid,text,boolean,integer,integer,integer,integer,integer,integer,text) to service_role;

select pg_notify('pgrst','reload schema');
commit;
