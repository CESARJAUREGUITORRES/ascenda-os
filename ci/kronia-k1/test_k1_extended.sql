\set ON_ERROR_STOP on

-- Auth primitives and compatibility claims must not be browser-callable.
DO $$
begin
  if has_function_privilege('anon','public.aos_login_v2(text,text)','EXECUTE') then
    raise exception 'K1-37 raw login primitive executable by anon';
  end if;
  if has_function_privilege('authenticated','public.aos_verificar_2fa(text,text)','EXECUTE') then
    raise exception 'K1-38 raw 2FA primitive executable by authenticated';
  end if;
  if has_function_privilege('anon','public.aos_kronia_claim_verified_2fa(text,text,text,text,text)','EXECUTE') then
    raise exception 'K1-39 extension compatibility claim browser-callable';
  end if;

  if has_function_privilege('anon','public.aos_kronia_claim_session(text,text,text,text,text,text)','EXECUTE') then
    raise exception 'K1-45 session claim browser-callable';
  end if;
  if has_function_privilege('authenticated','public.aos_kronia_claim_session(text,text,text,text,text,text)','EXECUTE') then
    raise exception 'K1-46 session claim authenticated-browser-callable';
  end if;
  if has_function_privilege('anon','public.aos_kronia_verify_token(text)','EXECUTE') then
    raise exception 'K1-47 token verifier browser-callable';
  end if;
  if has_function_privilege('anon','public.aos_kronia_revocar_token(text)','EXECUTE') then
    raise exception 'K1-48 token revoker browser-callable';
  end if;
  if not has_function_privilege('service_role','public.aos_kronia_claim_session(text,text,text,text,text,text)','EXECUTE') then
    raise exception 'K1-49 service role cannot issue sessions';
  end if;
  if not has_function_privilege('service_role','public.aos_kronia_verify_token(text)','EXECUTE') then
    raise exception 'K1-50 service role cannot verify sessions';
  end if;
  if not has_function_privilege('anon','public.aos_kronia_tool(text,text,jsonb)','EXECUTE') then
    raise exception 'K1-51 token-bound business gateway unavailable to browser';
  end if;
end $$;

-- Narrow Integration admin gateway: invalid token denied, advisor denied, ADMIN accepted.
insert into public.aos_rrhh(codigo_asesor,nombre,puesto,sede,usuario,password_hash,estado)
values
 ('A010','Carol Admin','Administradora','SAN ISIDRO','carol','pw-carol','ACTIVO'),
 ('A011','Dave Advisor','Asesor','PUEBLO LIBRE','dave','pw-dave','ACTIVO');
insert into public.aos_usuarios(nombre,email,rol,cargo,sede,activo,two_factor,codigo_asesor)
values
 ('Carol Admin','carol@example.test','ADMIN','Administradora','SAN ISIDRO',true,false,'A010'),
 ('Dave Advisor','dave@example.test','ASESOR','Asesor','PUEBLO LIBRE',true,false,'A011');

DO $$
declare
  admin_token text;
  advisor_token text;
  integration_id uuid;
  j jsonb;
  current_state text;
  current_key text;
begin
  select id into integration_id from public.aos_integraciones limit 1;

  j := public.aos_kronia_admin_desactivar_integracion('invalid-token',integration_id);
  if coalesce((j->>'ok')::boolean,true) then
    raise exception 'K1-40 integration admin gateway accepts invalid token';
  end if;

  advisor_token := public.aos_kronia_claim_session('dave','pw-dave',null,'ci',null,'web')->>'token';
  j := public.aos_kronia_admin_desactivar_integracion(advisor_token,integration_id);
  if coalesce((j->>'ok')::boolean,true) then
    raise exception 'K1-41 advisor can disable integration';
  end if;

  admin_token := public.aos_kronia_claim_session('carol','pw-carol',null,'ci',null,'web')->>'token';
  j := public.aos_kronia_admin_desactivar_integracion(admin_token,integration_id);
  if coalesce((j->>'ok')::boolean,false)=false then
    raise exception 'K1-42 admin integration gateway failed: %', j;
  end if;

  select estado,api_key into current_state,current_key
  from public.aos_integraciones where id=integration_id;
  if current_state <> 'pendiente' or current_key is not null then
    raise exception 'K1-43 integration secret/state not cleared by admin gateway';
  end if;

  if not exists (
    select 1 from public.aos_kronia_acciones
    where accion='integration_disable' and objeto_id=integration_id::text and exitoso=true
  ) then
    raise exception 'K1-44 integration admin action missing authoritative audit';
  end if;
end $$;

select 'KRONIA_K1_EXTENDED_CERTIFICATE=PASS' as certificate;
