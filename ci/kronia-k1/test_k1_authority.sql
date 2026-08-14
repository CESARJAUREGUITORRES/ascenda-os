\set ON_ERROR_STOP on

DO $$
declare
  alice_id uuid;
  bob_id uuid;
  level2_id uuid;
  admin_token text;
  level2_token text;
  j jsonb;
  code text := '771234';
  blocked boolean;
begin
  select id into alice_id from public.aos_usuarios where codigo_asesor='A001';
  select id into bob_id from public.aos_usuarios where codigo_asesor='A002';

  -- K1-106: free-form cargo/puesto cannot elevate a regular identity.
  update public.aos_usuarios set rol='asesor',nivel_jerarquia=4,cargo='ADMINISTRADOR',two_factor=false where id=bob_id;
  update public.aos_rrhh set puesto='ADMINISTRADOR' where codigo_asesor='A002';
  j:=public.aos_kronia_claim_session('bob','bob-pass',null,'ci-authority',null,'ci');
  if not coalesce((j->>'ok')::boolean,false) or j->>'rol'<>'ASESOR' then
    raise exception 'K1-106 free-form cargo/puesto elevated authority: %',j;
  end if;

  -- K1-107: DB invariant blocks role=admin outside privileged hierarchy.
  blocked:=false;
  begin
    update public.aos_usuarios set rol='admin' where id=bob_id;
  exception when others then blocked:=true;
  end;
  if not blocked then raise exception 'K1-107 ordinary level accepted ADMIN role'; end if;

  -- K1-108: privileged ADMIN session requires user-level 2FA enrollment.
  update public.aos_usuarios set rol='admin',nivel_jerarquia=1,two_factor=false where id=alice_id;
  j:=public.aos_kronia_claim_session('alice','alice-pass',null,'ci-authority',null,'ci');
  if coalesce((j->>'ok')::boolean,true) or j->>'error'<>'ADMIN_TWO_FACTOR_REQUIRED' then
    raise exception 'K1-108 ADMIN without 2FA obtained/approached session: %',j;
  end if;

  -- K1-109/110: verifier safely accepts username, resolves canonical 2FA subject,
  -- and consumes the OTP only once.
  update public.aos_usuarios set two_factor=true where id=alice_id;
  insert into public.aos_auth_codes(usuario,email,codigo,expira_at,usado)
  values('Alice Admin','alice@example.test',code,now()+interval '10 minutes',false);
  j:=public.aos_verificar_2fa('alice',code);
  if not coalesce((j->>'ok')::boolean,false) then raise exception 'K1-109 username-to-2FA-subject verification failed: %',j; end if;
  j:=public.aos_verificar_2fa('alice',code);
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1-110 consumed OTP replay succeeded'; end if;

  admin_token:=public.k1_ci_claim_token('alice','alice-pass');
  if (public.aos_kronia_verify_token(admin_token)->>'rol')<>'ADMIN' then
    raise exception 'K1-111 canonical owner token not ADMIN';
  end if;

  -- Build a level-2 ADMIN with valid 2FA proof.
  select id into level2_id from public.aos_usuarios where codigo_asesor='A004';
  if level2_id is null then
    insert into public.aos_rrhh(codigo_asesor,nombre,apellido,puesto,sede,usuario,password_hash,estado)
    values('A004','Level Two','Admin','ADMIN','SAN ISIDRO','level2',null,'ACTIVO');
    insert into public.aos_usuarios(codigo_asesor,nombre,apellidos,email,rol,cargo,sede,activo,two_factor,nivel_jerarquia)
    values('A004','Level Two','Admin','level2@example.test','admin','Admin','SAN ISIDRO',true,true,2)
    returning id into level2_id;
    perform public.aos_auth_set_password('A004','level2-pass');
  else
    update public.aos_usuarios set rol='admin',nivel_jerarquia=2,two_factor=true,activo=true where id=level2_id;
  end if;
  level2_token:=public.k1_ci_claim_token('level2','level2-pass');

  -- K1-112: level-2 cannot create another privileged ADMIN.
  j:=public.aos_kronia_admin_identity_safe(level2_token,'create_user',null,
      jsonb_build_object('nombre','Peer','apellido','Admin','email','peer@example.test','nivel_jerarquia',2,'cargo','ADMIN','area','general','acceso_geo','limitado','sede','SAN ISIDRO'));
  if coalesce((j->>'ok')::boolean,true) or j->>'error'<>'OWNER_LEVEL_REQUIRED' then
    raise exception 'K1-112 level-2 created privileged identity: %',j;
  end if;

  -- K1-113: attempting role=admin on an ordinary target cannot bypass hierarchy.
  j:=public.aos_kronia_admin_identity_safe(admin_token,'update_profile',bob_id,
      jsonb_build_object('rol','admin','nivel_jerarquia',4));
  if coalesce((j->>'ok')::boolean,false) then
    if exists(select 1 from public.aos_usuarios where id=bob_id and lower(coalesce(rol,''))='admin') then
      raise exception 'K1-113 ordinary identity was promoted via free-form role';
    end if;
  end if;

  -- K1-114: changing the canonical role invalidates an existing ADMIN token.
  update public.aos_usuarios set rol='asesor' where id=alice_id;
  j:=public.aos_kronia_verify_token(admin_token);
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1-114 role-changed ADMIN token remained valid'; end if;
  update public.aos_usuarios set rol='admin',nivel_jerarquia=1,two_factor=true where id=alice_id;
end $$;

select 'KRONIA_K1_AUTHORITY_CERTIFICATE=PASS' as certificate;
