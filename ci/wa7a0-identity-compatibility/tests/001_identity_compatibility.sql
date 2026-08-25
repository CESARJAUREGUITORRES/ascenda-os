\set ON_ERROR_STOP on

-- WA-7A.0 DB behavioral contract. Any violated invariant aborts psql.

do $$
declare
  v_c1 uuid;
  v_c2 uuid;
  v_req text:='wa7a0:req:1234567890123456';
begin
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='aos_wa_messages_v1' and column_name='from_user_id') then raise exception 'MISSING_FROM_USER_ID'; end if;
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='aos_wa_conversations_v1' and column_name='contact_address') then raise exception 'MISSING_CONTACT_ADDRESS'; end if;
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='aos_wa_outbound_requests_v1' and column_name='recipient_address') then raise exception 'MISSING_RECIPIENT_ADDRESS'; end if;
  if to_regclass('public.aos_wa_channel_aliases_v1') is null then raise exception 'MISSING_ALIAS_LEDGER'; end if;

  -- First inbound exposes phone + BSUID.
  insert into public.aos_wa_messages_v1(
    provider_message_id,direction,from_number,from_user_id,from_parent_user_id,phone_number_id,contact_name,contact_username,message_type,message_body,status,provider_timestamp,received_at
  ) values (
    'wamid.wa7a0.dual','INBOUND','51911112222','PE.user.001','PE.parent.001','pn-wa7a0','Dual User','dual.user','text','hola','received',now(),now()
  );
  select conversation_id into v_c1 from public.aos_wa_messages_v1 where provider_message_id='wamid.wa7a0.dual';
  if v_c1 is null then raise exception 'DUAL_NOT_BOUND'; end if;
  if not exists(select 1 from public.aos_wa_conversations_v1 where id=v_c1 and contact_number='51911112222' and contact_bsuid='PE.user.001' and contact_address_type='PHONE' and contact_address='51911112222' and contact_username='dual.user') then raise exception 'DUAL_FACTS_NOT_PRESERVED'; end if;
  if (select count(*) from public.aos_wa_channel_aliases_v1 where conversation_id=v_c1 and alias_type in ('PHONE','BSUID','PARENT_BSUID'))<>3 then raise exception 'DUAL_ALIASES_MISSING'; end if;

  -- Later privacy-safe inbound exposes only BSUID. It MUST remain in same conversation.
  insert into public.aos_wa_messages_v1(
    provider_message_id,direction,from_number,from_user_id,phone_number_id,contact_name,contact_username,message_type,message_body,status,provider_timestamp,received_at
  ) values (
    'wamid.wa7a0.bsuid-only','INBOUND',null,'PE.user.001','pn-wa7a0','Dual User','dual.newname','text','privado','received',now()+interval '1 second',now()
  );
  select conversation_id into v_c2 from public.aos_wa_messages_v1 where provider_message_id='wamid.wa7a0.bsuid-only';
  if v_c2 is distinct from v_c1 then raise exception 'BSUID_ONLY_SPLIT_CONVERSATION'; end if;
  if not exists(select 1 from public.aos_wa_conversations_v1 where id=v_c1 and contact_number='51911112222' and contact_address_type='BSUID' and contact_address='PE.user.001' and contact_username='dual.newname') then raise exception 'BSUID_CURRENT_ADDRESS_NOT_UPDATED'; end if;

  -- A later phone observation also converges to same conversation.
  insert into public.aos_wa_messages_v1(provider_message_id,direction,from_number,phone_number_id,message_type,message_body,status,provider_timestamp,received_at)
  values('wamid.wa7a0.phone-again','INBOUND','51911112222','pn-wa7a0','text','phone again','received',now()+interval '2 seconds',now());
  select conversation_id into v_c2 from public.aos_wa_messages_v1 where provider_message_id='wamid.wa7a0.phone-again';
  if v_c2 is distinct from v_c1 then raise exception 'PHONE_ALIAS_SPLIT_CONVERSATION'; end if;

  -- Legacy WA-3 server can pass BSUID through its old `to_number` property; DB normalizes it.
  insert into public.aos_wa_messages_v1(provider_message_id,conversation_id,direction,to_number,phone_number_id,message_type,message_body,status,received_at)
  values('wamid.wa7a0.out-bsuid',v_c1,'OUTBOUND','PE.user.001','pn-wa7a0','text','reply','accepted',now());
  if not exists(select 1 from public.aos_wa_messages_v1 where provider_message_id='wamid.wa7a0.out-bsuid' and to_number is null and to_user_id='PE.user.001' and conversation_id=v_c1) then raise exception 'LEGACY_OUTBOUND_NOT_NORMALIZED'; end if;

  -- Outbound idempotency ledger gains generic recipient semantics without losing phone compatibility.
  insert into public.aos_wa_outbound_requests_v1(idempotency_key,actor_id,to_number,message_type,state)
  values(v_req,gen_random_uuid(),'PE.user.001','text','PENDING');
  if not exists(select 1 from public.aos_wa_outbound_requests_v1 where idempotency_key=v_req and to_number is null and recipient_kind='BSUID' and recipient_address='PE.user.001') then raise exception 'OUTBOUND_BSUID_LEDGER_NOT_NORMALIZED'; end if;

  insert into public.aos_wa_outbound_requests_v1(idempotency_key,actor_id,to_number,message_type,state)
  values('wa7a0:req:phone:1234567890',gen_random_uuid(),'+51 922 222 222','text','PENDING');
  if not exists(select 1 from public.aos_wa_outbound_requests_v1 where idempotency_key='wa7a0:req:phone:1234567890' and to_number='51922222222' and recipient_kind='PHONE' and recipient_address='51922222222') then raise exception 'OUTBOUND_PHONE_COMPAT_BROKEN'; end if;

  -- Username must never become an alias/merge authority.
  if exists(select 1 from public.aos_wa_channel_aliases_v1 where alias_type not in ('PHONE','BSUID','PARENT_BSUID')) then raise exception 'USERNAME_ALIAS_FORBIDDEN'; end if;
end
$$;

-- Two already-distinct identities presented together must fail closed, never merge silently.
do $$
declare conflict_seen boolean:=false;
begin
  insert into public.aos_wa_messages_v1(provider_message_id,direction,from_number,from_user_id,phone_number_id,message_type,status,received_at)
  values('wamid.wa7a0.identity-a','INBOUND','51933333333','PE.user.A','pn-wa7a0','text','received',now());
  insert into public.aos_wa_messages_v1(provider_message_id,direction,from_number,from_user_id,phone_number_id,message_type,status,received_at)
  values('wamid.wa7a0.identity-b','INBOUND','51944444444','PE.user.B','pn-wa7a0','text','received',now());
  begin
    insert into public.aos_wa_messages_v1(provider_message_id,direction,from_number,from_user_id,phone_number_id,message_type,status,received_at)
    values('wamid.wa7a0.conflict','INBOUND','51933333333','PE.user.B','pn-wa7a0','text','received',now());
  exception when unique_violation then
    if position('WA7A0_IDENTITY_CONFLICT' in sqlerrm)>0 then conflict_seen:=true; else raise; end if;
  end;
  if not conflict_seen then raise exception 'IDENTITY_CONFLICT_DID_NOT_FAIL_CLOSED'; end if;
end
$$;

-- Security/access contract and S14 resolver source contract.
do $$
declare def text;
begin
  if has_table_privilege('anon','public.aos_wa_channel_aliases_v1','select') then raise exception 'ALIAS_LEDGER_ANON_READABLE'; end if;
  if has_table_privilege('authenticated','public.aos_wa_channel_aliases_v1','select') then raise exception 'ALIAS_LEDGER_AUTH_READABLE'; end if;
  select pg_get_functiondef('public.aos_push_targets_for_wa_v1(jsonb)'::regprocedure) into def;
  if position('m.provider_message_id=v_provider_id' in def)=0 then raise exception 'S14_STILL_PHONE_PRIMARY'; end if;
  select pg_get_functiondef('public.aos_wa3_human_send_authorize_v1(text,uuid)'::regprocedure) into def;
  if position('recipient_kind' in def)=0 or position('recipient_address' in def)=0 then raise exception 'WA3_GENERIC_RECIPIENT_MISSING'; end if;
end
$$;

select 'WA-7A.0 identity compatibility DB contract PASS' as result;
