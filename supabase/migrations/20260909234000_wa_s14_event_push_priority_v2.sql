-- WA-S14 production closeout: keep generic notification polling shielded while
-- restoring the bounded event-driven WhatsApp notification path.
-- No autonomous message authority changes.

begin;

-- Runtime VAPID read uses a dedicated service-role RPC name so the P0 foreground
-- shield can continue suppressing the historical background VAPID/pump paths.
create or replace function public.aos_push_vapid_runtime_config_v2(p_payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
begin
  return public.aos_push_vapid_config_v1(coalesce(p_payload,'{}'::jsonb));
end
$$;

revoke all on function public.aos_push_vapid_runtime_config_v2(jsonb) from public,anon,authenticated;
grant execute on function public.aos_push_vapid_runtime_config_v2(jsonb) to service_role;

-- V2 keeps the existing assigned HUMAN_ACTIVE behavior and adds one bounded
-- queue-supervisor fallback for an unassigned HUMAN_REQUESTED conversation.
-- Exactly one recipient is selected deterministically to avoid notification storms.
create or replace function public.aos_push_targets_for_wa_v2(p_payload jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path='public','pg_temp'
as $$
declare
  v_phone text:=trim(coalesce(p_payload->>'phone_number_id',''));
  v_provider_id text:=trim(coalesce(p_payload->>'provider_message_id',''));
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_recipient uuid;
  v_delivery_reason text;
  v_subs jsonb;
begin
  if v_provider_id='' then
    return jsonb_build_object('ok',false,'eligible',false,'error','INVALID_WA_TARGET');
  end if;

  select c.* into v_conv
  from public.aos_wa_messages_v1 m
  join public.aos_wa_conversations_v1 c on c.id=m.conversation_id
  where m.provider_message_id=v_provider_id
    and m.direction='INBOUND'
    and (v_phone='' or c.phone_number_id=v_phone)
    and c.last_message_id=v_provider_id
  order by c.updated_at desc
  limit 1;

  if not found then
    return jsonb_build_object('ok',true,'eligible',false,'reason','CONVERSATION_NOT_CURRENT');
  end if;
  if v_conv.last_message_direction<>'INBOUND' then
    return jsonb_build_object('ok',true,'eligible',false,'reason','INBOUND_NOT_CURRENT');
  end if;

  if v_conv.state='HUMAN_ACTIVE' and v_conv.owner_user_id is not null then
    v_recipient:=v_conv.owner_user_id;
    v_delivery_reason:='ASSIGNED_HUMAN_OWNER';
  elsif v_conv.state='HUMAN_REQUESTED' and v_conv.owner_user_id is null and v_conv.box_id is not null then
    select u.id into v_recipient
    from public.aos_wa_box_members_v1 bm
    join public.aos_usuarios u on u.id=bm.user_id and u.activo=true
    left join public.aos_wa_agent_presence_v1 p on p.user_id=u.id
    where bm.box_id=v_conv.box_id
      and bm.active=true
      and exists (
        select 1 from public.aos_push_subscriptions_v1 s
        where s.user_id=u.id
          and s.active=true
          and coalesce((s.channel_preferences->>'WHATSAPP')::boolean,true)=true
      )
    order by
      case coalesce(p.status,'OFFLINE') when 'AVAILABLE' then 0 when 'AWAY' then 1 else 2 end,
      case when p.last_seen_at>=now()-interval '10 minutes' then 0 else 1 end,
      u.nivel_jerarquia asc nulls last,
      bm.priority desc,
      bm.last_assigned_at asc nulls first,
      u.id
    limit 1;
    if v_recipient is null then
      return jsonb_build_object('ok',true,'eligible',false,'reason','NO_QUEUE_NOTIFICATION_RECIPIENT','conversation_id',v_conv.id);
    end if;
    v_delivery_reason:='QUEUE_SUPERVISOR_FALLBACK';
  else
    return jsonb_build_object('ok',true,'eligible',false,'reason','HUMAN_OWNER_REQUIRED','conversation_id',v_conv.id);
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',s.id,'endpoint',s.endpoint,'p256dh',s.p256dh,'auth',s.auth
  ) order by s.updated_at desc),'[]'::jsonb)
  into v_subs
  from public.aos_push_subscriptions_v1 s
  where s.user_id=v_recipient
    and s.active=true
    and coalesce((s.channel_preferences->>'WHATSAPP')::boolean,true)=true;

  if jsonb_array_length(v_subs)=0 then
    return jsonb_build_object('ok',true,'eligible',false,'reason','NO_ACTIVE_PUSH_SUBSCRIPTION','conversation_id',v_conv.id,'owner_user_id',v_recipient);
  end if;

  return jsonb_build_object(
    'ok',true,
    'eligible',true,
    'conversation_id',v_conv.id,
    'owner_user_id',v_recipient,
    'delivery_reason',v_delivery_reason,
    'contact_name',v_conv.contact_name,
    'contact_number',v_conv.contact_number,
    'contact_address_type',v_conv.contact_address_type,
    'contact_username',v_conv.contact_username,
    'subscriptions',v_subs
  );
end
$$;

revoke all on function public.aos_push_targets_for_wa_v2(jsonb) from public,anon,authenticated;
grant execute on function public.aos_push_targets_for_wa_v2(jsonb) to service_role;

commit;
