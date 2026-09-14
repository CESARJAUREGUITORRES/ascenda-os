-- WA continuity hardening: stale autonomous jobs cannot send or force human handoff.
begin;

create or replace function public.aos_wa_l10_message_current_v1(p_provider_message_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_job public.aos_wa_l10_bridge_jobs_v1%rowtype;
  v_msg record;
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_current boolean:=false;
begin
  select * into v_job
  from public.aos_wa_l10_bridge_jobs_v1
  where provider_message_id=p_provider_message_id;

  if v_job.provider_message_id is null then
    return jsonb_build_object('ok',false,'error','WA_L10_JOB_NOT_FOUND','current',false);
  end if;

  select m.provider_message_id,m.conversation_id,m.direction,m.created_at
    into v_msg
  from public.aos_wa_messages_v1 m
  where m.provider_message_id=p_provider_message_id
  limit 1;

  if v_msg.provider_message_id is null or v_msg.direction<>'INBOUND' then
    return jsonb_build_object('ok',true,'current',false,'reason','WA_L10_INBOUND_REQUIRED');
  end if;

  select * into v_conv
  from public.aos_wa_conversations_v1
  where id=v_job.conversation_id;

  if v_conv.id is null then
    return jsonb_build_object('ok',true,'current',false,'reason','WA_L10_CONVERSATION_NOT_FOUND');
  end if;

  v_current :=
    v_msg.conversation_id=v_conv.id
    and v_conv.last_message_direction='INBOUND'
    and v_conv.last_message_id=p_provider_message_id
    and not exists(
      select 1
      from public.aos_wa_messages_v1 newer
      where newer.conversation_id=v_conv.id
        and newer.created_at>v_msg.created_at
    );

  return jsonb_build_object(
    'ok',true,
    'current',v_current,
    'reason',case when v_current then 'WA_L10_CURRENT_MESSAGE' else 'WA_L10_STALE_MESSAGE' end,
    'conversation_id',v_conv.id
  );
end
$$;

create or replace function public.aos_wa_l10_handoff_if_current_v1(
  p_provider_message_id text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_job public.aos_wa_l10_bridge_jobs_v1%rowtype;
  v_msg record;
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_reason text:=left(regexp_replace(upper(btrim(coalesce(p_reason,'WA_L10_AI_HANDOFF'))),'[^A-Z0-9_.:-]','_','g'),128);
  v_out jsonb;
begin
  select * into v_job
  from public.aos_wa_l10_bridge_jobs_v1
  where provider_message_id=p_provider_message_id;

  if v_job.provider_message_id is null then
    return jsonb_build_object('ok',false,'error','WA_L10_JOB_NOT_FOUND','handed_off',false);
  end if;

  select m.provider_message_id,m.conversation_id,m.direction,m.created_at
    into v_msg
  from public.aos_wa_messages_v1 m
  where m.provider_message_id=p_provider_message_id
  limit 1;

  if v_msg.provider_message_id is null or v_msg.direction<>'INBOUND' then
    return jsonb_build_object('ok',true,'handed_off',false,'stale',true,'reason','WA_L10_INBOUND_REQUIRED');
  end if;

  select * into v_conv
  from public.aos_wa_conversations_v1
  where id=v_job.conversation_id
  for update;

  if v_conv.id is null then
    return jsonb_build_object('ok',true,'handed_off',false,'stale',true,'reason','WA_L10_CONVERSATION_NOT_FOUND');
  end if;

  if v_msg.conversation_id<>v_conv.id
     or v_conv.last_message_direction<>'INBOUND'
     or v_conv.last_message_id is distinct from p_provider_message_id
     or exists(
       select 1
       from public.aos_wa_messages_v1 newer
       where newer.conversation_id=v_conv.id
         and newer.created_at>v_msg.created_at
     )
  then
    return jsonb_build_object(
      'ok',true,'handed_off',false,'stale',true,
      'reason','WA_L10_STALE_HANDOFF_SKIPPED','conversation_id',v_conv.id
    );
  end if;

  v_out:=public.aos_wa3_handoff_request_v1(v_conv.id,null,null,v_reason);

  return jsonb_build_object(
    'ok',coalesce((v_out->>'ok')::boolean,false),
    'handed_off',coalesce((v_out->>'ok')::boolean,false),
    'stale',false,
    'reason',case when coalesce((v_out->>'ok')::boolean,false) then v_reason else coalesce(v_out->>'error','WA_L10_HANDOFF_FAILED') end,
    'handoff',v_out
  );
end
$$;

revoke all on function public.aos_wa_l10_message_current_v1(text) from public,anon,authenticated;
revoke all on function public.aos_wa_l10_handoff_if_current_v1(text,text) from public,anon,authenticated;
grant execute on function public.aos_wa_l10_message_current_v1(text) to service_role;
grant execute on function public.aos_wa_l10_handoff_if_current_v1(text,text) to service_role;

comment on function public.aos_wa_l10_message_current_v1(text) is
'Race guard: exact inbound provider message must still be the current conversation turn before autonomous send.';
comment on function public.aos_wa_l10_handoff_if_current_v1(text,text) is
'Race guard: stale autonomous jobs can never move a newer conversation into HUMAN_REQUESTED.';

commit;
