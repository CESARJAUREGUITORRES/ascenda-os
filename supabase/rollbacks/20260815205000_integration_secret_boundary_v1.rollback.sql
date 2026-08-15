-- Fail-closed recovery: do NOT restore secrets to aos_integraciones and do NOT restore permissive policies.
begin;
-- Keep vault, FORCE RLS, sanitized public catalog and sanitized policies intact.
-- Runtime can fall back to provider-specific environment variables if vault reads are unavailable.
update public.aos_integraciones set api_key='',api_secret='' where coalesce(api_key,'')<>'' or coalesce(api_secret,'')<>'';
commit;
