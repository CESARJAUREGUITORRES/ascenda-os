from pathlib import Path

ROOT=Path('.')
PRIVATE_LOOKUP="""    -- CURRENT provider-secret boundary: credential material is service-side only.
    -- aos_integraciones remains metadata/status; the key itself lives in the private vault.
    select s.api_key into v_api_key
    from public.aos_integration_secrets_v1 s
    join public.aos_integraciones i on i.id=s.integration_id
    where (lower(coalesce(s.tipo,''))='resend' or lower(coalesce(s.nombre,'')) like '%resend%')
      and coalesce(length(s.api_key),0)>10
      and lower(coalesce(i.estado,'')) in ('conectado','activo')
    order by coalesce(i.principal,false) desc,s.updated_at desc nulls last limit 1;"""

# K1-A login definition.
p=ROOT/'supabase/migrations/20260814170000_kronia_k1_private_credentials_auth_v3.sql'
s=p.read_text(encoding='utf-8')
old="""    select i.api_key into v_api_key from public.aos_integraciones i
    where (lower(coalesce(i.tipo,''))='resend' or lower(coalesce(i.nombre,'')) like '%resend%')
      and coalesce(length(i.api_key),0)>10
    order by coalesce(i.principal,false) desc,i.updated_at desc nulls last limit 1;"""
if old in s:
    s=s.replace(old,PRIVATE_LOOKUP,1)
if "select i.api_key into v_api_key from public.aos_integraciones" in s:
    raise SystemExit('K1-A legacy integration secret authority survived')
if 'from public.aos_integration_secrets_v1 s' not in s:
    raise SystemExit('K1-A private provider vault lookup missing')
p.write_text(s,encoding='utf-8')

# K1-E branded login is the final aos_login_v3 definition, so it must use the same vault.
p=ROOT/'supabase/migrations/20260814171800_kronia_k1_auth_v3_branded_alignment.sql'
s=p.read_text(encoding='utf-8')
old="""    select i.api_key into v_api_key
    from public.aos_integraciones i
    where (pg_catalog.lower(coalesce(i.tipo,''))='resend' or pg_catalog.lower(coalesce(i.nombre,'')) like '%resend%')
      and coalesce(pg_catalog.length(i.api_key),0)>10
    order by coalesce(i.principal,false) desc,i.updated_at desc nulls last limit 1;"""
new="""    -- CURRENT provider-secret boundary: final branded Auth V3 reads only the private vault.
    select s.api_key into v_api_key
    from public.aos_integration_secrets_v1 s
    join public.aos_integraciones i on i.id=s.integration_id
    where (pg_catalog.lower(coalesce(s.tipo,''))='resend' or pg_catalog.lower(coalesce(s.nombre,'')) like '%resend%')
      and coalesce(pg_catalog.length(s.api_key),0)>10
      and pg_catalog.lower(coalesce(i.estado,'')) in ('conectado','activo')
    order by coalesce(i.principal,false) desc,s.updated_at desc nulls last limit 1;"""
if old in s:
    s=s.replace(old,new,1)
if 'from public.aos_integraciones i\n    where' in s and 'select i.api_key into v_api_key' in s:
    raise SystemExit('K1-E legacy integration secret authority survived')
if 'from public.aos_integration_secrets_v1 s' not in s:
    raise SystemExit('K1-E private provider vault lookup missing')
p.write_text(s,encoding='utf-8')

# K1-B administrative integration gateway must never repopulate browser-readable secret columns.
p=ROOT/'supabase/migrations/20260814171000_kronia_k1_app_token_control_plane.sql'
s=p.read_text(encoding='utf-8')
old="""  if v_action='disable' then
    update public.aos_integraciones set estado='pendiente',api_key=null,api_secret=null,config=null,webhook_url=null,cuenta='',updated_at=now() where id=p_id;
  elsif v_action='update' then
    update public.aos_integraciones set
      cuenta=coalesce(p_data->>'cuenta',cuenta),estado=coalesce(p_data->>'estado',estado),
      principal=coalesce((p_data->>'principal')::boolean,principal),
      api_key=case when p_data ? 'api_key' then nullif(p_data->>'api_key','') else api_key end,
      api_secret=case when p_data ? 'api_secret' then nullif(p_data->>'api_secret','') else api_secret end,
      config=case when p_data ? 'config' then p_data->'config' else config end,
      webhook_url=case when p_data ? 'webhook_url' then nullif(p_data->>'webhook_url','') else webhook_url end,
      updated_at=now()
    where id=p_id;
  else return jsonb_build_object('ok',false,'error','ACTION_NOT_ALLOWED');
  end if;"""
new="""  if v_action='disable' then
    update public.aos_integraciones
      set estado='pendiente',api_key='',api_secret='',config=null,webhook_url=null,cuenta='',updated_at=now()
      where id=p_id;
    update public.aos_integration_secrets_v1
      set api_key='',api_secret='',updated_at=now()
      where integration_id=p_id;
  elsif v_action='update' then
    update public.aos_integraciones set
      cuenta=coalesce(p_data->>'cuenta',cuenta),estado=coalesce(p_data->>'estado',estado),
      principal=coalesce((p_data->>'principal')::boolean,principal),
      api_key='',api_secret='',
      config=case when p_data ? 'config' then p_data->'config' else config end,
      webhook_url=case when p_data ? 'webhook_url' then nullif(p_data->>'webhook_url','') else webhook_url end,
      updated_at=now()
    where id=p_id;
    if p_data ? 'api_key' or p_data ? 'api_secret' then
      insert into public.aos_integration_secrets_v1(integration_id,tipo,nombre,api_key,api_secret,captured_at,updated_at)
      select i.id,i.tipo,i.nombre,
             case when p_data ? 'api_key' then coalesce(p_data->>'api_key','') else '' end,
             case when p_data ? 'api_secret' then coalesce(p_data->>'api_secret','') else '' end,
             now(),now()
      from public.aos_integraciones i where i.id=p_id
      on conflict(integration_id) do update set
        tipo=excluded.tipo,nombre=excluded.nombre,
        api_key=case when p_data ? 'api_key' then excluded.api_key else public.aos_integration_secrets_v1.api_key end,
        api_secret=case when p_data ? 'api_secret' then excluded.api_secret else public.aos_integration_secrets_v1.api_secret end,
        updated_at=now();
    end if;
  else return jsonb_build_object('ok',false,'error','ACTION_NOT_ALLOWED');
  end if;"""
if old in s:
    s=s.replace(old,new,1)
if "api_key=case when p_data ? 'api_key'" in s or "api_secret=case when p_data ? 'api_secret'" in s:
    raise SystemExit('K1-B public integration secret write survived')
if 'insert into public.aos_integration_secrets_v1' not in s or 'update public.aos_integration_secrets_v1' not in s:
    raise SystemExit('K1-B private provider vault admin path missing')
p.write_text(s,encoding='utf-8')

# Synthetic CURRENT boundary: no production rows/secrets.
fixture=ROOT/'ci/kronia-k1-phase2/fixture_pre_k1.sql'
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

# Permanent regression assertions executed by the K1 certificate.
contract=ROOT/'ci/kronia-k1-phase2/runtime_contract.py'
c=contract.read_text(encoding='utf-8')
anchor="k1=(app/'server-k1.js').read_text(); inner=(app/'server.js').read_text(); browser=(app/'public/k1-browser-security.js').read_text()\n"
inject=(
    "migration_a=(root/'supabase/migrations/20260814170000_kronia_k1_private_credentials_auth_v3.sql').read_text()\n"
    "migration_b=(root/'supabase/migrations/20260814171000_kronia_k1_app_token_control_plane.sql').read_text()\n"
    "migration_e=(root/'supabase/migrations/20260814171800_kronia_k1_auth_v3_branded_alignment.sql').read_text()\n"
)
if "migration_a=(root/'supabase/migrations/20260814170000_kronia_k1_private_credentials_auth_v3.sql').read_text()" not in c:
    if anchor not in c:
        raise SystemExit('runtime contract anchor missing')
    c=c.replace(anchor,anchor+inject,1)
else:
    c=c.replace("migration=(root/'supabase/migrations/20260814170000_kronia_k1_private_credentials_auth_v3.sql').read_text()\n",inject)
assert_anchor="assert 'loadResendRuntimeKey' not in k1 and 'aos_integraciones?select=api_key' not in k1\n"
checks=(
    "assert 'from public.aos_integration_secrets_v1 s' in migration_a\n"
    "assert 'select i.api_key into v_api_key from public.aos_integraciones' not in migration_a\n"
    "assert 'from public.aos_integration_secrets_v1 s' in migration_e\n"
    "assert 'select i.api_key into v_api_key' not in migration_e\n"
    "assert 'insert into public.aos_integration_secrets_v1' in migration_b and 'update public.aos_integration_secrets_v1' in migration_b\n"
    "assert \"api_key=case when p_data ? 'api_key'\" not in migration_b and \"api_secret=case when p_data ? 'api_secret'\" not in migration_b\n"
)
# Remove the first-wave assertions if present, then install the complete set once.
c=c.replace("assert 'from public.aos_integration_secrets_v1 s' in migration\nassert 'select i.api_key into v_api_key from public.aos_integraciones' not in migration\n",'')
if checks not in c:
    if assert_anchor not in c:
        raise SystemExit('runtime contract assertion anchor missing')
    c=c.replace(assert_anchor,assert_anchor+checks,1)
contract.write_text(c,encoding='utf-8')

print('KRONIA_K1_PRIVATE_PROVIDER_SECRET_ALIGNMENT=PASS')
