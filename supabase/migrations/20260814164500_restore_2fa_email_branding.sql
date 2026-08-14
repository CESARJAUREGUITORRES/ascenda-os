-- ASCENDA OS — restore the established branded 2FA email while preserving Auth V3.
-- Functional auth/session behavior is unchanged; only sender display, subject and HTML presentation change.

create or replace function public.aos_login_v3(
  p_usuario text,
  p_password text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_user record;
  v_udata record;
  v_paneles text[];
  v_attempts integer;
  v_password_ok boolean:=false;
  v_code text;
  v_challenge uuid;
  v_api_key text;
  v_req bigint;
  v_token text;
  v_token_hash text;
  v_expires timestamptz;
  v_safe_name text;
  v_html text;
begin
  if coalesce(pg_catalog.length(pg_catalog.trim(p_usuario)),0)<1 or coalesce(pg_catalog.length(p_password),0)<1 then
    return pg_catalog.jsonb_build_object('ok',false,'error','Credenciales inválidas');
  end if;

  select r.codigo_asesor,r.nombre,r.apellido,r.puesto,r.sede,r.usuario,
         r.password_hash,r.permisos,r.estado
    into v_user
  from public.aos_rrhh r
  left join public.aos_usuarios u on pg_catalog.upper(u.nombre)=pg_catalog.upper(r.nombre)
  where (pg_catalog.lower(r.usuario)=pg_catalog.lower(pg_catalog.trim(p_usuario)) or pg_catalog.lower(coalesce(u.email,''))=pg_catalog.lower(pg_catalog.trim(p_usuario)))
    and r.estado='ACTIVO'
  limit 1;

  if v_user.codigo_asesor is null then
    insert into public.aos_security_log(usuario,accion,detalles)
    values (pg_catalog.left(pg_catalog.trim(p_usuario),120),'login_failed',pg_catalog.jsonb_build_object('reason','not_found','version','v3'));
    return pg_catalog.jsonb_build_object('ok',false,'error','Usuario o email no encontrado');
  end if;

  select pg_catalog.count(*) into v_attempts
  from public.aos_security_log
  where usuario=v_user.nombre and accion='login_failed' and created_at>pg_catalog.now()-interval '15 minutes';
  if v_attempts>=5 then
    return pg_catalog.jsonb_build_object('ok',false,'error','Cuenta bloqueada 15 min.');
  end if;

  if coalesce(v_user.password_hash,'') like '$2%' then
    v_password_ok := extensions.crypt(p_password,v_user.password_hash)=v_user.password_hash;
  else
    v_password_ok := coalesce(v_user.password_hash,'')=p_password;
  end if;

  if not v_password_ok then
    insert into public.aos_security_log(usuario,accion,detalles)
    values (v_user.nombre,'login_failed',pg_catalog.jsonb_build_object('reason','password','version','v3'));
    return pg_catalog.jsonb_build_object('ok',false,'error','Contraseña incorrecta');
  end if;

  if coalesce(v_user.password_hash,'') not like '$2%' then
    update public.aos_rrhh
       set password_hash=extensions.crypt(p_password,extensions.gen_salt('bf',10)),updated_at=pg_catalog.now()
     where codigo_asesor=v_user.codigo_asesor;
  end if;

  select u.* into v_udata
  from public.aos_usuarios u
  where u.codigo_asesor=v_user.codigo_asesor and u.activo=true
  limit 1;
  if v_udata.id is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','Usuario activo no encontrado');
  end if;
  v_paneles:=coalesce(v_udata.paneles_acceso,'{}'::text[]);

  if coalesce(v_udata.two_factor,false) then
    if coalesce(pg_catalog.trim(v_udata.email),'')='' then
      return pg_catalog.jsonb_build_object('ok',false,'error','2FA requiere un email válido');
    end if;

    v_code:=pg_catalog.lpad((((('x'||pg_catalog.substr(pg_catalog.encode(extensions.gen_random_bytes(4),'hex'),1,8))::bit(32)::bigint)%1000000))::text,6,'0');
    v_challenge:=extensions.gen_random_uuid();

    delete from public.aos_login_challenges_v3
     where user_id=v_udata.id and (consumed=true or expires_at<=pg_catalog.now() or created_at<pg_catalog.now()-interval '1 day');
    update public.aos_login_challenges_v3 set consumed=true
     where user_id=v_udata.id and consumed=false;

    insert into public.aos_login_challenges_v3(id,user_id,code_hash,expires_at)
    values (
      v_challenge,
      v_udata.id,
      pg_catalog.encode(extensions.digest(v_challenge::text||':'||v_code,'sha256'),'hex'),
      pg_catalog.now()+interval '5 minutes'
    );

    select i.api_key into v_api_key
    from public.aos_integraciones i
    where (pg_catalog.lower(coalesce(i.tipo,''))='resend' or pg_catalog.lower(coalesce(i.nombre,'')) like '%resend%')
      and coalesce(pg_catalog.length(i.api_key),0)>10
    order by coalesce(i.principal,false) desc,i.updated_at desc nulls last
    limit 1;

    if v_api_key is null then
      update public.aos_login_challenges_v3 set consumed=true where id=v_challenge;
      insert into public.aos_security_log(usuario,accion,detalles)
      values (v_user.nombre,'2fa_delivery_failed',pg_catalog.jsonb_build_object('reason','provider_unavailable','version','v3'));
      return pg_catalog.jsonb_build_object('ok',false,'error','No fue posible enviar el código 2FA');
    end if;

    v_safe_name:=pg_catalog.replace(pg_catalog.replace(pg_catalog.replace(pg_catalog.replace(coalesce(v_user.nombre,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;');
    v_html:=
      '<div style="font-family:Arial;max-width:400px;margin:0 auto;text-align:center;">'||
        '<div style="background:linear-gradient(135deg,#071D4A,#0A4FBF);padding:24px;border-radius:12px 12px 0 0;">'||
          '<div style="color:#00E5A0;font-size:10px;font-weight:700;letter-spacing:2px;">ASCENDA OS</div>'||
          '<div style="color:#fff;font-size:18px;font-weight:800;margin-top:6px;">Código de Verificación</div>'||
        '</div>'||
        '<div style="background:#fff;padding:24px;border:1px solid #eee;border-radius:0 0 12px 12px;">'||
          '<p>Hola <b>'||v_safe_name||'</b>,</p>'||
          '<p style="font-size:13px;color:#6B7BA8;">Tu código de acceso es:</p>'||
          '<div style="background:#F0F4FC;border-radius:12px;padding:20px;margin:16px 0;">'||
            '<div style="font-family:monospace;font-size:36px;font-weight:800;letter-spacing:8px;color:#0A4FBF;">'||v_code||'</div>'||
          '</div>'||
          '<p style="font-size:11px;color:#9AAAC8;">Este código expira en 5 minutos. Si no solicitaste este código, ignora este mensaje.</p>'||
        '</div>'||
      '</div>';

    select net.http_post(
      url:='https://api.resend.com/emails',
      headers:=pg_catalog.jsonb_build_object(
        'Authorization','Bearer '||v_api_key,
        'Content-Type','application/json'
      ),
      body:=pg_catalog.jsonb_build_object(
        'from','AscendaOS <info@zivital.pe>',
        'to',pg_catalog.jsonb_build_array(v_udata.email),
        'subject','🔐 Código de verificación — AscendaOS',
        'html',v_html
      )
    ) into v_req;

    insert into public.aos_security_log(usuario,accion,detalles)
    values (v_user.nombre,'2fa_challenge_sent',pg_catalog.jsonb_build_object('challenge_id',v_challenge,'request_id',v_req,'version','v3','template','ascenda_branded_v1'));

    return pg_catalog.jsonb_build_object(
      'ok',true,'require_2fa',true,'challenge_id',v_challenge,
      'email_masked',pg_catalog.substring(v_udata.email,1,3)||'***@'||pg_catalog.split_part(v_udata.email,'@',2),
      'usuario',v_user.nombre,'codigo_asesor',v_user.codigo_asesor,
      'nombre',v_user.nombre,'apellido',coalesce(v_user.apellido,v_udata.cargo),
      'puesto',coalesce(v_udata.cargo,v_user.puesto),'sede',v_user.sede,
      'paneles_acceso',to_jsonb(v_paneles),'avatar_url',v_udata.avatar_url,
      'nivel',v_udata.nivel_jerarquia,'area',v_udata.area,'acceso_geo',v_udata.acceso_geo,
      'permisos',coalesce(v_user.permisos,'{}'::jsonb)
    );
  end if;

  v_token:=pg_catalog.replace(extensions.gen_random_uuid()::text,'-','')||pg_catalog.replace(extensions.gen_random_uuid()::text,'-','');
  v_token_hash:=pg_catalog.encode(extensions.digest(v_token,'sha256'),'hex');
  v_expires:=pg_catalog.now()+interval '8 hours';
  update public.aos_app_sessions_v3 set revoked=true where user_id=v_udata.id and revoked=false;
  insert into public.aos_app_sessions_v3(token_hash,user_id,assurance_level,expires_at)
  values (v_token_hash,v_udata.id,'PASSWORD',v_expires);

  insert into public.aos_security_log(usuario,accion,detalles)
  values (v_user.nombre,'login',pg_catalog.jsonb_build_object('method','password_v3','expires_at',v_expires));

  return pg_catalog.jsonb_build_object(
    'ok',true,'require_2fa',false,'app_token',v_token,'expires_at',v_expires,
    'codigo_asesor',v_user.codigo_asesor,'nombre',v_user.nombre,
    'apellido',coalesce(v_user.apellido,v_udata.cargo),'puesto',coalesce(v_udata.cargo,v_user.puesto),
    'sede',v_user.sede,'usuario',v_user.usuario,'paneles_acceso',to_jsonb(v_paneles),
    'avatar_url',v_udata.avatar_url,'nivel',v_udata.nivel_jerarquia,'area',v_udata.area,
    'acceso_geo',v_udata.acceso_geo,'sedes_permitidas',to_jsonb(coalesce(v_udata.sedes_permitidas,'{}'::text[])),
    'permisos',coalesce(v_user.permisos,'{}'::jsonb)
  );
end
$function$;

revoke all on function public.aos_login_v3(text,text) from public;
grant execute on function public.aos_login_v3(text,text) to anon,authenticated,service_role;
