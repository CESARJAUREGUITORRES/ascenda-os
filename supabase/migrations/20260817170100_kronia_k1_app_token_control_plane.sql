-- ASCENDA OS — KronIA K1 rebased on Phase 2 Auth V3
-- K1-B: app-token control plane / RPC / secrets / audit boundary.
-- CRITICAL. Production only after Zero-Cost + canary release gate.

begin;

-- ══════════════════════════════════════════════════════════════════════════════
-- 1. Canonical identity = Phase 2 app session. No second KronIA login/session.
-- ══════════════════════════════════════════════════════════════════════════════
create or replace function public.aos_kronia_identity_v3(
  p_token text,
  p_require_admin boolean default false,
  p_required_panel text default null
) returns jsonb
language plpgsql stable security definer set search_path=''
as $function$
declare v_uid uuid; v_u record; v_r record;
begin
  v_uid:=public.aos_app_actor_v3(p_token,p_required_panel,p_require_admin);
  if v_uid is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  select u.* into v_u from public.aos_usuarios u where u.id=v_uid and u.activo=true limit 1;
  if v_u.id is null then return jsonb_build_object('ok',false,'error','IDENTITY_NOT_ACTIVE'); end if;
  select r.* into v_r from public.aos_rrhh r where r.codigo_asesor=v_u.codigo_asesor and r.estado='ACTIVO' limit 1;
  if v_r.codigo_asesor is null then return jsonb_build_object('ok',false,'error','RRHH_IDENTITY_NOT_ACTIVE'); end if;
  if p_require_admin and not (lower(coalesce(v_u.rol,''))='admin' and coalesce(v_u.nivel_jerarquia,99) in (1,2) and coalesce(v_u.two_factor,false)) then
    return jsonb_build_object('ok',false,'error','ADMIN_2FA_REQUIRED');
  end if;
  return jsonb_build_object(
    'ok',true,'user_id',v_u.id,'usuario',coalesce(nullif(v_r.usuario,''),v_u.nombre),
    'nombre',v_u.nombre,'id_asesor',v_u.codigo_asesor,
    'rol',case when lower(coalesce(v_u.rol,''))='admin' and coalesce(v_u.nivel_jerarquia,99) in (1,2) then 'ADMIN' else 'ASESOR' end,
    'nivel',v_u.nivel_jerarquia,'sede',coalesce(v_u.sede,v_r.sede),'email',v_u.email,
    'paneles_acceso',to_jsonb(coalesce(v_u.paneles_acceso,'{}'::text[]))
  );
end
$function$;

revoke all on function public.aos_kronia_identity_v3(text,boolean,text) from public;
grant execute on function public.aos_kronia_identity_v3(text,boolean,text) to anon,authenticated,service_role;

-- Canonical browser gateway. Raw business RPCs become implementation details.
create or replace function public.aos_kronia_tool_v3(
  p_token text,p_tool text,p_params jsonb default '{}'::jsonb
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_i jsonb; v_user text; v_role text; v_result jsonb; v_inner jsonb; v_session text;
begin
  v_i:=public.aos_kronia_identity_v3(p_token,false,null);
  if not coalesce((v_i->>'ok')::boolean,false) then return v_i; end if;
  v_user:=upper(coalesce(v_i->>'usuario',''));
  v_role:=v_i->>'rol';
  p_params:=coalesce(p_params,'{}'::jsonb);
  v_session:=nullif(p_params->>'_session_id','');

  case p_tool
    when 'aos_editar_venta' then
      v_result:=public.aos_editar_venta((p_params->>'p_venta_id')::bigint,coalesce(p_params->'p_campos','{}'::jsonb),v_user,v_role,'kronia');
    when 'aos_kronia_editar_cita' then
      v_result:=public.aos_kronia_editar_cita((p_params->>'p_cita_id')::bigint,coalesce(p_params->'p_campos','{}'::jsonb),v_user,v_role);
    when 'aos_kronia_editar_paciente' then
      v_result:=public.aos_kronia_editar_paciente(p_params->>'p_paciente_id',coalesce(p_params->'p_campos','{}'::jsonb),v_user);
    when 'aos_kronia_reprogramar_seguimiento' then
      v_result:=public.aos_kronia_reprogramar_seguimiento(p_params->>'p_seg_id',p_params->>'p_nueva_fecha',p_params->>'p_nueva_hora',v_user,v_role);
    when 'aos_kronia_marcar_estado_cita' then
      v_result:=public.aos_kronia_marcar_estado_cita((p_params->>'p_cita_id')::bigint,p_params->>'p_nuevo_estado',v_user,v_role);
    when 'aos_kronia_agregar_nota_paciente' then
      v_result:=public.aos_kronia_agregar_nota_paciente(p_params->>'p_numero_paciente',p_params->>'p_nota',v_user);
    when 'aos_kronia_buscar_venta' then
      v_result:=public.aos_kronia_buscar_venta(coalesce(p_params->>'p_filtro',''),v_user,v_role);
    when 'aos_kronia_buscar_cita' then
      v_result:=public.aos_kronia_buscar_cita(coalesce(p_params->>'p_filtro',''),v_user,v_role);
    when 'aos_kronia_buscar_paciente' then v_result:=public.aos_kronia_buscar_paciente(coalesce(p_params->>'p_filtro',''));
    when 'aos_kronia_stats_leads' then v_result:=public.aos_kronia_stats_leads();
    when 'aos_kronia_stats_agenda' then v_result:=public.aos_kronia_stats_agenda();
    when 'aos_kronia_stats_llamadas' then v_result:=public.aos_kronia_stats_llamadas();
    when 'aos_kronia_stats_pacientes' then v_result:=public.aos_kronia_stats_pacientes();
    when 'aos_kronia_obtener_insights_sofia' then v_result:=public.aos_kronia_obtener_insights_sofia();
    when 'aos_kronia_explorar' then
      if v_role<>'ADMIN' then return jsonb_build_object('ok',false,'error','ADMIN_REQUIRED'); end if;
      v_inner:=coalesce(p_params->'p_params','{}'::jsonb);
      if jsonb_typeof(v_inner)='string' then v_inner:=(p_params->>'p_params')::jsonb; end if;
      v_result:=public.aos_kronia_explorar(p_params->>'p_modulo',p_params->>'p_accion',v_inner);
    else return jsonb_build_object('ok',false,'error','TOOL_NOT_ALLOWED');
  end case;

  insert into public.aos_kronia_acciones(usuario,rol,accion,objeto_tipo,objeto_id,cambios,resultado,exitoso,session_id)
  values(v_user,v_role,'tool_call',p_tool,
    coalesce(p_params->>'p_venta_id',p_params->>'p_cita_id',p_params->>'p_paciente_id',p_params->>'p_seg_id',p_params->>'p_numero_paciente',''),
    p_params,case when v_result is null then null else left(v_result::text,2000) end,
    coalesce((v_result->>'ok')::boolean,true),v_session);
  return v_result;
exception when others then
  insert into public.aos_security_log(usuario,accion,detalles)
  values(coalesce(v_user,'unknown'),'KRONIA_TOOL_V3_ERROR',jsonb_build_object('tool',p_tool,'sqlstate',sqlstate));
  return jsonb_build_object('ok',false,'error','TOOL_EXECUTION_FAILED');
end
$function$;

revoke all on function public.aos_kronia_tool_v3(text,text,jsonb) from public;
grant execute on function public.aos_kronia_tool_v3(text,text,jsonb) to anon,authenticated,service_role;

-- Raw implementations and retired token helpers are never browser-callable after K1.
-- Optional legacy RPCs are resolved with to_regprocedure(): production revokes every
-- function that exists, while clean/staging installs do not abort on absent legacy code.
do $acl$
declare v_sig text; r regprocedure;
begin
  foreach v_sig in array array[
    'public.aos_editar_venta(bigint,jsonb,text,text,text)',
    'public.aos_kronia_agregar_nota_paciente(text,text,text)',
    'public.aos_kronia_buscar_cita(text,text,text)',
    'public.aos_kronia_buscar_paciente(text)',
    'public.aos_kronia_buscar_venta(text,text,text)',
    'public.aos_kronia_editar_cita(bigint,jsonb,text,text)',
    'public.aos_kronia_editar_paciente(text,jsonb,text)',
    'public.aos_kronia_explorar(text,text,jsonb)',
    'public.aos_kronia_marcar_estado_cita(bigint,text,text,text)',
    'public.aos_kronia_reprogramar_seguimiento(text,text,text,text,text)',
    'public.aos_kronia_obtener_insights_sofia()',
    'public.aos_kronia_stats_agenda()',
    'public.aos_kronia_stats_leads()',
    'public.aos_kronia_stats_llamadas()',
    'public.aos_kronia_stats_pacientes()',
    'public.aos_kronia_limpiar_tokens_expirados()',
    'public.aos_kronia_emitir_token(text,text,text,text,text,text,text)',
    'public.aos_kronia_verify_token(text)',
    'public.aos_kronia_revocar_token(text)'
  ] loop
    r:=to_regprocedure(v_sig);
    if r is not null then
      execute format('revoke all on function %s from public,anon,authenticated',r);
      execute format('grant execute on function %s to service_role',r);
    end if;
  end loop;
end
$acl$;

-- Legacy KronIA tokens are no longer an authority source.
alter table public.aos_kronia_tokens enable row level security;
drop policy if exists kronia_tokens_service_only on public.aos_kronia_tokens;
create policy kronia_tokens_service_only on public.aos_kronia_tokens for all to service_role using(true) with check(true);
revoke all on table public.aos_kronia_tokens from public,anon,authenticated;
grant all on table public.aos_kronia_tokens to service_role;

-- ══════════════════════════════════════════════════════════════════════════════
-- 2. Authoritative audit/log stores = service-only. Browser reads use feeds.
-- ══════════════════════════════════════════════════════════════════════════════
drop policy if exists kronia_acc_all on public.aos_kronia_acciones;
drop policy if exists aos_kronia_conv_all on public.aos_kronia_conversaciones;
revoke all on table public.aos_kronia_acciones from anon,authenticated;
revoke all on table public.aos_kronia_conversaciones from anon,authenticated;
revoke all on table public.aos_agente_logs from anon,authenticated;
revoke all on table public.aos_agente_acciones from anon,authenticated;
revoke all on table public.aos_log_auditoria from anon,authenticated;
revoke all on table public.aos_security_log from anon,authenticated;
grant all on table public.aos_kronia_acciones to service_role;
grant all on table public.aos_kronia_conversaciones to service_role;
grant all on table public.aos_agente_logs to service_role;
grant all on table public.aos_agente_acciones to service_role;
grant all on table public.aos_log_auditoria to service_role;
grant all on table public.aos_security_log to service_role;

create or replace function public.aos_kronia_feed_v3(
  p_token text,p_feed text,p_limit integer default 50
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_i jsonb; v_limit integer:=greatest(1,least(coalesce(p_limit,50),200)); v_rows jsonb;
begin
  v_i:=public.aos_kronia_identity_v3(p_token,true,null);
  if not coalesce((v_i->>'ok')::boolean,false) then return v_i; end if;
  case lower(coalesce(p_feed,''))
    when 'agent_logs' then
      select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into v_rows from (
        select id,agente_id,accion,input_resumen,output_resumen,exitoso,duracion_ms,created_at
        from public.aos_agente_logs order by created_at desc limit v_limit
      ) x;
    when 'audit' then
      select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into v_rows from (
        select id,usuario,accion,modulo,created_at from public.aos_log_auditoria order by created_at desc limit v_limit
      ) x;
    when 'kronia_actions' then
      select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into v_rows from (
        select id,usuario,rol,accion,objeto_tipo,objeto_id,exitoso,session_id,created_at
        from public.aos_kronia_acciones order by created_at desc limit v_limit
      ) x;
    else return jsonb_build_object('ok',false,'error','FEED_NOT_ALLOWED');
  end case;
  return jsonb_build_object('ok',true,'rows',v_rows);
end
$function$;
revoke all on function public.aos_kronia_feed_v3(text,text,integer) from public;
grant execute on function public.aos_kronia_feed_v3(text,text,integer) to anon,authenticated,service_role;

-- ══════════════════════════════════════════════════════════════════════════════
-- 3. Identity administration. Owner-admin + 2FA + admin-team panel only.
-- ══════════════════════════════════════════════════════════════════════════════
create or replace function public.aos_admin_identity_v4(
  p_token text,p_action text,p_target_user_id uuid,p_params jsonb default '{}'::jsonb
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_actor record; v_target record; v_action text:=lower(trim(coalesce(p_action,''))); v_level integer;
begin
  select u.id,u.nombre,u.nivel_jerarquia into v_actor from public.aos_usuarios u
  where u.id=public.aos_app_actor_v3(p_token,'admin-team',true)
    and u.activo=true and lower(coalesce(u.rol,''))='admin' and u.nivel_jerarquia=1;
  if v_actor.id is null then return jsonb_build_object('ok',false,'error','OWNER_ADMIN_2FA_REQUIRED'); end if;
  if v_action not in ('update_profile','set_services','set_2fa','change_username','toggle_active','delete_user','force_logout') then
    return jsonb_build_object('ok',false,'error','ACTION_NOT_ALLOWED');
  end if;
  if p_target_user_id is null then return jsonb_build_object('ok',false,'error','TARGET_REQUIRED'); end if;
  select u.id,u.codigo_asesor,u.nombre,u.rol,u.nivel_jerarquia,u.two_factor into v_target
  from public.aos_usuarios u where u.id=p_target_user_id limit 1 for update;
  if v_target.id is null then return jsonb_build_object('ok',false,'error','TARGET_NOT_FOUND'); end if;

  if v_action='update_profile' then
    begin v_level:=coalesce(nullif(p_params->>'nivel_jerarquia','')::integer,v_target.nivel_jerarquia); exception when others then return jsonb_build_object('ok',false,'error','LEVEL_INVALID'); end;
    if v_level not between 1 and 5 then return jsonb_build_object('ok',false,'error','LEVEL_INVALID'); end if;
    if v_level in (1,2) and coalesce(trim(p_params->>'email'),'')='' and not exists(select 1 from public.aos_usuarios where id=v_target.id and coalesce(trim(email),'')<>'') then
      return jsonb_build_object('ok',false,'error','ADMIN_EMAIL_2FA_REQUIRED');
    end if;
    update public.aos_usuarios set
      nombre=coalesce(nullif(upper(trim(p_params->>'nombre')),''),nombre),
      apellidos=coalesce(nullif(upper(trim(p_params->>'apellidos')),''),apellidos),
      email=coalesce(nullif(trim(p_params->>'email'),''),email),
      telefono_personal=coalesce(p_params->>'telefono_personal',telefono_personal),
      cargo=coalesce(nullif(upper(trim(p_params->>'cargo')),''),cargo),
      area=coalesce(nullif(p_params->>'area',''),area),sede=coalesce(nullif(upper(trim(p_params->>'sede')),''),sede),
      nivel_jerarquia=v_level,acceso_geo=coalesce(nullif(p_params->>'acceso_geo',''),acceso_geo),
      rol=case when v_level in (1,2) then 'admin' else 'asesor' end,
      two_factor=case when v_level in (1,2) then true else two_factor end,updated_at=now()
    where id=v_target.id;
  elsif v_action='set_services' then
    update public.aos_usuarios set servicios=coalesce(array(select jsonb_array_elements_text(coalesce(p_params->'servicios','[]'::jsonb))),'{}'::text[]),updated_at=now() where id=v_target.id;
  elsif v_action='set_2fa' then
    if lower(coalesce(v_target.rol,''))='admin' and coalesce(v_target.nivel_jerarquia,99) in (1,2) and not coalesce((p_params->>'enabled')::boolean,false) then
      return jsonb_build_object('ok',false,'error','ADMIN_TWO_FACTOR_CANNOT_BE_DISABLED');
    end if;
    update public.aos_usuarios set two_factor=coalesce((p_params->>'enabled')::boolean,false),updated_at=now() where id=v_target.id;
  elsif v_action='change_username' then
    if coalesce(trim(p_params->>'username'),'')='' then return jsonb_build_object('ok',false,'error','USERNAME_REQUIRED'); end if;
    if exists(select 1 from public.aos_rrhh where lower(usuario)=lower(trim(p_params->>'username')) and codigo_asesor<>v_target.codigo_asesor) then return jsonb_build_object('ok',false,'error','USERNAME_EXISTS'); end if;
    update public.aos_rrhh set usuario=lower(trim(p_params->>'username')),updated_at=now() where codigo_asesor=v_target.codigo_asesor;
  elsif v_action='toggle_active' then
    update public.aos_usuarios set activo=coalesce((p_params->>'enabled')::boolean,false),updated_at=now() where id=v_target.id;
    update public.aos_rrhh set estado=case when coalesce((p_params->>'enabled')::boolean,false) then 'ACTIVO' else 'INACTIVO' end,updated_at=now() where codigo_asesor=v_target.codigo_asesor;
  elsif v_action='delete_user' then
    update public.aos_usuarios set activo=false,updated_at=now() where id=v_target.id;
    update public.aos_rrhh set estado='INACTIVO',updated_at=now() where codigo_asesor=v_target.codigo_asesor;
  elsif v_action='force_logout' then null;
  end if;

  if v_action in ('update_profile','set_2fa','change_username','toggle_active','delete_user','force_logout') then
    update public.aos_app_sessions_v3 set revoked=true where user_id=v_target.id and revoked=false;
    update public.aos_cia_admin_sessions set revoked=true where user_id=v_target.id and revoked=false;
  end if;
  insert into public.aos_security_log(usuario,accion,detalles)
  values(v_actor.nombre,'K1_ADMIN_IDENTITY_'||upper(v_action),jsonb_build_object('actor_id',v_actor.id,'target_user_id',v_target.id));
  return jsonb_build_object('ok',true,'action',v_action,'target_user_id',v_target.id);
end
$function$;
revoke all on function public.aos_admin_identity_v4(text,text,uuid,jsonb) from public;
grant execute on function public.aos_admin_identity_v4(text,text,uuid,jsonb) to anon,authenticated,service_role;

-- Browser identity writes are retired; reads remain for existing UI compatibility.
revoke insert,update,delete on table public.aos_usuarios from anon,authenticated;
revoke insert,update,delete on table public.aos_rrhh from anon,authenticated;
grant select on table public.aos_usuarios to anon,authenticated;
grant select on table public.aos_rrhh to anon,authenticated;

-- ══════════════════════════════════════════════════════════════════════════════
-- 4. Configuration and integration secrets.
-- ══════════════════════════════════════════════════════════════════════════════
alter table public.aos_configuracion enable row level security;
drop policy if exists gas_access_configuracion on public.aos_configuracion;
drop policy if exists k1_config_browser_read on public.aos_configuracion;
create policy k1_config_browser_read on public.aos_configuracion for select to anon,authenticated
using (lower(clave) not like '%secret%' and lower(clave) not like '%api_key%' and lower(clave) not in ('email_resend_key','seg_turnstile_secret_key'));
revoke insert,update,delete on table public.aos_configuracion from anon,authenticated;
grant select on table public.aos_configuracion to anon,authenticated;

create or replace function public.aos_admin_config_v3(p_token text,p_clave text,p_valor text)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_actor record; v_key text:=trim(coalesce(p_clave,''));
begin
  select u.id,u.nombre into v_actor from public.aos_usuarios u
  where u.id=public.aos_app_actor_v3(p_token,'admin-config',true)
    and u.activo=true and lower(coalesce(u.rol,''))='admin' and u.nivel_jerarquia=1;
  if v_actor.id is null then return jsonb_build_object('ok',false,'error','OWNER_ADMIN_2FA_REQUIRED'); end if;
  if v_key='' or not exists(select 1 from public.aos_configuracion where clave=v_key) then return jsonb_build_object('ok',false,'error','CONFIG_KEY_NOT_ALLOWED'); end if;
  if lower(v_key) like '%secret%' or lower(v_key) like '%api_key%' or lower(v_key) in ('email_resend_key','seg_turnstile_secret_key') then
    return jsonb_build_object('ok',false,'error','SECRET_CONFIG_SERVER_MANAGED');
  end if;
  if v_key='seg_2fa_habilitado' and lower(trim(coalesce(p_valor,'')))<>'true' then return jsonb_build_object('ok',false,'error','TWO_FACTOR_CANNOT_BE_DISABLED'); end if;
  update public.aos_configuracion set valor=p_valor,updated_at=now(),updated_by=v_actor.nombre where clave=v_key;
  insert into public.aos_security_log(usuario,accion,detalles) values(v_actor.nombre,'K1_CONFIG_UPDATE',jsonb_build_object('clave',v_key));
  return jsonb_build_object('ok',true,'clave',v_key);
end
$function$;
revoke all on function public.aos_admin_config_v3(text,text,text) from public;
grant execute on function public.aos_admin_config_v3(text,text,text) to anon,authenticated,service_role;

-- Global 2FA cannot be disabled/deleted even by direct privileged SQL mistakes.
insert into public.aos_configuracion(clave,valor,descripcion,updated_at)
values('seg_2fa_habilitado','true','2FA global obligatorio',now())
on conflict(clave) do update set valor='true',updated_at=now();
create or replace function public.aos_k1_guard_global_2fa_v3() returns trigger
language plpgsql security definer set search_path='pg_catalog'
as $function$
begin
  if tg_op='DELETE' and old.clave='seg_2fa_habilitado' then raise exception 'K1_TWO_FACTOR_CONFIG_REQUIRED'; end if;
  if tg_op in ('INSERT','UPDATE') and new.clave='seg_2fa_habilitado' then
    if lower(trim(coalesce(new.valor,'')))<>'true' then raise exception 'K1_TWO_FACTOR_CANNOT_BE_DISABLED'; end if;
    new.valor:='true';
  end if;
  return case when tg_op='DELETE' then old else new end;
end
$function$;
revoke all on function public.aos_k1_guard_global_2fa_v3() from public,anon,authenticated;
drop trigger if exists trg_k1_global_2fa_v3 on public.aos_configuracion;
create trigger trg_k1_global_2fa_v3 before insert or update or delete on public.aos_configuracion
for each row execute function public.aos_k1_guard_global_2fa_v3();

-- Integration registry: no secret column is browser-readable and no direct write.
alter table public.aos_integraciones enable row level security;
drop policy if exists anon_integ_read_non_auth_provider on public.aos_integraciones;
drop policy if exists anon_integ_write_non_auth_provider on public.aos_integraciones;
revoke all on table public.aos_integraciones from anon,authenticated;
grant select(id,tipo,nombre,cuenta,estado,principal,categoria,icono,descripcion,uso_para,orden,url_docs,url_signup,multi_cuenta,logo_url,created_at,updated_at)
  on public.aos_integraciones to anon,authenticated;
grant all on table public.aos_integraciones to service_role;
create policy k1_integrations_metadata_read on public.aos_integraciones for select to anon,authenticated using(true);

create or replace function public.aos_admin_integracion_v3(
  p_token text,p_id uuid,p_action text,p_data jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_actor record; v_action text:=lower(trim(coalesce(p_action,'')));
begin
  select u.id,u.nombre into v_actor from public.aos_usuarios u
  where u.id=public.aos_app_actor_v3(p_token,'admin-config',true)
    and u.activo=true and lower(coalesce(u.rol,''))='admin' and u.nivel_jerarquia=1;
  if v_actor.id is null then return jsonb_build_object('ok',false,'error','OWNER_ADMIN_2FA_REQUIRED'); end if;
  if p_id is null or not exists(select 1 from public.aos_integraciones where id=p_id) then return jsonb_build_object('ok',false,'error','INTEGRATION_NOT_FOUND'); end if;
  if v_action='disable' then
    update public.aos_integraciones
      set estado='pendiente',api_key='',api_secret='',config=null,webhook_url=null,cuenta='',updated_at=now()
      where id=p_id;
    update public.aos_integration_secrets_v1
      set api_key='',api_secret='',updated_at=now()
      where integration_id=p_id;
  elsif v_action='update' then
    update public.aos_integraciones set
      cuenta=coalesce(p_data->>'cuenta',cuenta),estado=coalesce(p_data->>'estado',estado),
      principal=coalesce((p_data->>'principal')::boolean,principal),
      api_key='',api_secret='',
      config=case when p_data ? 'config' then p_data->'config' else config end,
      webhook_url=case when p_data ? 'webhook_url' then nullif(p_data->>'webhook_url','') else webhook_url end,
      updated_at=now()
    where id=p_id;
    if p_data ? 'api_key' or p_data ? 'api_secret' then
      insert into public.aos_integration_secrets_v1(integration_id,tipo,nombre,api_key,api_secret,captured_at,updated_at)
      select i.id,i.tipo,i.nombre,
             case when p_data ? 'api_key' then coalesce(p_data->>'api_key','') else '' end,
             case when p_data ? 'api_secret' then coalesce(p_data->>'api_secret','') else '' end,
             now(),now()
      from public.aos_integraciones i where i.id=p_id
      on conflict(integration_id) do update set
        tipo=excluded.tipo,nombre=excluded.nombre,
        api_key=case when p_data ? 'api_key' then excluded.api_key else public.aos_integration_secrets_v1.api_key end,
        api_secret=case when p_data ? 'api_secret' then excluded.api_secret else public.aos_integration_secrets_v1.api_secret end,
        updated_at=now();
    end if;
  else return jsonb_build_object('ok',false,'error','ACTION_NOT_ALLOWED');
  end if;
  insert into public.aos_security_log(usuario,accion,detalles)
  values(v_actor.nombre,'K1_INTEGRATION_'||upper(v_action),jsonb_build_object('integration_id',p_id));
  return jsonb_build_object('ok',true,'action',v_action,'integration_id',p_id);
end
$function$;
revoke all on function public.aos_admin_integracion_v3(text,uuid,text,jsonb) from public;
grant execute on function public.aos_admin_integracion_v3(text,uuid,text,jsonb) to anon,authenticated,service_role;

-- Legacy SECURITY DEFINER admin/auth functions remain explicitly closed.
revoke execute on function public.aos_login(text,text) from public,anon,authenticated;
revoke execute on function public.aos_admin_crear_usuario(text,text,text,text,text,text,integer,text,text) from public,anon,authenticated;
revoke execute on function public.aos_admin_cambiar_password(uuid,text) from public,anon,authenticated;
revoke execute on function public.aos_admin_cambiar_password(text,text,text,text) from public,anon,authenticated;
revoke execute on function public.aos_cambiar_password(text,text,text) from public,anon,authenticated;


-- K1 CURRENT sensitive identity read boundary.
-- Raw browser access is a minimal operational directory only. Full Team/PII
-- requires an Auth V3 app token, privileged admin identity and 2FA.
revoke all on table public.aos_usuarios from anon,authenticated;
grant select(id,codigo_asesor,nombre,apellidos,rol,cargo,area,sede,activo,cuenta_activada,two_factor,paneles_acceso,avatar_url,nivel_jerarquia,acceso_geo,sedes_permitidas,cmp,servicios)
  on public.aos_usuarios to anon,authenticated;
revoke all on table public.aos_rrhh from anon,authenticated;
grant select(codigo_asesor,nombre,apellido,puesto,sede,estado)
  on public.aos_rrhh to anon,authenticated;
revoke all on table public.aos_team_full from public,anon,authenticated;
grant select on table public.aos_team_full to service_role;

create or replace function public.aos_team_feed_v3(
  p_token text,
  p_cargo text default null,
  p_limit integer default 200
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_i jsonb; v_rows jsonb; v_limit integer:=greatest(1,least(coalesce(p_limit,200),500));
begin
  v_i:=public.aos_kronia_identity_v3(p_token,true,'admin-team');
  if not coalesce((v_i->>'ok')::boolean,false) then return v_i; end if;
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into v_rows
  from (
    select * from public.aos_team_full t
    where nullif(trim(coalesce(p_cargo,'')),'') is null or t.cargo=p_cargo
    order by t.nivel_jerarquia,t.nombre
    limit v_limit
  ) x;
  return jsonb_build_object('ok',true,'rows',v_rows);
end
$function$;
revoke all on function public.aos_team_feed_v3(text,text,integer) from public;
grant execute on function public.aos_team_feed_v3(text,text,integer) to anon,authenticated,service_role;

commit;
