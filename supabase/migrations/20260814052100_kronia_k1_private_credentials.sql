-- K1 — Private credential store + bcrypt migration.
-- CRITICAL: existing aos_rrhh.password_hash values are plaintext despite the
-- historical column name. Move them atomically to a service-only credential
-- table, hash with bcrypt, clear the browser-readable legacy column, and update
-- every active authentication proof that depends on the credential.

begin;

create table if not exists public.aos_auth_credentials (
  codigo_asesor text primary key references public.aos_rrhh(codigo_asesor) on update cascade on delete cascade,
  password_hash text not null,
  algorithm text not null default 'bcrypt',
  updated_at timestamptz not null default now()
);

alter table public.aos_auth_credentials enable row level security;
drop policy if exists auth_credentials_service_only on public.aos_auth_credentials;
create policy auth_credentials_service_only on public.aos_auth_credentials
  for all to service_role using (true) with check (true);
revoke all on table public.aos_auth_credentials from public, anon, authenticated;
grant select,insert,update,delete on table public.aos_auth_credentials to service_role;

-- One-time migration. If a row was already bcrypt-hashed during a recovered
-- partial environment, preserve it rather than hashing the hash again.
insert into public.aos_auth_credentials(codigo_asesor,password_hash,algorithm,updated_at)
select r.codigo_asesor,
       case
         when r.password_hash like '$2a$%' or r.password_hash like '$2b$%' or r.password_hash like '$2y$%'
           then r.password_hash
         else extensions.crypt(r.password_hash,extensions.gen_salt('bf',12))
       end,
       'bcrypt',now()
from public.aos_rrhh r
where nullif(r.password_hash,'') is not null
on conflict (codigo_asesor) do nothing;

-- Legacy column remains for schema compatibility only; no credential material
-- may remain in this browser-readable table after K1.
update public.aos_rrhh
set password_hash=null, updated_at=now()
where password_hash is not null;

create or replace function public.aos_auth_password_matches(
  p_codigo_asesor text,
  p_password text
) returns boolean
language sql
security definer
stable
set search_path = ''
as $function$
  select exists(
    select 1
    from public.aos_auth_credentials c
    where c.codigo_asesor=p_codigo_asesor
      and c.algorithm='bcrypt'
      and extensions.crypt(coalesce(p_password,''),c.password_hash)=c.password_hash
  );
$function$;

create or replace function public.aos_auth_set_password(
  p_codigo_asesor text,
  p_password text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if p_codigo_asesor is null or coalesce(length(p_password),0)<6 then
    return false;
  end if;
  insert into public.aos_auth_credentials(codigo_asesor,password_hash,algorithm,updated_at)
  values (
    p_codigo_asesor,
    extensions.crypt(p_password,extensions.gen_salt('bf',12)),
    'bcrypt',now()
  )
  on conflict (codigo_asesor) do update
  set password_hash=excluded.password_hash,algorithm='bcrypt',updated_at=now();
  update public.aos_rrhh set password_hash=null,updated_at=now()
  where codigo_asesor=p_codigo_asesor and password_hash is not null;
  return true;
end;
$function$;

revoke all on function public.aos_auth_password_matches(text,text) from public,anon,authenticated;
revoke all on function public.aos_auth_set_password(text,text) from public,anon,authenticated;
grant execute on function public.aos_auth_password_matches(text,text) to service_role;
grant execute on function public.aos_auth_set_password(text,text) to service_role;

-- Server-only main login. Preserve the production JSON contract and lockout
-- semantics, but verify against the private bcrypt credential store.
create or replace function public.aos_login_v2(p_usuario text,p_password text)
returns json
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user record;
  v_udata record;
  v_2fa_enabled boolean := true;
  v_code text;
  v_email text;
  v_locked_until timestamptz;
begin
  select r.codigo_asesor,r.nombre,r.apellido,r.puesto,r.sede,r.usuario,r.permisos,r.estado
  into v_user
  from public.aos_rrhh r
  where lower(r.usuario)=lower(p_usuario) and r.estado='ACTIVO'
  limit 1;

  if not found then
    insert into public.aos_security_log(usuario,accion,detalles)
    values (p_usuario,'login_failed',jsonb_build_object('reason','user_not_found'));
    return json_build_object('ok',false,'error','Usuario no encontrado o inactivo');
  end if;

  select u.id,u.email,u.cargo,u.area,u.nivel_jerarquia,u.acceso_geo,u.sedes_permitidas,
         u.two_factor,u.paneles_acceso,u.avatar_url,u.failed_attempts,u.locked_until
  into v_udata
  from public.aos_usuarios u
  where upper(u.nombre)=upper(v_user.nombre)
  limit 1;

  if v_udata.locked_until is not null and v_udata.locked_until>now() then
    return json_build_object('ok',false,'error','Cuenta bloqueada temporalmente. Intenta en unos minutos.','locked',true);
  end if;

  if not public.aos_auth_password_matches(v_user.codigo_asesor,p_password) then
    update public.aos_usuarios
    set failed_attempts=coalesce(failed_attempts,0)+1,
        locked_until=case when coalesce(failed_attempts,0)+1>=5 then now()+interval '15 minutes' else null end,
        updated_at=now()
    where id=v_udata.id;
    insert into public.aos_security_log(usuario,accion,detalles)
    values (v_user.nombre,'login_failed',jsonb_build_object('reason','wrong_password'));
    return json_build_object('ok',false,'error','Contraseña incorrecta');
  end if;

  update public.aos_usuarios
  set failed_attempts=0,locked_until=null,ultimo_acceso=now(),updated_at=now()
  where id=v_udata.id;

  select coalesce(valor::boolean,true) into v_2fa_enabled
  from public.aos_configuracion where clave='seg_2fa_habilitado';

  if v_2fa_enabled and coalesce(v_udata.two_factor,false) and coalesce(v_udata.email,'')<>'' then
    v_code:=lpad((floor(random()*1000000))::int::text,6,'0');
    v_email:=v_udata.email;
    insert into public.aos_auth_codes(usuario,email,codigo,expira_at)
    values (v_user.nombre,v_email,v_code,now()+interval '10 minutes');
    insert into public.aos_security_log(usuario,accion,detalles)
    values (v_user.nombre,'2fa_sent',jsonb_build_object('email_masked',left(v_email,2)||'***'));
    return json_build_object(
      'ok',true,'require_2fa',true,'usuario',v_user.nombre,'email_masked',left(v_email,2)||'***',
      'email_real',v_email,'code',v_code
    );
  end if;

  insert into public.aos_security_log(usuario,accion,detalles)
  values (v_user.nombre,'login',jsonb_build_object('method','password_bcrypt'));

  return json_build_object(
    'ok',true,'require_2fa',false,
    'codigo_asesor',v_user.codigo_asesor,'nombre',v_user.nombre,'apellido',v_user.apellido,
    'puesto',coalesce(v_udata.cargo,v_user.puesto),'sede',v_user.sede,'usuario',v_user.usuario,
    'permisos',coalesce(v_user.permisos,'{}'::jsonb),'paneles_acceso',to_json(coalesce(v_udata.paneles_acceso,array[]::text[])),
    'avatar_url',v_udata.avatar_url,'nivel',v_udata.nivel_jerarquia,'area',v_udata.area,
    'acceso_geo',v_udata.acceso_geo,'sedes_permitidas',to_json(coalesce(v_udata.sedes_permitidas,array[]::text[]))
  );
end;
$function$;

-- Legacy login remains only as a server/owner compatibility primitive; direct
-- browser execution is revoked below so it cannot bypass 2FA.
create or replace function public.aos_login(p_usuario text,p_password text)
returns json
language plpgsql
security definer
set search_path = ''
as $function$
declare v_user record;
begin
  select r.codigo_asesor,r.nombre,r.apellido,r.puesto,r.sede,r.usuario,r.permisos
  into v_user from public.aos_rrhh r
  where lower(r.usuario)=lower(p_usuario) and r.estado='ACTIVO' limit 1;
  if v_user.codigo_asesor is null or not public.aos_auth_password_matches(v_user.codigo_asesor,p_password) then
    return json_build_object('ok',false,'error','Credenciales inválidas');
  end if;
  return json_build_object('ok',true,'codigo_asesor',v_user.codigo_asesor,'nombre',v_user.nombre,
    'apellido',v_user.apellido,'puesto',v_user.puesto,'sede',v_user.sede,'usuario',v_user.usuario,
    'permisos',coalesce(v_user.permisos,'{}'::jsonb));
end;
$function$;

-- K1 session claim now verifies the private bcrypt credential instead of the
-- browser-readable RRHH legacy column.
create or replace function public.aos_kronia_claim_session(
  p_login_usuario text,p_password text,p_2fa_codigo text default null,
  p_device_info text default null,p_ip_origen text default null,p_origen text default 'web'
) returns jsonb
language plpgsql
security definer
set search_path = 'pg_catalog','extensions'
as $function$
declare
  v_rr public.aos_rrhh%rowtype;
  v_u public.aos_usuarios%rowtype;
  v_code public.aos_auth_codes%rowtype;
  v_token text;
  v_digest text;
  v_exp timestamptz;
  v_role_raw text;
  v_role text;
  v_user_key text;
begin
  if nullif(trim(coalesce(p_login_usuario,'')),'') is null or coalesce(length(p_password),0)<1 then
    return jsonb_build_object('ok',false,'error','INVALID_CREDENTIALS');
  end if;

  select r.* into v_rr from public.aos_rrhh r
  where lower(r.usuario)=lower(trim(p_login_usuario)) and upper(coalesce(r.estado,''))='ACTIVO' limit 1;
  if v_rr.codigo_asesor is null or not public.aos_auth_password_matches(v_rr.codigo_asesor,p_password) then
    return jsonb_build_object('ok',false,'error','INVALID_CREDENTIALS');
  end if;

  select u.* into v_u from public.aos_usuarios u
  where u.codigo_asesor=v_rr.codigo_asesor and u.activo=true limit 1;
  if v_u.id is null then return jsonb_build_object('ok',false,'error','IDENTITY_NOT_ACTIVE'); end if;

  if coalesce(v_u.two_factor,false) then
    if nullif(trim(coalesce(p_2fa_codigo,'')),'') is null then return jsonb_build_object('ok',false,'error','TWO_FACTOR_REQUIRED'); end if;
    select a.* into v_code from public.aos_auth_codes a
    where upper(a.usuario)=upper(v_rr.nombre) and a.codigo=p_2fa_codigo and a.usado=true
      and a.expira_at>now() and a.created_at>now()-interval '15 minutes'
      and a.kronia_claimed_at is null
    order by a.created_at desc limit 1 for update;
    if v_code.id is null then return jsonb_build_object('ok',false,'error','TWO_FACTOR_PROOF_INVALID'); end if;
    update public.aos_auth_codes set kronia_claimed_at=now() where id=v_code.id and kronia_claimed_at is null;
    if not found then return jsonb_build_object('ok',false,'error','TWO_FACTOR_PROOF_REPLAYED'); end if;
  end if;

  v_role_raw:=upper(coalesce(v_u.rol,v_u.cargo,v_rr.puesto,'ASESOR'));
  v_role:=case when v_role_raw like '%ADMIN%' then 'ADMIN' else 'ASESOR' end;
  v_user_key:=coalesce(nullif(v_rr.usuario,''),v_rr.nombre);
  v_token:=encode(extensions.gen_random_bytes(32),'hex');
  v_digest:=encode(extensions.digest(v_token,'sha256'),'hex');
  v_exp:=now()+interval '8 hours';

  update public.aos_kronia_tokens set revocado=true where lower(usuario)=lower(v_user_key) and not revocado;
  insert into public.aos_kronia_tokens(token,usuario,id_asesor,rol,sede,email,device_info,ip_origen,expira_at,origen)
  values(v_digest,v_user_key,v_rr.codigo_asesor,v_role,v_rr.sede,v_u.email,p_device_info,p_ip_origen,v_exp,coalesce(nullif(p_origen,''),'web'));
  return jsonb_build_object('ok',true,'token',v_token,'usuario',v_user_key,'id_asesor',v_rr.codigo_asesor,'rol',v_role,'sede',v_rr.sede,'email',v_u.email,'expira_at',v_exp);
end;
$function$;

-- Sales Intelligence keeps its password-change invalidation property by
-- snapshotting a digest of the PRIVATE bcrypt hash and verifying the submitted
-- password against the live credential store.
DO $outer$
begin
  if to_regclass('public.aos_sales_intelligence_access') is not null
     and to_regclass('public.aos_cia_admin_sessions') is not null then
    execute $sql$
      update public.aos_sales_intelligence_access sia
      set password_digest=encode(extensions.digest(c.password_hash,'sha256'),'hex'),updated_at=now()
      from public.aos_usuarios u
      join public.aos_auth_credentials c on c.codigo_asesor=u.codigo_asesor
      where sia.user_id=u.id
    $sql$;
    execute 'update public.aos_cia_admin_sessions set revoked=true where revoked=false';

    execute $fn$
      create or replace function public.aos_sales_intelligence_claim_session(
        p_login_usuario text,p_password text,p_usuario text,p_codigo text
      ) returns jsonb
      language plpgsql security definer set search_path=''
      as $body$
      declare c record; u record; v_token text; v_hash text; v_exp timestamptz;
      begin
        select au.id,au.nombre,sia.twofa_subject
        into u
        from public.aos_sales_intelligence_access sia
        join public.aos_usuarios au on au.id=sia.user_id
        join public.aos_auth_credentials cred on cred.codigo_asesor=au.codigo_asesor
        join public.aos_rrhh rr on rr.codigo_asesor=au.codigo_asesor
        where sia.enabled=true
          and lower(sia.login_usuario)=lower(trim(coalesce(p_login_usuario,'')))
          and sia.password_digest=encode(extensions.digest(cred.password_hash,'sha256'),'hex')
          and extensions.crypt(coalesce(p_password,''),cred.password_hash)=cred.password_hash
          and upper(coalesce(rr.estado,''))='ACTIVO'
          and au.activo=true and au.two_factor=true and au.nivel_jerarquia in (1,2)
          and lower(coalesce(au.rol,''))='admin'
          and coalesce(au.paneles_acceso,'{}'::text[]) @> array['admin-sales-intelligence']::text[]
        limit 1;
        if u.id is null then return jsonb_build_object('ok',false,'error','PROOF_INVALID'); end if;
        select ac.id,ac.usuario into c from public.aos_auth_codes ac
        where upper(ac.usuario)=upper(u.twofa_subject) and upper(ac.usuario)=upper(p_usuario)
          and ac.codigo=p_codigo and ac.usado=true and ac.created_at>now()-interval '5 minutes' and ac.expira_at>now()
        order by ac.created_at desc limit 1 for update;
        if c.id is null then return jsonb_build_object('ok',false,'error','PROOF_INVALID'); end if;
        if exists(select 1 from public.aos_cia_admin_sessions s where s.source_auth_code_id=c.id) then
          return jsonb_build_object('ok',false,'error','PROOF_ALREADY_CLAIMED');
        end if;
        update public.aos_cia_admin_sessions set revoked=true where user_id=u.id and revoked=false;
        v_token:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
        v_hash:=encode(extensions.digest(v_token,'sha256'),'hex'); v_exp:=now()+interval '8 hours';
        begin
          insert into public.aos_cia_admin_sessions(token_hash,user_id,usuario,expires_at,source_auth_code_id)
          values(v_hash,u.id,u.nombre,v_exp,c.id);
        exception when unique_violation then return jsonb_build_object('ok',false,'error','PROOF_ALREADY_CLAIMED'); end;
        insert into public.aos_security_log(usuario,accion,detalles)
        values(u.nombre,'SALES_INTELLIGENCE_SESSION_CLAIMED',jsonb_build_object('user_id',u.id,'expires_at',v_exp));
        return jsonb_build_object('ok',true,'token',v_token,'expires_at',v_exp,'panel','admin-sales-intelligence');
      end;
      $body$
    $fn$;

    execute $fn$
      create or replace function public.aos_sales_intelligence_set_access(
        p_token text,p_target_user_id uuid,p_enabled boolean
      ) returns jsonb
      language plpgsql security definer set search_path=''
      as $body$
      declare v_hash text; v_actor record; v_target record;
      begin
        if coalesce(length(p_token),0)<32 or p_target_user_id is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
        v_hash:=encode(extensions.digest(p_token,'sha256'),'hex');
        select au.id,au.nombre into v_actor
        from public.aos_cia_admin_sessions s
        join public.aos_usuarios au on au.id=s.user_id
        join public.aos_sales_intelligence_access sia on sia.user_id=au.id and sia.enabled=true
        where s.token_hash=v_hash and s.revoked=false and s.expires_at>now() and au.activo=true
          and au.two_factor=true and au.nivel_jerarquia=1 and lower(coalesce(au.rol,''))='admin'
          and coalesce(au.paneles_acceso,'{}'::text[]) @> array['admin-sales-intelligence']::text[] limit 1;
        if v_actor.id is null then return jsonb_build_object('ok',false,'error','OWNER_ADMIN_REQUIRED'); end if;
        select au.id,au.nombre,au.activo,au.two_factor,au.nivel_jerarquia,au.rol,au.codigo_asesor,
               r.usuario as login_usuario,r.nombre as twofa_subject,r.estado as rrhh_estado,
               encode(extensions.digest(c.password_hash,'sha256'),'hex') as password_digest
        into v_target
        from public.aos_usuarios au
        join public.aos_rrhh r on r.codigo_asesor=au.codigo_asesor
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
          update public.aos_usuarios set paneles_acceso=case when coalesce(paneles_acceso,'{}'::text[]) @> array['admin-sales-intelligence']::text[] then coalesce(paneles_acceso,'{}'::text[]) else array_append(coalesce(paneles_acceso,'{}'::text[]),'admin-sales-intelligence') end,updated_at=now() where id=v_target.id;
        else
          update public.aos_sales_intelligence_access set enabled=false,granted_by=v_actor.id,updated_at=now() where user_id=v_target.id;
          update public.aos_usuarios set paneles_acceso=array_remove(coalesce(paneles_acceso,'{}'::text[]),'admin-sales-intelligence'),updated_at=now() where id=v_target.id;
          update public.aos_cia_admin_sessions set revoked=true where user_id=v_target.id and revoked=false;
        end if;
        insert into public.aos_security_log(usuario,accion,detalles)
        values(v_actor.nombre,case when coalesce(p_enabled,false) then 'SALES_INTELLIGENCE_ACCESS_GRANTED' else 'SALES_INTELLIGENCE_ACCESS_REVOKED' end,jsonb_build_object('actor_id',v_actor.id,'target_user_id',v_target.id));
        return jsonb_build_object('ok',true,'enabled',coalesce(p_enabled,false),'target_user_id',v_target.id);
      end;
      $body$
    $fn$;
  end if;
end;
$outer$;

-- Team UI keeps the same shape but derives the boolean from the private store.
create or replace view public.aos_team_full as
select u.id,u.codigo_asesor,u.nombre,u.apellidos,u.email,u.telefono,u.dni,u.rol,u.cargo,u.area,u.sede,
       u.activo,u.cuenta_activada,u.invitacion_enviada,u.two_factor,u.paneles_acceso,u.permisos,u.avatar_url,
       u.ultimo_login,u.nivel_jerarquia,u.acceso_geo,u.sedes_permitidas,u.cmp,u.servicios,u.bono_metas,u.sueldo,
       u.fecha_ingreso,u.tipo_contrato,u.fecha_nacimiento,u.lugar_nacimiento,u.pais,u.departamento,u.provincia,
       u.distrito,u.direccion,u.contacto_emergencia,u.telefono_personal,u.rh,
       r.usuario as username_login,
       exists(select 1 from public.aos_auth_credentials c where c.codigo_asesor=u.codigo_asesor) as tiene_password,
       r.meta as meta_rrhh,r.bonus_pct as bonus_pct_rrhh,r.estado as estado_rrhh
from public.aos_usuarios u
left join public.aos_rrhh r on r.codigo_asesor=u.codigo_asesor
where u.activo=true;

-- Kill browser-visible legacy auth/admin primitives. K1 server uses login_v2;
-- admin-team is migrated to the token-bound identity gateway in migration 522.
revoke all on function public.aos_login(text,text) from public,anon,authenticated,service_role;
revoke all on function public.aos_login_v2(text,text) from public,anon,authenticated;
grant execute on function public.aos_login_v2(text,text) to service_role;
revoke all on function public.aos_cambiar_password(text,text,text) from public,anon,authenticated,service_role;
revoke all on function public.aos_admin_cambiar_password(uuid,text) from public,anon,authenticated,service_role;
revoke all on function public.aos_admin_cambiar_password(text,text,text,text) from public,anon,authenticated,service_role;
revoke all on function public.aos_admin_crear_usuario(text,text,text,text,text,text,integer,text,text) from public,anon,authenticated,service_role;
revoke all on function public.aos_admin_cambiar_username(uuid,text) from public,anon,authenticated,service_role;
revoke all on function public.aos_admin_toggle_usuario(uuid,boolean) from public,anon,authenticated,service_role;
revoke all on function public.aos_admin_eliminar_usuario(uuid,text) from public,anon,authenticated,service_role;

-- Any proof created before the credential-store migration must be renewed.
update public.aos_auth_codes set usado=true where usado=false;

commit;
