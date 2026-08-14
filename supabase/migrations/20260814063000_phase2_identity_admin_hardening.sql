-- ASCENDA OS — Phase 2 identity administration hardening.
-- Replaces unauthenticated legacy login/user/password RPCs with strong app-token gates.

begin;

create or replace function public.aos_admin_crear_usuario_v3(
  p_token text,
  p_nombre text,
  p_apellido text,
  p_email text default '',
  p_telefono text default '',
  p_cargo text default 'ASESOR',
  p_area text default 'enfermería',
  p_nivel_jerarquia integer default 3,
  p_acceso_geo text default 'limitado',
  p_sede text default 'TODAS'
) returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_actor record;
  v_max_num integer;
  v_codigo text;
  v_username text;
  v_password text;
  v_usuario_id uuid;
begin
  select au.id,au.nombre,au.rol,au.nivel_jerarquia into v_actor
  from public.aos_usuarios au
  where au.id=public.aos_app_actor_v3(p_token,'admin-team',true)
    and au.activo=true
    and lower(coalesce(au.rol,''))='admin'
    and au.nivel_jerarquia=1;
  if v_actor.id is null then
    return jsonb_build_object('ok',false,'error','OWNER_ADMIN_2FA_REQUIRED');
  end if;

  if trim(coalesce(p_nombre,''))='' or trim(coalesce(p_apellido,''))='' then
    return jsonb_build_object('ok',false,'error','Nombre y apellido son obligatorios');
  end if;
  if p_nivel_jerarquia not between 1 and 5 then
    return jsonb_build_object('ok',false,'error','Nivel inválido');
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('aos_admin_crear_usuario_v3'));

  select coalesce(max(nullif(pg_catalog.regexp_replace(codigo_asesor,'[^0-9]','','g'),'')::integer),100)
    into v_max_num
  from public.aos_rrhh
  where codigo_asesor like 'ZIV-%';
  v_codigo:='ZIV-'||lpad((v_max_num+1)::text,3,'0');

  v_username:=lower(trim(split_part(p_nombre,' ',1)))||'.'||lower(trim(split_part(p_apellido,' ',1)));
  v_username:=pg_catalog.regexp_replace(v_username,'[^a-z0-9._-]','','g');
  if exists(select 1 from public.aos_rrhh where usuario=v_username) then
    v_username:=v_username||(v_max_num+1)::text;
  end if;

  -- One-time strong bootstrap password. Only the authorized owner-admin receives plaintext once.
  v_password:='Az!'||substr(encode(extensions.gen_random_bytes(9),'hex'),1,15);

  insert into public.aos_rrhh(
    codigo_asesor,nombre,apellido,usuario,password_hash,puesto,sede,estado,created_at,updated_at
  ) values (
    v_codigo,upper(trim(p_nombre)),upper(trim(p_apellido)),v_username,
    extensions.crypt(v_password,extensions.gen_salt('bf',10)),
    upper(trim(p_cargo)),upper(trim(p_sede)),'ACTIVO',now(),now()
  );

  insert into public.aos_usuarios(
    nombre,apellidos,email,telefono_personal,cargo,area,sede,nivel_jerarquia,acceso_geo,
    sedes_permitidas,codigo_asesor,cuenta_activada,activo,two_factor,paneles_acceso,created_at,updated_at
  ) values (
    upper(trim(p_nombre)),upper(trim(p_apellido)),trim(p_email),trim(p_telefono),upper(trim(p_cargo)),
    p_area,upper(trim(p_sede)),p_nivel_jerarquia,p_acceso_geo,
    case when p_acceso_geo='limitado' then array['SAN_ISIDRO','PUEBLO_LIBRE']::text[] else '{}'::text[] end,
    v_codigo,false,true,(trim(coalesce(p_email,''))<>''),'{}'::text[],now(),now()
  ) returning id into v_usuario_id;

  insert into public.aos_security_log(usuario,accion,detalles)
  values (v_actor.nombre,'CREATE_USER_V3',jsonb_build_object(
    'actor_id',v_actor.id,'target_user_id',v_usuario_id,'codigo',v_codigo,'username',v_username
  ));

  return jsonb_build_object(
    'ok',true,'codigo',v_codigo,'username',v_username,'password',v_password,
    'email',trim(p_email),'nombre',upper(trim(p_nombre))||' '||upper(trim(p_apellido)),
    'usuario_id',v_usuario_id
  );
exception when unique_violation then
  return jsonb_build_object('ok',false,'error','Ya existe un usuario con ese nombre o código');
when others then
  return jsonb_build_object('ok',false,'error','CREATE_USER_REJECTED','detail',sqlstate);
end
$function$;

create or replace function public.aos_admin_cambiar_password_v3(
  p_token text,
  p_usuario_id uuid,
  p_nueva_password text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_actor record;
  v_target record;
begin
  select au.id,au.nombre into v_actor
  from public.aos_usuarios au
  where au.id=public.aos_app_actor_v3(p_token,'admin-team',true)
    and au.activo=true
    and lower(coalesce(au.rol,''))='admin'
    and au.nivel_jerarquia=1;
  if v_actor.id is null then
    return jsonb_build_object('ok',false,'error','OWNER_ADMIN_2FA_REQUIRED');
  end if;
  if p_usuario_id is null or coalesce(length(p_nueva_password),0)<10 then
    return jsonb_build_object('ok',false,'error','La nueva contraseña debe tener al menos 10 caracteres');
  end if;

  select au.id,au.codigo_asesor,au.nombre,rr.usuario
    into v_target
  from public.aos_usuarios au
  join public.aos_rrhh rr on rr.codigo_asesor=au.codigo_asesor
  where au.id=p_usuario_id and au.activo=true and rr.estado='ACTIVO'
  limit 1
  for update of rr;
  if v_target.id is null then
    return jsonb_build_object('ok',false,'error','Usuario no encontrado o inactivo');
  end if;

  update public.aos_rrhh
  set password_hash=extensions.crypt(p_nueva_password,extensions.gen_salt('bf',10)),updated_at=now()
  where codigo_asesor=v_target.codigo_asesor;

  update public.aos_app_sessions_v3 set revoked=true where user_id=v_target.id and revoked=false;
  update public.aos_cia_admin_sessions set revoked=true where user_id=v_target.id and revoked=false;

  insert into public.aos_security_log(usuario,accion,detalles)
  values (v_actor.nombre,'ADMIN_PASSWORD_CHANGE_V3',jsonb_build_object(
    'actor_id',v_actor.id,'target_user_id',v_target.id,'codigo_asesor',v_target.codigo_asesor
  ));

  return jsonb_build_object('ok',true,'mensaje','Contraseña actualizada','usuario',v_target.nombre,'codigo_asesor',v_target.codigo_asesor,'username',v_target.usuario);
end
$function$;

create or replace function public.aos_cambiar_password_v3(
  p_token text,
  p_password_actual text,
  p_password_nuevo text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_uid uuid;
  v_user record;
  v_ok boolean:=false;
begin
  v_uid:=public.aos_app_actor_v3(p_token,null,false);
  if v_uid is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  if coalesce(length(p_password_nuevo),0)<10 then
    return jsonb_build_object('ok',false,'error','La nueva contraseña debe tener al menos 10 caracteres');
  end if;

  select au.id,au.nombre,au.codigo_asesor,rr.password_hash
    into v_user
  from public.aos_usuarios au
  join public.aos_rrhh rr on rr.codigo_asesor=au.codigo_asesor
  where au.id=v_uid and au.activo=true and rr.estado='ACTIVO'
  limit 1
  for update of rr;
  if v_user.id is null then return jsonb_build_object('ok',false,'error','Usuario no encontrado'); end if;

  if coalesce(v_user.password_hash,'') like '$2%' then
    v_ok:=extensions.crypt(coalesce(p_password_actual,''),v_user.password_hash)=v_user.password_hash;
  else
    v_ok:=coalesce(v_user.password_hash,'')=coalesce(p_password_actual,'');
  end if;
  if not v_ok then
    insert into public.aos_security_log(usuario,accion,detalles)
    values (v_user.nombre,'PASSWORD_CHANGE_FAILED_V3',jsonb_build_object('reason','current_password'));
    return jsonb_build_object('ok',false,'error','Contraseña actual incorrecta');
  end if;

  update public.aos_rrhh
  set password_hash=extensions.crypt(p_password_nuevo,extensions.gen_salt('bf',10)),updated_at=now()
  where codigo_asesor=v_user.codigo_asesor;
  update public.aos_app_sessions_v3 set revoked=true where user_id=v_uid and revoked=false;
  update public.aos_cia_admin_sessions set revoked=true where user_id=v_uid and revoked=false;

  insert into public.aos_security_log(usuario,accion,detalles)
  values (v_user.nombre,'PASSWORD_CHANGED_V3',jsonb_build_object('reauth_required',true));
  return jsonb_build_object('ok',true,'reauth_required',true);
end
$function$;

revoke all on function public.aos_admin_crear_usuario_v3(text,text,text,text,text,text,text,integer,text,text) from public;
revoke all on function public.aos_admin_cambiar_password_v3(text,uuid,text) from public;
revoke all on function public.aos_cambiar_password_v3(text,text,text) from public;
grant execute on function public.aos_admin_crear_usuario_v3(text,text,text,text,text,text,text,integer,text,text) to anon,authenticated,service_role;
grant execute on function public.aos_admin_cambiar_password_v3(text,uuid,text) to anon,authenticated,service_role;
grant execute on function public.aos_cambiar_password_v3(text,text,text) to anon,authenticated,service_role;

-- Legacy identity administration is retired after UI/SW cutover.
revoke execute on function public.aos_login(text,text) from public,anon,authenticated;
revoke execute on function public.aos_admin_crear_usuario(text,text,text,text,text,text,integer,text,text) from public,anon,authenticated;
revoke execute on function public.aos_admin_cambiar_password(uuid,text) from public,anon,authenticated;
revoke execute on function public.aos_admin_cambiar_password(text,text,text,text) from public,anon,authenticated;
revoke execute on function public.aos_cambiar_password(text,text,text) from public,anon,authenticated;

commit;
