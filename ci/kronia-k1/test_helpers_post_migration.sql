\set ON_ERROR_STOP on

-- CI-only helper. Never shipped as a production migration. It creates a used,
-- valid synthetic OTP proof for an existing synthetic user and then exercises
-- the REAL K1 session claim. This keeps tests honest once ADMIN sessions require
-- 2FA instead of disabling the factor in fixtures.
--
-- Normalize synthetic passwords only AFTER migration 521 moved credentials into
-- aos_auth_credentials. No plaintext credential is written back to aos_rrhh.
select public.aos_auth_set_password('A001','alice-pass');
select public.aos_auth_set_password('A002','eve-pass');
select public.aos_auth_set_password('A003','bob-pass');

create or replace function public.k1_ci_claim_token(p_login text,p_password text)
returns text
language plpgsql
security definer
set search_path='pg_catalog'
as $$
declare
  v_rr public.aos_rrhh%rowtype;
  v_u public.aos_usuarios%rowtype;
  v_code text;
  v_result jsonb;
begin
  select * into v_rr from public.aos_rrhh where lower(usuario)=lower(p_login) and estado='ACTIVO' limit 1;
  if v_rr.codigo_asesor is null then raise exception 'CI_LOGIN_NOT_FOUND %',p_login; end if;
  select * into v_u from public.aos_usuarios where codigo_asesor=v_rr.codigo_asesor and activo=true limit 1;
  if v_u.id is null then raise exception 'CI_IDENTITY_NOT_FOUND %',p_login; end if;

  if lower(coalesce(v_u.rol,''))='admin' and coalesce(v_u.nivel_jerarquia,99) in (1,2) then
    update public.aos_usuarios set two_factor=true where id=v_u.id;
  end if;

  if coalesce((select two_factor from public.aos_usuarios where id=v_u.id),false) then
    v_code:=lpad((100000+floor(random()*899999))::int::text,6,'0');
    insert into public.aos_auth_codes(usuario,email,codigo,expira_at,usado)
    values(v_rr.nombre,coalesce(v_u.email,'ci@example.test'),v_code,now()+interval '10 minutes',true);
    v_result:=public.aos_kronia_claim_session(p_login,p_password,v_code,'ci-helper',null,'ci');
  else
    v_result:=public.aos_kronia_claim_session(p_login,p_password,null,'ci-helper',null,'ci');
  end if;

  if not coalesce((v_result->>'ok')::boolean,false) then
    raise exception 'CI_TOKEN_CLAIM_FAILED %',v_result;
  end if;
  return v_result->>'token';
end;
$$;
