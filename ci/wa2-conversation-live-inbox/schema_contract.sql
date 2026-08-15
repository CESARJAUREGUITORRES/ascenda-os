create extension if not exists pgcrypto;

-- WA-1 legacy prerequisites, synthetic only.
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

create table if not exists public.aos_webhook_log (
  id uuid primary key default gen_random_uuid(),
  source text,
  payload jsonb,
  processed boolean default false,
  error text,
  created_at timestamptz default now()
);
grant all on table public.aos_webhook_log to anon, authenticated, service_role;

create table if not exists public.aos_meta_config (
  id uuid primary key default gen_random_uuid(),
  key text not null,
  value text not null,
  updated_at timestamptz default now()
);
grant all on table public.aos_meta_config to anon, authenticated, service_role;

-- Existing ASCENDA permission catalog, minimum contract needed by WA-2.
create table if not exists public.aos_paneles_disponibles (
  id text primary key,
  nombre text not null,
  icono text default '📄',
  categoria text default 'general',
  descripcion text default '',
  orden integer default 0
);

create table if not exists public.aos_usuarios (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  codigo_asesor text default '',
  activo boolean default true,
  two_factor boolean default false,
  paneles_acceso text[] default '{}'::text[],
  nivel_jerarquia integer default 3,
  updated_at timestamptz default now()
);

insert into public.aos_paneles_disponibles(id,nombre,icono,categoria,descripcion,orden)
values ('admin-chats','Coordinación','💬','admin','Synthetic prerequisite',3)
on conflict (id) do nothing;

insert into public.aos_usuarios(id,nombre,codigo_asesor,activo,two_factor,paneles_acceso,nivel_jerarquia)
values
 ('11111111-1111-4111-8111-111111111111','ADMIN CANARY','TST-001',true,true,array['admin-chats'],1),
 ('22222222-2222-4222-8222-222222222222','ADMIN LEVEL2','TST-002',true,true,array['admin-chats'],2),
 ('33333333-3333-4333-8333-333333333333','ASESOR','TST-003',true,true,array['admin-chats'],3)
on conflict (id) do nothing;
