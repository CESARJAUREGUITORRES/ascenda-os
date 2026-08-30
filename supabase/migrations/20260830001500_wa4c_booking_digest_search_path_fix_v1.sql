-- WA-4C governed booking runtime correction.
-- pgcrypto is installed in schema extensions in Supabase; the original SECURITY DEFINER
-- function used search_path=public, so unqualified digest(...) could not resolve at runtime.
-- Keep the boundary restrictive while explicitly making the extension schema resolvable.
begin;

alter function public.aos_wa4_commit_booking_v1(uuid,text,uuid,jsonb)
  set search_path = 'pg_catalog', 'public', 'extensions', 'pg_temp';

comment on function public.aos_wa4_commit_booking_v1(uuid,text,uuid,jsonb) is
'WA-4C HUMAN_ONLY transactional booking commit: ownership, identity, role, fresh schedule, slot revalidation and idempotency. SECURITY DEFINER search_path hardened with pgcrypto extensions resolution; does not send WhatsApp or fabricate Call Center calls.';

commit;
