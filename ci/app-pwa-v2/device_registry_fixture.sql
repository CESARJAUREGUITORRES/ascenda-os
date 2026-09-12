-- APP-PWA-V2 #517 — minimal synthetic authority fixture
create extension if not exists pgcrypto;

do $$
begin
  if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role nologin; end if;
end $$;

create table public.aos_usuarios (
  id uuid primary key,
  activo boolean not null default true
);

create table public.aos_push_subscriptions_v1 (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.aos_usuarios(id) on delete cascade,
  endpoint text not null unique,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.aos_usuarios(id,activo) values
('11111111-1111-1111-1111-111111111111',true),
('22222222-2222-2222-2222-222222222222',true),
('33333333-3333-3333-3333-333333333333',false);
