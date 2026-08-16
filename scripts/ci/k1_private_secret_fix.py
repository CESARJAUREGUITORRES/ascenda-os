from pathlib import Path

mig=Path('supabase/migrations/20260814170000_kronia_k1_private_credentials_auth_v3.sql')
s=mig.read_text(encoding='utf-8')
old="""    select i.api_key into v_api_key from public.aos_integraciones i
    where (lower(coalesce(i.tipo,''))='resend' or lower(coalesce(i.nombre,'')) like '%resend%')
      and coalesce(length(i.api_key),0)>10
    order by coalesce(i.principal,false) desc,i.updated_at desc nulls last limit 1;"""
new="""    -- CURRENT provider-secret boundary: credential material is service-side only.
    -- aos_integraciones remains metadata/status; the key itself lives in the private vault.
    select s.api_key into v_api_key
    from public.aos_integration_secrets_v1 s
    join public.aos_integraciones i on i.id=s.integration_id
    where (lower(coalesce(s.tipo,''))='resend' or lower(coalesce(s.nombre,'')) like '%resend%')
      and coalesce(length(s.api_key),0)>10
      and lower(coalesce(i.estado,'')) in ('conectado','activo')
    order by coalesce(i.principal,false) desc,s.updated_at desc nulls last limit 1;"""
if old not in s:
    raise SystemExit('expected legacy Resend lookup not found in K1 migration')
s=s.replace(old,new,1)
if "select i.api_key into v_api_key from public.aos_integraciones" in s:
    raise SystemExit('legacy integration secret authority survived')
if 'from public.aos_integration_secrets_v1 s' not in s:
    raise SystemExit('private provider vault lookup missing')
mig.write_text(s,encoding='utf-8')

fixture=Path('ci/kronia-k1-phase2/fixture_pre_k1.sql')
f=fixture.read_text(encoding='utf-8')
block="""

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
update public.aos_integraciones set api_key='',updated_at=now() where coalesce(api_key,'')<>'';
"""
if 'CURRENT provider-secret boundary (synthetic shape + dummy credential only)' not in f:
    f += block
fixture.write_text(f,encoding='utf-8')

contract=Path('ci/kronia-k1-phase2/runtime_contract.py')
c=contract.read_text(encoding='utf-8')
anchor="k1=(app/'server-k1.js').read_text(); inner=(app/'server.js').read_text(); browser=(app/'public/k1-browser-security.js').read_text()\n"
inject="migration=(root/'supabase/migrations/20260814170000_kronia_k1_private_credentials_auth_v3.sql').read_text()\n"
if inject not in c:
    if anchor not in c:
        raise SystemExit('runtime contract anchor missing')
    c=c.replace(anchor,anchor+inject,1)
assert_anchor="assert 'loadResendRuntimeKey' not in k1 and 'aos_integraciones?select=api_key' not in k1\n"
checks="assert 'from public.aos_integration_secrets_v1 s' in migration\nassert 'select i.api_key into v_api_key from public.aos_integraciones' not in migration\n"
if checks not in c:
    if assert_anchor not in c:
        raise SystemExit('runtime contract assertion anchor missing')
    c=c.replace(assert_anchor,assert_anchor+checks,1)
contract.write_text(c,encoding='utf-8')
print('KRONIA_K1_PRIVATE_PROVIDER_SECRET_ALIGNMENT=PASS')
