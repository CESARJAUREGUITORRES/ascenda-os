-- K1 — Authoritative role derivation + 2FA subject compatibility.
-- Final identity closure: ADMIN authority may only come from canonical
-- aos_usuarios rol=admin + nivel_jerarquia 1/2, never free-form cargo/puesto.
-- 2FA verification accepts either login username or canonical employee name.

begin;

-- Normalize any inconsistent legacy ADMIN role outside privileged levels.
update public.aos_usuarios
set rol='asesor',updated_at=now()
where lower(coalesce(rol,''))='admin'
  and coalesce(nivel_jerarquia,99) not in (1,2);

create or replace function public.aos_k1_guard_admin_role()
returns trigger
language plpgsql
security definer
set search_path='pg_catalog'
as $function$
begin
  if lower(coalesce(new.rol,''))='admin' and coalesce(new.nivel_jerarquia,99) not in (1,2) then
    raise exception 'K1_ADMIN_ROLE_REQUIRES_PRIVILEGED_LEVEL';
  end if;
  return new;
end;
$function$;
revoke all on function public.aos_k1_guard_admin_role() from public,anon,authenticated;
drop trigger if exists trg_k1_guard_admin_role on public.aos_usuarios;
create trigger trg_k1_guard_admin_role
before insert or update of rol,nivel_jerarquia on public.aos_usuarios
for each row execute function public.aos_k1_guard_admin_role();

-- Resolve p_usuario safely whether caller supplies username or the canonical
-- full-name subject historically stored in aos_auth_codes.usuario.
create or replace function public.aos_verificar_2fa(p_usuario text,p_codigo text)
returns json
language plpgsql
security definer
set search_path='pg_catalog'
as $function$
declare
  v_auth public.aos_auth_codes%rowtype;
  v_user public.aos_rrhh%rowtype;
  v_udata public.aos_usuarios%rowtype;
  v_paneles text[];
  v_subject text;
begin
  select r.nombre into v_subject
  from public.aos_rrhh r
  where r.estado='ACTIVO'
    and (lower(r.usuario)=lower(trim(coalesce(p_usuario,''))) or upper(r.nombre)=upper(trim(coalesce(p_usuario,''))))
  order by case when lower(r.usuario)=lower(trim(coalesce(p_usuario,''))) then 0 else 1 end
  limit 1;

  if v_subject is null then
    insert into public.aos_security_log(usuario,accion,detalles)
    values(p_usuario,'2fa_failed',jsonb_build_object('reason','subject_not_found'));
    return json_build_object('ok',false,'error','Código incorrecto o expirado');
  end if;

  with candidate as (
    select id
    from public.aos_auth_codes
    where upper(usuario)=upper(v_subject)
      and codigo=p_codigo
      and usado=false
      and expira_at>now()
    order by created_at desc
    for update skip locked
    limit 1
  )
  update public.aos_auth_codes a
  set usado=true
  from candidate c
  where a.id=c.id and a.usado=false
  returning a.* into v_auth;

  if v_auth.id is null then
    insert into public.aos_security_log(usuario,accion,detalles)
    values(v_subject,'2fa_failed',jsonb_build_object('reason','invalid_expired_used_or_concurrent'));
    return json_build_object('ok',false,'error','Código incorrecto o expirado');
  end if;

  select * into v_user from public.aos_rrhh
  where upper(nombre)=upper(v_subject) and estado='ACTIVO' limit 1;
  if v_user.codigo_asesor is null then
    return json_build_object('ok',false,'error','Usuario activo no encontrado');
  end if;
  select * into v_udata from public.aos_usuarios
  where codigo_asesor=v_user.codigo_asesor and activo=true limit 1;
  if v_udata.id is null then
    return json_build_object('ok',false,'error','Identidad activa no encontrada');
  end if;
  v_paneles:=coalesce(v_udata.paneles_acceso,array[]::text[]);

  insert into public.aos_security_log(usuario,accion,detalles)
  values(v_subject,'login',jsonb_build_object('method','2fa_email','atomic',true));

  return json_build_object(
    'ok',true,'codigo_asesor',v_user.codigo_asesor,'nombre',v_user.nombre,
    'apellido',coalesce(v_user.apellido,v_udata.cargo),'puesto',coalesce(v_udata.cargo,v_user.puesto),
    'sede',v_user.sede,'usuario',v_user.usuario,'permisos',coalesce(v_user.permisos,'{}'::jsonb),
    'paneles_acceso',to_json(v_paneles),'avatar_url',v_udata.avatar_url,'nivel',v_udata.nivel_jerarquia,
    'area',v_udata.area,'acceso_geo',v_udata.acceso_geo,
    'sedes_permitidas',to_json(coalesce(v_udata.sedes_permitidas,array[]::text[]))
  );
end;
$function$;
revoke all on function public.aos_verificar_2fa(text,text) from public,anon,authenticated;
grant execute on function public.aos_verificar_2fa(text,text) to service_role;

-- Final K1 session claim: live active identity, private bcrypt proof, canonical
-- role derivation, and mandatory 2FA proof for every privileged ADMIN session.
create or replace function public.aos_kronia_claim_session(
  p_login_usuario text,p_password text,p_2fa_codigo text default null,
  p_device_info text default null,p_ip_origen text default null,p_origen text default 'web'
) returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','extensions'
as $function$
declare
  v_rr public.aos_rrhh%rowtype;
  v_u public.aos_usuarios%rowtype;
  v_code public.aos_auth_codes%rowtype;
  v_token text;
  v_digest text;
  v_exp timestamptz;
  v_role text;
  v_user_key text;
begin
  if nullif(trim(coalesce(p_login_usuario,'')),'') is null or coalesce(length(p_password),0)<1 then
    return jsonb_build_object('ok',false,'error','INVALID_CREDENTIALS');
  end if;
  select r.* into v_rr from public.aos_rrhh r
  where lower(r.usuario)=lower(trim(p_login_usuario)) and upper(coalesce(r.estado,''))='ACTIVO' limit 1;
  if v_rr.codigo_asesor is null or not public.aos_auth_password_matches(v_rr.codigo_asesor,p_password) then
    return jsonb_build_object('ok',false,'error','INVALID_CREDENTIALS');
  end if;
  select u.* into v_u from public.aos_usuarios u
  where u.codigo_asesor=v_rr.codigo_asesor and u.activo=true limit 1;
  if v_u.id is null then return jsonb_build_object('ok',false,'error','IDENTITY_NOT_ACTIVE'); end if;

  v_role:=case when lower(coalesce(v_u.rol,''))='admin' and coalesce(v_u.nivel_jerarquia,99) in (1,2)
               then 'ADMIN' else 'ASESOR' end;

  if v_role='ADMIN' and not coalesce(v_u.two_factor,false) then
    return jsonb_build_object('ok',false,'error','ADMIN_TWO_FACTOR_REQUIRED');
  end if;

  if coalesce(v_u.two_factor,false) then
    if nullif(trim(coalesce(p_2fa_codigo,'')),'') is null then
      return jsonb_build_object('ok',false,'error','TWO_FACTOR_REQUIRED');
    end if;
    select a.* into v_code from public.aos_auth_codes a
    where upper(a.usuario)=upper(v_rr.nombre) and a.codigo=p_2fa_codigo and a.usado=true
      and a.expira_at>now() and a.created_at>now()-interval '15 minutes'
      and a.kronia_claimed_at is null
    order by a.created_at desc limit 1 for update;
    if v_code.id is null then return jsonb_build_object('ok',false,'error','TWO_FACTOR_PROOF_INVALID'); end if;
    update public.aos_auth_codes set kronia_claimed_at=now()
    where id=v_code.id and kronia_claimed_at is null;
    if not found then return jsonb_build_object('ok',false,'error','TWO_FACTOR_PROOF_REPLAYED'); end if;
  end if;

  v_user_key:=coalesce(nullif(v_rr.usuario,''),v_rr.nombre);
  v_token:=encode(extensions.gen_random_bytes(32),'hex');
  v_digest:=encode(extensions.digest(v_token,'sha256'),'hex');
  v_exp:=now()+interval '8 hours';
  update public.aos_kronia_tokens set revocado=true
  where lower(usuario)=lower(v_user_key) and not revocado;
  insert into public.aos_kronia_tokens(token,usuario,id_asesor,rol,sede,email,device_info,ip_origen,expira_at,origen)
  values(v_digest,v_user_key,v_rr.codigo_asesor,v_role,v_rr.sede,v_u.email,p_device_info,p_ip_origen,v_exp,coalesce(nullif(p_origen,''),'web'));
  return jsonb_build_object('ok',true,'token',v_token,'usuario',v_user_key,'id_asesor',v_rr.codigo_asesor,
    'rol',v_role,'sede',v_rr.sede,'email',v_u.email,'expira_at',v_exp);
end;
$function$;
revoke all on function public.aos_kronia_claim_session(text,text,text,text,text,text) from public,anon,authenticated;
grant execute on function public.aos_kronia_claim_session(text,text,text,text,text,text) to service_role;

-- Final verifier re-derives ADMIN from the same canonical fields. Role/cargo/
-- puesto strings outside that contract cannot elevate an existing token.
create or replace function public.aos_kronia_verify_token(p_token text)
returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','extensions'
as $function$
declare
  v_row public.aos_kronia_tokens%rowtype;
  v_rr public.aos_rrhh%rowtype;
  v_u public.aos_usuarios%rowtype;
  v_digest text;
  v_role_now text;
begin
  if p_token is null or length(p_token)<32 then return jsonb_build_object('ok',false,'error','Token invalido'); end if;
  v_digest:=encode(extensions.digest(p_token,'sha256'),'hex');
  select * into v_row from public.aos_kronia_tokens where token=v_digest limit 1;
  if v_row.id is null or v_row.revocado or v_row.expira_at<now() then return jsonb_build_object('ok',false,'error','Sesion invalida o expirada'); end if;
  select * into v_rr from public.aos_rrhh where codigo_asesor=v_row.id_asesor and upper(coalesce(estado,''))='ACTIVO' limit 1;
  select * into v_u from public.aos_usuarios where codigo_asesor=v_row.id_asesor and activo=true limit 1;
  if v_rr.codigo_asesor is null or v_u.id is null then
    update public.aos_kronia_tokens set revocado=true where id=v_row.id;
    return jsonb_build_object('ok',false,'error','IDENTITY_NOT_ACTIVE');
  end if;
  v_role_now:=case when lower(coalesce(v_u.rol,''))='admin' and coalesce(v_u.nivel_jerarquia,99) in (1,2)
                   then 'ADMIN' else 'ASESOR' end;
  if v_role_now<>v_row.rol then
    update public.aos_kronia_tokens set revocado=true where id=v_row.id;
    return jsonb_build_object('ok',false,'error','ROLE_CHANGED');
  end if;
  if v_role_now='ADMIN' and not coalesce(v_u.two_factor,false) then
    update public.aos_kronia_tokens set revocado=true where id=v_row.id;
    return jsonb_build_object('ok',false,'error','ADMIN_TWO_FACTOR_REQUIRED');
  end if;
  update public.aos_kronia_tokens set ultimo_uso=now() where id=v_row.id;
  return jsonb_build_object('ok',true,'usuario',v_row.usuario,'id_asesor',v_row.id_asesor,
    'rol',v_role_now,'sede',v_rr.sede,'email',v_u.email,'expira_at',v_row.expira_at);
end;
$function$;
revoke all on function public.aos_kronia_verify_token(text) from public,anon,authenticated;
grant execute on function public.aos_kronia_verify_token(text) to service_role;

commit;
