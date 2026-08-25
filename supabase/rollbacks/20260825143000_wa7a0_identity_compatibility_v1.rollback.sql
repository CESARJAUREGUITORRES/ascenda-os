-- WA-7A.0 Identity Compatibility V1 rollback
-- Fail closed once BSUID evidence exists because the phone-only model cannot represent it.

begin;

do $$
begin
  if exists(select 1 from public.aos_wa_messages_v1 where from_user_id is not null or from_parent_user_id is not null or to_user_id is not null or to_parent_user_id is not null)
     or exists(select 1 from public.aos_wa_conversations_v1 where contact_address_type='BSUID' or contact_bsuid is not null or contact_parent_bsuid is not null)
     or exists(select 1 from public.aos_wa_channel_aliases_v1 where alias_type in ('BSUID','PARENT_BSUID'))
     or exists(select 1 from public.aos_wa_outbound_requests_v1 where recipient_kind='BSUID') then
    raise exception 'WA7A0_ROLLBACK_BLOCKED_BSUID_DATA' using errcode='55000';
  end if;
end
$$;

drop trigger if exists trg_aos_wa7a0_normalize_outbound_request_v1 on public.aos_wa_outbound_requests_v1;
drop function if exists public.aos_wa7a0_normalize_outbound_request_v1();

-- Restore phone-only WA-2 bind behavior.
create or replace function public.aos_wa2_bind_conversation_v1()
returns trigger
language plpgsql
set search_path=public,pg_temp
as $$
declare
  v_contact text;
  v_key text;
  v_ts timestamptz;
  v_conv uuid;
begin
  if tg_op='UPDATE' and new.conversation_id is not null then return new; end if;
  v_contact:=regexp_replace(coalesce(case when new.direction='INBOUND' then new.from_number else new.to_number end,''),'[^0-9]','','g');
  if v_contact='' then raise exception 'WA2_CONTACT_REQUIRED' using errcode='23514'; end if;
  v_key:=coalesce(nullif(new.phone_number_id,''),'default')||':'||v_contact;
  v_ts:=coalesce(new.provider_timestamp,new.received_at,new.sent_at,new.created_at,now());
  insert into public.aos_wa_conversations_v1(conversation_key,contact_number,contact_name,phone_number_id,state,opened_at,updated_at)
  values(v_key,v_contact,nullif(new.contact_name,''),new.phone_number_id,'NEW',v_ts,now())
  on conflict(conversation_key) do nothing returning id into v_conv;
  if v_conv is null then select id into v_conv from public.aos_wa_conversations_v1 where conversation_key=v_key; end if;
  if v_conv is null then raise exception 'WA2_CONVERSATION_BIND_FAILED'; end if;
  new.conversation_id:=v_conv;return new;
end
$$;

-- Restore WA-3 authorization response to phone-only recipient.
create or replace function public.aos_wa3_human_send_authorize_v1(p_token text,p_conversation_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_actor jsonb; v_uid uuid; v_conv record; v_enabled boolean;
begin
  v_actor:=public.aos_wa3_actor_v1(p_token);
  if coalesce((v_actor->>'ok')::boolean,false) is not true then return v_actor; end if;
  v_uid:=(v_actor->>'actor_id')::uuid;
  select human_send_enabled into v_enabled from public.aos_wa_routing_control_v1 where id=1;
  if coalesce(v_enabled,false) is not true then return jsonb_build_object('ok',false,'error','WA3_HUMAN_SEND_DISABLED'); end if;
  select c.id,c.contact_number,c.owner_user_id,c.state,c.box_id into v_conv from public.aos_wa_conversations_v1 c where c.id=p_conversation_id;
  if v_conv.id is null then return jsonb_build_object('ok',false,'error','WA3_CONVERSATION_NOT_FOUND'); end if;
  if v_conv.owner_user_id is distinct from v_uid then return jsonb_build_object('ok',false,'error','WA3_NOT_OWNER'); end if;
  if v_conv.state not in ('HUMAN_ACTIVE','AI_COPILOT') then return jsonb_build_object('ok',false,'error','WA3_HUMAN_MODE_REQUIRED'); end if;
  if not exists(select 1 from public.aos_wa_assignments_v1 a where a.conversation_id=p_conversation_id and a.owner_user_id=v_uid and a.state='ACTIVE') then return jsonb_build_object('ok',false,'error','WA3_ACTIVE_ASSIGNMENT_REQUIRED'); end if;
  return jsonb_build_object('ok',true,'actor_id',v_uid,'conversation_id',v_conv.id,'to_number',v_conv.contact_number,'state',v_conv.state,'box_id',v_conv.box_id);
end
$$;

-- Restore S14 phone-target resolver.
create or replace function public.aos_push_targets_for_wa_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_contact text:=regexp_replace(coalesce(p_payload->>'contact_number',''),'\D','','g');
  v_phone text:=trim(coalesce(p_payload->>'phone_number_id',''));
  v_provider_id text:=trim(coalesce(p_payload->>'provider_message_id',''));
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_subs jsonb;
begin
  if length(v_contact)<8 or v_provider_id='' then return jsonb_build_object('ok',false,'eligible',false,'error','INVALID_WA_TARGET'); end if;
  select * into v_conv from public.aos_wa_conversations_v1 c
  where regexp_replace(c.contact_number,'\D','','g')=v_contact
    and (v_phone='' or c.phone_number_id=v_phone)
    and c.last_message_id=v_provider_id
  order by c.updated_at desc limit 1;
  if not found then return jsonb_build_object('ok',true,'eligible',false,'reason','CONVERSATION_NOT_CURRENT'); end if;
  if v_conv.state<>'HUMAN_ACTIVE' or v_conv.owner_user_id is null or v_conv.last_message_direction<>'INBOUND' then
    return jsonb_build_object('ok',true,'eligible',false,'reason','HUMAN_OWNER_REQUIRED');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'endpoint',s.endpoint,'p256dh',s.p256dh,'auth',s.auth) order by s.updated_at desc),'[]'::jsonb)
  into v_subs from public.aos_push_subscriptions_v1 s
  where s.user_id=v_conv.owner_user_id and s.active=true and coalesce((s.channel_preferences->>'WHATSAPP')::boolean,true)=true;
  return jsonb_build_object('ok',true,'eligible',true,'conversation_id',v_conv.id,'owner_user_id',v_conv.owner_user_id,'contact_name',v_conv.contact_name,'contact_number',v_conv.contact_number,'subscriptions',v_subs);
end
$$;

update public.aos_wa_outbound_requests_v1
set to_number=recipient_address
where recipient_kind='PHONE' and to_number is null;

do $$
begin
  if exists(select 1 from public.aos_wa_conversations_v1 where contact_number is null)
     or exists(select 1 from public.aos_wa_outbound_requests_v1 where to_number is null) then
    raise exception 'WA7A0_ROLLBACK_PHONE_REQUIRED' using errcode='55000';
  end if;
end
$$;

alter table public.aos_wa_outbound_requests_v1 drop constraint if exists aos_wa_outbound_requests_v1_recipient_kind_chk;
alter table public.aos_wa_outbound_requests_v1 alter column to_number set not null;
alter table public.aos_wa_outbound_requests_v1 drop column if exists recipient_kind;
alter table public.aos_wa_outbound_requests_v1 drop column if exists recipient_address;

alter table public.aos_wa_conversations_v1 drop constraint if exists aos_wa_conversations_v1_contact_address_type_chk;
alter table public.aos_wa_conversations_v1 alter column contact_number set not null;
drop index if exists public.aos_wa_conversations_v1_bsuid_idx;
drop index if exists public.aos_wa_conversations_v1_address_idx;
alter table public.aos_wa_conversations_v1
  drop column if exists contact_address,
  drop column if exists contact_address_type,
  drop column if exists contact_bsuid,
  drop column if exists contact_parent_bsuid,
  drop column if exists contact_username;

drop table if exists public.aos_wa_channel_aliases_v1;

drop index if exists public.aos_wa_messages_v1_from_user_idx;
drop index if exists public.aos_wa_messages_v1_to_user_idx;
alter table public.aos_wa_messages_v1
  drop column if exists from_user_id,
  drop column if exists from_parent_user_id,
  drop column if exists to_user_id,
  drop column if exists to_parent_user_id,
  drop column if exists contact_username;

revoke all on function public.aos_wa2_bind_conversation_v1() from public,anon,authenticated;
revoke all on function public.aos_wa3_human_send_authorize_v1(text,uuid) from public;
revoke all on function public.aos_push_targets_for_wa_v1(jsonb) from public,anon,authenticated;
grant execute on function public.aos_wa3_human_send_authorize_v1(text,uuid) to anon,authenticated,service_role;
grant execute on function public.aos_push_targets_for_wa_v1(jsonb) to service_role;

commit;
