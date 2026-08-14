\set ON_ERROR_STOP on

DO $$
declare
  owner_id uuid;
  level2_id uuid;
  owner_token text;
  level2_token text;
  j jsonb;
  v text;
begin
  -- K1-93..95: config table is read-only to browser and 2FA is forced ON.
  if has_table_privilege('anon','public.aos_configuracion','UPDATE')
     or has_table_privilege('authenticated','public.aos_configuracion','UPDATE')
     or has_table_privilege('anon','public.aos_configuracion','INSERT')
     or has_table_privilege('anon','public.aos_configuracion','DELETE') then
    raise exception 'K1-93 browser can mutate security configuration';
  end if;
  select valor into v from public.aos_configuracion where clave='seg_2fa_habilitado';
  if lower(coalesce(v,''))<>'true' then raise exception 'K1-94 global 2FA not forced true'; end if;
  if not has_function_privilege('anon','public.aos_kronia_admin_config_safe(text,text,text)','EXECUTE') then
    raise exception 'K1-95 safe config gateway unavailable to browser';
  end if;

  -- Build owner session without depending on a previous test's session state.
  select id into owner_id from public.aos_usuarios where codigo_asesor='A001';
  update public.aos_usuarios set two_factor=false,activo=true,nivel_jerarquia=1,rol='admin' where id=owner_id;
  owner_token:=public.aos_kronia_claim_session('alice','alice-pass',null,'ci-config',null,'web')->>'token';
  if owner_token is null then raise exception 'K1-96 owner session setup failed'; end if;

  -- Level-2 admin from identity test may exist; create it idempotently if needed.
  select id into level2_id from public.aos_usuarios where codigo_asesor='A004';
  if level2_id is null then
    insert into public.aos_rrhh(codigo_asesor,nombre,apellido,puesto,sede,usuario,password_hash,estado)
    values('A004','Level Two','Admin','ADMIN','SAN ISIDRO','level2',null,'ACTIVO');
    insert into public.aos_usuarios(codigo_asesor,nombre,apellidos,email,rol,cargo,sede,activo,two_factor,nivel_jerarquia)
    values('A004','Level Two','Admin','level2@example.test','admin','Admin','SAN ISIDRO',true,false,2)
    returning id into level2_id;
    perform public.aos_auth_set_password('A004','level2-pass');
  else
    update public.aos_usuarios set activo=true,two_factor=false,nivel_jerarquia=2,rol='admin' where id=level2_id;
  end if;
  level2_token:=public.aos_kronia_claim_session('level2','level2-pass',null,'ci-config',null,'web')->>'token';

  -- Security policy knobs are owner-only.
  j:=public.aos_kronia_admin_config_safe(level2_token,'max_intentos_login','6');
  if coalesce((j->>'ok')::boolean,true) or j->>'error'<>'OWNER_LEVEL_REQUIRED' then
    raise exception 'K1-97 level-2 admin changed owner-only security knob: %',j;
  end if;

  -- 2FA cannot be disabled even by owner.
  j:=public.aos_kronia_admin_config_safe(owner_token,'seg_2fa_habilitado','false');
  if coalesce((j->>'ok')::boolean,true) or j->>'error'<>'TWO_FACTOR_CANNOT_BE_DISABLED' then
    raise exception 'K1-98 owner could disable global 2FA: %',j;
  end if;

  -- Allowed values/ranges work and unknown keys fail closed.
  j:=public.aos_kronia_admin_config_safe(owner_token,'max_intentos_login','6');
  if not coalesce((j->>'ok')::boolean,false) then raise exception 'K1-99 valid owner config update failed: %',j; end if;
  select valor into v from public.aos_configuracion where clave='max_intentos_login';
  if v<>'6' then raise exception 'K1-100 config value not persisted through gateway'; end if;

  j:=public.aos_kronia_admin_config_safe(owner_token,'max_intentos_login','999');
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1-101 out-of-range security value accepted'; end if;
  j:=public.aos_kronia_admin_config_safe(owner_token,'made_up_key','x');
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1-102 unknown config key accepted'; end if;
end $$;

select 'KRONIA_K1_CONFIG_CERTIFICATE=PASS' as certificate;
