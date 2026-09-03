\set ON_ERROR_STOP on
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table public.aos_usuarios(
  id uuid primary key,
  activo boolean not null default true,
  nivel_jerarquia integer,
  paneles_acceso text[] not null default '{}'::text[]
);

create table public.aos_wa_ai_control_v1(
  id smallint primary key default 1 check(id=1),
  provider text not null default 'groq',
  fast_model text not null default 'openai/gpt-oss-20b',
  reasoning_model text not null default 'openai/gpt-oss-120b',
  safety_model text not null default 'openai/gpt-oss-safeguard-20b',
  copilot_enabled boolean not null default false,
  auto_reply_enabled boolean not null default false,
  daily_budget_usd numeric(10,4) not null default 0.5000,
  max_context_messages integer not null default 24,
  max_catalog_items integer not null default 12,
  updated_by uuid references public.aos_usuarios(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint aos_wa_ai_control_v1_auto_reply_enabled_check check(auto_reply_enabled=false)
);
insert into public.aos_wa_ai_control_v1(id,copilot_enabled) values(1,true);

create table public.aos_wa_routing_control_v1(
  id smallint primary key default 1 check(id=1),
  auto_routing_enabled boolean not null default false,
  human_send_enabled boolean not null default true,
  ai_send_enabled boolean not null default false,
  updated_by uuid references public.aos_usuarios(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint aos_wa_routing_control_v1_ai_send_enabled_check check(ai_send_enabled=false)
);
insert into public.aos_wa_routing_control_v1(id) values(1);

create table public.aos_wa_conversations_v1(
  id uuid primary key,
  state text not null,
  contact_address_type text not null check(contact_address_type in ('PHONE','BSUID')),
  contact_address text not null,
  human_takeover_at timestamptz
);

create table public.aos_agenda_delivery_template_registry_v3(
  delivery_kind text not null,
  channel text not null,
  site_scope text not null default '*',
  template_key text not null,
  provider text not null,
  provider_template_name text,
  provider_verified boolean not null default false,
  active boolean not null default true,
  evidence_ref text not null,
  updated_at timestamptz not null default now(),
  primary key(delivery_kind,channel,site_scope,template_key)
);

create table public.aos_wa_outbound_requests_v1(
  idempotency_key text primary key,
  actor_id uuid not null,
  to_number text,
  message_type text not null,
  state text not null default 'PENDING' check(state in ('PENDING','ACCEPTED','FAILED')),
  provider_message_id text,
  error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  recipient_kind text not null check(recipient_kind in ('PHONE','BSUID')),
  recipient_address text not null
);

create table public.aos_wa_messages_v1(
  id uuid primary key default gen_random_uuid(),
  provider_message_id text not null unique,
  direction text not null,
  message_type text not null,
  conversation_id uuid references public.aos_wa_conversations_v1(id) on delete restrict,
  created_at timestamptz not null default now()
);

insert into public.aos_usuarios(id,activo,nivel_jerarquia,paneles_acceso) values
('11111111-1111-4111-8111-111111111111',true,1,array['admin-whatsapp']),
('22222222-2222-4222-8222-222222222222',true,2,array['admin-whatsapp']);

insert into public.aos_wa_conversations_v1(id,state,contact_address_type,contact_address,human_takeover_at) values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','AI_ACTIVE','PHONE','999111222',null),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2','AI_ACTIVE','PHONE','999111333',null),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3','HUMAN_ACTIVE','PHONE','999111444',now()),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4','AI_ACTIVE','PHONE','999111555',null),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa5','AI_ACTIVE','BSUID','bsuid-test-001',null);

insert into public.aos_agenda_delivery_template_registry_v3(delivery_kind,channel,site_scope,template_key,provider,provider_template_name,provider_verified,active,evidence_ref) values
('CONFIRMATION','WHATSAPP','*','verified_tpl','META_CLOUD_API','verified_template',true,true,'CI_VERIFIED'),
('REMINDER_TODAY','WHATSAPP','*','unverified_tpl','META_CLOUD_API','unverified_template',false,true,'CI_UNVERIFIED');
