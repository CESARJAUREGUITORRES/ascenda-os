-- WA-2 Conversation Store & Live Inbox V1
-- Additive conversation projection over the WA-1 canonical message ledger.

create table if not exists public.aos_wa_conversations_v1 (
  id uuid primary key default gen_random_uuid(),
  conversation_key text not null unique,
  contact_number text not null,
  contact_name text,
  phone_number_id text,
  state text not null default 'NEW' check (state in (
    'NEW','AI_ACTIVE','HUMAN_REQUESTED','HUMAN_ACTIVE','AI_COPILOT',
    'WAITING_CUSTOMER','APPOINTMENT_PENDING','APPOINTMENT_BOOKED','WON','LOST','CLOSED'
  )),
  last_message_id text,
  last_message_direction text check (last_message_direction is null or last_message_direction in ('INBOUND','OUTBOUND')),
  last_message_type text,
  last_message_preview text,
  last_message_status text,
  last_message_at timestamptz,
  unread_count integer not null default 0 check (unread_count >= 0),
  message_count integer not null default 0 check (message_count >= 0),
  first_inbound_at timestamptz,
  first_outbound_at timestamptz,
  last_inbound_at timestamptz,
  last_outbound_at timestamptz,
  last_read_at timestamptz,
  last_read_by uuid,
  campaign_source text,
  ad_id text,
  lead_id text,
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists aos_wa_conversations_v1_last_idx
  on public.aos_wa_conversations_v1(last_message_at desc nulls last, updated_at desc);
create index if not exists aos_wa_conversations_v1_state_idx
  on public.aos_wa_conversations_v1(state, last_message_at desc nulls last);
create index if not exists aos_wa_conversations_v1_unread_idx
  on public.aos_wa_conversations_v1(unread_count, last_message_at desc nulls last)
  where unread_count > 0;
create index if not exists aos_wa_conversations_v1_contact_idx
  on public.aos_wa_conversations_v1(contact_number);

alter table public.aos_wa_conversations_v1 enable row level security;
alter table public.aos_wa_conversations_v1 force row level security;
revoke all on table public.aos_wa_conversations_v1 from public, anon, authenticated;
grant select, insert, update on table public.aos_wa_conversations_v1 to service_role;

create table if not exists public.aos_wa_conversation_events_v1 (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.aos_wa_conversations_v1(id) on delete restrict,
  event_type text not null,
  actor_id uuid,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists aos_wa_conversation_events_v1_conv_idx
  on public.aos_wa_conversation_events_v1(conversation_id, created_at desc);

alter table public.aos_wa_conversation_events_v1 enable row level security;
alter table public.aos_wa_conversation_events_v1 force row level security;
revoke all on table public.aos_wa_conversation_events_v1 from public, anon, authenticated;
grant select, insert on table public.aos_wa_conversation_events_v1 to service_role;

alter table public.aos_wa_messages_v1
  add column if not exists conversation_id uuid references public.aos_wa_conversations_v1(id) on delete restrict;
create index if not exists aos_wa_messages_v1_conversation_idx
  on public.aos_wa_messages_v1(conversation_id, created_at asc);

create or replace function public.aos_wa2_bind_conversation_v1()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_contact text;
  v_key text;
  v_ts timestamptz;
  v_preview text;
  v_conv uuid;
begin
  if tg_op = 'UPDATE' and new.conversation_id is not null then
    return new;
  end if;

  v_contact := regexp_replace(
    coalesce(case when new.direction = 'INBOUND' then new.from_number else new.to_number end, ''),
    '[^0-9]', '', 'g'
  );
  if v_contact = '' then
    raise exception 'WA2_CONTACT_REQUIRED' using errcode = '23514';
  end if;

  v_key := coalesce(nullif(new.phone_number_id,''), 'default') || ':' || v_contact;
  v_ts := coalesce(new.provider_timestamp, new.received_at, new.sent_at, new.created_at, now());
  v_preview := left(coalesce(nullif(new.message_body,''), '[' || coalesce(new.message_type,'message') || ']'), 240);

  insert into public.aos_wa_conversations_v1 as c (
    conversation_key, contact_number, contact_name, phone_number_id, state,
    last_message_id, last_message_direction, last_message_type, last_message_preview,
    last_message_status, last_message_at, unread_count, message_count,
    first_inbound_at, first_outbound_at, last_inbound_at, last_outbound_at,
    campaign_source, ad_id, lead_id, opened_at, updated_at
  ) values (
    v_key, v_contact, nullif(new.contact_name,''), new.phone_number_id, 'NEW',
    new.provider_message_id, new.direction, new.message_type, v_preview,
    new.status, v_ts, case when new.direction='INBOUND' then 1 else 0 end, 1,
    case when new.direction='INBOUND' then v_ts end,
    case when new.direction='OUTBOUND' then v_ts end,
    case when new.direction='INBOUND' then v_ts end,
    case when new.direction='OUTBOUND' then v_ts end,
    new.campaign_source, new.ad_id, new.lead_id, v_ts, now()
  )
  on conflict (conversation_key) do update set
    contact_name = coalesce(nullif(excluded.contact_name,''), c.contact_name),
    phone_number_id = coalesce(excluded.phone_number_id, c.phone_number_id),
    state = case
      when excluded.last_message_direction='INBOUND'
       and c.state='CLOSED'
       and excluded.last_message_at >= coalesce(c.closed_at, '-infinity'::timestamptz)
      then 'NEW'
      else c.state
    end,
    closed_at = case
      when excluded.last_message_direction='INBOUND'
       and c.state='CLOSED'
       and excluded.last_message_at >= coalesce(c.closed_at, '-infinity'::timestamptz)
      then null
      else c.closed_at
    end,
    last_message_id = case
      when excluded.last_message_at >= coalesce(c.last_message_at, '-infinity'::timestamptz)
      then excluded.last_message_id else c.last_message_id end,
    last_message_direction = case
      when excluded.last_message_at >= coalesce(c.last_message_at, '-infinity'::timestamptz)
      then excluded.last_message_direction else c.last_message_direction end,
    last_message_type = case
      when excluded.last_message_at >= coalesce(c.last_message_at, '-infinity'::timestamptz)
      then excluded.last_message_type else c.last_message_type end,
    last_message_preview = case
      when excluded.last_message_at >= coalesce(c.last_message_at, '-infinity'::timestamptz)
      then excluded.last_message_preview else c.last_message_preview end,
    last_message_status = case
      when excluded.last_message_at >= coalesce(c.last_message_at, '-infinity'::timestamptz)
      then excluded.last_message_status else c.last_message_status end,
    last_message_at = greatest(coalesce(c.last_message_at, excluded.last_message_at), excluded.last_message_at),
    unread_count = c.unread_count + case when excluded.last_message_direction='INBOUND' then 1 else 0 end,
    message_count = c.message_count + 1,
    first_inbound_at = case
      when c.first_inbound_at is null then excluded.first_inbound_at
      when excluded.first_inbound_at is null then c.first_inbound_at
      else least(c.first_inbound_at, excluded.first_inbound_at)
    end,
    first_outbound_at = case
      when c.first_outbound_at is null then excluded.first_outbound_at
      when excluded.first_outbound_at is null then c.first_outbound_at
      else least(c.first_outbound_at, excluded.first_outbound_at)
    end,
    last_inbound_at = case
      when c.last_inbound_at is null then excluded.last_inbound_at
      when excluded.last_inbound_at is null then c.last_inbound_at
      else greatest(c.last_inbound_at, excluded.last_inbound_at)
    end,
    last_outbound_at = case
      when c.last_outbound_at is null then excluded.last_outbound_at
      when excluded.last_outbound_at is null then c.last_outbound_at
      else greatest(c.last_outbound_at, excluded.last_outbound_at)
    end,
    campaign_source = coalesce(c.campaign_source, excluded.campaign_source),
    ad_id = coalesce(c.ad_id, excluded.ad_id),
    lead_id = coalesce(c.lead_id, excluded.lead_id),
    version = c.version + 1,
    updated_at = now()
  returning id into v_conv;

  new.conversation_id := v_conv;
  return new;
end
$$;

revoke all on function public.aos_wa2_bind_conversation_v1() from public, anon, authenticated;

-- Bind future inserts and allow a safe backfill of any WA-1 messages that may arrive between preflight and cutover.
drop trigger if exists trg_aos_wa2_bind_conversation_v1 on public.aos_wa_messages_v1;
create trigger trg_aos_wa2_bind_conversation_v1
before insert or update of conversation_id on public.aos_wa_messages_v1
for each row execute function public.aos_wa2_bind_conversation_v1();

update public.aos_wa_messages_v1
set conversation_id = null
where conversation_id is null;

-- Register the panel in the existing permission catalog. Canary access: active level-1 admins with 2FA only.
insert into public.aos_paneles_disponibles(id,nombre,icono,categoria,descripcion,orden)
values ('admin-whatsapp','WhatsApp Live Inbox','💬','admin','Inbox WhatsApp seguro. Requiere administrador, 2FA y autorización explícita.',77)
on conflict (id) do nothing;

update public.aos_usuarios
set paneles_acceso = array_append(coalesce(paneles_acceso,'{}'::text[]),'admin-whatsapp'),
    updated_at = now()
where nivel_jerarquia = 1
  and activo is true
  and two_factor is true
  and not ('admin-whatsapp' = any(coalesce(paneles_acceso,'{}'::text[])));

comment on table public.aos_wa_conversations_v1 is 'WA-2 canonical conversation projection over WA-1 messages. Service-only; browser access is mediated by admin+2FA APIs.';
comment on table public.aos_wa_conversation_events_v1 is 'WA-2 append-only internal conversation activity/audit ledger.';
comment on column public.aos_wa_messages_v1.conversation_id is 'WA-2 deterministic link to canonical WhatsApp conversation.';
comment on function public.aos_wa2_bind_conversation_v1() is 'WA-2 trigger projection: atomically binds each WA-1 message to a conversation and updates unread/message counters with provider-timestamp ordering.';
