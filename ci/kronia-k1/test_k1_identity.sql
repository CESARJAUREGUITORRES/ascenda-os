\set ON_ERROR_STOP on

DO $$
declare
  n integer;
  j jsonb;
  alice_token text;
  bob_token text;
  eve_token text;
  level2_token text;
  level2_id uuid;
  alice_id uuid;
  bob_id uuid;
  eve_id uuid;
  new_id uuid;
  temp_pw text;
  new_code text;
  stored_hash text;
  digest_snapshot text;
  digest_live text;
  code_id uuid;
begin
  -- K1-61..65: private credential store and plaintext eradication.
  select count(*) into n from public.aos_auth_credentials;
  if n <> 3 then raise exception 'K1-61 expected 3 migrated synthetic credentials, got %',n; end if;
  if has_table_privilege('anon','public.aos_auth_credentials','SELECT')
     or has_table_privilege('authenticated','public.aos_auth_credentials','SELECT') then
    raise exception 'K1-62/63 private credentials browser-readable';
  end if;
  select count(*) into n from public.aos_auth_credentials
  where password_hash !~ '^\$2[aby]\$[0-9]{2}\$' or length(password_hash) < 59;
  if n<>0 then raise exception 'K1-64 non-bcrypt credential rows=%',n; end if;
  select count(*) into n from public.aos_rrhh where nullif(password_hash,'') is not null;
  if n<>0 then raise exception 'K1-65 plaintext/legacy password material remains in RRHH rows=%',n; end if;

  -- K1-66..68: legacy auth/admin write surface retired.
  if has_function_privilege('anon','public.aos_login(text,text)','EXECUTE') then raise exception 'K1-66 legacy password-only login remains browser-callable'; end if;
  if has_function_privilege('anon','public.aos_admin_cambiar_password(uuid,text)','EXECUTE')
     or has_function_privilege('anon','public.aos_admin_crear_usuario(text,text,text,text,text,text,integer,text,text)','EXECUTE')
     or has_function_privilege('anon','public.aos_admin_cambiar_username(uuid,text)','EXECUTE')
     or has_function_privilege('anon','public.aos_admin_toggle_usuario(uuid,boolean)','EXECUTE')
     or has_function_privilege('anon','public.aos_admin_eliminar_usuario(uuid,text)','EXECUTE') then
    raise exception 'K1-67 legacy ADMIN identity RPC remains browser-callable';
  end if;
  if has_table_privilege('anon','public.aos_rrhh','UPDATE')
     or has_table_privilege('authenticated','public.aos_rrhh','UPDATE')
     or has_table_privilege('anon','public.aos_usuarios','UPDATE') then
    raise exception 'K1-68 direct browser identity write remains';
  end if;

  -- K1-69/70: correct password survives migration; wrong password fails.
  j:=public.aos_kronia_claim_session('alice','alice-pass',null,'ci',null,'web');
  if not coalesce((j->>'ok')::boolean,false) then raise exception 'K1-69 migrated bcrypt credential rejected: %',j; end if;
  alice_token:=j->>'token';
  j:=public.aos_kronia_claim_session('alice','wrong-password',null,'ci',null,'web');
  if coalesce((j->>'ok')::boolean,false) then raise exception 'K1-70 wrong password accepted'; end if;

  select id into alice_id from public.aos_usuarios where codigo_asesor='A001';
  select id into bob_id from public.aos_usuarios where codigo_asesor='A002';
  select id into eve_id from public.aos_usuarios where codigo_asesor='A003';

  -- Browser can call only the hierarchy-safe wrapper; implementation is server-only.
  if not has_function_privilege('anon','public.aos_kronia_admin_identity_safe(text,text,uuid,jsonb)','EXECUTE') then
    raise exception 'K1-71 safe identity gateway unavailable';
  end if;
  if has_function_privilege('anon','public.aos_kronia_admin_identity(text,text,uuid,jsonb)','EXECUTE') then
    raise exception 'K1-72 implementation identity gateway directly browser-callable';
  end if;

  -- Advisor cannot use ADMIN identity gateway.
  bob_token:=public.aos_kronia_claim_session('bob','bob-pass',null,'ci',null,'web')->>'token';
  j:=public.aos_kronia_admin_identity_safe(bob_token,'set_services',bob_id,jsonb_build_object('servicios',jsonb_build_array('TEST')));
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1-73 advisor used ADMIN identity gateway'; end if;

  -- Create a synthetic level-2 ADMIN; it may manage regular users but never owner level 1.
  insert into public.aos_rrhh(codigo_asesor,nombre,apellido,puesto,sede,usuario,password_hash,estado)
  values('A004','Level Two','Admin','ADMIN','SAN ISIDRO','level2',null,'ACTIVO');
  insert into public.aos_usuarios(codigo_asesor,nombre,apellidos,email,rol,cargo,sede,activo,two_factor,nivel_jerarquia)
  values('A004','Level Two','Admin','level2@example.test','admin','Admin','SAN ISIDRO',true,false,2)
  returning id into level2_id;
  perform public.aos_auth_set_password('A004','level2-pass');
  level2_token:=public.aos_kronia_claim_session('level2','level2-pass',null,'ci',null,'web')->>'token';
  j:=public.aos_kronia_admin_identity_safe(level2_token,'change_username',alice_id,jsonb_build_object('username','owner-hijack'));
  if coalesce((j->>'ok')::boolean,true) or j->>'error'<>'OWNER_LEVEL_REQUIRED' then
    raise exception 'K1-74 level-2 ADMIN can mutate owner: %',j;
  end if;

  -- Level-1 ADMIN can execute allowlisted action on regular user; unknown action denied.
  j:=public.aos_kronia_admin_identity_safe(alice_token,'set_services',bob_id,jsonb_build_object('servicios',jsonb_build_array('LASER')));
  if not coalesce((j->>'ok')::boolean,false) then raise exception 'K1-75 owner ADMIN allowlisted action failed: %',j; end if;
  j:=public.aos_kronia_admin_identity_safe(alice_token,'sql_query',bob_id,'{}'::jsonb);
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1-76 unknown identity action accepted'; end if;

  -- Create-user returns temporary password once, but DB stores only bcrypt and
  -- team view preserves tiene_password without exposing the hash.
  j:=public.aos_kronia_admin_identity_safe(alice_token,'create_user',null,
      jsonb_build_object('nombre','New','apellido','User','email','new@example.test','telefono','999999999','cargo','ASESOR','area','ventas','nivel_jerarquia',4,'acceso_geo','limitado','sede','SAN ISIDRO'));
  if not coalesce((j->>'ok')::boolean,false) then raise exception 'K1-77 create_user failed: %',j; end if;
  new_id:=(j->>'user_id')::uuid; temp_pw:=j->>'password'; new_code:=j->>'codigo';
  if coalesce(length(temp_pw),0)<8 or coalesce(new_code,'')='' then raise exception 'K1-78 one-time create credentials missing'; end if;
  select c.password_hash into stored_hash from public.aos_auth_credentials c where c.codigo_asesor=new_code;
  if stored_hash is null or extensions.crypt(temp_pw,stored_hash)<>stored_hash then raise exception 'K1-79 generated temp password not stored as bcrypt'; end if;
  if exists(select 1 from public.aos_rrhh where codigo_asesor=new_code and nullif(password_hash,'') is not null) then raise exception 'K1-80 generated credential leaked to RRHH'; end if;
  if not coalesce((select tiene_password from public.aos_team_full where id=new_id),false) then raise exception 'K1-81 team view lost tiene_password compatibility'; end if;

  -- Sensitive identity changes revoke active target sessions.
  if bob_token is null then raise exception 'K1-82 Bob session setup missing'; end if;
  j:=public.aos_kronia_admin_identity_safe(alice_token,'change_username',bob_id,jsonb_build_object('username','bob.secure'));
  if not coalesce((j->>'ok')::boolean,false) then raise exception 'K1-83 username change failed: %',j; end if;
  if coalesce((public.aos_kronia_verify_token(bob_token)->>'ok')::boolean,false) then raise exception 'K1-84 username change did not revoke target session'; end if;

  eve_token:=public.aos_kronia_claim_session('eve','eve-pass',null,'ci',null,'web')->>'token';
  j:=public.aos_kronia_admin_identity_safe(alice_token,'toggle_active',eve_id,jsonb_build_object('enabled',false));
  if not coalesce((j->>'ok')::boolean,false) then raise exception 'K1-85 deactivation failed: %',j; end if;
  if coalesce((public.aos_kronia_verify_token(eve_token)->>'ok')::boolean,false) then raise exception 'K1-86 deactivation did not revoke target session'; end if;

  -- Password reset produces a new bcrypt hash and old credential stops matching.
  j:=public.aos_kronia_admin_identity_safe(alice_token,'change_password',bob_id,jsonb_build_object('password','bob-new-pass-2026'));
  if not coalesce((j->>'ok')::boolean,false) then raise exception 'K1-87 password change failed: %',j; end if;
  if public.aos_auth_password_matches('A002','bob-pass') then raise exception 'K1-88 old password still matches after reset'; end if;
  if not public.aos_auth_password_matches('A002','bob-new-pass-2026') then raise exception 'K1-89 new password does not match'; end if;
  if exists(select 1 from public.aos_rrhh where codigo_asesor='A002' and nullif(password_hash,'') is not null) then raise exception 'K1-90 password reset repopulated RRHH secret'; end if;

  -- Sales Intelligence snapshots the private bcrypt hash, not plaintext.
  select sia.password_digest into digest_snapshot from public.aos_sales_intelligence_access sia where sia.user_id=alice_id;
  select encode(extensions.digest(c.password_hash,'sha256'),'hex') into digest_live from public.aos_auth_credentials c where c.codigo_asesor='A001';
  if digest_snapshot is distinct from digest_live then raise exception 'K1-91 Sales Intelligence credential snapshot not aligned to private bcrypt'; end if;

  -- SI claim remains compatible with a used, valid 2FA proof.
  update public.aos_usuarios set two_factor=true,paneles_acceso=array_append(coalesce(paneles_acceso,'{}'::text[]),'admin-sales-intelligence') where id=alice_id;
  insert into public.aos_auth_codes(usuario,email,codigo,expira_at,usado)
  values('Alice Admin','alice@example.test','654321',now()+interval '10 minutes',true)
  returning id into code_id;
  j:=public.aos_sales_intelligence_claim_session('alice','alice-pass','Alice Admin','654321');
  if not coalesce((j->>'ok')::boolean,false) then raise exception 'K1-92 Sales Intelligence bcrypt/2FA compatibility failed: %',j; end if;
end $$;

select 'KRONIA_K1_IDENTITY_CERTIFICATE=PASS' as certificate;
