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

-- Bind only. This function MUST NOT increment counters: PostgreSQL runs BEFORE INSERT
-- even for INSERT ... ON CONFLICT, so keeping projection side effects here would break
-- WA-1 idempotency when Meta retries an already-known provider_message_id.
create or replace function public.aos_wa2_bind_conversation_v1()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_contact text;
  v_key text;
  v_ts timestamptz;
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

  insert into public.aos_wa_conversations_v1(
    conversation_key, contact_number, contact_name, phone_number_id, state, opened_at, updated_at
  ) values (
    v_key, v_contact, nullif(new.contact_name,''), new.phone_number_id, 'NEW', v_ts, now()
  )
  on conflict (conversation_key) do nothing
  returning id into v_conv;

  if v_conv is null then
    select id into v_conv
    from public.aos_wa_conversations_v1
    where conversation_key = v_key;
  end if;

  if v_conv is null then
    raise exception 'WA2_CONVERSATION_BIND_FAILED';
  end if;

  new.conversation_id := v_conv;
  return new;
end
$$;

-- Projection only after an actual new ledger row, or after a true NULL->bound backfill.
create or replace function public.aos_wa2_project_message_v1()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_ts timestamptz;
  v_preview text;
begin
  if new.conversation_id is null then
    raise exception 'WA2_CONVERSATION_REQUIRED' using errcode = '23514';
  end if;

  v_ts := coalesce(new.provider_timestamp, new.received_at, new.sent_at, new.created_at, now());
  v_preview := left(coalesce(nullif(new.message_body,''), '[' || coalesce(new.message_type,'message') || ']'), 240);

  update public.aos_wa_conversations_v1 c
  set
    contact_name = coalesce(nullif(new.contact_name,''), c.contact_name),
    phone_number_id = coalesce(new.phone_number_id, c.phone_number_id),
    state = case
      when new.direction='INBOUND'
       and c.state='CLOSED'
       and v_ts >= coalesce(c.closed_at, '-infinity'::timestamptz)
      then 'NEW'
      else c.state
    end,
    closed_at = case
      when new.direction='INBOUND'
       and c.state='CLOSED'
       and v_ts >= coalesce(c.closed_at, '-infinity'::timestamptz)
      then null
      else c.closed_at
    end,
    last_message_id = case
      when v_ts >= coalesce(c.last_message_at, '-infinity'::timestamptz)
      then new.provider_message_id else c.last_message_id end,
    last_message_direction = case
      when v_ts >= coalesce(c.last_message_at, '-infinity'::timestamptz)
      then new.direction else c.last_message_direction end,
    last_message_type = case
      when v_ts >= coalesce(c.last_message_at, '-infinity'::timestamptz)
      then new.message_type else c.last_message_type end,
    last_message_preview = case
      when v_ts >= coalesce(c.last_message_at, '-infinity'::timestamptz)
      then v_preview else c.last_message_preview end,
    last_message_status = case
      when v_ts >= coalesce(c.last_message_at, '-infinity'::timestamptz)
      then new.status else c.last_message_status end,
    last_message_at = greatest(coalesce(c.last_message_at, v_ts), v_ts),
    unread_count = c.unread_count + case
      when new.direction='INBOUND'
       and (c.last_read_at is null or v_ts > c.last_read_at)
      then 1 else 0 end,
    message_count = c.message_count + 1,
    first_inbound_at = case
      when new.direction <> 'INBOUND' then c.first_inbound_at
      when c.first_inbound_at is null then v_ts
      else least(c.first_inbound_at, v_ts)
    end,
    first_outbound_at = case
      when new.direction <> 'OUTBOUND' then c.first_outbound_at
      when c.first_outbound_at is null then v_ts
      else least(c.first_outbound_at, v_ts)
    end,
    last_inbound_at = case
      when new.direction <> 'INBOUND' then c.last_inbound_at
      when c.last_inbound_at is null then v_ts
      else greatest(c.last_inbound_at, v_ts)
    end,
    last_outbound_at = case
      when new.direction <> 'OUTBOUND' then c.last_outbound_at
      when c.last_outbound_at is null then v_ts
      else greatest(c.last_outbound_at, v_ts)
    end,
    campaign_source = coalesce(c.campaign_source, new.campaign_source),
    ad_id = coalesce(c.ad_id, new.ad_id),
    lead_id = coalesce(c.lead_id, new.lead_id),
    version = c.version + 1,
    updated_at = now()
  where c.id = new.conversation_id;

  if not found then
    raise exception 'WA2_CONVERSATION_PROJECT_FAILED';
  end if;
  return null;
end
$$;

revoke all on function public.aos_wa2_bind_conversation_v1() from public, anon, authenticated;
revoke all on function public.aos_wa2_project_message_v1() from public, anon, authenticated;

drop trigger if exists trg_aos_wa2_bind_conversation_v1 on public.aos_wa_messages_v1;
create trigger trg_aos_wa2_bind_conversation_v1
before insert or update of conversation_id on public.aos_wa_messages_v1
for each row execute function public.aos_wa2_bind_conversation_v1();

drop trigger if exists trg_aos_wa2_project_insert_v1 on public.aos_wa_messages_v1;
create trigger trg_aos_wa2_project_insert_v1
after insert on public.aos_wa_messages_v1
for each row execute function public.aos_wa2_project_message_v1();

drop trigger if exists trg_aos_wa2_project_backfill_v1 on public.aos_wa_messages_v1;
create trigger trg_aos_wa2_project_backfill_v1
after update of conversation_id on public.aos_wa_messages_v1
for each row
when (old.conversation_id is null and new.conversation_id is not null)
execute function public.aos_wa2_project_message_v1();

-- Safe backfill: the BEFORE trigger turns NULL into a deterministic conversation_id;
-- the AFTER backfill trigger projects the message exactly once.
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
comment on function public.aos_wa2_bind_conversation_v1() is 'WA-2 idempotent bind-only trigger function. It never changes conversation counters.';
comment on function public.aos_wa2_project_message_v1() is 'WA-2 post-insert/backfill projection. Updates counters once per real ledger row and respects provider timestamp ordering.';
