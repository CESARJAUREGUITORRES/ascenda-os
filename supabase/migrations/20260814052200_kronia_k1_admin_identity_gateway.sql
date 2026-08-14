-- K1 — Token-bound ADMIN identity gateway.
-- Replaces browser-direct aos_usuarios/aos_rrhh writes and legacy unauthenticated
-- SECURITY DEFINER admin RPCs used by admin-team.html.

begin;

create or replace function public.aos_kronia_admin_identity(
  p_token text,
  p_action text,
  p_target_user_id uuid default null,
  p_params jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = 'pg_catalog','extensions'
as $function$
declare
  v_auth jsonb;
  v_actor public.aos_usuarios%rowtype;
  v_target public.aos_usuarios%rowtype;
  v_rr public.aos_rrhh%rowtype;
  v_action text := lower(trim(coalesce(p_action,'')));
  v_codigo text;
  v_username text;
  v_temp_password text;
  v_email text;
  v_level integer;
  v_panels text[];
  v_services text[];
  v_new_password text;
  v_new_hash text;
  v_seq integer;
begin
  v_auth:=public.aos_kronia_verify_token(p_token);
  if not coalesce((v_auth->>'ok')::boolean,false) or upper(coalesce(v_auth->>'rol',''))<>'ADMIN' then
    return jsonb_build_object('ok',false,'error','ADMIN_SESSION_REQUIRED');
  end if;

  select u.* into v_actor from public.aos_usuarios u
  where u.codigo_asesor=v_auth->>'id_asesor'
    and u.activo=true
    and lower(coalesce(u.rol,''))='admin'
    and coalesce(u.nivel_jerarquia,99) in (1,2)
  limit 1;
  if v_actor.id is null then return jsonb_build_object('ok',false,'error','ADMIN_IDENTITY_REQUIRED'); end if;

  if v_action in ('update_profile','set_services','set_2fa','activate_account','change_password','change_username','toggle_active','delete_user') then
    if p_target_user_id is null then return jsonb_build_object('ok',false,'error','TARGET_REQUIRED'); end if;
    select u.* into v_target from public.aos_usuarios u where u.id=p_target_user_id limit 1 for update;
    if v_target.id is null then return jsonb_build_object('ok',false,'error','TARGET_NOT_FOUND'); end if;
    select r.* into v_rr from public.aos_rrhh r where r.codigo_asesor=v_target.codigo_asesor limit 1 for update;
  end if;

  if v_action='update_profile' then
    if coalesce(v_target.nivel_jerarquia,99)=1 and v_actor.nivel_jerarquia<>1 then
      return jsonb_build_object('ok',false,'error','OWNER_LEVEL_REQUIRED');
    end if;
    v_level:=case when p_params ? 'nivel_jerarquia' then nullif(p_params->>'nivel_jerarquia','')::integer else v_target.nivel_jerarquia end;
    if v_level=1 and v_actor.nivel_jerarquia<>1 then return jsonb_build_object('ok',false,'error','OWNER_LEVEL_REQUIRED'); end if;
    if p_params ? 'paneles_acceso' then select coalesce(array_agg(x),'{}'::text[]) into v_panels from jsonb_array_elements_text(coalesce(p_params->'paneles_acceso','[]'::jsonb)) x; else v_panels:=v_target.paneles_acceso; end if;
    if p_params ? 'servicios' then select coalesce(array_agg(x),'{}'::text[]) into v_services from jsonb_array_elements_text(coalesce(p_params->'servicios','[]'::jsonb)) x; else v_services:=v_target.servicios; end if;

    update public.aos_usuarios u set
      nombre=case when p_params?'nombre' then upper(trim(p_params->>'nombre')) else u.nombre end,
      apellidos=case when p_params?'apellidos' then upper(trim(coalesce(p_params->>'apellidos',''))) else u.apellidos end,
      email=case when p_params?'email' then nullif(trim(p_params->>'email'),'') else u.email end,
      dni=case when p_params?'dni' then nullif(trim(p_params->>'dni'),'') else u.dni end,
      telefono_personal=case when p_params?'telefono_personal' then nullif(trim(p_params->>'telefono_personal'),'') else u.telefono_personal end,
      contacto_emergencia=case when p_params?'contacto_emergencia' then nullif(trim(p_params->>'contacto_emergencia'),'') else u.contacto_emergencia end,
      fecha_nacimiento=case when p_params?'fecha_nacimiento' then nullif(p_params->>'fecha_nacimiento','')::date else u.fecha_nacimiento end,
      lugar_nacimiento=case when p_params?'lugar_nacimiento' then nullif(trim(p_params->>'lugar_nacimiento'),'') else u.lugar_nacimiento end,
      rh=case when p_params?'rh' then nullif(trim(p_params->>'rh'),'') else u.rh end,
      departamento=case when p_params?'departamento' then nullif(trim(p_params->>'departamento'),'') else u.departamento end,
      provincia=case when p_params?'provincia' then nullif(trim(p_params->>'provincia'),'') else u.provincia end,
      distrito=case when p_params?'distrito' then nullif(trim(p_params->>'distrito'),'') else u.distrito end,
      direccion=case when p_params?'direccion' then nullif(trim(p_params->>'direccion'),'') else u.direccion end,
      cargo=case when p_params?'cargo' then nullif(trim(p_params->>'cargo'),'') else u.cargo end,
      area=case when p_params?'area' then nullif(trim(p_params->>'area'),'') else u.area end,
      sede=case when p_params?'sede' then nullif(trim(p_params->>'sede'),'') else u.sede end,
      fecha_ingreso=case when p_params?'fecha_ingreso' then nullif(p_params->>'fecha_ingreso','')::date else u.fecha_ingreso end,
      tipo_contrato=case when p_params?'tipo_contrato' then nullif(trim(p_params->>'tipo_contrato'),'') else u.tipo_contrato end,
      nivel_jerarquia=coalesce(v_level,u.nivel_jerarquia),
      acceso_geo=case when p_params?'acceso_geo' then nullif(trim(p_params->>'acceso_geo'),'') else u.acceso_geo end,
      sueldo=case when p_params?'sueldo' then coalesce(nullif(p_params->>'sueldo','')::numeric,0) else u.sueldo end,
      bono_metas=case when p_params?'bono_metas' then coalesce(nullif(p_params->>'bono_metas','')::numeric,0) else u.bono_metas end,
      avatar_url=case when p_params?'avatar_url' then nullif(trim(p_params->>'avatar_url'),'') else u.avatar_url end,
      paneles_acceso=v_panels,
      servicios=v_services,
      cmp=case when p_params?'cmp' then nullif(trim(p_params->>'cmp'),'') else u.cmp end,
      rol=case when coalesce(v_level,u.nivel_jerarquia)<=2 then 'admin' else coalesce(nullif(lower(p_params->>'rol'),''),u.rol,'asesor') end,
      updated_at=now()
    where u.id=v_target.id;

    update public.aos_rrhh r set
      nombre=case when p_params?'nombre' then upper(trim(p_params->>'nombre')) else r.nombre end,
      puesto=case when p_params?'cargo' then nullif(trim(p_params->>'cargo'),'') else r.puesto end,
      sede=case when p_params?'sede' then nullif(trim(p_params->>'sede'),'') else r.sede end,
      updated_at=now()
    where r.codigo_asesor=v_target.codigo_asesor;

    update public.aos_kronia_tokens set revocado=true where id_asesor=v_target.codigo_asesor and not revocado;

  elsif v_action='set_services' then
    select coalesce(array_agg(x),'{}'::text[]) into v_services from jsonb_array_elements_text(coalesce(p_params->'servicios','[]'::jsonb)) x;
    update public.aos_usuarios set servicios=v_services,
      cmp=case when p_params?'cmp' then nullif(trim(p_params->>'cmp'),'') else cmp end,updated_at=now()
    where id=v_target.id;

  elsif v_action='set_2fa' then
    if not (p_params ? 'enabled') then return jsonb_build_object('ok',false,'error','ENABLED_REQUIRED'); end if;
    if coalesce(v_target.nivel_jerarquia,99)=1 and not (p_params->>'enabled')::boolean then return jsonb_build_object('ok',false,'error','OWNER_2FA_REQUIRED'); end if;
    update public.aos_usuarios set two_factor=(p_params->>'enabled')::boolean,updated_at=now() where id=v_target.id;
    update public.aos_kronia_tokens set revocado=true where id_asesor=v_target.codigo_asesor and not revocado;

  elsif v_action='activate_account' then
    v_new_password:=coalesce(p_params->>'password','');
    if length(v_new_password)<8 then return jsonb_build_object('ok',false,'error','PASSWORD_MIN_8'); end if;
    if not public.aos_auth_set_password(v_target.codigo_asesor,v_new_password) then return jsonb_build_object('ok',false,'error','PASSWORD_SET_FAILED'); end if;
    update public.aos_usuarios set cuenta_activada=true,updated_at=now() where id=v_target.id;
    update public.aos_rrhh set estado='ACTIVO',updated_at=now() where codigo_asesor=v_target.codigo_asesor;
    update public.aos_kronia_tokens set revocado=true where id_asesor=v_target.codigo_asesor and not revocado;

  elsif v_action='change_password' then
    if coalesce(v_target.nivel_jerarquia,99)=1 and v_actor.nivel_jerarquia<>1 then return jsonb_build_object('ok',false,'error','OWNER_LEVEL_REQUIRED'); end if;
    v_new_password:=coalesce(p_params->>'password','');
    if length(v_new_password)<8 then return jsonb_build_object('ok',false,'error','PASSWORD_MIN_8'); end if;
    if not public.aos_auth_set_password(v_target.codigo_asesor,v_new_password) then return jsonb_build_object('ok',false,'error','PASSWORD_SET_FAILED'); end if;
    select c.password_hash into v_new_hash from public.aos_auth_credentials c where c.codigo_asesor=v_target.codigo_asesor;
    update public.aos_kronia_tokens set revocado=true where id_asesor=v_target.codigo_asesor and not revocado;
    if to_regclass('public.aos_cia_admin_sessions') is not null then
      execute 'update public.aos_cia_admin_sessions set revoked=true where user_id=$1 and revoked=false' using v_target.id;
    end if;
    if to_regclass('public.aos_sales_intelligence_access') is not null and v_new_hash is not null then
      execute 'update public.aos_sales_intelligence_access set password_digest=encode(extensions.digest($1,''sha256''),''hex''),updated_at=now() where user_id=$2'
      using v_new_hash,v_target.id;
    end if;

  elsif v_action='change_username' then
    v_username:=lower(trim(coalesce(p_params->>'username','')));
    if length(v_username)<3 or length(v_username)>50 or v_username !~ '^[a-z0-9._-]+$' then return jsonb_build_object('ok',false,'error','USERNAME_INVALID'); end if;
    if exists(select 1 from public.aos_rrhh r where lower(r.usuario)=v_username and r.codigo_asesor<>v_target.codigo_asesor) then return jsonb_build_object('ok',false,'error','USERNAME_IN_USE'); end if;
    update public.aos_rrhh set usuario=v_username,updated_at=now() where codigo_asesor=v_target.codigo_asesor;
    update public.aos_kronia_tokens set revocado=true where id_asesor=v_target.codigo_asesor and not revocado;

  elsif v_action='toggle_active' then
    if not (p_params ? 'enabled') then return jsonb_build_object('ok',false,'error','ENABLED_REQUIRED'); end if;
    if coalesce(v_target.nivel_jerarquia,99)=1 and not (p_params->>'enabled')::boolean then return jsonb_build_object('ok',false,'error','OWNER_CANNOT_DISABLE'); end if;
    update public.aos_usuarios set activo=(p_params->>'enabled')::boolean,updated_at=now() where id=v_target.id;
    update public.aos_rrhh set estado=case when (p_params->>'enabled')::boolean then 'ACTIVO' else 'INACTIVO' end,updated_at=now() where codigo_asesor=v_target.codigo_asesor;
    if not (p_params->>'enabled')::boolean then update public.aos_kronia_tokens set revocado=true where id_asesor=v_target.codigo_asesor and not revocado; end if;

  elsif v_action='delete_user' then
    if coalesce(v_target.nivel_jerarquia,99)=1 or v_target.codigo_asesor='ZIV-001' then return jsonb_build_object('ok',false,'error','OWNER_CANNOT_DELETE'); end if;
    update public.aos_usuarios set activo=false,nombre=nombre||' [ELIMINADO]',updated_at=now() where id=v_target.id;
    update public.aos_rrhh set estado='ELIMINADO',updated_at=now() where codigo_asesor=v_target.codigo_asesor;
    update public.aos_kronia_tokens set revocado=true where id_asesor=v_target.codigo_asesor and not revocado;

  elsif v_action='create_user' then
    if nullif(trim(coalesce(p_params->>'nombre','')),'') is null or nullif(trim(coalesce(p_params->>'apellido','')),'') is null then return jsonb_build_object('ok',false,'error','NAME_REQUIRED'); end if;
    v_email:=nullif(lower(trim(p_params->>'email')),'');
    if v_email is not null and exists(select 1 from public.aos_usuarios where lower(email)=v_email) then return jsonb_build_object('ok',false,'error','EMAIL_EXISTS'); end if;
    v_level:=coalesce(nullif(p_params->>'nivel_jerarquia','')::integer,3);
    if v_level=1 and v_actor.nivel_jerarquia<>1 then return jsonb_build_object('ok',false,'error','OWNER_LEVEL_REQUIRED'); end if;
    select coalesce(max(nullif(regexp_replace(codigo_asesor,'\D','','g'),'')::integer),0)+1 into v_seq from public.aos_rrhh where codigo_asesor ~ '[0-9]';
    v_codigo:='ZIV-'||lpad(v_seq::text,3,'0');
    v_username:=lower(split_part(trim(p_params->>'nombre'),' ',1))||'.'||lower(split_part(trim(p_params->>'apellido'),' ',1));
    v_username:=regexp_replace(v_username,'[^a-z0-9._-]','','g');
    if exists(select 1 from public.aos_rrhh where lower(usuario)=v_username) then v_username:=v_username||v_seq::text; end if;
    v_temp_password:='Zv!'||encode(extensions.gen_random_bytes(8),'hex');

    insert into public.aos_usuarios(codigo_asesor,nombre,apellidos,email,telefono,cargo,area,nivel_jerarquia,acceso_geo,sede,rol,activo,cuenta_activada,two_factor,created_at,updated_at)
    values(v_codigo,upper(trim(p_params->>'nombre')),upper(trim(p_params->>'apellido')),v_email,nullif(trim(p_params->>'telefono'),''),
      coalesce(nullif(trim(p_params->>'cargo'),''),'ASESOR'),coalesce(nullif(trim(p_params->>'area'),''),'general'),v_level,
      coalesce(nullif(trim(p_params->>'acceso_geo'),''),'limitado'),coalesce(nullif(trim(p_params->>'sede'),''),'TODAS'),
      case when v_level<=2 then 'admin' else 'asesor' end,true,false,false,now(),now())
    returning id into p_target_user_id;

    insert into public.aos_rrhh(codigo_asesor,nombre,apellido,puesto,sede,usuario,password_hash,estado,created_at,updated_at)
    values(v_codigo,upper(trim(p_params->>'nombre')),upper(trim(p_params->>'apellido')),coalesce(nullif(trim(p_params->>'cargo'),''),'ASESOR'),
      coalesce(nullif(trim(p_params->>'sede'),''),'TODAS'),v_username,null,'ACTIVO',now(),now());
    if not public.aos_auth_set_password(v_codigo,v_temp_password) then raise exception 'credential creation failed'; end if;

  else
    return jsonb_build_object('ok',false,'error','ACTION_NOT_ALLOWED');
  end if;

  insert into public.aos_security_log(usuario,accion,detalles,ip)
  values(v_actor.nombre,'K1_ADMIN_IDENTITY_'||upper(v_action),jsonb_build_object('actor_id',v_actor.id,'target_user_id',p_target_user_id,'action',v_action),'k1-admin-gateway');

  if v_action='create_user' then
    return jsonb_build_object('ok',true,'action',v_action,'user_id',p_target_user_id,'codigo_asesor',v_codigo,'username',v_username,'temporary_password',v_temp_password);
  end if;
  return jsonb_build_object('ok',true,'action',v_action,'target_user_id',p_target_user_id);
exception when others then
  insert into public.aos_security_log(usuario,accion,detalles,ip)
  values(coalesce(v_actor.nombre,'SYSTEM'),'K1_ADMIN_IDENTITY_FAILED',jsonb_build_object('action',v_action,'sqlstate',sqlstate),'k1-admin-gateway');
  return jsonb_build_object('ok',false,'error','IDENTITY_ACTION_FAILED');
end;
$function$;

revoke all on function public.aos_kronia_admin_identity(text,text,uuid,jsonb) from public;
grant execute on function public.aos_kronia_admin_identity(text,text,uuid,jsonb) to anon,authenticated,service_role;

-- Identity tables remain readable for current operational modules, but browser
-- mutation is no longer an authorization mechanism.
revoke insert,update,delete on table public.aos_rrhh from anon,authenticated;
revoke insert,update,delete on table public.aos_usuarios from anon,authenticated;

-- Retire all legacy browser-admin identity mutation functions. The K1 gateway
-- above is the only browser-callable mutation path for this scope.
revoke all on function public.aos_admin_cambiar_password(uuid,text) from public,anon,authenticated,service_role;
revoke all on function public.aos_admin_cambiar_password(text,text,text,text) from public,anon,authenticated,service_role;
revoke all on function public.aos_admin_crear_usuario(text,text,text,text,text,text,integer,text,text) from public,anon,authenticated,service_role;
revoke all on function public.aos_admin_cambiar_username(uuid,text) from public,anon,authenticated,service_role;
revoke all on function public.aos_admin_toggle_usuario(uuid,boolean) from public,anon,authenticated,service_role;
revoke all on function public.aos_admin_eliminar_usuario(uuid,text) from public,anon,authenticated,service_role;

comment on function public.aos_kronia_admin_identity(text,text,uuid,jsonb) is
'K1 token-bound ADMIN identity gateway. Explicit actions only; actor/role/nivel are derived from the opaque KronIA session.';

commit;
