\set ON_ERROR_STOP on

-- Extend the existing Phase 2 synthetic fixture only. No production PII.
update public.aos_usuarios
set paneles_acceso=array['admin-sales-intelligence','admin-cartera','admin-caja','admin-team','admin-config']::text[],
    rol='admin',nivel_jerarquia=1,two_factor=true,activo=true
where codigo_asesor='CAROWNER';

insert into public.aos_rrhh(codigo_asesor,nombre,apellido,puesto,sede,usuario,password_hash,permisos,estado)
values('K1ADV','K1 ADVISOR','TEST','ASESOR','SAN ISIDRO','k1.advisor','advisor-pass-2026','{}','ACTIVO')
on conflict(codigo_asesor) do nothing;

insert into public.aos_usuarios(codigo_asesor,nombre,email,rol,paneles_acceso,nivel_jerarquia,sedes_permitidas,area,cargo,two_factor,activo)
values('K1ADV','K1 ADVISOR','advisor@example.invalid','asesor',array['ventas']::text[],4,array['SAN ISIDRO']::text[],'VENTAS','ASESOR',false,true)
on conflict(codigo_asesor) do nothing;

-- Known 2FA app token for owner-admin gateway tests. This is a synthetic CI token.
insert into public.aos_app_sessions_v3(token_hash,user_id,assurance_level,expires_at,revoked)
select encode(extensions.digest('k1-owner-app-token-00000000000000000000000001','sha256'),'hex'),id,'PASSWORD_2FA',now()+interval '8 hours',false
from public.aos_usuarios where codigo_asesor='CAROWNER';

-- Advisor token for negative/positive non-admin control-plane tests.
insert into public.aos_app_sessions_v3(token_hash,user_id,assurance_level,expires_at,revoked)
select encode(extensions.digest('k1-advisor-app-token-000000000000000000000001','sha256'),'hex'),id,'PASSWORD',now()+interval '8 hours',false
from public.aos_usuarios where codigo_asesor='K1ADV';

-- K1 CURRENT synthetic schema compatibility (shape only; no production data).
alter table public.aos_usuarios
  add column if not exists auth_id uuid,
  add column if not exists telefono text,
  add column if not exists sede text default '',
  add column if not exists permisos jsonb default '{}'::jsonb,
  add column if not exists ultimo_login timestamptz,
  add column if not exists login_method text default 'password',
  add column if not exists sueldo numeric default 0,
  add column if not exists fecha_ingreso date,
  add column if not exists dni text default '',
  add column if not exists telefono_personal text default '',
  add column if not exists direccion text default '',
  add column if not exists contacto_emergencia text default '',
  add column if not exists invitacion_enviada boolean default false,
  add column if not exists cuenta_activada boolean default false,
  add column if not exists apellidos text default '',
  add column if not exists fecha_nacimiento date,
  add column if not exists lugar_nacimiento text default '',
  add column if not exists pais text default 'Perú',
  add column if not exists departamento text default '',
  add column if not exists provincia text default '',
  add column if not exists distrito text default '',
  add column if not exists tipo_contrato text default 'prueba',
  add column if not exists rh text default '',
  add column if not exists bono_metas numeric default 0,
  add column if not exists cmp text default '',
  add column if not exists servicios text[] default '{}'::text[];

alter table public.aos_rrhh
  add column if not exists sueldo numeric,
  add column if not exists fecha_ingreso date,
  add column if not exists fecha_salida date,
  add column if not exists meta numeric default 0,
  add column if not exists bonus_pct numeric default 0,
  add column if not exists label text,
  add column if not exists numero text,
  add column if not exists tiene_agenda text default 'NO',
  add column if not exists foto_url text,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();


-- CURRENT aos_integraciones shape required by K1-B (shape only).
alter table public.aos_integraciones
  add column if not exists cuenta text default '',
  add column if not exists config jsonb default '{}'::jsonb,
  add column if not exists created_at timestamptz default now(),
  add column if not exists categoria text default 'infraestructura',
  add column if not exists icono text default '🔗',
  add column if not exists descripcion text default '',
  add column if not exists api_secret text default '',
  add column if not exists webhook_url text default '',
  add column if not exists pasos_guia jsonb default '[]'::jsonb,
  add column if not exists uso_para text[] default '{}'::text[],
  add column if not exists orden integer default 0,
  add column if not exists url_api text default '',
  add column if not exists url_docs text default '',
  add column if not exists url_signup text default '',
  add column if not exists multi_cuenta boolean default false,
  add column if not exists logo_url text default '';


-- CURRENT provider-secret boundary (synthetic shape + dummy credential only).
-- The browser-readable integration catalog keeps metadata; credential material
-- moves to a FORCE-RLS service-only vault exactly as in CURRENT production.
create table if not exists public.aos_integration_secrets_v1 (
  integration_id uuid primary key references public.aos_integraciones(id) on delete cascade,
  tipo text not null,
  nombre text not null,
  api_key text not null default '',
  api_secret text not null default '',
  captured_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.aos_integration_secrets_v1 enable row level security;
alter table public.aos_integration_secrets_v1 force row level security;
revoke all on table public.aos_integration_secrets_v1 from public,anon,authenticated;
grant select,insert,update on table public.aos_integration_secrets_v1 to service_role;
insert into public.aos_integration_secrets_v1(integration_id,tipo,nombre,api_key,api_secret,captured_at,updated_at)
select id,tipo,nombre,api_key,'',now(),now()
from public.aos_integraciones
where coalesce(api_key,'')<>''
on conflict(integration_id) do update
set tipo=excluded.tipo,nombre=excluded.nombre,api_key=excluded.api_key,updated_at=now();
update public.aos_integraciones set api_key='',api_secret='',updated_at=now()
where coalesce(api_key,'')<>'' or coalesce(api_secret,'')<>'';
