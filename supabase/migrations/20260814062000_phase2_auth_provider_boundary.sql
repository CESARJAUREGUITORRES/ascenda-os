-- ASCENDA OS — Phase 2 auth provider boundary.
-- The v3 login issuer is SECURITY DEFINER and can read the Resend integration,
-- while browser/anon traffic must not read or mutate that credential.

begin;

alter table public.aos_integraciones enable row level security;

drop policy if exists anon_integ_read on public.aos_integraciones;
drop policy if exists anon_integ_write on public.aos_integraciones;

drop policy if exists anon_integ_read_non_auth_provider on public.aos_integraciones;
create policy anon_integ_read_non_auth_provider
on public.aos_integraciones
for select
to anon
using (
  lower(coalesce(tipo,'')) <> 'resend'
  and lower(coalesce(nombre,'')) not like '%resend%'
);

drop policy if exists anon_integ_write_non_auth_provider on public.aos_integraciones;
create policy anon_integ_write_non_auth_provider
on public.aos_integraciones
for all
to anon
using (
  lower(coalesce(tipo,'')) <> 'resend'
  and lower(coalesce(nombre,'')) not like '%resend%'
)
with check (
  lower(coalesce(tipo,'')) <> 'resend'
  and lower(coalesce(nombre,'')) not like '%resend%'
);

comment on table public.aos_integraciones is
'Integration registry. Phase 2 blocks anon read/write access to the Resend auth-provider row; remaining legacy integration ACLs require a separate global secrets migration.';

commit;
