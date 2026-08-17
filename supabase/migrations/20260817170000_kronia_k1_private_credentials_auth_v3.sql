-- ASCENDA OS — KronIA K1 rebased on Phase 2 Auth V3
-- K1-A: private credential store + Auth V3 compatibility.
-- CRITICAL / transactional. Production only after the K1 release gate.
--
-- Phase 2 already made aos_app_sessions_v3 the canonical session authority.
-- This migration does NOT create a competing session system. It removes password
-- material from browser-readable aos_rrhh and adapts every active V3 credential
-- consumer before clearing the legacy column.

begin;

-- K1 CURRENT private provider vault bootstrap.
-- This makes K1 valid on both CURRENT production (table already exists) and
-- chronological fresh migration replay before the later WA4 boundary migration.
create table if not exists public.aos_integration_secrets_v1 (
  integration_id uuid primary key references public.aos_integraciones(id) on delete cascade,
  tipo text not null,
  nombre text not null,
  api_key text not null default '',
  api_secret text not null default '',
  captured_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists aos_integration_secrets_v1_tipo_idx on public.aos_integration_secrets_v1(lower(tipo));
alter table public.aos_integration_secrets_v1 enable row level security;
alter table public.aos_integration_secrets_v1 force row level security;
revoke all on table public.aos_integration_secrets_v1 from public,anon,authenticated;
grant select,insert,update on table public.aos_integration_secrets_v1 to service_role;
insert into public.aos_integration_secrets_v1(integration_id,tipo,nombre,api_key,api_secret,captured_at,updated_at)
select id,tipo,nombre,coalesce(api_key,''),coalesce(api_secret,''),now(),now()
from public.aos_integraciones
where coalesce(api_key,'')<>'' or coalesce(api_secret,'')<>''
on conflict(integration_id) do update
set tipo=excluded.tipo,nombre=excluded.nombre,
    api_key=case when excluded.api_key<>'' then excluded.api_key else public.aos_integration_secrets_v1.api_key end,
    api_secret=case when excluded.api_secret<>'' then excluded.api_secret else public.aos_integration_secrets_v1.api_secret end,
    updated_at=now();
update public.aos_integraciones set api_key='',api_secret='',updated_at=now()
where coalesce(api_key,'')<>'' or coalesce(api_secret,'')<>'';

create extension if not exists pgcrypto;

create table if not exists public.aos_auth_credentials (
  codigo_asesor text primary key references public.aos_rrhh(codigo_asesor) on update cascade on delete cascade,
  password_hash text not null,
  algorithm text not null default 'bcrypt' check (algorithm='bcrypt'),
  updated_at timestamptz not null default now()
);

alter table public.aos_auth_credentials enable row level security;
drop policy if exists auth_credentials_service_only on public.aos_auth_credentials;
create policy auth_credentials_service_only on public.aos_auth_credentials
  for all to service_role using (true) with check (true);
revoke all on table public.aos_auth_credentials from public,anon,authenticated;
grant select,insert,update,delete on table public.aos_auth_credentials to service_role;

-- One-time bridge from Phase 2's transitional RRHH credential column. Existing
-- bcrypt values remain byte-for-byte; legacy plaintext-equivalent values are
-- converted once. No value is logged or returned.
insert into public.aos_auth_credentials(codigo_asesor,password_hash,algorithm,updated_at)
select r.codigo_asesor,
       case when r.password_hash like '$2a$%' or r.password_hash like '$2b$%' or r.password_hash like '$2y$%'
            then r.password_hash
            else extensions.crypt(r.password_hash,extensions.gen_salt('bf',12)) end,
       'bcrypt',now()
from public.aos_rrhh r
where nullif(r.password_hash,'') is not null
on conflict (codigo_asesor) do nothing;

create or replace function public.aos_auth_password_matches(
  p_codigo_asesor text,p_password text
) returns boolean
language sql stable security definer set search_path=''
as $function$
  select exists(
    select 1 from public.aos_auth_credentials c
    where c.codigo_asesor=p_codigo_asesor
      and c.algorithm='bcrypt'
      and extensions.crypt(coalesce(p_password,''),c.password_hash)=c.password_hash
  )
$function$;

create or replace function public.aos_auth_set_password(
  p_codigo_asesor text,p_password text
) returns boolean
language plpgsql security definer set search_path=''
as $function$
begin
  if coalesce(trim(p_codigo_asesor),'')='' or coalesce(length(p_password),0)<10 then return false; end if;
  if not exists(select 1 from public.aos_rrhh where codigo_asesor=p_codigo_asesor) then return false; end if;
  insert into public.aos_auth_credentials(codigo_asesor,password_hash,algorithm,updated_at)
  values(p_codigo_asesor,extensions.crypt(p_password,extensions.gen_salt('bf',12)),'bcrypt',now())
  on conflict(codigo_asesor) do update
  set password_hash=excluded.password_hash,algorithm='bcrypt',updated_at=now();
  -- Schema compatibility only; never repopulate this browser-readable column.
  update public.aos_rrhh set password_hash=null,updated_at=now()
  where codigo_asesor=p_codigo_asesor and password_hash is not null;
  return true;
end
$function$;

revoke all on function public.aos_auth_password_matches(text,text) from public,anon,authenticated;
revoke all on function public.aos_auth_set_password(text,text) from public,anon,authenticated;
grant execute on function public.aos_auth_password_matches(text,text) to service_role;
grant execute on function public.aos_auth_set_password(text,text) to service_role;

-- Preserve Phase 2 login/challenge/session semantics, replacing only the
-- credential source. OTP remains hashed in aos_login_challenges_v3 and delivery
-- remains server-side via SECURITY DEFINER.
create or replace function public.aos_login_v3(
  p_usuario text,p_password text
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare
  v_user record; v_udata record; v_paneles text[]; v_attempts integer;
  v_code text; v_challenge uuid; v_api_key text; v_req bigint;
  v_token text; v_token_hash text; v_expires timestamptz;
begin
  if coalesce(length(trim(p_usuario)),0)<1 or coalesce(length(p_password),0)<1 then
    return jsonb_build_object('ok',false,'error','Credenciales inválidas');
  end if;

  select r.codigo_asesor,r.nombre,r.apellido,r.puesto,r.sede,r.usuario,r.permisos,r.estado
    into v_user
  from public.aos_rrhh r
  left join public.aos_usuarios u on u.codigo_asesor=r.codigo_asesor
  where (lower(r.usuario)=lower(trim(p_usuario)) or lower(coalesce(u.email,''))=lower(trim(p_usuario)))
    and r.estado='ACTIVO'
  limit 1;

  if v_user.codigo_asesor is null then
    insert into public.aos_security_log(usuario,accion,detalles)
    values(left(trim(p_usuario),120),'login_failed',jsonb_build_object('reason','not_found','version','v3-k1'));
    return jsonb_build_object('ok',false,'error','Usuario o email no encontrado');
  end if;

  select count(*) into v_attempts from public.aos_security_log
  where usuario=v_user.nombre and accion='login_failed' and created_at>now()-interval '15 minutes';
  if v_attempts>=5 then return jsonb_build_object('ok',false,'error','Cuenta bloqueada 15 min.'); end if;

  if not public.aos_auth_password_matches(v_user.codigo_asesor,p_password) then
    insert into public.aos_security_log(usuario,accion,detalles)
    values(v_user.nombre,'login_failed',jsonb_build_object('reason','password','version','v3-k1'));
    return jsonb_build_object('ok',false,'error','Contraseña incorrecta');
  end if;

  select u.* into v_udata from public.aos_usuarios u
  where u.codigo_asesor=v_user.codigo_asesor and u.activo=true limit 1;
  if v_udata.id is null then return jsonb_build_object('ok',false,'error','Usuario activo no encontrado'); end if;
  v_paneles:=coalesce(v_udata.paneles_acceso,'{}'::text[]);

  -- Privileged ADMIN identities are never allowed to bypass 2FA.
  if lower(coalesce(v_udata.rol,''))='admin' and coalesce(v_udata.nivel_jerarquia,99) in (1,2)
     and (not coalesce(v_udata.two_factor,false) or coalesce(trim(v_udata.email),'')='') then
    return jsonb_build_object('ok',false,'error','ADMIN_2FA_REQUIRED');
  end if;

  if coalesce(v_udata.two_factor,false) then
    if coalesce(trim(v_udata.email),'')='' then return jsonb_build_object('ok',false,'error','2FA requiere un email válido'); end if;
    v_code:=lpad((((('x'||substr(encode(extensions.gen_random_bytes(4),'hex'),1,8))::bit(32)::bigint)%1000000))::text,6,'0');
    v_challenge:=extensions.gen_random_uuid();
    delete from public.aos_login_challenges_v3
      where user_id=v_udata.id and (consumed=true or expires_at<=now() or created_at<now()-interval '1 day');
    update public.aos_login_challenges_v3 set consumed=true where user_id=v_udata.id and consumed=false;
    insert into public.aos_login_challenges_v3(id,user_id,code_hash,expires_at)
    values(v_challenge,v_udata.id,encode(extensions.digest(v_challenge::text||':'||v_code,'sha256'),'hex'),now()+interval '5 minutes');

    -- CURRENT provider-secret boundary: credential material is service-side only.
    -- aos_integraciones remains metadata/status; the key itself lives in the private vault.
    select s.api_key into v_api_key
    from public.aos_integration_secrets_v1 s
    join public.aos_integraciones i on i.id=s.integration_id
    where (lower(coalesce(s.tipo,''))='resend' or lower(coalesce(s.nombre,'')) like '%resend%')
      and coalesce(length(s.api_key),0)>10
      and lower(coalesce(i.estado,'')) in ('conectado','activo')
    order by coalesce(i.principal,false) desc,s.updated_at desc nulls last limit 1;
    if v_api_key is null then
      update public.aos_login_challenges_v3 set consumed=true where id=v_challenge;
      insert into public.aos_security_log(usuario,accion,detalles)
      values(v_user.nombre,'2fa_delivery_failed',jsonb_build_object('reason','provider_unavailable','version','v3-k1'));
      return jsonb_build_object('ok',false,'error','No fue posible enviar el código 2FA');
    end if;

    select net.http_post(
      url:='https://api.resend.com/emails',
      headers:=jsonb_build_object('Authorization','Bearer '||v_api_key,'Content-Type','application/json'),
      body:=jsonb_build_object(
        'from','Clínica Zi Vital <info@zivital.pe>','to',jsonb_build_array(v_udata.email),
        'subject','Código de acceso ASCENDA',
        'html','<div style="font-family:Arial,sans-serif"><h2>ASCENDA OS</h2><p>Tu código de acceso es:</p><p style="font-size:32px;font-weight:700;letter-spacing:6px">'||v_code||'</p><p>Vence en 5 minutos. Si no solicitaste este acceso, ignora este mensaje.</p></div>'
      )
    ) into v_req;

    insert into public.aos_security_log(usuario,accion,detalles)
    values(v_user.nombre,'2fa_challenge_sent',jsonb_build_object('challenge_id',v_challenge,'request_id',v_req,'version','v3-k1'));
    return jsonb_build_object(
      'ok',true,'require_2fa',true,'challenge_id',v_challenge,
      'email_masked',substring(v_udata.email,1,3)||'***@'||split_part(v_udata.email,'@',2),
      'usuario',v_user.nombre,'codigo_asesor',v_user.codigo_asesor,'nombre',v_user.nombre,
      'apellido',coalesce(v_user.apellido,v_udata.cargo),'puesto',coalesce(v_udata.cargo,v_user.puesto),
      'sede',v_user.sede,'paneles_acceso',to_jsonb(v_paneles),'avatar_url',v_udata.avatar_url,
      'nivel',v_udata.nivel_jerarquia,'area',v_udata.area,'acceso_geo',v_udata.acceso_geo,
      'permisos',coalesce(v_user.permisos,'{}'::jsonb)
    );
  end if;

  v_token:=replace(extensions.gen_random_uuid()::text,'-','')||replace(extensions.gen_random_uuid()::text,'-','');
  v_token_hash:=encode(extensions.digest(v_token,'sha256'),'hex'); v_expires:=now()+interval '8 hours';
  update public.aos_app_sessions_v3 set revoked=true where user_id=v_udata.id and revoked=false;
  insert into public.aos_app_sessions_v3(token_hash,user_id,assurance_level,expires_at)
  values(v_token_hash,v_udata.id,'PASSWORD',v_expires);
  insert into public.aos_security_log(usuario,accion,detalles)
  values(v_user.nombre,'login',jsonb_build_object('method','password_v3_k1','expires_at',v_expires));
  return jsonb_build_object(
    'ok',true,'require_2fa',false,'app_token',v_token,'expires_at',v_expires,
    'codigo_asesor',v_user.codigo_asesor,'nombre',v_user.nombre,'apellido',coalesce(v_user.apellido,v_udata.cargo),
    'puesto',coalesce(v_udata.cargo,v_user.puesto),'sede',v_user.sede,'usuario',v_user.usuario,
    'paneles_acceso',to_jsonb(v_paneles),'avatar_url',v_udata.avatar_url,'nivel',v_udata.nivel_jerarquia,
    'area',v_udata.area,'acceso_geo',v_udata.acceso_geo,
    'sedes_permitidas',to_jsonb(coalesce(v_udata.sedes_permitidas,'{}'::text[])),
    'permisos',coalesce(v_user.permisos,'{}'::jsonb)
  );
end
$function$;

-- Owner/admin user creation remains app-token + 2FA gated. Credentials are
-- written only to the private store. Privileged levels require a valid email and
-- are enrolled in 2FA atomically.
create or replace function public.aos_admin_crear_usuario_v3(
  p_token text,p_nombre text,p_apellido text,p_email text default '',p_telefono text default '',
  p_cargo text default 'ASESOR',p_area text default 'enfermería',p_nivel_jerarquia integer default 3,
  p_acceso_geo text default 'limitado',p_sede text default 'TODAS'
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_actor record; v_max_num integer; v_codigo text; v_username text; v_password text; v_usuario_id uuid; v_is_priv boolean;
begin
  select au.id,au.nombre into v_actor from public.aos_usuarios au
  where au.id=public.aos_app_actor_v3(p_token,'admin-team',true)
    and au.activo=true and lower(coalesce(au.rol,''))='admin' and au.nivel_jerarquia=1;
  if v_actor.id is null then return jsonb_build_object('ok',false,'error','OWNER_ADMIN_2FA_REQUIRED'); end if;
  if trim(coalesce(p_nombre,''))='' or trim(coalesce(p_apellido,''))='' then return jsonb_build_object('ok',false,'error','Nombre y apellido son obligatorios'); end if;
  if p_nivel_jerarquia not between 1 and 5 then return jsonb_build_object('ok',false,'error','Nivel inválido'); end if;
  v_is_priv:=p_nivel_jerarquia in (1,2);
  if v_is_priv and trim(coalesce(p_email,''))='' then return jsonb_build_object('ok',false,'error','ADMIN_EMAIL_2FA_REQUIRED'); end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('aos_admin_crear_usuario_v3'));
  select coalesce(max(nullif(pg_catalog.regexp_replace(codigo_asesor,'[^0-9]','','g'),'')::integer),100) into v_max_num
  from public.aos_rrhh where codigo_asesor like 'ZIV-%';
  v_codigo:='ZIV-'||lpad((v_max_num+1)::text,3,'0');
  v_username:=pg_catalog.regexp_replace(lower(trim(split_part(p_nombre,' ',1)))||'.'||lower(trim(split_part(p_apellido,' ',1))),'[^a-z0-9._-]','','g');
  if exists(select 1 from public.aos_rrhh where usuario=v_username) then v_username:=v_username||(v_max_num+1)::text; end if;
  v_password:='Az!'||substr(encode(extensions.gen_random_bytes(9),'hex'),1,15);

  insert into public.aos_rrhh(codigo_asesor,nombre,apellido,usuario,password_hash,puesto,sede,estado,created_at,updated_at)
  values(v_codigo,upper(trim(p_nombre)),upper(trim(p_apellido)),v_username,null,upper(trim(p_cargo)),upper(trim(p_sede)),'ACTIVO',now(),now());
  insert into public.aos_usuarios(
    nombre,apellidos,email,telefono_personal,cargo,area,sede,nivel_jerarquia,acceso_geo,sedes_permitidas,
    codigo_asesor,cuenta_activada,activo,two_factor,paneles_acceso,rol,created_at,updated_at
  ) values(
    upper(trim(p_nombre)),upper(trim(p_apellido)),trim(p_email),trim(p_telefono),upper(trim(p_cargo)),p_area,upper(trim(p_sede)),
    p_nivel_jerarquia,p_acceso_geo,case when p_acceso_geo='limitado' then array['SAN_ISIDRO','PUEBLO_LIBRE']::text[] else '{}'::text[] end,
    v_codigo,false,true,case when v_is_priv then true else (trim(coalesce(p_email,''))<>'') end,'{}'::text[],
    case when v_is_priv then 'admin' else 'asesor' end,now(),now()
  ) returning id into v_usuario_id;
  if not public.aos_auth_set_password(v_codigo,v_password) then raise exception 'credential write failed'; end if;
  insert into public.aos_security_log(usuario,accion,detalles)
  values(v_actor.nombre,'CREATE_USER_V3_K1',jsonb_build_object('actor_id',v_actor.id,'target_user_id',v_usuario_id,'codigo',v_codigo,'username',v_username));
  return jsonb_build_object('ok',true,'codigo',v_codigo,'username',v_username,'password',v_password,'email',trim(p_email),
    'nombre',upper(trim(p_nombre))||' '||upper(trim(p_apellido)),'usuario_id',v_usuario_id);
exception when unique_violation then return jsonb_build_object('ok',false,'error','Ya existe un usuario con ese nombre o código');
when others then return jsonb_build_object('ok',false,'error','CREATE_USER_REJECTED','detail',sqlstate);
end
$function$;

create or replace function public.aos_admin_cambiar_password_v3(
  p_token text,p_usuario_id uuid,p_nueva_password text
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_actor record; v_target record;
begin
  select au.id,au.nombre into v_actor from public.aos_usuarios au
  where au.id=public.aos_app_actor_v3(p_token,'admin-team',true)
    and au.activo=true and lower(coalesce(au.rol,''))='admin' and au.nivel_jerarquia=1;
  if v_actor.id is null then return jsonb_build_object('ok',false,'error','OWNER_ADMIN_2FA_REQUIRED'); end if;
  if p_usuario_id is null or coalesce(length(p_nueva_password),0)<10 then return jsonb_build_object('ok',false,'error','La nueva contraseña debe tener al menos 10 caracteres'); end if;
  select au.id,au.codigo_asesor,au.nombre,rr.usuario into v_target
  from public.aos_usuarios au join public.aos_rrhh rr on rr.codigo_asesor=au.codigo_asesor
  where au.id=p_usuario_id and au.activo=true and rr.estado='ACTIVO' limit 1 for update of rr;
  if v_target.id is null then return jsonb_build_object('ok',false,'error','Usuario no encontrado o inactivo'); end if;
  if not public.aos_auth_set_password(v_target.codigo_asesor,p_nueva_password) then return jsonb_build_object('ok',false,'error','PASSWORD_SET_FAILED'); end if;
  update public.aos_app_sessions_v3 set revoked=true where user_id=v_target.id and revoked=false;
  update public.aos_cia_admin_sessions set revoked=true where user_id=v_target.id and revoked=false;
  insert into public.aos_security_log(usuario,accion,detalles)
  values(v_actor.nombre,'ADMIN_PASSWORD_CHANGE_V3_K1',jsonb_build_object('actor_id',v_actor.id,'target_user_id',v_target.id,'codigo_asesor',v_target.codigo_asesor));
  return jsonb_build_object('ok',true,'mensaje','Contraseña actualizada','usuario',v_target.nombre,'codigo_asesor',v_target.codigo_asesor,'username',v_target.usuario);
end
$function$;

create or replace function public.aos_cambiar_password_v3(
  p_token text,p_password_actual text,p_password_nuevo text
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid; v_user record;
begin
  v_uid:=public.aos_app_actor_v3(p_token,null,false);
  if v_uid is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  if coalesce(length(p_password_nuevo),0)<10 then return jsonb_build_object('ok',false,'error','La nueva contraseña debe tener al menos 10 caracteres'); end if;
  select au.id,au.nombre,au.codigo_asesor into v_user from public.aos_usuarios au
  join public.aos_rrhh rr on rr.codigo_asesor=au.codigo_asesor
  where au.id=v_uid and au.activo=true and rr.estado='ACTIVO' limit 1 for update of rr;
  if v_user.id is null then return jsonb_build_object('ok',false,'error','Usuario no encontrado'); end if;
  if not public.aos_auth_password_matches(v_user.codigo_asesor,p_password_actual) then
    insert into public.aos_security_log(usuario,accion,detalles)
    values(v_user.nombre,'PASSWORD_CHANGE_FAILED_V3_K1',jsonb_build_object('reason','current_password'));
    return jsonb_build_object('ok',false,'error','Contraseña actual incorrecta');
  end if;
  if not public.aos_auth_set_password(v_user.codigo_asesor,p_password_nuevo) then return jsonb_build_object('ok',false,'error','PASSWORD_SET_FAILED'); end if;
  update public.aos_app_sessions_v3 set revoked=true where user_id=v_uid and revoked=false;
  update public.aos_cia_admin_sessions set revoked=true where user_id=v_uid and revoked=false;
  insert into public.aos_security_log(usuario,accion,detalles)
  values(v_user.nombre,'PASSWORD_CHANGED_V3_K1',jsonb_build_object('reauth_required',true));
  return jsonb_build_object('ok',true,'reauth_required',true);
end
$function$;

-- Team view preserves the boolean UX without exposing credential material.
create or replace view public.aos_team_full as
select u.id,u.codigo_asesor,u.nombre,u.apellidos,u.email,u.telefono,u.dni,u.rol,u.cargo,u.area,u.sede,
       u.activo,u.cuenta_activada,u.invitacion_enviada,u.two_factor,u.paneles_acceso,u.permisos,u.avatar_url,
       u.ultimo_login,u.nivel_jerarquia,u.acceso_geo,u.sedes_permitidas,u.cmp,u.servicios,u.bono_metas,u.sueldo,
       u.fecha_ingreso,u.tipo_contrato,u.fecha_nacimiento,u.lugar_nacimiento,u.pais,u.departamento,u.provincia,
       u.distrito,u.direccion,u.contacto_emergencia,u.telefono_personal,u.rh,r.usuario as username_login,
       exists(select 1 from public.aos_auth_credentials c where c.codigo_asesor=u.codigo_asesor) as tiene_password,
       r.meta as meta_rrhh,r.bonus_pct as bonus_pct_rrhh,r.estado as estado_rrhh
from public.aos_usuarios u left join public.aos_rrhh r on r.codigo_asesor=u.codigo_asesor
where u.activo=true;

-- Sales Intelligence now receives the same Auth V3 app/finance token after 2FA.
-- Retire the legacy password+OTP claimant and make grant snapshots reference the
-- private bcrypt hash only as an invalidation fingerprint.
revoke all on function public.aos_sales_intelligence_claim_session(text,text,text,text) from public,anon,authenticated;

create or replace function public.aos_sales_intelligence_set_access(
  p_token text,p_target_user_id uuid,p_enabled boolean
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_actor record; v_target record;
begin
  select au.id,au.nombre into v_actor from public.aos_usuarios au
  where au.id=public.aos_app_actor_v3(p_token,'admin-sales-intelligence',true)
    and au.activo=true and au.two_factor=true and au.nivel_jerarquia=1 and lower(coalesce(au.rol,''))='admin'
  limit 1;
  if v_actor.id is null then return jsonb_build_object('ok',false,'error','OWNER_ADMIN_REQUIRED'); end if;

  select au.id,au.nombre,au.activo,au.two_factor,au.nivel_jerarquia,au.rol,au.codigo_asesor,
         r.usuario as login_usuario,r.nombre as twofa_subject,r.estado as rrhh_estado,
         encode(extensions.digest(c.password_hash,'sha256'),'hex') as password_digest
    into v_target
  from public.aos_usuarios au join public.aos_rrhh r on r.codigo_asesor=au.codigo_asesor
  left join public.aos_auth_credentials c on c.codigo_asesor=au.codigo_asesor
  where au.id=p_target_user_id limit 1 for update of au;
  if v_target.id is null then return jsonb_build_object('ok',false,'error','TARGET_NOT_FOUND'); end if;
  if coalesce(p_enabled,false) and not (
    coalesce(v_target.activo,false) and coalesce(v_target.two_factor,false)
    and v_target.nivel_jerarquia in (1,2) and lower(coalesce(v_target.rol,''))='admin'
    and upper(coalesce(v_target.rrhh_estado,''))='ACTIVO'
    and coalesce(trim(v_target.login_usuario),'')<>'' and coalesce(trim(v_target.twofa_subject),'')<>''
    and coalesce(v_target.password_digest,'')<>''
  ) then return jsonb_build_object('ok',false,'error','TARGET_ADMIN_2FA_REQUIRED'); end if;

  if coalesce(p_enabled,false) then
    insert into public.aos_sales_intelligence_access(user_id,enabled,login_usuario,twofa_subject,codigo_asesor_snapshot,password_digest,granted_by,granted_at,updated_at)
    values(v_target.id,true,v_target.login_usuario,v_target.twofa_subject,v_target.codigo_asesor,v_target.password_digest,v_actor.id,now(),now())
    on conflict(user_id) do update set enabled=true,login_usuario=excluded.login_usuario,twofa_subject=excluded.twofa_subject,
      codigo_asesor_snapshot=excluded.codigo_asesor_snapshot,password_digest=excluded.password_digest,granted_by=excluded.granted_by,
      granted_at=case when not public.aos_sales_intelligence_access.enabled then now() else public.aos_sales_intelligence_access.granted_at end,updated_at=now();
    update public.aos_usuarios set paneles_acceso=case when coalesce(paneles_acceso,'{}'::text[]) @> array['admin-sales-intelligence']::text[]
      then coalesce(paneles_acceso,'{}'::text[]) else array_append(coalesce(paneles_acceso,'{}'::text[]),'admin-sales-intelligence') end,updated_at=now()
    where id=v_target.id;
  else
    update public.aos_sales_intelligence_access set enabled=false,granted_by=v_actor.id,updated_at=now() where user_id=v_target.id;
    update public.aos_usuarios set paneles_acceso=array_remove(coalesce(paneles_acceso,'{}'::text[]),'admin-sales-intelligence'),updated_at=now() where id=v_target.id;
    update public.aos_cia_admin_sessions set revoked=true where user_id=v_target.id and revoked=false;
  end if;
  insert into public.aos_security_log(usuario,accion,detalles)
  values(v_actor.nombre,case when coalesce(p_enabled,false) then 'SALES_INTELLIGENCE_ACCESS_GRANTED' else 'SALES_INTELLIGENCE_ACCESS_REVOKED' end,
    jsonb_build_object('actor_id',v_actor.id,'target_user_id',v_target.id));
  return jsonb_build_object('ok',true,'enabled',coalesce(p_enabled,false),'target_user_id',v_target.id);
end
$function$;

-- Canonical privileged identities must be 2FA-enrolled; free-form cargo/puesto
-- never confers authority. This invariant protects future writes as well.
create or replace function public.aos_k1_guard_admin_identity_v3()
returns trigger language plpgsql security definer set search_path='pg_catalog'
as $function$
begin
  if lower(coalesce(new.rol,''))='admin' then
    if coalesce(new.nivel_jerarquia,99) not in (1,2) then raise exception 'K1_ADMIN_ROLE_REQUIRES_PRIVILEGED_LEVEL'; end if;
    if not coalesce(new.two_factor,false) or coalesce(trim(new.email),'')='' then raise exception 'K1_ADMIN_TWO_FACTOR_EMAIL_REQUIRED'; end if;
  end if;
  return new;
end
$function$;
revoke all on function public.aos_k1_guard_admin_identity_v3() from public,anon,authenticated;
drop trigger if exists trg_k1_guard_admin_identity_v3 on public.aos_usuarios;
create trigger trg_k1_guard_admin_identity_v3
before insert or update of rol,nivel_jerarquia,two_factor,email on public.aos_usuarios
for each row execute function public.aos_k1_guard_admin_identity_v3();

-- Final cutover step only after every V3 consumer above has been replaced.
update public.aos_rrhh set password_hash=null,updated_at=now() where password_hash is not null;

-- Direct browser access to the private credential and OTP proof stores is
-- explicitly denied even if future table-level defaults change.
revoke all on table public.aos_auth_credentials from public,anon,authenticated;
revoke all on table public.aos_login_challenges_v3 from public,anon,authenticated;
revoke all on table public.aos_app_sessions_v3 from public,anon,authenticated;
revoke all on table public.aos_auth_codes from public,anon,authenticated;
grant all on table public.aos_auth_credentials to service_role;
grant all on table public.aos_login_challenges_v3 to service_role;
grant all on table public.aos_app_sessions_v3 to service_role;
grant all on table public.aos_auth_codes to service_role;

comment on table public.aos_auth_credentials is
'K1 canonical password store. bcrypt only, service-role only. aos_rrhh.password_hash is retained as an empty compatibility column.';

commit;
