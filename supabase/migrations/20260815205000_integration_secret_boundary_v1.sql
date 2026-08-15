-- P0: remove provider API secrets from the browser-readable integrations catalog.
-- Secrets are copied into a FORCE-RLS service-only vault before public columns are cleared.
begin;

create table if not exists public.aos_integration_secrets_v1 (
  integration_id uuid primary key references public.aos_integraciones(id) on delete cascade,
  tipo text not null,
  nombre text not null,
  api_key text not null default '',
  api_secret text not null default '',
  captured_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists aos_integration_secrets_v1_tipo_idx on public.aos_integration_secrets_v1(lower(tipo));
alter table public.aos_integration_secrets_v1 enable row level security;
alter table public.aos_integration_secrets_v1 force row level security;
revoke all on table public.aos_integration_secrets_v1 from public,anon,authenticated;
grant select,insert,update on table public.aos_integration_secrets_v1 to service_role;

insert into public.aos_integration_secrets_v1(integration_id,tipo,nombre,api_key,api_secret,captured_at,updated_at)
select id,tipo,nombre,coalesce(api_key,''),coalesce(api_secret,''),now(),now()
from public.aos_integraciones
where coalesce(api_key,'')<>'' or coalesce(api_secret,'')<>''
on conflict(integration_id) do update
set tipo=excluded.tipo,nombre=excluded.nombre,
    api_key=case when excluded.api_key<>'' then excluded.api_key else public.aos_integration_secrets_v1.api_key end,
    api_secret=case when excluded.api_secret<>'' then excluded.api_secret else public.aos_integration_secrets_v1.api_secret end,
    updated_at=now();

update public.aos_integraciones
set api_key='',api_secret='',updated_at=now()
where coalesce(api_key,'')<>'' or coalesce(api_secret,'')<>'';

drop policy if exists anon_integ_read_non_auth_provider on public.aos_integraciones;
drop policy if exists anon_integ_write_non_auth_provider on public.aos_integraciones;
create policy anon_integ_read_sanitized_v1 on public.aos_integraciones
for select to anon
using (coalesce(api_key,'')='' and coalesce(api_secret,'')='');
create policy anon_integ_write_sanitized_v1 on public.aos_integraciones
for all to anon
using (coalesce(api_key,'')='' and coalesce(api_secret,'')='')
with check (coalesce(api_key,'')='' and coalesce(api_secret,'')='');

drop policy if exists auth_integ_read_sanitized_v1 on public.aos_integraciones;
drop policy if exists auth_integ_write_sanitized_v1 on public.aos_integraciones;
create policy auth_integ_read_sanitized_v1 on public.aos_integraciones
for select to authenticated
using (coalesce(api_key,'')='' and coalesce(api_secret,'')='');
create policy auth_integ_write_sanitized_v1 on public.aos_integraciones
for all to authenticated
using (coalesce(api_key,'')='' and coalesce(api_secret,'')='')
with check (coalesce(api_key,'')='' and coalesce(api_secret,'')='');

comment on table public.aos_integration_secrets_v1 is 'Server-only integration credential vault introduced by WA-4 P0. Never expose through browser or anon/authenticated PostgREST.';
commit;
