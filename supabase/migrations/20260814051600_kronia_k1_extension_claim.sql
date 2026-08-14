-- K1 compatibility bridge for the Chrome extension.
-- Requires a 2FA code that has already been verified/consumed by aos_verificar_2fa.
-- No role, sede or identity claim is accepted from the browser.

create or replace function public.aos_kronia_claim_verified_2fa(
  p_usuario text,
  p_codigo text,
  p_device_info text default null,
  p_ip_origen text default null,
  p_origen text default 'chrome_extension'
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rr public.aos_rrhh%rowtype;
  v_u public.aos_usuarios%rowtype;
  v_auth_id bigint;
  v_raw_token text;
  v_digest text;
  v_expira timestamptz;
  v_role_raw text;
  v_role text;
  v_user_key text;
begin
  if nullif(trim(coalesce(p_usuario,'')),'') is null
     or nullif(trim(coalesce(p_codigo,'')),'') is null then
    return jsonb_build_object('ok',false,'error','Usuario y código requeridos');
  end if;

  select id into v_auth_id
  from public.aos_auth_codes
  where upper(usuario)=upper(p_usuario)
    and codigo=p_codigo
    and usado=true
    and expira_at>now()
    and kronia_claimed_at is null
  order by created_at desc
  limit 1;

  if v_auth_id is null then
    return jsonb_build_object('ok',false,'error','Código no verificado, expirado o ya utilizado');
  end if;

  select * into v_rr from public.aos_rrhh
  where upper(nombre)=upper(p_usuario) and estado='ACTIVO' limit 1;
  if v_rr is null then
    return jsonb_build_object('ok',false,'error','Identidad no vigente');
  end if;

  select * into v_u from public.aos_usuarios
  where upper(nombre)=upper(v_rr.nombre) limit 1;
  if v_u.id is not null and coalesce(v_u.activo,true)=false then
    return jsonb_build_object('ok',false,'error','Identidad inactiva');
  end if;

  update public.aos_auth_codes set kronia_claimed_at=now() where id=v_auth_id;

  v_role_raw := upper(coalesce(v_u.rol,v_u.cargo,v_rr.puesto,'ASESOR'));
  v_role := case when v_role_raw like '%ADMIN%' then 'ADMIN' else 'ASESOR' end;
  v_user_key := coalesce(nullif(v_rr.usuario,''),v_rr.nombre);
  v_raw_token := encode(gen_random_bytes(32),'hex');
  v_digest := encode(digest(v_raw_token,'sha256'),'hex');
  v_expira := now()+interval '8 hours';

  update public.aos_kronia_tokens set revocado=true
  where upper(usuario)=upper(v_user_key)
    and coalesce(origen,'')=coalesce(p_origen,'chrome_extension')
    and revocado=false;

  insert into public.aos_kronia_tokens(
    token,usuario,id_asesor,rol,sede,email,device_info,ip_origen,expira_at,origen
  ) values (
    v_digest,upper(v_user_key),v_rr.codigo_asesor,v_role,
    coalesce(v_u.sede,v_rr.sede),v_u.email,p_device_info,p_ip_origen,
    v_expira,coalesce(p_origen,'chrome_extension')
  );

  insert into public.aos_security_log(usuario,accion,detalles)
  values (v_rr.nombre,'kronia_extension_session_issued',
          jsonb_build_object('origin',coalesce(p_origen,'chrome_extension')));

  return jsonb_build_object(
    'ok',true,'token',v_raw_token,'usuario',upper(v_user_key),
    'id_asesor',v_rr.codigo_asesor,'rol',v_role,
    'sede',coalesce(v_u.sede,v_rr.sede),'expira_at',v_expira
  );
end;
$$;

revoke all on function public.aos_kronia_claim_verified_2fa(text,text,text,text,text) from public;
grant execute on function public.aos_kronia_claim_verified_2fa(text,text,text,text,text) to anon, authenticated;
