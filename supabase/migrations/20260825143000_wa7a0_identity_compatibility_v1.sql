-- WA-7A.0 — WhatsApp Identity Compatibility V1
-- Additive PHONE + BSUID compatibility. Username is display-only.
-- This migration is safe for the existing phone-first runtime: legacy `to_number`
-- continues to work while BSUID values are normalized into generic recipient fields.

begin;

alter table public.aos_wa_messages_v1
  add column if not exists from_user_id text,
  add column if not exists from_parent_user_id text,
  add column if not exists to_user_id text,
  add column if not exists to_parent_user_id text,
  add column if not exists contact_username text;

create index if not exists aos_wa_messages_v1_from_user_idx
  on public.aos_wa_messages_v1(phone_number_id, from_user_id, created_at desc)
  where from_user_id is not null;
create index if not exists aos_wa_messages_v1_to_user_idx
  on public.aos_wa_messages_v1(phone_number_id, to_user_id, created_at desc)
  where to_user_id is not null;

alter table public.aos_wa_conversations_v1
  alter column contact_number drop not null,
  add column if not exists contact_address text,
  add column if not exists contact_address_type text,
  add column if not exists contact_bsuid text,
  add column if not exists contact_parent_bsuid text,
  add column if not exists contact_username text;

update public.aos_wa_conversations_v1
set contact_address = coalesce(contact_address, nullif(regexp_replace(coalesce(contact_number,''),'[^0-9]','','g'),'')),
    contact_address_type = coalesce(contact_address_type, case when nullif(regexp_replace(coalesce(contact_number,''),'[^0-9]','','g'),'') is not null then 'PHONE' end)
where contact_address is null or contact_address_type is null;

alter table public.aos_wa_conversations_v1
  add constraint aos_wa_conversations_v1_contact_address_type_chk
  check (contact_address_type in ('PHONE','BSUID')) not valid;
alter table public.aos_wa_conversations_v1 validate constraint aos_wa_conversations_v1_contact_address_type_chk;
alter table public.aos_wa_conversations_v1 alter column contact_address set not null;
alter table public.aos_wa_conversations_v1 alter column contact_address_type set not null;

create index if not exists aos_wa_conversations_v1_bsuid_idx
  on public.aos_wa_conversations_v1(phone_number_id, contact_bsuid)
  where contact_bsuid is not null;
create index if not exists aos_wa_conversations_v1_address_idx
  on public.aos_wa_conversations_v1(phone_number_id, contact_address_type, contact_address);

create table if not exists public.aos_wa_channel_aliases_v1 (
  id uuid primary key default gen_random_uuid(),
  business_scope text not null,
  alias_type text not null check (alias_type in ('PHONE','BSUID','PARENT_BSUID')),
  alias_value text not null check (char_length(trim(alias_value)) between 1 and 256),
  conversation_id uuid not null references public.aos_wa_conversations_v1(id) on delete restrict,
  active boolean not null default true,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_scope, alias_type, alias_value)
);
create index if not exists aos_wa_channel_aliases_v1_conversation_idx
  on public.aos_wa_channel_aliases_v1(conversation_id, alias_type, last_seen_at desc);
alter table public.aos_wa_channel_aliases_v1 enable row level security;
alter table public.aos_wa_channel_aliases_v1 force row level security;
revoke all on table public.aos_wa_channel_aliases_v1 from public, anon, authenticated;
grant select, insert, update on table public.aos_wa_channel_aliases_v1 to service_role;

insert into public.aos_wa_channel_aliases_v1(business_scope,alias_type,alias_value,conversation_id,first_seen_at,last_seen_at)
select coalesce(nullif(c.phone_number_id,''),'default'), 'PHONE', regexp_replace(c.contact_number,'[^0-9]','','g'), c.id, c.created_at, c.updated_at
from public.aos_wa_conversations_v1 c
where nullif(regexp_replace(coalesce(c.contact_number,''),'[^0-9]','','g'),'') is not null
on conflict (business_scope,alias_type,alias_value) do update
set last_seen_at=greatest(public.aos_wa_channel_aliases_v1.last_seen_at,excluded.last_seen_at),updated_at=now();

alter table public.aos_wa_outbound_requests_v1
  alter column to_number drop not null,
  add column if not exists recipient_kind text,
  add column if not exists recipient_address text;

update public.aos_wa_outbound_requests_v1
set to_number=regexp_replace(to_number,'[^0-9]','','g'),
    recipient_kind='PHONE',
    recipient_address=regexp_replace(to_number,'[^0-9]','','g')
where recipient_address is null and nullif(regexp_replace(coalesce(to_number,''),'[^0-9]','','g'),'') is not null;

alter table public.aos_wa_outbound_requests_v1
  add constraint aos_wa_outbound_requests_v1_recipient_kind_chk
  check (recipient_kind in ('PHONE','BSUID')) not valid;
alter table public.aos_wa_outbound_requests_v1 validate constraint aos_wa_outbound_requests_v1_recipient_kind_chk;
alter table public.aos_wa_outbound_requests_v1 alter column recipient_kind set not null;
alter table public.aos_wa_outbound_requests_v1 alter column recipient_address set not null;

create or replace function public.aos_wa7a0_normalize_outbound_request_v1()
returns trigger
language plpgsql
set search_path=public,pg_temp
as $$
declare v_raw text; v_phone text;
begin
  v_raw:=trim(coalesce(new.recipient_address,new.to_number,''));
  if v_raw='' then raise exception 'WA7A0_RECIPIENT_REQUIRED' using errcode='23514'; end if;
  v_phone:=case when v_raw !~ '[A-Za-z]' then nullif(regexp_replace(v_raw,'[^0-9]','','g'),'') else null end;
  if new.recipient_kind is null then
    new.recipient_kind:=case when v_phone is not null and char_length(v_phone) between 8 and 20 then 'PHONE' else 'BSUID' end;
  end if;
  if new.recipient_kind='PHONE' then
    if v_phone is null or char_length(v_phone) not between 8 and 20 then raise exception 'WA7A0_INVALID_PHONE_RECIPIENT' using errcode='23514'; end if;
    new.to_number:=v_phone;new.recipient_address:=v_phone;
  elsif new.recipient_kind='BSUID' then
    if char_length(v_raw)>256 then raise exception 'WA7A0_INVALID_BSUID_RECIPIENT' using errcode='23514'; end if;
    new.to_number:=null;new.recipient_address:=v_raw;
  else
    raise exception 'WA7A0_INVALID_RECIPIENT_KIND' using errcode='23514';
  end if;
  new.updated_at:=now();
  return new;
end
$$;

drop trigger if exists trg_aos_wa7a0_normalize_outbound_request_v1 on public.aos_wa_outbound_requests_v1;
create trigger trg_aos_wa7a0_normalize_outbound_request_v1
before insert or update of to_number,recipient_kind,recipient_address on public.aos_wa_outbound_requests_v1
for each row execute function public.aos_wa7a0_normalize_outbound_request_v1();

-- Replace WA-2 binder with identity-aware deterministic binding.
-- Scope is intentionally phone_number_id (narrower than portfolio scope); cross-number
-- portfolio reconciliation belongs to WA-7A.1 and must not be guessed here.
create or replace function public.aos_wa2_bind_conversation_v1()
returns trigger
language plpgsql
set search_path=public,pg_temp
as $$
declare
  v_scope text;
  v_phone text;
  v_bsuid text;
  v_parent text;
  v_kind text;
  v_address text;
  v_key text;
  v_ts timestamptz;
  v_conv uuid;
  v_phone_conv uuid;
  v_bsuid_conv uuid;
  v_parent_conv uuid;
  v_existing uuid;
begin
  v_scope:=coalesce(nullif(trim(new.phone_number_id),''),'default');
  v_ts:=coalesce(new.provider_timestamp,new.received_at,new.sent_at,new.created_at,now());

  -- Compatibility normalization for old server code that still writes a generic BSUID
  -- into from_number/to_number. Never strip letters out of a BSUID.
  if new.direction='INBOUND' then
    if new.from_user_id is null and nullif(trim(coalesce(new.from_number,'')),'') is not null and new.from_number ~ '[A-Za-z]' then
      new.from_user_id:=left(trim(new.from_number),256);new.from_number:=null;
    end if;
    v_phone:=case when coalesce(new.from_number,'') !~ '[A-Za-z]' then nullif(regexp_replace(coalesce(new.from_number,''),'[^0-9]','','g'),'') else null end;
    v_bsuid:=nullif(left(trim(coalesce(new.from_user_id,'')),256),'');
    v_parent:=nullif(left(trim(coalesce(new.from_parent_user_id,'')),256),'');
  else
    if new.to_user_id is null and nullif(trim(coalesce(new.to_number,'')),'') is not null and new.to_number ~ '[A-Za-z]' then
      new.to_user_id:=left(trim(new.to_number),256);new.to_number:=null;
    end if;
    v_phone:=case when coalesce(new.to_number,'') !~ '[A-Za-z]' then nullif(regexp_replace(coalesce(new.to_number,''),'[^0-9]','','g'),'') else null end;
    v_bsuid:=nullif(left(trim(coalesce(new.to_user_id,'')),256),'');
    v_parent:=nullif(left(trim(coalesce(new.to_parent_user_id,'')),256),'');
  end if;

  if v_phone is not null and char_length(v_phone) not between 8 and 20 then v_phone:=null; end if;
  if v_phone is null and v_bsuid is null and v_parent is null then
    raise exception 'WA7A0_CONTACT_REQUIRED' using errcode='23514';
  end if;

  v_kind:=case when v_phone is not null then 'PHONE' else 'BSUID' end;
  v_address:=coalesce(v_phone,v_bsuid,v_parent);

  -- Lock every presented alias in a fixed order to prevent concurrent split conversations.
  if v_phone is not null then perform pg_advisory_xact_lock(hashtextextended(v_scope||'|PHONE|'||v_phone,0)); end if;
  if v_parent is not null then perform pg_advisory_xact_lock(hashtextextended(v_scope||'|PARENT_BSUID|'||v_parent,0)); end if;
  if v_bsuid is not null then perform pg_advisory_xact_lock(hashtextextended(v_scope||'|BSUID|'||v_bsuid,0)); end if;

  if new.conversation_id is not null then
    select id into v_conv from public.aos_wa_conversations_v1 where id=new.conversation_id for update;
    if v_conv is null then raise exception 'WA7A0_CONVERSATION_BIND_FAILED'; end if;
  else
    if v_phone is not null then select conversation_id into v_phone_conv from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='PHONE' and alias_value=v_phone; end if;
    if v_parent is not null then select conversation_id into v_parent_conv from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='PARENT_BSUID' and alias_value=v_parent; end if;
    if v_bsuid is not null then select conversation_id into v_bsuid_conv from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='BSUID' and alias_value=v_bsuid; end if;

    v_existing:=coalesce(v_bsuid_conv,v_parent_conv,v_phone_conv);
    if (v_phone_conv is not null and v_existing<>v_phone_conv)
       or (v_parent_conv is not null and v_existing<>v_parent_conv)
       or (v_bsuid_conv is not null and v_existing<>v_bsuid_conv) then
      raise exception 'WA7A0_IDENTITY_CONFLICT' using errcode='23505';
    end if;
    v_conv:=v_existing;

    if v_conv is null then
      v_key:=v_scope||':'||v_kind||':'||v_address;
      insert into public.aos_wa_conversations_v1(
        conversation_key,contact_number,contact_name,phone_number_id,state,opened_at,updated_at,
        contact_address,contact_address_type,contact_bsuid,contact_parent_bsuid,contact_username
      ) values (
        v_key,v_phone,nullif(new.contact_name,''),new.phone_number_id,'NEW',v_ts,now(),
        v_address,v_kind,v_bsuid,v_parent,nullif(new.contact_username,'')
      )
      on conflict (conversation_key) do nothing
      returning id into v_conv;
      if v_conv is null then select id into v_conv from public.aos_wa_conversations_v1 where conversation_key=v_key; end if;
    end if;
  end if;

  if v_conv is null then raise exception 'WA7A0_CONVERSATION_BIND_FAILED'; end if;

  update public.aos_wa_conversations_v1
  set contact_number=coalesce(v_phone,contact_number),
      contact_name=coalesce(nullif(new.contact_name,''),contact_name),
      phone_number_id=coalesce(new.phone_number_id,phone_number_id),
      contact_address=v_address,
      contact_address_type=v_kind,
      contact_bsuid=coalesce(v_bsuid,contact_bsuid),
      contact_parent_bsuid=coalesce(v_parent,contact_parent_bsuid),
      contact_username=coalesce(nullif(new.contact_username,''),contact_username),
      updated_at=now()
  where id=v_conv;

  if v_phone is not null then
    insert into public.aos_wa_channel_aliases_v1(business_scope,alias_type,alias_value,conversation_id,first_seen_at,last_seen_at)
    values(v_scope,'PHONE',v_phone,v_conv,v_ts,v_ts)
    on conflict (business_scope,alias_type,alias_value) do update set last_seen_at=greatest(public.aos_wa_channel_aliases_v1.last_seen_at,excluded.last_seen_at),active=true,updated_at=now();
    select conversation_id into v_existing from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='PHONE' and alias_value=v_phone;
    if v_existing<>v_conv then raise exception 'WA7A0_IDENTITY_CONFLICT' using errcode='23505'; end if;
  end if;
  if v_parent is not null then
    insert into public.aos_wa_channel_aliases_v1(business_scope,alias_type,alias_value,conversation_id,first_seen_at,last_seen_at)
    values(v_scope,'PARENT_BSUID',v_parent,v_conv,v_ts,v_ts)
    on conflict (business_scope,alias_type,alias_value) do update set last_seen_at=greatest(public.aos_wa_channel_aliases_v1.last_seen_at,excluded.last_seen_at),active=true,updated_at=now();
    select conversation_id into v_existing from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='PARENT_BSUID' and alias_value=v_parent;
    if v_existing<>v_conv then raise exception 'WA7A0_IDENTITY_CONFLICT' using errcode='23505'; end if;
  end if;
  if v_bsuid is not null then
    insert into public.aos_wa_channel_aliases_v1(business_scope,alias_type,alias_value,conversation_id,first_seen_at,last_seen_at)
    values(v_scope,'BSUID',v_bsuid,v_conv,v_ts,v_ts)
    on conflict (business_scope,alias_type,alias_value) do update set last_seen_at=greatest(public.aos_wa_channel_aliases_v1.last_seen_at,excluded.last_seen_at),active=true,updated_at=now();
    select conversation_id into v_existing from public.aos_wa_channel_aliases_v1 where business_scope=v_scope and alias_type='BSUID' and alias_value=v_bsuid;
    if v_existing<>v_conv then raise exception 'WA7A0_IDENTITY_CONFLICT' using errcode='23505'; end if;
  end if;

  new.conversation_id:=v_conv;
  return new;
end
$$;

-- Keep all existing WA-3 authorization gates. Return a generic recipient in addition
-- to the legacy `to_number` key so current runtime remains compatible during rollout.
create or replace function public.aos_wa3_human_send_authorize_v1(p_token text,p_conversation_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_actor jsonb; v_uid uuid; v_conv record; v_enabled boolean; v_address text; v_kind text;
begin
  v_actor:=public.aos_wa3_actor_v1(p_token);
  if coalesce((v_actor->>'ok')::boolean,false) is not true then return v_actor; end if;
  v_uid:=(v_actor->>'actor_id')::uuid;
  select human_send_enabled into v_enabled from public.aos_wa_routing_control_v1 where id=1;
  if coalesce(v_enabled,false) is not true then return jsonb_build_object('ok',false,'error','WA3_HUMAN_SEND_DISABLED'); end if;
  select c.id,c.contact_number,c.contact_address,c.contact_address_type,c.owner_user_id,c.state,c.box_id into v_conv from public.aos_wa_conversations_v1 c where c.id=p_conversation_id;
  if v_conv.id is null then return jsonb_build_object('ok',false,'error','WA3_CONVERSATION_NOT_FOUND'); end if;
  if v_conv.owner_user_id is distinct from v_uid then return jsonb_build_object('ok',false,'error','WA3_NOT_OWNER'); end if;
  if v_conv.state not in ('HUMAN_ACTIVE','AI_COPILOT') then return jsonb_build_object('ok',false,'error','WA3_HUMAN_MODE_REQUIRED'); end if;
  if not exists(select 1 from public.aos_wa_assignments_v1 a where a.conversation_id=p_conversation_id and a.owner_user_id=v_uid and a.state='ACTIVE') then return jsonb_build_object('ok',false,'error','WA3_ACTIVE_ASSIGNMENT_REQUIRED'); end if;
  v_address:=coalesce(v_conv.contact_address,v_conv.contact_number);
  v_kind:=coalesce(v_conv.contact_address_type,case when v_conv.contact_number is not null then 'PHONE' end);
  if v_address is null or v_kind not in ('PHONE','BSUID') then return jsonb_build_object('ok',false,'error','WA7A0_RECIPIENT_UNAVAILABLE'); end if;
  return jsonb_build_object('ok',true,'actor_id',v_uid,'conversation_id',v_conv.id,
    'to_number',v_address,'recipient_kind',v_kind,'recipient_address',v_address,
    'state',v_conv.state,'box_id',v_conv.box_id);
end
$$;

-- S14 strict dependency: resolve inbound push by immutable provider message evidence,
-- not by a mandatory phone number. Signature is unchanged for runtime compatibility.
create or replace function public.aos_push_targets_for_wa_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_phone text:=trim(coalesce(p_payload->>'phone_number_id',''));
  v_provider_id text:=trim(coalesce(p_payload->>'provider_message_id',''));
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_subs jsonb;
begin
  if v_provider_id='' then return jsonb_build_object('ok',false,'eligible',false,'error','INVALID_WA_TARGET'); end if;
  select c.* into v_conv
  from public.aos_wa_messages_v1 m
  join public.aos_wa_conversations_v1 c on c.id=m.conversation_id
  where m.provider_message_id=v_provider_id
    and m.direction='INBOUND'
    and (v_phone='' or c.phone_number_id=v_phone)
    and c.last_message_id=v_provider_id
  order by c.updated_at desc
  limit 1;
  if not found then return jsonb_build_object('ok',true,'eligible',false,'reason','CONVERSATION_NOT_CURRENT'); end if;
  if v_conv.state<>'HUMAN_ACTIVE' or v_conv.owner_user_id is null or v_conv.last_message_direction<>'INBOUND' then
    return jsonb_build_object('ok',true,'eligible',false,'reason','HUMAN_OWNER_REQUIRED');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'endpoint',s.endpoint,'p256dh',s.p256dh,'auth',s.auth) order by s.updated_at desc),'[]'::jsonb)
  into v_subs from public.aos_push_subscriptions_v1 s
  where s.user_id=v_conv.owner_user_id and s.active=true and coalesce((s.channel_preferences->>'WHATSAPP')::boolean,true)=true;
  return jsonb_build_object('ok',true,'eligible',true,'conversation_id',v_conv.id,'owner_user_id',v_conv.owner_user_id,
    'contact_name',v_conv.contact_name,'contact_number',v_conv.contact_number,'contact_address_type',v_conv.contact_address_type,
    'contact_username',v_conv.contact_username,'subscriptions',v_subs);
end
$$;

revoke all on function public.aos_wa7a0_normalize_outbound_request_v1() from public,anon,authenticated;
revoke all on function public.aos_wa2_bind_conversation_v1() from public,anon,authenticated;
revoke all on function public.aos_wa3_human_send_authorize_v1(text,uuid) from public;
revoke all on function public.aos_push_targets_for_wa_v1(jsonb) from public,anon,authenticated;
grant execute on function public.aos_wa3_human_send_authorize_v1(text,uuid) to anon,authenticated,service_role;
grant execute on function public.aos_push_targets_for_wa_v1(jsonb) to service_role;

comment on table public.aos_wa_channel_aliases_v1 is 'WA-7A.0 channel alias continuity ledger. PHONE/BSUID/PARENT_BSUID map to one conversation within the current phone_number_id scope; not a canonical customer master.';
comment on column public.aos_wa_conversations_v1.contact_address is 'Current provider-routable WhatsApp address. May be PHONE or BSUID; not canonical person identity.';
comment on column public.aos_wa_conversations_v1.contact_username is 'WhatsApp username for display/search UX only. Never routing or merge authority.';
comment on function public.aos_wa2_bind_conversation_v1() is 'WA-7A.0 identity-compatible binder. PHONE+BSUID aliases converge; conflicts fail closed.';
comment on function public.aos_push_targets_for_wa_v1(jsonb) is 'S14 target resolver keyed by provider message/conversation evidence; phone is optional.';

commit;
