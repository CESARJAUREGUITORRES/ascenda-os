-- ASCENDA OS — Phase 2 prerequisite: independent 2FA + opaque app sessions
-- Additive. Does not revoke legacy paths; cutover happens in 20260814060000.

begin;

create extension if not exists pg_net;

create table if not exists public.aos_login_challenges_v3 (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references public.aos_usuarios(id) on delete cascade,
  code_hash text not null,
  expires_at timestamptz not null,
  attempts integer not null default 0 check (attempts between 0 and 5),
  consumed boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_aos_login_challenges_v3_user
  on public.aos_login_challenges_v3(user_id,created_at desc);
alter table public.aos_login_challenges_v3 enable row level security;
revoke all on table public.aos_login_challenges_v3 from public,anon,authenticated;
grant all on table public.aos_login_challenges_v3 to service_role;

create table if not exists public.aos_app_sessions_v3 (
  token_hash text primary key,
  user_id uuid not null references public.aos_usuarios(id) on delete cascade,
  assurance_level text not null check (assurance_level in ('PASSWORD','PASSWORD_2FA')),
  expires_at timestamptz not null,
  last_used_at timestamptz,
  revoked boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_aos_app_sessions_v3_user
  on public.aos_app_sessions_v3(user_id,expires_at desc);
alter table public.aos_app_sessions_v3 enable row level security;
revoke all on table public.aos_app_sessions_v3 from public,anon,authenticated;
grant all on table public.aos_app_sessions_v3 to service_role;

create or replace function public.aos_app_actor_v3(
  p_token text,
  p_required_panel text default null,
  p_require_2fa boolean default false
) returns uuid
language sql
stable
security definer
set search_path=''
as $function$
  select au.id
  from public.aos_app_sessions_v3 s
  join public.aos_usuarios au on au.id=s.user_id
  where s.token_hash=encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex')
    and s.revoked=false
    and s.expires_at>now()
    and au.activo=true
    and (not coalesce(p_require_2fa,false) or s.assurance_level='PASSWORD_2FA')
    and (
      coalesce(trim(p_required_panel),'')=''
      or coalesce(au.paneles_acceso,'{}'::text[]) @> array[p_required_panel]::text[]
      or (lower(coalesce(au.rol,''))='admin' and au.nivel_jerarquia=1)
    )
  limit 1
$function$;

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
begin
  if coalesce(length(trim(p_usuario)),0)<1 or coalesce(length(p_password),0)<1 then
    return jsonb_build_object('ok',false,'error','Credenciales inválidas');
  end if;

  select r.codigo_asesor,r.nombre,r.apellido,r.puesto,r.sede,r.usuario,
         r.password_hash,r.permisos,r.estado
    into v_user
  from public.aos_rrhh r
  left join public.aos_usuarios u on upper(u.nombre)=upper(r.nombre)
  where (lower(r.usuario)=lower(trim(p_usuario)) or lower(coalesce(u.email,''))=lower(trim(p_usuario)))
    and r.estado='ACTIVO'
  limit 1;

  if v_user.codigo_asesor is null then
    insert into public.aos_security_log(usuario,accion,detalles)
    values (left(trim(p_usuario),120),'login_failed',jsonb_build_object('reason','not_found','version','v3'));
    return jsonb_build_object('ok',false,'error','Usuario o email no encontrado');
  end if;

  select count(*) into v_attempts
  from public.aos_security_log
  where usuario=v_user.nombre and accion='login_failed' and created_at>now()-interval '15 minutes';
  if v_attempts>=5 then
    return jsonb_build_object('ok',false,'error','Cuenta bloqueada 15 min.');
  end if;

  if coalesce(v_user.password_hash,'') like '$2%' then
    v_password_ok := extensions.crypt(p_password,v_user.password_hash)=v_user.password_hash;
  else
    v_password_ok := coalesce(v_user.password_hash,'')=p_password;
  end if;

  if not v_password_ok then
    insert into public.aos_security_log(usuario,accion,detalles)
    values (v_user.nombre,'login_failed',jsonb_build_object('reason','password','version','v3'));
    return jsonb_build_object('ok',false,'error','Contraseña incorrecta');
  end if;

  -- Opportunistic migration of legacy plaintext-equivalent passwords to bcrypt.
  if coalesce(v_user.password_hash,'') not like '$2%' then
    update public.aos_rrhh
       set password_hash=extensions.crypt(p_password,extensions.gen_salt('bf',10))
     where codigo_asesor=v_user.codigo_asesor;
  end if;

  select u.* into v_udata
  from public.aos_usuarios u
  where u.codigo_asesor=v_user.codigo_asesor and u.activo=true
  limit 1;
  if v_udata.id is null then
    return jsonb_build_object('ok',false,'error','Usuario activo no encontrado');
  end if;
  v_paneles:=coalesce(v_udata.paneles_acceso,'{}'::text[]);

  if coalesce(v_udata.two_factor,false) then
    if coalesce(trim(v_udata.email),'')='' then
      return jsonb_build_object('ok',false,'error','2FA requiere un email válido');
    end if;

    -- 32 random bits -> six decimal digits; the plaintext exists only in this function invocation.
    v_code:=lpad((((('x'||substr(encode(extensions.gen_random_bytes(4),'hex'),1,8))::bit(32)::bigint)%1000000))::text,6,'0');
    v_challenge:=extensions.gen_random_uuid();

    delete from public.aos_login_challenges_v3
     where user_id=v_udata.id and (consumed=true or expires_at<=now() or created_at<now()-interval '1 day');
    update public.aos_login_challenges_v3 set consumed=true
     where user_id=v_udata.id and consumed=false;

    insert into public.aos_login_challenges_v3(id,user_id,code_hash,expires_at)
    values (
      v_challenge,
      v_udata.id,
      encode(extensions.digest(v_challenge::text||':'||v_code,'sha256'),'hex'),
      now()+interval '5 minutes'
    );

    select i.api_key into v_api_key
    from public.aos_integraciones i
    where (lower(coalesce(i.tipo,''))='resend' or lower(coalesce(i.nombre,'')) like '%resend%')
      and coalesce(length(i.api_key),0)>10
    order by coalesce(i.principal,false) desc,i.updated_at desc nulls last
    limit 1;

    if v_api_key is null then
      update public.aos_login_challenges_v3 set consumed=true where id=v_challenge;
      insert into public.aos_security_log(usuario,accion,detalles)
      values (v_user.nombre,'2fa_delivery_failed',jsonb_build_object('reason','provider_unavailable','version','v3'));
      return jsonb_build_object('ok',false,'error','No fue posible enviar el código 2FA');
    end if;

    select net.http_post(
      url:='https://api.resend.com/emails',
      headers:=jsonb_build_object(
        'Authorization','Bearer '||v_api_key,
        'Content-Type','application/json'
      ),
      body:=jsonb_build_object(
        'from','Clínica Zi Vital <info@zivital.pe>',
        'to',jsonb_build_array(v_udata.email),
        'subject','Código de acceso ASCENDA',
        'html','<div style="font-family:Arial,sans-serif"><h2>ASCENDA OS</h2><p>Tu código de acceso es:</p><p style="font-size:32px;font-weight:700;letter-spacing:6px">'||v_code||'</p><p>Vence en 5 minutos. Si no solicitaste este acceso, ignora este mensaje.</p></div>'
      )
    ) into v_req;

    insert into public.aos_security_log(usuario,accion,detalles)
    values (v_user.nombre,'2fa_challenge_sent',jsonb_build_object('challenge_id',v_challenge,'request_id',v_req,'version','v3'));

    return jsonb_build_object(
      'ok',true,'require_2fa',true,'challenge_id',v_challenge,
      'email_masked',substring(v_udata.email,1,3)||'***@'||split_part(v_udata.email,'@',2),
      'usuario',v_user.nombre,'codigo_asesor',v_user.codigo_asesor,
      'nombre',v_user.nombre,'apellido',coalesce(v_user.apellido,v_udata.cargo),
      'puesto',coalesce(v_udata.cargo,v_user.puesto),'sede',v_user.sede,
      'paneles_acceso',to_jsonb(v_paneles),'avatar_url',v_udata.avatar_url,
      'nivel',v_udata.nivel_jerarquia,'area',v_udata.area,'acceso_geo',v_udata.acceso_geo,
      'permisos',coalesce(v_user.permisos,'{}'::jsonb)
    );
  end if;

  v_token:=replace(extensions.gen_random_uuid()::text,'-','')||replace(extensions.gen_random_uuid()::text,'-','');
  v_token_hash:=encode(extensions.digest(v_token,'sha256'),'hex');
  v_expires:=now()+interval '8 hours';
  update public.aos_app_sessions_v3 set revoked=true where user_id=v_udata.id and revoked=false;
  insert into public.aos_app_sessions_v3(token_hash,user_id,assurance_level,expires_at)
  values (v_token_hash,v_udata.id,'PASSWORD',v_expires);

  insert into public.aos_security_log(usuario,accion,detalles)
  values (v_user.nombre,'login',jsonb_build_object('method','password_v3','expires_at',v_expires));

  return jsonb_build_object(
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

create or replace function public.aos_verificar_2fa_v3(
  p_challenge_id uuid,
  p_codigo text
) returns jsonb
language plpgsql
security definer
set search_path=''
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

  update public.aos_app_sessions_v3 set revoked=true where user_id=u.id and revoked=false;
  insert into public.aos_app_sessions_v3(token_hash,user_id,assurance_level,expires_at)
  values (v_token_hash,u.id,'PASSWORD_2FA',v_exp);

  -- Same opaque token also satisfies existing Sales Intelligence / Phase 2 admin gateways.
  if lower(coalesce(u.rol,''))='admin' and u.nivel_jerarquia in (1,2) then
    update public.aos_cia_admin_sessions set revoked=true where user_id=u.id and revoked=false;
    insert into public.aos_cia_admin_sessions(token_hash,user_id,usuario,expires_at,revoked,source_auth_code_id)
    values (v_token_hash,u.id,u.nombre,v_exp,false,null)
    on conflict (token_hash) do update set expires_at=excluded.expires_at,revoked=false;
  end if;

  insert into public.aos_security_log(usuario,accion,detalles)
  values (u.nombre,'login',jsonb_build_object('method','2fa_email_v3','expires_at',v_exp,'challenge_id',c.id));

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

revoke all on function public.aos_app_actor_v3(text,text,boolean) from public;
revoke all on function public.aos_login_v3(text,text) from public;
revoke all on function public.aos_verificar_2fa_v3(uuid,text) from public;
grant execute on function public.aos_login_v3(text,text) to anon,authenticated,service_role;
grant execute on function public.aos_verificar_2fa_v3(uuid,text) to anon,authenticated,service_role;
grant execute on function public.aos_app_actor_v3(text,text,boolean) to service_role;

commit;
