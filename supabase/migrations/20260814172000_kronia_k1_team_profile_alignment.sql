-- K1-F — full Team profile compatibility behind the owner-admin identity gateway.
-- Explicit allowlist only; no dynamic SQL and no client-provided authority.

begin;

create or replace function public.aos_admin_identity_v4(
  p_token text,p_action text,p_target_user_id uuid,p_params jsonb default '{}'::jsonb
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare
  v_actor record;
  v_target record;
  v_action text:=lower(trim(coalesce(p_action,'')));
  v_level integer;
  v_panels text[];
  v_services text[];
  v_si_enabled boolean:=false;
begin
  select u.id,u.nombre,u.nivel_jerarquia into v_actor
  from public.aos_usuarios u
  where u.id=public.aos_app_actor_v3(p_token,'admin-team',true)
    and u.activo=true and lower(coalesce(u.rol,''))='admin' and u.nivel_jerarquia=1;
  if v_actor.id is null then return jsonb_build_object('ok',false,'error','OWNER_ADMIN_2FA_REQUIRED'); end if;

  if v_action not in ('update_profile','set_services','set_2fa','change_username','toggle_active','delete_user','force_logout') then
    return jsonb_build_object('ok',false,'error','ACTION_NOT_ALLOWED');
  end if;
  if p_target_user_id is null then return jsonb_build_object('ok',false,'error','TARGET_REQUIRED'); end if;

  select u.id,u.codigo_asesor,u.nombre,u.rol,u.nivel_jerarquia,u.two_factor,u.paneles_acceso
  into v_target from public.aos_usuarios u where u.id=p_target_user_id limit 1 for update;
  if v_target.id is null then return jsonb_build_object('ok',false,'error','TARGET_NOT_FOUND'); end if;

  if v_action='update_profile' then
    begin
      v_level:=case when p_params ? 'nivel_jerarquia' then coalesce(nullif(p_params->>'nivel_jerarquia','')::integer,v_target.nivel_jerarquia) else v_target.nivel_jerarquia end;
    exception when others then return jsonb_build_object('ok',false,'error','LEVEL_INVALID'); end;
    if v_level not between 1 and 5 then return jsonb_build_object('ok',false,'error','LEVEL_INVALID'); end if;

    if v_target.id=v_actor.id and v_level<>1 then return jsonb_build_object('ok',false,'error','OWNER_SELF_PROTECTION'); end if;

    if v_level in (1,2) and coalesce(
      case when p_params ? 'email' then nullif(trim(p_params->>'email'),'') else (select nullif(trim(email),'') from public.aos_usuarios where id=v_target.id) end,
      ''
    )='' then return jsonb_build_object('ok',false,'error','ADMIN_EMAIL_2FA_REQUIRED'); end if;

    if p_params ? 'paneles_acceso' then
      begin v_panels:=array(select jsonb_array_elements_text(coalesce(p_params->'paneles_acceso','[]'::jsonb)));
      exception when others then return jsonb_build_object('ok',false,'error','PANELS_INVALID'); end;
      v_panels:=array_remove(coalesce(v_panels,'{}'::text[]),'admin-sales-intelligence');
      select exists(select 1 from public.aos_sales_intelligence_access s where s.user_id=v_target.id and s.enabled=true) into v_si_enabled;
      if v_si_enabled then v_panels:=array_append(v_panels,'admin-sales-intelligence'); end if;
    else v_panels:=v_target.paneles_acceso; end if;

    if p_params ? 'servicios' then
      begin v_services:=array(select jsonb_array_elements_text(coalesce(p_params->'servicios','[]'::jsonb)));
      exception when others then return jsonb_build_object('ok',false,'error','SERVICES_INVALID'); end;
    end if;

    update public.aos_usuarios set
      nombre=case when p_params ? 'nombre' then upper(trim(coalesce(p_params->>'nombre',''))) else nombre end,
      apellidos=case when p_params ? 'apellidos' then upper(trim(coalesce(p_params->>'apellidos',''))) else apellidos end,
      email=case when p_params ? 'email' then trim(coalesce(p_params->>'email','')) else email end,
      dni=case when p_params ? 'dni' then p_params->>'dni' else dni end,
      telefono_personal=case when p_params ? 'telefono_personal' then p_params->>'telefono_personal' else telefono_personal end,
      contacto_emergencia=case when p_params ? 'contacto_emergencia' then p_params->>'contacto_emergencia' else contacto_emergencia end,
      fecha_nacimiento=case when p_params ? 'fecha_nacimiento' then nullif(p_params->>'fecha_nacimiento','')::date else fecha_nacimiento end,
      lugar_nacimiento=case when p_params ? 'lugar_nacimiento' then p_params->>'lugar_nacimiento' else lugar_nacimiento end,
      rh=case when p_params ? 'rh' then p_params->>'rh' else rh end,
      departamento=case when p_params ? 'departamento' then p_params->>'departamento' else departamento end,
      provincia=case when p_params ? 'provincia' then p_params->>'provincia' else provincia end,
      distrito=case when p_params ? 'distrito' then p_params->>'distrito' else distrito end,
      direccion=case when p_params ? 'direccion' then p_params->>'direccion' else direccion end,
      cargo=case when p_params ? 'cargo' then upper(trim(coalesce(p_params->>'cargo',''))) else cargo end,
      area=case when p_params ? 'area' then p_params->>'area' else area end,
      sede=case when p_params ? 'sede' then upper(trim(coalesce(p_params->>'sede',''))) else sede end,
      fecha_ingreso=case when p_params ? 'fecha_ingreso' then nullif(p_params->>'fecha_ingreso','')::date else fecha_ingreso end,
      tipo_contrato=case when p_params ? 'tipo_contrato' then p_params->>'tipo_contrato' else tipo_contrato end,
      nivel_jerarquia=v_level,
      acceso_geo=case when p_params ? 'acceso_geo' then p_params->>'acceso_geo' else acceso_geo end,
      sueldo=case when p_params ? 'sueldo' then coalesce(nullif(p_params->>'sueldo','')::numeric,0) else sueldo end,
      bono_metas=case when p_params ? 'bono_metas' then coalesce(nullif(p_params->>'bono_metas','')::numeric,0) else bono_metas end,
      avatar_url=case when p_params ? 'avatar_url' then p_params->>'avatar_url' else avatar_url end,
      paneles_acceso=coalesce(v_panels,'{}'::text[]),
      rol=case when v_level in (1,2) then 'admin' else 'asesor' end,
      two_factor=case when v_level in (1,2) then true else two_factor end,
      servicios=case when p_params ? 'servicios' then coalesce(v_services,'{}'::text[]) else servicios end,
      cmp=case when p_params ? 'cmp' then p_params->>'cmp' else cmp end,
      cuenta_activada=case when p_params ? 'cuenta_activada' then coalesce((p_params->>'cuenta_activada')::boolean,false) else cuenta_activada end,
      updated_at=now()
    where id=v_target.id;

  elsif v_action='set_services' then
    begin v_services:=array(select jsonb_array_elements_text(coalesce(p_params->'servicios','[]'::jsonb)));
    exception when others then return jsonb_build_object('ok',false,'error','SERVICES_INVALID'); end;
    update public.aos_usuarios set servicios=coalesce(v_services,'{}'::text[]),
      cmp=case when p_params ? 'cmp' then p_params->>'cmp' else cmp end,updated_at=now()
    where id=v_target.id;

  elsif v_action='set_2fa' then
    if lower(coalesce(v_target.rol,''))='admin' and coalesce(v_target.nivel_jerarquia,99) in (1,2)
       and not coalesce((p_params->>'enabled')::boolean,false) then
      return jsonb_build_object('ok',false,'error','ADMIN_TWO_FACTOR_CANNOT_BE_DISABLED');
    end if;
    update public.aos_usuarios set two_factor=coalesce((p_params->>'enabled')::boolean,false),updated_at=now() where id=v_target.id;

  elsif v_action='change_username' then
    if coalesce(trim(p_params->>'username'),'')='' then return jsonb_build_object('ok',false,'error','USERNAME_REQUIRED'); end if;
    if exists(select 1 from public.aos_rrhh where lower(usuario)=lower(trim(p_params->>'username')) and codigo_asesor<>v_target.codigo_asesor) then
      return jsonb_build_object('ok',false,'error','USERNAME_EXISTS');
    end if;
    update public.aos_rrhh set usuario=lower(trim(p_params->>'username')),updated_at=now() where codigo_asesor=v_target.codigo_asesor;

  elsif v_action='toggle_active' then
    if v_target.id=v_actor.id and not coalesce((p_params->>'enabled')::boolean,false) then return jsonb_build_object('ok',false,'error','OWNER_SELF_PROTECTION'); end if;
    update public.aos_usuarios set activo=coalesce((p_params->>'enabled')::boolean,false),updated_at=now() where id=v_target.id;
    update public.aos_rrhh set estado=case when coalesce((p_params->>'enabled')::boolean,false) then 'ACTIVO' else 'INACTIVO' end,updated_at=now() where codigo_asesor=v_target.codigo_asesor;

  elsif v_action='delete_user' then
    if v_target.id=v_actor.id then return jsonb_build_object('ok',false,'error','OWNER_SELF_PROTECTION'); end if;
    update public.aos_usuarios set activo=false,updated_at=now() where id=v_target.id;
    update public.aos_rrhh set estado='INACTIVO',updated_at=now() where codigo_asesor=v_target.codigo_asesor;

  elsif v_action='force_logout' then null;
  end if;

  -- Ordinary update_profile fields do not force logout. K1-G revokes sessions
  -- only if role/level/2FA/email/active actually changed. Explicit security/lifecycle
  -- actions below always invalidate current sessions.
  if v_action in ('set_2fa','change_username','toggle_active','delete_user','force_logout') then
    update public.aos_app_sessions_v3 set revoked=true where user_id=v_target.id and revoked=false;
    update public.aos_cia_admin_sessions set revoked=true where user_id=v_target.id and revoked=false;
  end if;

  insert into public.aos_security_log(usuario,accion,detalles)
  values(v_actor.nombre,'K1_ADMIN_IDENTITY_'||upper(v_action),jsonb_build_object('actor_id',v_actor.id,'target_user_id',v_target.id));
  return jsonb_build_object('ok',true,'action',v_action,'target_user_id',v_target.id);
exception when invalid_text_representation or datetime_field_overflow or numeric_value_out_of_range then
  return jsonb_build_object('ok',false,'error','PROFILE_VALUE_INVALID');
end
$function$;

revoke all on function public.aos_admin_identity_v4(text,text,uuid,jsonb) from public;
grant execute on function public.aos_admin_identity_v4(text,text,uuid,jsonb) to anon,authenticated,service_role;

commit;
