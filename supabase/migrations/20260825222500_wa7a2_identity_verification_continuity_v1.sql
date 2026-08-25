-- WA-7A.2 — Identity Verification & Continuity V1
-- Extends the existing WhatsApp alias ledger and event ledger only.
-- No customer/person master. No aos_pacientes or REV canonical mutation.
-- Current Meta contract (2026-08): BSUID changes arrive as system messages on the existing `messages` webhook.

begin;

alter table public.aos_wa_channel_aliases_v1
  add column if not exists verification_status text not null default 'UNKNOWN',
  add column if not exists verification_source text not null default 'LEGACY_OBSERVED',
  add column if not exists verification_observed_at timestamptz,
  add column if not exists evidence_event_key text,
  add column if not exists valid_to timestamptz,
  add column if not exists superseded_by uuid,
  add column if not exists supersession_reason text;

update public.aos_wa_channel_aliases_v1
set verification_observed_at=coalesce(verification_observed_at,last_seen_at,first_seen_at,created_at),
    verification_status=coalesce(nullif(verification_status,''),'UNKNOWN'),
    verification_source=coalesce(nullif(verification_source,''),'LEGACY_OBSERVED')
where verification_observed_at is null
   or verification_status is null or verification_status=''
   or verification_source is null or verification_source='';

do $$ begin
  alter table public.aos_wa_channel_aliases_v1
    add constraint aos_wa_channel_aliases_v1_verification_status_chk
    check (verification_status in ('VERIFIED','CLAIMED','UNKNOWN','CONFLICT'));
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.aos_wa_channel_aliases_v1
    add constraint aos_wa_channel_aliases_v1_superseded_fk
    foreign key (superseded_by) references public.aos_wa_channel_aliases_v1(id) on delete restrict;
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.aos_wa_channel_aliases_v1
    add constraint aos_wa_channel_aliases_v1_no_self_supersede_chk
    check (superseded_by is null or superseded_by<>id);
exception when duplicate_object then null; end $$;

create index if not exists aos_wa_channel_aliases_v1_lineage_idx
  on public.aos_wa_channel_aliases_v1(conversation_id,alias_type,active,valid_to,last_seen_at desc);
create index if not exists aos_wa_channel_aliases_v1_evidence_idx
  on public.aos_wa_channel_aliases_v1(evidence_event_key)
  where evidence_event_key is not null;

create or replace function public.aos_wa7a2_normalize_phone_v1(p_value text)
returns text
language plpgsql
immutable
set search_path=''
as $$
declare v text;
begin
  if p_value is null or p_value ~ '[A-Za-z]' then return null; end if;
  v:=regexp_replace(p_value,'[^0-9]','','g');
  if char_length(v) between 8 and 20 then return v; end if;
  return null;
end
$$;
revoke all on function public.aos_wa7a2_normalize_phone_v1(text) from public,anon,authenticated;
grant execute on function public.aos_wa7a2_normalize_phone_v1(text) to service_role;

create or replace function public.aos_wa7a2_apply_identity_event_v1()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  v_scope text:=coalesce(nullif(trim(new.payload->>'business_scope'),''),'default');
  v_obs timestamptz:=coalesce(nullif(new.payload->>'observed_at','')::timestamptz,new.created_at,now());
  v_phone text;
  v_sender_phone text;
  v_user text:=nullif(trim(coalesce(new.payload->>'user_id',new.payload->>'recipient_user_id',new.payload->>'sender_user_id')),'');
  v_parent text:=nullif(trim(coalesce(new.payload->>'parent_user_id',new.payload->>'recipient_parent_user_id',new.payload->>'sender_parent_user_id')),'');
  v_prev_user text:=nullif(trim(new.payload->>'previous_user_id'),'');
  v_prev_parent text:=nullif(trim(new.payload->>'previous_parent_user_id'),'');
  v_origin text:=lower(trim(coalesce(new.payload->>'origin','')));
  v_system_type text:=lower(trim(coalesce(new.payload->>'system_type','')));
  v_shared_count integer:=coalesce(nullif(new.payload->>'shared_phone_count','')::integer,case when nullif(new.payload->>'shared_phone','') is null then 0 else 1 end);
  v_conv uuid;
  v_phone_conv uuid;
  v_user_conv uuid;
  v_parent_conv uuid;
  v_prev_user_conv uuid;
  v_prev_parent_conv uuid;
  v_alias uuid;
  v_new_user_alias uuid;
  v_new_parent_alias uuid;
  v_new_phone_alias uuid;
  v_prev_user_alias uuid;
  v_prev_parent_alias uuid;
  v_prev_user_active boolean;
  v_prev_parent_active boolean;
  v_prev_user_superseded uuid;
  v_prev_parent_superseded uuid;
  v_active_phone_count integer:=0;
  v_old_phone_alias uuid;
  v_old_phone text;
  v_msg_conv uuid;
  v_msg_phone text;
  v_msg_user text;
  v_conflict boolean:=false;
begin
  if new.event_type not in ('identity.meta_pair','identity.system_change','identity.contact_disclosure','identity.status_binding') then
    return new;
  end if;

  -- Usernames are intentionally absent from every authority path in this function.
  if new.event_type='identity.meta_pair' then
    v_phone:=public.aos_wa7a2_normalize_phone_v1(new.payload->>'phone');
    if v_phone is null or v_user is null then
      new.status:='UNRESOLVED';
      new.payload:=new.payload||jsonb_build_object('verification_result','UNRESOLVED','reason','PAIR_REQUIRES_PHONE_AND_BSUID');
      return new;
    end if;

    perform pg_advisory_xact_lock(hashtextextended(v_scope||'|PHONE|'||v_phone,0));
    if v_parent is not null then perform pg_advisory_xact_lock(hashtextextended(v_scope||'|PARENT_BSUID|'||v_parent,0)); end if;
    perform pg_advisory_xact_lock(hashtextextended(v_scope||'|BSUID|'||v_user,0));

    select conversation_id into v_phone_conv from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='PHONE' and alias_value=v_phone;
    select conversation_id into v_user_conv from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='BSUID' and alias_value=v_user;
    if v_parent is not null then select conversation_id into v_parent_conv from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='PARENT_BSUID' and alias_value=v_parent; end if;
    v_conv:=coalesce(v_user_conv,v_parent_conv,v_phone_conv);
    if v_conv is null then
      new.status:='UNRESOLVED';
      new.payload:=new.payload||jsonb_build_object('verification_result','UNRESOLVED','reason','PAIR_HAS_NO_BOUND_CONVERSATION');
      return new;
    end if;
    if (v_phone_conv is not null and v_phone_conv<>v_conv)
       or (v_user_conv is not null and v_user_conv<>v_conv)
       or (v_parent_conv is not null and v_parent_conv<>v_conv) then v_conflict:=true; end if;
    if v_conflict then
      new.status:='CONFLICT';new.payload:=new.payload||jsonb_build_object('verification_result','CONFLICT','reason','PAIR_ALIAS_CONFLICT');return new;
    end if;

    insert into public.aos_wa_channel_aliases_v1(business_scope,alias_type,alias_value,conversation_id,active,first_seen_at,last_seen_at,verification_status,verification_source,verification_observed_at,evidence_event_key)
    values(v_scope,'PHONE',v_phone,v_conv,true,v_obs,v_obs,'VERIFIED','META_SIGNED_MESSAGE_PAIR',v_obs,new.event_key)
    on conflict (business_scope,alias_type,alias_value) do update set
      active=true,last_seen_at=greatest(public.aos_wa_channel_aliases_v1.last_seen_at,excluded.last_seen_at),
      valid_to=null,superseded_by=null,supersession_reason=null,
      verification_status='VERIFIED',verification_source='META_SIGNED_MESSAGE_PAIR',verification_observed_at=v_obs,evidence_event_key=new.event_key,updated_at=now();
    insert into public.aos_wa_channel_aliases_v1(business_scope,alias_type,alias_value,conversation_id,active,first_seen_at,last_seen_at,verification_status,verification_source,verification_observed_at,evidence_event_key)
    values(v_scope,'BSUID',v_user,v_conv,true,v_obs,v_obs,'VERIFIED','META_SIGNED_MESSAGE_PAIR',v_obs,new.event_key)
    on conflict (business_scope,alias_type,alias_value) do update set
      active=true,last_seen_at=greatest(public.aos_wa_channel_aliases_v1.last_seen_at,excluded.last_seen_at),
      valid_to=null,superseded_by=null,supersession_reason=null,
      verification_status='VERIFIED',verification_source='META_SIGNED_MESSAGE_PAIR',verification_observed_at=v_obs,evidence_event_key=new.event_key,updated_at=now();
    if v_parent is not null then
      insert into public.aos_wa_channel_aliases_v1(business_scope,alias_type,alias_value,conversation_id,active,first_seen_at,last_seen_at,verification_status,verification_source,verification_observed_at,evidence_event_key)
      values(v_scope,'PARENT_BSUID',v_parent,v_conv,true,v_obs,v_obs,'VERIFIED','META_SIGNED_MESSAGE_PAIR',v_obs,new.event_key)
      on conflict (business_scope,alias_type,alias_value) do update set
        active=true,last_seen_at=greatest(public.aos_wa_channel_aliases_v1.last_seen_at,excluded.last_seen_at),valid_to=null,
        verification_status='VERIFIED',verification_source='META_SIGNED_MESSAGE_PAIR',verification_observed_at=v_obs,evidence_event_key=new.event_key,updated_at=now();
    end if;
    new.status:='VERIFIED';new.payload:=new.payload||jsonb_build_object('verification_result','VERIFIED','conversation_id',v_conv);return new;
  end if;

  if new.event_type='identity.system_change' then
    v_phone:=public.aos_wa7a2_normalize_phone_v1(coalesce(new.payload->>'phone',new.payload->>'wa_id'));
    if v_system_type not in ('user_changed_number','user_changed_user_id') or v_user is null then
      new.status:='UNRESOLVED';new.payload:=new.payload||jsonb_build_object('verification_result','UNRESOLVED','reason','UNSUPPORTED_OR_INCOMPLETE_SYSTEM_CHANGE');return new;
    end if;

    if v_phone is not null then perform pg_advisory_xact_lock(hashtextextended(v_scope||'|PHONE|'||v_phone,0)); end if;
    if v_prev_parent is not null or v_parent is not null then
      if coalesce(v_prev_parent,'')<=coalesce(v_parent,'') then
        if v_prev_parent is not null then perform pg_advisory_xact_lock(hashtextextended(v_scope||'|PARENT_BSUID|'||v_prev_parent,0)); end if;
        if v_parent is not null and v_parent is distinct from v_prev_parent then perform pg_advisory_xact_lock(hashtextextended(v_scope||'|PARENT_BSUID|'||v_parent,0)); end if;
      else
        if v_parent is not null then perform pg_advisory_xact_lock(hashtextextended(v_scope||'|PARENT_BSUID|'||v_parent,0)); end if;
        if v_prev_parent is not null and v_prev_parent is distinct from v_parent then perform pg_advisory_xact_lock(hashtextextended(v_scope||'|PARENT_BSUID|'||v_prev_parent,0)); end if;
      end if;
    end if;
    if v_prev_user is not null and v_prev_user<=v_user then
      perform pg_advisory_xact_lock(hashtextextended(v_scope||'|BSUID|'||v_prev_user,0));
      if v_user is distinct from v_prev_user then perform pg_advisory_xact_lock(hashtextextended(v_scope||'|BSUID|'||v_user,0)); end if;
    else
      perform pg_advisory_xact_lock(hashtextextended(v_scope||'|BSUID|'||v_user,0));
      if v_prev_user is not null and v_prev_user is distinct from v_user then perform pg_advisory_xact_lock(hashtextextended(v_scope||'|BSUID|'||v_prev_user,0)); end if;
    end if;

    if v_prev_user is not null then
      select id,conversation_id,active,superseded_by into v_prev_user_alias,v_prev_user_conv,v_prev_user_active,v_prev_user_superseded
      from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='BSUID' and alias_value=v_prev_user for update;
    end if;
    if v_prev_parent is not null then
      select id,conversation_id,active,superseded_by into v_prev_parent_alias,v_prev_parent_conv,v_prev_parent_active,v_prev_parent_superseded
      from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='PARENT_BSUID' and alias_value=v_prev_parent for update;
    end if;
    select id,conversation_id into v_new_user_alias,v_user_conv from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='BSUID' and alias_value=v_user for update;
    if v_parent is not null then select id,conversation_id into v_new_parent_alias,v_parent_conv from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='PARENT_BSUID' and alias_value=v_parent for update; end if;

    v_conv:=coalesce(v_prev_user_conv,v_prev_parent_conv,v_user_conv,v_parent_conv);
    if v_conv is null then
      new.status:='UNRESOLVED';new.payload:=new.payload||jsonb_build_object('verification_result','UNRESOLVED','reason','PREVIOUS_BSUID_NOT_KNOWN');return new;
    end if;
    if (v_prev_user_conv is not null and v_prev_user_conv<>v_conv)
       or (v_prev_parent_conv is not null and v_prev_parent_conv<>v_conv)
       or (v_user_conv is not null and v_user_conv<>v_conv)
       or (v_parent_conv is not null and v_parent_conv<>v_conv) then v_conflict:=true; end if;
    if v_conflict then new.status:='CONFLICT';new.payload:=new.payload||jsonb_build_object('verification_result','CONFLICT','reason','SYSTEM_ALIAS_CONFLICT');return new; end if;

    -- A previous alias that already points to a different successor may not fork lineage.
    if v_prev_user_alias is not null and v_prev_user_active is false and v_prev_user<>v_user then
      if v_prev_user_superseded is not null and v_prev_user_superseded=v_new_user_alias then
        new.status:='ALREADY_APPLIED';new.payload:=new.payload||jsonb_build_object('verification_result','VERIFIED','reason','LINEAGE_ALREADY_APPLIED','conversation_id',v_conv);return new;
      end if;
      new.status:='CONFLICT';new.payload:=new.payload||jsonb_build_object('verification_result','CONFLICT','reason','STALE_PREVIOUS_BSUID');return new;
    end if;

    select count(*) into v_active_phone_count from public.aos_wa_channel_aliases_v1 where conversation_id=v_conv and alias_type='PHONE' and active=true;
    if v_active_phone_count>1 then
      new.status:='CONFLICT';new.payload:=new.payload||jsonb_build_object('verification_result','CONFLICT','reason','MULTIPLE_ACTIVE_PHONE_ALIASES');return new;
    elsif v_active_phone_count=1 then
      select id,alias_value into v_old_phone_alias,v_old_phone from public.aos_wa_channel_aliases_v1 where conversation_id=v_conv and alias_type='PHONE' and active=true for update;
    end if;

    if v_phone is not null then
      select id,conversation_id into v_new_phone_alias,v_phone_conv from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='PHONE' and alias_value=v_phone for update;
      if v_phone_conv is not null and v_phone_conv<>v_conv then
        new.status:='CONFLICT';new.payload:=new.payload||jsonb_build_object('verification_result','CONFLICT','reason','NEW_PHONE_OWNED_BY_OTHER_CONVERSATION');return new;
      end if;
    end if;

    insert into public.aos_wa_channel_aliases_v1(business_scope,alias_type,alias_value,conversation_id,active,first_seen_at,last_seen_at,verification_status,verification_source,verification_observed_at,evidence_event_key)
    values(v_scope,'BSUID',v_user,v_conv,true,v_obs,v_obs,'VERIFIED','META_SYSTEM_CHANGE',v_obs,new.event_key)
    on conflict (business_scope,alias_type,alias_value) do update set active=true,last_seen_at=greatest(public.aos_wa_channel_aliases_v1.last_seen_at,excluded.last_seen_at),valid_to=null,superseded_by=null,supersession_reason=null,verification_status='VERIFIED',verification_source='META_SYSTEM_CHANGE',verification_observed_at=v_obs,evidence_event_key=new.event_key,updated_at=now()
    returning id into v_new_user_alias;

    if v_prev_user_alias is not null and v_prev_user_alias<>v_new_user_alias then
      update public.aos_wa_channel_aliases_v1 set active=false,valid_to=v_obs,superseded_by=v_new_user_alias,supersession_reason=v_system_type,evidence_event_key=new.event_key,updated_at=now() where id=v_prev_user_alias;
    end if;

    if v_parent is not null then
      insert into public.aos_wa_channel_aliases_v1(business_scope,alias_type,alias_value,conversation_id,active,first_seen_at,last_seen_at,verification_status,verification_source,verification_observed_at,evidence_event_key)
      values(v_scope,'PARENT_BSUID',v_parent,v_conv,true,v_obs,v_obs,'VERIFIED','META_SYSTEM_CHANGE',v_obs,new.event_key)
      on conflict (business_scope,alias_type,alias_value) do update set active=true,last_seen_at=greatest(public.aos_wa_channel_aliases_v1.last_seen_at,excluded.last_seen_at),valid_to=null,superseded_by=null,supersession_reason=null,verification_status='VERIFIED',verification_source='META_SYSTEM_CHANGE',verification_observed_at=v_obs,evidence_event_key=new.event_key,updated_at=now()
      returning id into v_new_parent_alias;
    end if;
    if v_prev_parent_alias is not null and v_prev_parent_alias is distinct from v_new_parent_alias then
      update public.aos_wa_channel_aliases_v1 set active=false,valid_to=v_obs,superseded_by=v_new_parent_alias,supersession_reason=v_system_type,evidence_event_key=new.event_key,updated_at=now() where id=v_prev_parent_alias;
    end if;

    if v_phone is not null then
      insert into public.aos_wa_channel_aliases_v1(business_scope,alias_type,alias_value,conversation_id,active,first_seen_at,last_seen_at,verification_status,verification_source,verification_observed_at,evidence_event_key)
      values(v_scope,'PHONE',v_phone,v_conv,true,v_obs,v_obs,'VERIFIED','META_SYSTEM_CHANGE',v_obs,new.event_key)
      on conflict (business_scope,alias_type,alias_value) do update set active=true,last_seen_at=greatest(public.aos_wa_channel_aliases_v1.last_seen_at,excluded.last_seen_at),valid_to=null,superseded_by=null,supersession_reason=null,verification_status='VERIFIED',verification_source='META_SYSTEM_CHANGE',verification_observed_at=v_obs,evidence_event_key=new.event_key,updated_at=now()
      returning id into v_new_phone_alias;
    end if;
    if v_old_phone_alias is not null and (v_phone is null or v_old_phone<>v_phone) then
      update public.aos_wa_channel_aliases_v1 set active=false,valid_to=v_obs,superseded_by=v_new_phone_alias,supersession_reason=case when v_phone is null then 'USER_CHANGED_PHONE_NO_NEW_PHONE' else v_system_type end,evidence_event_key=new.event_key,updated_at=now() where id=v_old_phone_alias;
    end if;

    update public.aos_wa_conversations_v1 set
      contact_number=v_phone,
      contact_bsuid=v_user,
      contact_parent_bsuid=case when v_prev_parent is not null then v_parent else coalesce(v_parent,contact_parent_bsuid) end,
      contact_address=coalesce(v_phone,v_user),
      contact_address_type=case when v_phone is not null then 'PHONE' else 'BSUID' end,
      updated_at=now()
    where id=v_conv;

    new.status:='VERIFIED';new.payload:=new.payload||jsonb_build_object('verification_result','VERIFIED','conversation_id',v_conv,'phone_shared',v_phone is not null);return new;
  end if;

  if new.event_type='identity.contact_disclosure' then
    v_sender_phone:=public.aos_wa7a2_normalize_phone_v1(new.payload->>'sender_phone');
    v_phone:=public.aos_wa7a2_normalize_phone_v1(new.payload->>'shared_phone');
    if v_phone is not null then perform pg_advisory_xact_lock(hashtextextended(v_scope||'|PHONE|'||v_phone,0)); end if;
    if v_sender_phone is not null and v_sender_phone is distinct from v_phone then perform pg_advisory_xact_lock(hashtextextended(v_scope||'|PHONE|'||v_sender_phone,0)); end if;
    if v_user is not null then perform pg_advisory_xact_lock(hashtextextended(v_scope||'|BSUID|'||v_user,0)); end if;

    if v_sender_phone is not null then select conversation_id into v_phone_conv from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='PHONE' and alias_value=v_sender_phone; end if;
    if v_user is not null then select conversation_id into v_user_conv from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='BSUID' and alias_value=v_user; end if;
    v_conv:=coalesce(v_user_conv,v_phone_conv);
    if v_conv is null then new.status:='UNRESOLVED';new.payload:=new.payload||jsonb_build_object('verification_result','UNRESOLVED','reason','CONTACT_SENDER_NOT_BOUND');return new; end if;
    if v_user_conv is not null and v_phone_conv is not null and v_user_conv<>v_phone_conv then new.status:='CONFLICT';new.payload:=new.payload||jsonb_build_object('verification_result','CONFLICT','reason','CONTACT_SENDER_ALIAS_CONFLICT');return new; end if;

    -- Only WhatsApp's native request response is attested. Forwarded/manual contact cards are evidence only.
    if v_origin<>'contact_request' then
      new.status:=case when v_phone is null then 'UNKNOWN' else 'CLAIMED' end;
      new.payload:=new.payload||jsonb_build_object('verification_result',new.status,'reason','NON_ATTESTED_CONTACT_SHARE','conversation_id',v_conv);
      return new;
    end if;
    if v_shared_count<>1 or v_phone is null then
      new.status:='CONFLICT';new.payload:=new.payload||jsonb_build_object('verification_result','CONFLICT','reason','CONTACT_REQUEST_AMBIGUOUS_PHONE','conversation_id',v_conv);return new;
    end if;

    select id,conversation_id into v_new_phone_alias,v_phone_conv from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='PHONE' and alias_value=v_phone for update;
    if v_phone_conv is not null and v_phone_conv<>v_conv then new.status:='CONFLICT';new.payload:=new.payload||jsonb_build_object('verification_result','CONFLICT','reason','ATTESTED_PHONE_OWNED_BY_OTHER_CONVERSATION');return new; end if;

    select count(*) into v_active_phone_count from public.aos_wa_channel_aliases_v1 where conversation_id=v_conv and alias_type='PHONE' and active=true and alias_value<>v_phone;
    if v_active_phone_count>1 then new.status:='CONFLICT';new.payload:=new.payload||jsonb_build_object('verification_result','CONFLICT','reason','MULTIPLE_PRIOR_PHONE_ALIASES');return new; end if;
    if v_active_phone_count=1 then select id,alias_value into v_old_phone_alias,v_old_phone from public.aos_wa_channel_aliases_v1 where conversation_id=v_conv and alias_type='PHONE' and active=true and alias_value<>v_phone for update; end if;

    insert into public.aos_wa_channel_aliases_v1(business_scope,alias_type,alias_value,conversation_id,active,first_seen_at,last_seen_at,verification_status,verification_source,verification_observed_at,evidence_event_key)
    values(v_scope,'PHONE',v_phone,v_conv,true,v_obs,v_obs,'VERIFIED','META_CONTACT_REQUEST',v_obs,new.event_key)
    on conflict (business_scope,alias_type,alias_value) do update set active=true,last_seen_at=greatest(public.aos_wa_channel_aliases_v1.last_seen_at,excluded.last_seen_at),valid_to=null,superseded_by=null,supersession_reason=null,verification_status='VERIFIED',verification_source='META_CONTACT_REQUEST',verification_observed_at=v_obs,evidence_event_key=new.event_key,updated_at=now()
    returning id into v_new_phone_alias;
    if v_old_phone_alias is not null then update public.aos_wa_channel_aliases_v1 set active=false,valid_to=v_obs,superseded_by=v_new_phone_alias,supersession_reason='META_CONTACT_REQUEST',evidence_event_key=new.event_key,updated_at=now() where id=v_old_phone_alias; end if;
    update public.aos_wa_conversations_v1 set contact_number=v_phone,contact_address=v_phone,contact_address_type='PHONE',updated_at=now() where id=v_conv;
    new.status:='VERIFIED';new.payload:=new.payload||jsonb_build_object('verification_result','VERIFIED','conversation_id',v_conv);return new;
  end if;

  if new.event_type='identity.status_binding' then
    if new.status not in ('delivered','read','received','sent') then null; end if;
    if v_user is null then new.status:='UNRESOLVED';new.payload:=new.payload||jsonb_build_object('verification_result','UNRESOLVED','reason','STATUS_HAS_NO_RECIPIENT_BSUID');return new; end if;
    select conversation_id,to_number,to_user_id into v_msg_conv,v_msg_phone,v_msg_user from public.aos_wa_messages_v1 where provider_message_id=new.provider_message_id and direction='OUTBOUND';
    if v_msg_conv is null then new.status:='UNRESOLVED';new.payload:=new.payload||jsonb_build_object('verification_result','UNRESOLVED','reason','OUTBOUND_MESSAGE_NOT_BOUND');return new; end if;
    v_phone:=public.aos_wa7a2_normalize_phone_v1(v_msg_phone);
    if v_phone is not null then perform pg_advisory_xact_lock(hashtextextended(v_scope||'|PHONE|'||v_phone,0)); end if;
    if v_parent is not null then perform pg_advisory_xact_lock(hashtextextended(v_scope||'|PARENT_BSUID|'||v_parent,0)); end if;
    perform pg_advisory_xact_lock(hashtextextended(v_scope||'|BSUID|'||v_user,0));
    select conversation_id into v_user_conv from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='BSUID' and alias_value=v_user;
    if v_parent is not null then select conversation_id into v_parent_conv from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='PARENT_BSUID' and alias_value=v_parent; end if;
    if v_phone is not null then select conversation_id into v_phone_conv from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='PHONE' and alias_value=v_phone; end if;
    if (v_user_conv is not null and v_user_conv<>v_msg_conv) or (v_parent_conv is not null and v_parent_conv<>v_msg_conv) or (v_phone_conv is not null and v_phone_conv<>v_msg_conv) then
      new.status:='CONFLICT';new.payload:=new.payload||jsonb_build_object('verification_result','CONFLICT','reason','STATUS_BINDING_ALIAS_CONFLICT');return new;
    end if;
    insert into public.aos_wa_channel_aliases_v1(business_scope,alias_type,alias_value,conversation_id,active,first_seen_at,last_seen_at,verification_status,verification_source,verification_observed_at,evidence_event_key)
    values(v_scope,'BSUID',v_user,v_msg_conv,true,v_obs,v_obs,'VERIFIED','META_STATUS_RECIPIENT_USER_ID',v_obs,new.event_key)
    on conflict (business_scope,alias_type,alias_value) do update set active=true,last_seen_at=greatest(public.aos_wa_channel_aliases_v1.last_seen_at,excluded.last_seen_at),verification_status='VERIFIED',verification_source='META_STATUS_RECIPIENT_USER_ID',verification_observed_at=v_obs,evidence_event_key=new.event_key,updated_at=now();
    if v_parent is not null then
      insert into public.aos_wa_channel_aliases_v1(business_scope,alias_type,alias_value,conversation_id,active,first_seen_at,last_seen_at,verification_status,verification_source,verification_observed_at,evidence_event_key)
      values(v_scope,'PARENT_BSUID',v_parent,v_msg_conv,true,v_obs,v_obs,'VERIFIED','META_STATUS_RECIPIENT_USER_ID',v_obs,new.event_key)
      on conflict (business_scope,alias_type,alias_value) do update set active=true,last_seen_at=greatest(public.aos_wa_channel_aliases_v1.last_seen_at,excluded.last_seen_at),verification_status='VERIFIED',verification_source='META_STATUS_RECIPIENT_USER_ID',verification_observed_at=v_obs,evidence_event_key=new.event_key,updated_at=now();
    end if;
    if v_phone is not null then
      update public.aos_wa_channel_aliases_v1 set verification_status='VERIFIED',verification_source='META_STATUS_RECIPIENT_USER_ID',verification_observed_at=v_obs,evidence_event_key=new.event_key,last_seen_at=greatest(last_seen_at,v_obs),updated_at=now()
      where business_scope=v_scope and alias_type='PHONE' and alias_value=v_phone and conversation_id=v_msg_conv;
    end if;
    update public.aos_wa_conversations_v1 set contact_bsuid=coalesce(contact_bsuid,v_user),contact_parent_bsuid=coalesce(contact_parent_bsuid,v_parent),updated_at=now() where id=v_msg_conv;
    new.status:='VERIFIED';new.payload:=new.payload||jsonb_build_object('verification_result','VERIFIED','conversation_id',v_msg_conv,'phone_bound',v_phone is not null);return new;
  end if;

  return new;
end
$$;

comment on function public.aos_wa7a2_apply_identity_event_v1() is
'WA-7A.2 service-only BEFORE INSERT event processor. Reuses aos_wa_events_v1 idempotency and aos_wa_channel_aliases_v1; preserves lineage, treats non-attested contact cards as CLAIMED evidence only, and never mutates canonical patient identity.';

drop trigger if exists trg_aos_wa7a2_apply_identity_event_v1 on public.aos_wa_events_v1;
create trigger trg_aos_wa7a2_apply_identity_event_v1
before insert on public.aos_wa_events_v1
for each row
when (new.event_type in ('identity.meta_pair','identity.system_change','identity.contact_disclosure','identity.status_binding'))
execute function public.aos_wa7a2_apply_identity_event_v1();

revoke all on function public.aos_wa7a2_apply_identity_event_v1() from public,anon,authenticated;

comment on table public.aos_wa_channel_aliases_v1 is
'WhatsApp scoped channel alias ledger. WA-7A.2 adds verification/source/evidence and non-destructive supersession lineage. BSUID is not a canonical person id; username is never an alias authority.';

select pg_notify('pgrst','reload schema');
commit;
