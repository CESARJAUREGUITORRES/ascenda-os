-- K1 canonical closure.
-- Makes the release migration self-sufficient: no CI-only privilege or
-- SECURITY DEFINER search-path correction is required.

-- SECURITY DEFINER functions may use pgcrypto but must never search public.
alter function public.aos_kronia_claim_session(text,text,text,text,text,text)
  set search_path = 'pg_catalog', 'extensions';
alter function public.aos_kronia_verify_token(text)
  set search_path = 'pg_catalog', 'extensions';
alter function public.aos_kronia_revocar_token(text)
  set search_path = 'pg_catalog', 'extensions';
alter function public.aos_kronia_claim_verified_2fa(text,text,text,text,text)
  set search_path = 'pg_catalog', 'extensions';

-- Raw authentication primitives are server-only. Explicitly revoke every
-- browser path instead of relying only on PUBLIC ACL inheritance.
revoke all on function public.aos_login_v2(text,text)
  from public, anon, authenticated;
revoke all on function public.aos_verificar_2fa(text,text)
  from public, anon, authenticated;
grant execute on function public.aos_login_v2(text,text) to service_role;
grant execute on function public.aos_verificar_2fa(text,text) to service_role;

-- Chrome compatibility claim is likewise server-only.
revoke all on function public.aos_kronia_claim_verified_2fa(text,text,text,text,text)
  from public, anon, authenticated;
grant execute on function public.aos_kronia_claim_verified_2fa(text,text,text,text,text)
  to service_role;

-- `url_api` is non-secret integration metadata used by configuration UI.
-- Credential/config/webhook columns remain revoked.
grant select(url_api) on public.aos_integraciones to anon, authenticated;

comment on function public.aos_kronia_claim_session(text,text,text,text,text,text) is
'K1 authoritative session claim. SECURITY DEFINER search path restricted to pg_catalog/extensions; identity/role/sede derived server-side.';
