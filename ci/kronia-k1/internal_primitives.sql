\set ON_ERROR_STOP on

-- Production-shaped internal read model required by migration 520. The live
-- function is SECURITY INVOKER and returns jsonb; the fixture mirrors only that
-- contract and contains no production data.
create or replace function public.aos_security_dashboard()
returns jsonb
language sql
security invoker
as $$ select jsonb_build_object('ok',true,'fixture',true) $$;

grant execute on function public.aos_security_dashboard() to anon, authenticated, service_role;
