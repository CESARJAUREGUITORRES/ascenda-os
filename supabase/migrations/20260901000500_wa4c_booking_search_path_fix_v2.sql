-- WA-4C governed booking runtime hardening V2.
-- The pool booking migration replaces aos_wa4_commit_booking_v1 and would otherwise
-- reset SECURITY DEFINER search_path to public-only. Supabase pgcrypto lives in extensions.
-- Keep digest/pgcrypto resolvable while preserving an explicit restrictive search path.
begin;

alter function public.aos_wa4_commit_booking_v1(uuid,text,uuid,jsonb)
  set search_path = 'pg_catalog', 'public', 'extensions', 'pg_temp';

comment on function public.aos_wa4_commit_booking_v1(uuid,text,uuid,jsonb) is
'WA-4C HUMAN_ONLY booking commit. Catalog role + Team skill + date/site schedule authority; doctors exact-provider, nursing site-pool. SECURITY DEFINER search_path explicitly includes extensions for pgcrypto digest resolution. No autonomous WhatsApp send.';

commit;
