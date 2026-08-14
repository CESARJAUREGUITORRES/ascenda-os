-- K1 — Atomic 2FA verification / replay hardening.
-- Preserves the legacy JSON contract while ensuring a code can be consumed by
-- only one concurrent transaction. This function is server-only after K1.

create or replace function public.aos_verificar_2fa(
  p_usuario text,
  p_codigo text
) returns json
language plpgsql
security definer
set search_path = 'pg_catalog'
as $$
declare
  v_auth public.aos_auth_codes%rowtype;
  v_user public.aos_rrhh%rowtype;
  v_udata public.aos_usuarios%rowtype;
  v_paneles text[];
begin
  -- Lock and consume one still-valid code in a single transaction. Concurrent
  -- requests either skip the locked row or observe it as already used.
  with candidate as (
    select id
    from public.aos_auth_codes
    where upper(usuario) = upper(p_usuario)
      and codigo = p_codigo
      and usado = false
      and expira_at > now()
    order by created_at desc
    for update skip locked
    limit 1
  )
  update public.aos_auth_codes a
  set usado = true
  from candidate c
  where a.id = c.id
    and a.usado = false
  returning a.* into v_auth;

  if v_auth.id is null then
    insert into public.aos_security_log(usuario,accion,detalles)
    values (p_usuario,'2fa_failed',jsonb_build_object('reason','invalid_expired_used_or_concurrent'));
    return json_build_object('ok',false,'error','Código incorrecto o expirado');
  end if;

  select * into v_user
  from public.aos_rrhh
  where upper(nombre)=upper(p_usuario)
    and estado='ACTIVO'
  limit 1;

  if v_user.codigo_asesor is null then
    insert into public.aos_security_log(usuario,accion,detalles)
    values (p_usuario,'2fa_failed',jsonb_build_object('reason','active_user_not_found'));
    return json_build_object('ok',false,'error','Usuario activo no encontrado');
  end if;

  select * into v_udata
  from public.aos_usuarios
  where upper(nombre)=upper(v_user.nombre)
  limit 1;

  v_paneles := coalesce(v_udata.paneles_acceso,array[]::text[]);

  insert into public.aos_security_log(usuario,accion,detalles)
  values (p_usuario,'login',jsonb_build_object('method','2fa_email','atomic',true));

  return json_build_object(
    'ok',true,
    'codigo_asesor',v_user.codigo_asesor,
    'nombre',v_user.nombre,
    'apellido',coalesce(v_user.apellido,v_udata.cargo),
    'puesto',coalesce(v_udata.cargo,v_user.puesto),
    'sede',v_user.sede,
    'usuario',v_user.usuario,
    'permisos',coalesce(v_user.permisos,'{}'::jsonb),
    'paneles_acceso',to_json(v_paneles),
    'avatar_url',v_udata.avatar_url,
    'nivel',v_udata.nivel_jerarquia,
    'area',v_udata.area,
    'acceso_geo',v_udata.acceso_geo,
    'sedes_permitidas',to_json(coalesce(v_udata.sedes_permitidas,array[]::text[]))
  );
end;
$$;

revoke all on function public.aos_verificar_2fa(text,text)
  from public, anon, authenticated;
grant execute on function public.aos_verificar_2fa(text,text) to service_role;

comment on function public.aos_verificar_2fa(text,text) is
'K1 server-only atomic 2FA verifier. Consumes a valid OTP once using row locking; preserves legacy JSON response contract.';
