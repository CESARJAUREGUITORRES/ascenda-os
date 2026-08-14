-- K1 — KronIA Identity, Session & Secrets Hardening
-- CRITICAL. Apply in staging first. Production only after explicit release gate.

create extension if not exists pgcrypto;

-- 1) Session material is never directly readable/writable by browser roles.
alter table public.aos_kronia_tokens enable row level security;
revoke all on table public.aos_kronia_tokens from anon, authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='aos_kronia_tokens'
      and policyname='kronia_tokens_service_only'
  ) then
    create policy kronia_tokens_service_only on public.aos_kronia_tokens
      for all to service_role using (true) with check (true);
  end if;
end $$;

-- One-time conversion of legacy raw tokens to SHA-256 digests. The raw token
-- previously held by a valid client still verifies because verify() hashes input.
update public.aos_kronia_tokens
set token = encode(digest(token, 'sha256'), 'hex')
where token is not null;

alter table public.aos_auth_codes
  add column if not exists kronia_claimed_at timestamptz;

-- 2) Web session claim. Role/sede/identity are derived from current server-side
-- identity sources. No client-supplied role is accepted.
create or replace function public.aos_kronia_claim_session(
  p_login_usuario text,
  p_password text,
  p_2fa_codigo text default null,
  p_device_info text default null,
  p_ip_origen text default null,
  p_origen text default 'web'
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rr public.aos_rrhh%rowtype;
  v_u public.aos_usuarios%rowtype;
  v_2fa_global boolean := true;
  v_2fa_required boolean := false;
  v_auth_id uuid;
  v_raw_token text;
  v_digest text;
  v_expira timestamptz;
  v_role_raw text;
  v_role text;
  v_user_key text;
begin
  if nullif(trim(coalesce(p_login_usuario,'')), '') is null or p_password is null then
    return jsonb_build_object('ok',false,'error','Credenciales requeridas');
  end if;

  select r.* into v_rr
  from public.aos_rrhh r
  left join public.aos_usuarios u on upper(u.nombre)=upper(r.nombre)
  where (lower(r.usuario)=lower(p_login_usuario)
         or lower(coalesce(u.email,''))=lower(p_login_usuario))
    and r.estado='ACTIVO'
  limit 1;

  if v_rr is null or coalesce(v_rr.password_hash,'') <> p_password then
    insert into public.aos_security_log(usuario,accion,detalles)
    values (coalesce(p_login_usuario,'?'),'kronia_session_denied',
            jsonb_build_object('reason','invalid_credentials'));
    return jsonb_build_object('ok',false,'error','Credenciales inválidas');
  end if;

  select * into v_u
  from public.aos_usuarios
  where upper(nombre)=upper(v_rr.nombre)
  limit 1;

  if v_u.id is not null and coalesce(v_u.activo,true)=false then
    return jsonb_build_object('ok',false,'error','Usuario inactivo');
  end if;

  select coalesce((valor::text='true'),true) into v_2fa_global
  from public.aos_configuracion where clave='seg_2fa_habilitado' limit 1;
  v_2fa_global := coalesce(v_2fa_global,true);
  v_2fa_required := v_2fa_global
    and coalesce(v_u.two_factor,false)
    and nullif(coalesce(v_u.email,''),'') is not null;

  if v_2fa_required then
    select id into v_auth_id
    from public.aos_auth_codes
    where upper(usuario)=upper(v_rr.nombre)
      and codigo=p_2fa_codigo
      and expira_at>now()
      and kronia_claimed_at is null
    order by created_at desc
    limit 1;

    if v_auth_id is null then
      return jsonb_build_object('ok',false,'error','Segundo factor requerido o expirado');
    end if;

    update public.aos_auth_codes
    set usado=true, kronia_claimed_at=now()
    where id=v_auth_id;
  end if;

  v_role_raw := upper(coalesce(v_u.rol,v_u.cargo,v_rr.puesto,'ASESOR'));
  v_role := case when v_role_raw like '%ADMIN%' then 'ADMIN' else 'ASESOR' end;
  v_user_key := coalesce(nullif(v_rr.usuario,''),v_rr.nombre);
  v_raw_token := encode(gen_random_bytes(32),'hex');
  v_digest := encode(digest(v_raw_token,'sha256'),'hex');
  v_expira := now() + interval '8 hours';

  update public.aos_kronia_tokens
  set revocado=true
  where upper(usuario)=upper(v_user_key)
    and coalesce(origen,'')=coalesce(p_origen,'web')
    and revocado=false;

  insert into public.aos_kronia_tokens(
    token,usuario,id_asesor,rol,sede,email,device_info,ip_origen,expira_at,origen
  ) values (
    v_digest,upper(v_user_key),v_rr.codigo_asesor,v_role,
    coalesce(v_u.sede,v_rr.sede),v_u.email,p_device_info,p_ip_origen,
    v_expira,coalesce(p_origen,'web')
  );

  insert into public.aos_security_log(usuario,accion,detalles)
  values (v_rr.nombre,'kronia_session_issued',
          jsonb_build_object('origin',coalesce(p_origen,'web'),'2fa',v_2fa_required));

  return jsonb_build_object(
    'ok',true,'token',v_raw_token,'usuario',upper(v_user_key),
    'id_asesor',v_rr.codigo_asesor,'rol',v_role,
    'sede',coalesce(v_u.sede,v_rr.sede),'expira_at',v_expira
  );
end;
$$;

-- 3) Verification re-derives current identity and role every time.
create or replace function public.aos_kronia_verify_token(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.aos_kronia_tokens%rowtype;
  v_rr public.aos_rrhh%rowtype;
  v_u public.aos_usuarios%rowtype;
  v_digest text;
  v_role_raw text;
  v_role text;
begin
  if p_token is null or length(p_token)<32 then
    return jsonb_build_object('ok',false,'error','Token inválido');
  end if;
  v_digest := encode(digest(p_token,'sha256'),'hex');

  select * into v_row from public.aos_kronia_tokens where token=v_digest limit 1;
  if v_row.id is null or v_row.revocado or v_row.expira_at<now() then
    return jsonb_build_object('ok',false,'error','Sesión inválida o expirada');
  end if;

  select * into v_rr from public.aos_rrhh
  where (upper(usuario)=upper(v_row.usuario) or upper(nombre)=upper(v_row.usuario))
    and estado='ACTIVO' limit 1;
  if v_rr is null then
    update public.aos_kronia_tokens set revocado=true where id=v_row.id;
    return jsonb_build_object('ok',false,'error','Identidad no vigente');
  end if;

  select * into v_u from public.aos_usuarios
  where upper(nombre)=upper(v_rr.nombre) limit 1;
  if v_u.id is not null and coalesce(v_u.activo,true)=false then
    update public.aos_kronia_tokens set revocado=true where id=v_row.id;
    return jsonb_build_object('ok',false,'error','Identidad inactiva');
  end if;

  v_role_raw := upper(coalesce(v_u.rol,v_u.cargo,v_rr.puesto,'ASESOR'));
  v_role := case when v_role_raw like '%ADMIN%' then 'ADMIN' else 'ASESOR' end;

  update public.aos_kronia_tokens
  set ultimo_uso=now(),rol=v_role,id_asesor=v_rr.codigo_asesor,
      sede=coalesce(v_u.sede,v_rr.sede)
  where id=v_row.id;

  return jsonb_build_object(
    'ok',true,'usuario',upper(coalesce(nullif(v_rr.usuario,''),v_rr.nombre)),
    'nombre',v_rr.nombre,'id_asesor',v_rr.codigo_asesor,
    'rol',v_role,'sede',coalesce(v_u.sede,v_rr.sede),
    'email',v_u.email,'expira_at',v_row.expira_at
  );
end;
$$;

create or replace function public.aos_kronia_revocar_token(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer; v_digest text;
begin
  if p_token is null then return jsonb_build_object('ok',true,'revocados',0); end if;
  v_digest := encode(digest(p_token,'sha256'),'hex');
  update public.aos_kronia_tokens set revocado=true
  where token=v_digest and not revocado;
  get diagnostics v_count=row_count;
  return jsonb_build_object('ok',true,'revocados',v_count);
end;
$$;

-- 4) Token-bound tool gateway. It is the authoritative execution/audit boundary.
create or replace function public.aos_kronia_tool(
  p_token text,
  p_tool text,
  p_params jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ident jsonb;
  v_user text;
  v_role text;
  v_result jsonb;
  v_inner jsonb;
begin
  v_ident := public.aos_kronia_verify_token(p_token);
  if coalesce((v_ident->>'ok')::boolean,false)=false then return v_ident; end if;
  v_user := v_ident->>'usuario';
  v_role := v_ident->>'rol';
  p_params := coalesce(p_params,'{}'::jsonb);

  case p_tool
    when 'aos_editar_venta' then
      v_result := public.aos_editar_venta((p_params->>'p_venta_id')::bigint,
        coalesce(p_params->'p_campos','{}'::jsonb),v_user,v_role,'kronia');
    when 'aos_kronia_editar_cita' then
      v_result := public.aos_kronia_editar_cita((p_params->>'p_cita_id')::bigint,
        coalesce(p_params->'p_campos','{}'::jsonb),v_user,v_role);
    when 'aos_kronia_editar_paciente' then
      v_result := public.aos_kronia_editar_paciente(p_params->>'p_paciente_id',
        coalesce(p_params->'p_campos','{}'::jsonb),v_user);
    when 'aos_kronia_reprogramar_seguimiento' then
      v_result := public.aos_kronia_reprogramar_seguimiento(p_params->>'p_seg_id',
        p_params->>'p_nueva_fecha',p_params->>'p_nueva_hora',v_user,v_role);
    when 'aos_kronia_marcar_estado_cita' then
      v_result := public.aos_kronia_marcar_estado_cita((p_params->>'p_cita_id')::bigint,
        p_params->>'p_nuevo_estado',v_user,v_role);
    when 'aos_kronia_agregar_nota_paciente' then
      v_result := public.aos_kronia_agregar_nota_paciente(p_params->>'p_numero_paciente',
        p_params->>'p_nota',v_user);
    when 'aos_kronia_buscar_venta' then
      v_result := public.aos_kronia_buscar_venta(p_params->>'p_filtro',v_user,v_role);
    when 'aos_kronia_buscar_cita' then
      v_result := public.aos_kronia_buscar_cita(p_params->>'p_filtro',v_user,v_role);
    when 'aos_kronia_buscar_paciente' then
      v_result := public.aos_kronia_buscar_paciente(p_params->>'p_filtro');
    when 'aos_kronia_stats_leads' then v_result := public.aos_kronia_stats_leads();
    when 'aos_kronia_stats_agenda' then v_result := public.aos_kronia_stats_agenda();
    when 'aos_kronia_stats_llamadas' then v_result := public.aos_kronia_stats_llamadas();
    when 'aos_kronia_stats_pacientes' then v_result := public.aos_kronia_stats_pacientes();
    when 'aos_kronia_obtener_insights_sofia' then v_result := public.aos_kronia_obtener_insights_sofia();
    when 'aos_kronia_explorar' then
      if v_role <> 'ADMIN' then
        return jsonb_build_object('ok',false,'error','Herramienta restringida a administrador');
      end if;
      v_inner := p_params->'p_params';
      if jsonb_typeof(v_inner)='string' then v_inner := (p_params->>'p_params')::jsonb; end if;
      v_result := public.aos_kronia_explorar(p_params->>'p_modulo',p_params->>'p_accion',
        coalesce(v_inner,'{}'::jsonb));
    else
      return jsonb_build_object('ok',false,'error','Tool no permitida');
  end case;

  insert into public.aos_kronia_acciones(
    usuario,rol,accion,objeto_tipo,objeto_id,cambios,resultado,exitoso,session_id
  ) values (
    v_user,v_role,'tool_call',p_tool,
    coalesce(p_params->>'p_venta_id',p_params->>'p_cita_id',p_params->>'p_paciente_id',
             p_params->>'p_seg_id',p_params->>'p_numero_paciente',''),
    p_params,
    case when v_result is null then null else left(v_result::text,2000) end,
    coalesce((v_result->>'ok')::boolean,true),
    nullif(p_params->>'_session_id','')
  );

  return v_result;
exception when others then
  insert into public.aos_security_log(usuario,accion,detalles)
  values (coalesce(v_user,'unknown'),'kronia_tool_error',
          jsonb_build_object('tool',p_tool,'sqlstate',sqlstate));
  return jsonb_build_object('ok',false,'error','Error ejecutando herramienta');
end;
$$;

-- Public session API: possession of the opaque token is the credential.
revoke all on function public.aos_kronia_claim_session(text,text,text,text,text,text) from public;
revoke all on function public.aos_kronia_verify_token(text) from public;
revoke all on function public.aos_kronia_revocar_token(text) from public;
revoke all on function public.aos_kronia_tool(text,text,jsonb) from public;
grant execute on function public.aos_kronia_claim_session(text,text,text,text,text,text) to anon, authenticated;
grant execute on function public.aos_kronia_verify_token(text) to anon, authenticated;
grant execute on function public.aos_kronia_revocar_token(text) to anon, authenticated;
grant execute on function public.aos_kronia_tool(text,text,jsonb) to anon, authenticated;

-- Legacy token administration is never browser-callable.
revoke execute on function public.aos_kronia_emitir_token(text,text,text,text,text,text,text) from public,anon,authenticated;
revoke execute on function public.aos_kronia_limpiar_tokens_expirados() from public,anon,authenticated;

-- Underlying KronIA business functions are reachable only through the gateway.
revoke execute on function public.aos_kronia_buscar_cita(text,text,text) from public,anon,authenticated;
revoke execute on function public.aos_kronia_buscar_paciente(text) from public,anon,authenticated;
revoke execute on function public.aos_kronia_buscar_venta(text,text,text) from public,anon,authenticated;
revoke execute on function public.aos_kronia_editar_cita(bigint,jsonb,text,text) from public,anon,authenticated;
revoke execute on function public.aos_kronia_editar_paciente(text,jsonb,text) from public,anon,authenticated;
revoke execute on function public.aos_kronia_reprogramar_seguimiento(text,text,text,text,text) from public,anon,authenticated;
revoke execute on function public.aos_kronia_marcar_estado_cita(bigint,text,text,text) from public,anon,authenticated;
revoke execute on function public.aos_kronia_agregar_nota_paciente(text,text,text) from public,anon,authenticated;
revoke execute on function public.aos_kronia_explorar(text,text,jsonb) from public,anon,authenticated;
revoke execute on function public.aos_kronia_obtener_insights_sofia() from public,anon,authenticated;
revoke execute on function public.aos_kronia_stats_leads() from public,anon,authenticated;
revoke execute on function public.aos_kronia_stats_agenda() from public,anon,authenticated;
revoke execute on function public.aos_kronia_stats_llamadas() from public,anon,authenticated;
revoke execute on function public.aos_kronia_stats_pacientes() from public,anon,authenticated;
revoke execute on function public.aos_editar_venta(bigint,jsonb,text,text,text) from public,anon,authenticated;

-- 5) Integration secrets: browser receives metadata, never secret material.
drop policy if exists anon_integ_read on public.aos_integraciones;
drop policy if exists anon_integ_write on public.aos_integraciones;
revoke all on table public.aos_integraciones from anon,authenticated;
create policy integrations_browser_metadata on public.aos_integraciones
  for select to anon,authenticated using (true);
grant select(id,tipo,nombre,cuenta,estado,principal,created_at,updated_at,categoria,icono,
             descripcion,pasos_guia,uso_para,orden,url_docs,url_signup,multi_cuenta,logo_url)
  on public.aos_integraciones to anon,authenticated;

-- 6) Identity source remains readable for legacy UI compatibility in K1, but
-- browser roles cannot promote, disable or otherwise mutate identities.
drop policy if exists anon_usuarios_all on public.aos_usuarios;
revoke insert,update,delete on public.aos_usuarios from anon,authenticated;
create policy usuarios_legacy_read on public.aos_usuarios
  for select to anon,authenticated using (true);

-- 7) Audit integrity. KronIA action audit is private and gateway-owned.
drop policy if exists kronia_acc_all on public.aos_kronia_acciones;
revoke all on public.aos_kronia_acciones from anon,authenticated;
alter table public.aos_kronia_acciones enable row level security;

-- Conversation/legacy operational logs remain readable/appendable where current
-- consumers require it, but browser roles cannot rewrite or delete history.
revoke update,delete on public.aos_kronia_conversaciones from anon,authenticated;
revoke update,delete on public.aos_agente_logs from anon,authenticated;
revoke update,delete on public.aos_agente_acciones from anon,authenticated;
revoke update,delete on public.aos_log_auditoria from anon,authenticated;

-- Security log is only written/read through privileged functions/server paths.
revoke all on public.aos_security_log from anon,authenticated;

comment on function public.aos_kronia_tool(text,text,jsonb) is
'K1 authoritative gateway. Browser role/user/sede claims are ignored; identity is re-derived from an opaque session token.';
