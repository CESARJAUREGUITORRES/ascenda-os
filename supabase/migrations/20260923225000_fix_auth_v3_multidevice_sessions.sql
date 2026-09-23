-- P0 · Auth V3 multi-device session coexistence
-- Incident: a second successful 2FA login revoked the first device session,
-- leaving the PWA open but causing governed Call Center writes to return UNAUTHORIZED.
-- Scope is intentionally narrow: 2FA verification sessions only.
-- Security properties preserved:
--   * 8 hour expiry
--   * PASSWORD_2FA assurance
--   * password changes / admin reset can still revoke all sessions
--   * active sessions are bounded to the five newest sessions per user

create or replace function public.aos_verificar_2fa_v3(
  p_challenge_id uuid,
  p_codigo text
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  c record;
  u record;
  r record;
  v_hash text;
  v_token text;
  v_token_hash text;
  v_exp timestamptz;
  v_paneles text[];
begin
  select * into c
  from public.aos_login_challenges_v3
  where id=p_challenge_id and consumed=false and expires_at>now() and attempts<5
  for update;
  if c.id is null then
    return jsonb_build_object('ok',false,'error','Código incorrecto o expirado');
  end if;

  update public.aos_login_challenges_v3 set attempts=attempts+1 where id=c.id;
  v_hash:=encode(extensions.digest(c.id::text||':'||coalesce(p_codigo,''),'sha256'),'hex');
  if v_hash<>c.code_hash then
    insert into public.aos_security_log(usuario,accion,detalles)
    select au.nombre,'2fa_failed',jsonb_build_object('challenge_id',c.id,'version','v3')
      from public.aos_usuarios au where au.id=c.user_id;
    return jsonb_build_object('ok',false,'error','Código incorrecto o expirado');
  end if;

  update public.aos_login_challenges_v3 set consumed=true where id=c.id;

  select au.* into u from public.aos_usuarios au where au.id=c.user_id and au.activo=true for update;
  if u.id is null or not coalesce(u.two_factor,false) then
    return jsonb_build_object('ok',false,'error','Usuario 2FA no disponible');
  end if;
  select rr.* into r from public.aos_rrhh rr where rr.codigo_asesor=u.codigo_asesor and rr.estado='ACTIVO' limit 1;
  if r.codigo_asesor is null then
    return jsonb_build_object('ok',false,'error','Usuario activo no encontrado');
  end if;
  v_paneles:=coalesce(u.paneles_acceso,'{}'::text[]);

  v_token:=replace(extensions.gen_random_uuid()::text,'-','')||replace(extensions.gen_random_uuid()::text,'-','');
  v_token_hash:=encode(extensions.digest(v_token,'sha256'),'hex');
  v_exp:=now()+interval '8 hours';

  -- Multi-device policy: a new successful 2FA login must not invalidate another
  -- recently authenticated device. Expired sessions are retired and only the
  -- five newest unexpired sessions remain active.
  update public.aos_app_sessions_v3
     set revoked=true
   where user_id=u.id
     and revoked=false
     and expires_at<=now();

  insert into public.aos_app_sessions_v3(token_hash,user_id,assurance_level,expires_at)
  values (v_token_hash,u.id,'PASSWORD_2FA',v_exp);

  update public.aos_app_sessions_v3 s
     set revoked=true
   where s.user_id=u.id
     and s.revoked=false
     and s.token_hash in (
       select x.token_hash
       from public.aos_app_sessions_v3 x
       where x.user_id=u.id
         and x.revoked=false
         and x.expires_at>now()
       order by x.created_at desc, x.token_hash desc
       offset 5
     );

  -- Existing CIA admin sessions intentionally remain single-session. This P0
  -- only changes the app session used by operative panels such as Call Center.
  if lower(coalesce(u.rol,''))='admin' and u.nivel_jerarquia in (1,2) then
    update public.aos_cia_admin_sessions set revoked=true where user_id=u.id and revoked=false;
    insert into public.aos_cia_admin_sessions(token_hash,user_id,usuario,expires_at,revoked,source_auth_code_id)
    values (v_token_hash,u.id,u.nombre,v_exp,false,null)
    on conflict (token_hash) do update set expires_at=excluded.expires_at,revoked=false;
  end if;

  insert into public.aos_security_log(usuario,accion,detalles)
  values (
    u.nombre,
    'login',
    jsonb_build_object(
      'method','2fa_email_v3',
      'expires_at',v_exp,
      'challenge_id',c.id,
      'session_policy','MULTI_DEVICE_MAX_5'
    )
  );

  return jsonb_build_object(
    'ok',true,'app_token',v_token,'finance_token',v_token,'expires_at',v_exp,
    'codigo_asesor',r.codigo_asesor,'nombre',r.nombre,
    'apellido',coalesce(r.apellido,u.cargo),'puesto',coalesce(u.cargo,r.puesto),
    'sede',r.sede,'usuario',r.usuario,'permisos',coalesce(r.permisos,'{}'::jsonb),
    'paneles_acceso',to_jsonb(v_paneles),'avatar_url',u.avatar_url,
    'nivel',u.nivel_jerarquia,'area',u.area,'acceso_geo',u.acceso_geo,
    'sedes_permitidas',to_jsonb(coalesce(u.sedes_permitidas,'{}'::text[]))
  );
end
$function$;

comment on function public.aos_verificar_2fa_v3(uuid,text) is
'Auth V3 2FA verification. P0 2026-09-23: preserves up to five concurrent unexpired app sessions so desktop login does not revoke an authenticated mobile/PWA session.';
