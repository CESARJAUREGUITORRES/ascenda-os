-- Minimal auth signatures required by security-only migrations in isolated CI.
-- No production credentials or data are present here.
-- IMPORTANT: return types mirror the current production contracts exactly.
create or replace function public.aos_login_v2(p_usuario text, p_password text)
returns json language sql security definer
as $$ select json_build_object('ok',false,'fixture',true) $$;

create or replace function public.aos_verificar_2fa(p_usuario text, p_codigo text)
returns json language sql security definer
as $$ select json_build_object('ok',false,'fixture',true) $$;

grant execute on function public.aos_login_v2(text,text) to anon,authenticated;
grant execute on function public.aos_verificar_2fa(text,text) to anon,authenticated;
