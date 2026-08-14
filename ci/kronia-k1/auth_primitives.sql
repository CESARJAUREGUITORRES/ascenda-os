\set ON_ERROR_STOP on

-- Production-shaped auth primitive signatures needed by K1 revocation tests.
-- The real implementations remain production-owned; these fixtures intentionally
-- expose only the contract needed to prove browser EXECUTE is removed.
-- Return types intentionally mirror live production: json (not jsonb).
create or replace function public.aos_login_v2(p_usuario text, p_password text)
returns json
language sql
security definer
as $$ select json_build_object('ok',false,'fixture',true) $$;

create or replace function public.aos_verificar_2fa(p_usuario text, p_codigo text)
returns json
language sql
security definer
as $$ select json_build_object('ok',false,'fixture',true) $$;

grant execute on function public.aos_login_v2(text,text) to anon,authenticated;
grant execute on function public.aos_verificar_2fa(text,text) to anon,authenticated;
