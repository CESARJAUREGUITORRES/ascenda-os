\set ON_ERROR_STOP on

-- Extend the synthetic K1 identity contract with the live login-lockout columns.
alter table public.aos_usuarios add column if not exists failed_attempts integer default 0;
alter table public.aos_usuarios add column if not exists locked_until timestamptz;
alter table public.aos_usuarios add column if not exists ultimo_acceso timestamptz;
alter table public.aos_usuarios add column if not exists ip_ultimo text;

-- Make the synthetic ADMIN hierarchy representative of production.
update public.aos_usuarios set nivel_jerarquia=1, rol='admin', cargo='Administradora'
where codigo_asesor='A001';
update public.aos_usuarios set nivel_jerarquia=4, rol='asesor'
where codigo_asesor in ('A002','A003');

-- Minimal Sales Intelligence identity/session contracts used by migration 521.
create table if not exists public.aos_sales_intelligence_access(
  user_id uuid primary key references public.aos_usuarios(id) on delete cascade,
  enabled boolean not null default false,
  login_usuario text not null,
  twofa_subject text not null,
  codigo_asesor_snapshot text not null,
  password_digest text not null,
  granted_by uuid references public.aos_usuarios(id),
  granted_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.aos_cia_admin_sessions(
  id uuid primary key default gen_random_uuid(),
  token_hash text not null,
  user_id uuid not null references public.aos_usuarios(id) on delete cascade,
  usuario text not null,
  expires_at timestamptz not null,
  source_auth_code_id uuid references public.aos_auth_codes(id),
  revoked boolean not null default false,
  last_used_at timestamptz default now()
);
create unique index if not exists k1_fixture_cia_source_code_uidx
  on public.aos_cia_admin_sessions(source_auth_code_id)
  where source_auth_code_id is not null;

do $$
declare v_admin uuid;
begin
  select id into v_admin from public.aos_usuarios where codigo_asesor='A001';
  insert into public.aos_sales_intelligence_access(
    user_id,enabled,login_usuario,twofa_subject,codigo_asesor_snapshot,password_digest,granted_by
  ) values(v_admin,true,'alice','Alice Admin','A001',repeat('0',64),v_admin)
  on conflict(user_id) do nothing;
end $$;

-- Production-signature legacy identity primitives. K1 must prove that every
-- browser-executable legacy path is explicitly retired by migrations 521/522.
create or replace function public.aos_login(p_usuario text,p_password text)
returns json language sql security definer as $$ select json_build_object('ok',false,'fixture',true) $$;

create or replace function public.aos_cambiar_password(p_usuario text,p_password_actual text,p_password_nuevo text)
returns json language sql security definer as $$ select json_build_object('ok',false,'fixture',true) $$;

create or replace function public.aos_admin_cambiar_password(p_usuario_id uuid,p_nueva_password text)
returns jsonb language sql security definer as $$ select jsonb_build_object('ok',false,'fixture',true) $$;

create or replace function public.aos_admin_cambiar_password(p_codigo_asesor text,p_nueva_password text,p_admin_id text,p_ip text)
returns jsonb language sql security definer as $$ select jsonb_build_object('ok',false,'fixture',true) $$;

create or replace function public.aos_admin_crear_usuario(
  p_nombre text,p_apellido text,p_email text,p_telefono text,p_cargo text,p_area text,
  p_nivel_jerarquia integer,p_acceso_geo text,p_sede text
) returns jsonb language sql security definer
as $$ select jsonb_build_object('ok',false,'fixture',true) $$;

create or replace function public.aos_admin_cambiar_username(p_usuario_id uuid,p_nuevo_username text)
returns json language sql security definer as $$ select json_build_object('ok',false,'fixture',true) $$;

create or replace function public.aos_admin_toggle_usuario(p_usuario_id uuid,p_activar boolean)
returns jsonb language sql security definer as $$ select jsonb_build_object('ok',false,'fixture',true) $$;

create or replace function public.aos_admin_eliminar_usuario(p_usuario_id uuid,p_admin_id text)
returns jsonb language sql security definer as $$ select jsonb_build_object('ok',false,'fixture',true) $$;

grant execute on function public.aos_login(text,text) to anon,authenticated,service_role;
grant execute on function public.aos_cambiar_password(text,text,text) to anon,authenticated,service_role;
grant execute on function public.aos_admin_cambiar_password(uuid,text) to anon,authenticated,service_role;
grant execute on function public.aos_admin_cambiar_password(text,text,text,text) to anon,authenticated,service_role;
grant execute on function public.aos_admin_crear_usuario(text,text,text,text,text,text,integer,text,text) to anon,authenticated,service_role;
grant execute on function public.aos_admin_cambiar_username(uuid,text) to anon,authenticated,service_role;
grant execute on function public.aos_admin_toggle_usuario(uuid,boolean) to anon,authenticated,service_role;
grant execute on function public.aos_admin_eliminar_usuario(uuid,text) to anon,authenticated,service_role;
