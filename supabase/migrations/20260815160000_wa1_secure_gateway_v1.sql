-- WA-1 Secure WhatsApp Gateway V1 — additive, fail-closed storage.

create table if not exists public.aos_wa_messages_v1 (
  id uuid primary key default gen_random_uuid(),
  provider_message_id text not null unique,
  idempotency_key text unique,
  direction text not null check (direction in ('INBOUND','OUTBOUND')),
  from_number text,
  to_number text,
  phone_number_id text,
  contact_name text,
  message_type text not null,
  message_body text,
  media_id text,
  status text not null default 'received',
  campaign_source text,
  ad_id text,
  lead_id text,
  raw_referral jsonb,
  actor_id uuid,
  pricing_category text,
  pricing_model text,
  billable boolean,
  error_code text,
  error_title text,
  provider_timestamp timestamptz,
  received_at timestamptz,
  sent_at timestamptz,
  delivered_at timestamptz,
  read_at timestamptz,
  failed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists aos_wa_messages_v1_to_number_idx on public.aos_wa_messages_v1(to_number, created_at desc);
create index if not exists aos_wa_messages_v1_from_number_idx on public.aos_wa_messages_v1(from_number, created_at desc);
create index if not exists aos_wa_messages_v1_status_idx on public.aos_wa_messages_v1(status, created_at desc);
create index if not exists aos_wa_messages_v1_ad_idx on public.aos_wa_messages_v1(ad_id, created_at desc) where ad_id is not null;

alter table public.aos_wa_messages_v1 enable row level security;
alter table public.aos_wa_messages_v1 force row level security;
revoke all on table public.aos_wa_messages_v1 from public, anon, authenticated;
grant select, insert, update on table public.aos_wa_messages_v1 to service_role;

create table if not exists public.aos_wa_events_v1 (
  id uuid primary key default gen_random_uuid(),
  event_key text not null unique,
  event_type text not null,
  provider_message_id text,
  status text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists aos_wa_events_v1_message_idx on public.aos_wa_events_v1(provider_message_id, created_at desc);
create index if not exists aos_wa_events_v1_type_idx on public.aos_wa_events_v1(event_type, created_at desc);

alter table public.aos_wa_events_v1 enable row level security;
alter table public.aos_wa_events_v1 force row level security;
revoke all on table public.aos_wa_events_v1 from public, anon, authenticated;
grant select, insert on table public.aos_wa_events_v1 to service_role;

-- Legacy WhatsApp table remains available for historical reads, but direct client writes close.
revoke insert, update, delete, truncate, references, trigger on table public.aos_whatsapp_mensajes from anon, authenticated;

-- Meta credential/config store was historically exposed with RLS disabled and broad client grants.
-- No CURRENT runtime consumer reads it directly; WA-1 moves active secrets to server-side environment.
alter table public.aos_meta_config enable row level security;
alter table public.aos_meta_config force row level security;
revoke all on table public.aos_meta_config from public, anon, authenticated;
grant select, insert, update, delete on table public.aos_meta_config to service_role;

do $$ begin
  comment on table public.aos_wa_messages_v1 is 'WA-1 canonical normalized WhatsApp message store. Server/service-role only; no raw webhook payloads.';
  comment on table public.aos_wa_events_v1 is 'WA-1 idempotent WhatsApp event/status ledger. Server/service-role only; sanitized payload only.';
  comment on table public.aos_meta_config is 'Legacy Meta configuration store. WA-1 closes all browser/client access; active secrets belong in server-side runtime environment.';
exception when others then null; end $$;
