-- P0 #457 bounded certification status rollback.
-- Removes only additive v2 safety readback surfaces and restores legacy comments.

begin;

drop function if exists public.aos_wa_l9_safety_status_v2();
drop function if exists public.aos_wa_l8_safety_status_v2();

comment on function public.aos_wa_l8_security_status_v1() is
  'WA-L8 security/readback surface. Includes audit counts; no raw PII or message bodies are returned.';
comment on function public.aos_wa_l9_status_v1() is
  'WA-L9 shadow/demo status surface.';

select pg_catalog.pg_notify('pgrst','reload schema');
commit;
