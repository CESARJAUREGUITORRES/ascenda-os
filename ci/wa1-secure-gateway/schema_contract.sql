create extension if not exists pgcrypto;
create table if not exists public.aos_whatsapp_mensajes (
  id uuid primary key default gen_random_uuid(),
  wa_message_id text,
  from_number text not null,
  message_type text,
  message_body text,
  estado text,
  created_at timestamptz default now()
);
grant all on table public.aos_whatsapp_mensajes to anon, authenticated, service_role;

create table if not exists public.aos_meta_config (
  id uuid primary key default gen_random_uuid(),
  key text not null,
  value text not null,
  updated_at timestamptz default now()
);
grant all on table public.aos_meta_config to anon, authenticated, service_role;
