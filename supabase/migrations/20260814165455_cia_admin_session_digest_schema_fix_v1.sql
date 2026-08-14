create or replace function public.aos_cia_verify_admin_session_v1(p_token text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $function$
declare
  v_hash text;
  v_user_id uuid;
  v_usuario text;
  v_exp timestamptz;
begin
  if p_token is null or length(p_token)<48 then
    return jsonb_build_object('ok',false);
  end if;
  v_hash:=encode(extensions.digest(p_token,'sha256'),'hex');
  select s.user_id,s.usuario,s.expires_at
  into v_user_id,v_usuario,v_exp
  from public.aos_cia_admin_sessions s
  join public.aos_usuarios u on u.id=s.user_id
  where s.token_hash=v_hash and not s.revoked and s.expires_at>now()
    and u.activo=true and lower(coalesce(u.rol,''))='admin'
  limit 1;
  if v_user_id is null then return jsonb_build_object('ok',false); end if;
  update public.aos_cia_admin_sessions set last_used_at=now() where token_hash=v_hash;
  return jsonb_build_object('ok',true,'user_id',v_user_id,'usuario',v_usuario,'expires_at',v_exp);
end;
$function$;

create or replace function public.aos_cia_issue_admin_session_v1(p_identity text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $function$
declare
  u record;
  v_token text;
  v_hash text;
  v_exp timestamptz;
begin
  select id,nombre into u
  from public.aos_usuarios
  where activo=true
    and lower(coalesce(rol,''))='admin'
    and upper(nombre)=upper(p_identity)
  limit 1;
  if not found then
    return jsonb_build_object('ok',false,'eligible',false);
  end if;
  v_token:=replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','');
  v_hash:=encode(extensions.digest(v_token,'sha256'),'hex');
  v_exp:=now()+interval '8 hours';
  insert into public.aos_cia_admin_sessions(token_hash,user_id,usuario,expires_at)
  values(v_hash,u.id,u.nombre,v_exp);
  return jsonb_build_object('ok',true,'eligible',true,'token',v_token,'expires_at',v_exp);
end;
$function$;

create or replace function public.aos_cia_claim_admin_session_v1(p_usuario text,p_codigo text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $function$
declare
  c record;
  u record;
  v_token text;
  v_hash text;
  v_exp timestamptz;
begin
  select id,usuario into c
  from public.aos_auth_codes
  where upper(usuario)=upper(p_usuario)
    and codigo=p_codigo
    and usado=true
    and created_at>now()-interval '5 minutes'
    and expira_at>now()-interval '5 minutes'
  order by created_at desc
  limit 1
  for update;

  if c.id is null then
    return jsonb_build_object('ok',false,'error','PROOF_INVALID');
  end if;

  if exists (
    select 1 from public.aos_cia_admin_sessions s
    where s.source_auth_code_id=c.id
  ) then
    return jsonb_build_object('ok',false,'error','PROOF_ALREADY_CLAIMED');
  end if;

  select id,nombre into u
  from public.aos_usuarios
  where activo=true
    and lower(coalesce(rol,''))='admin'
    and upper(nombre)=upper(c.usuario)
  limit 1;

  if u.id is null then
    return jsonb_build_object('ok',false,'error','ADMIN_REQUIRED');
  end if;

  update public.aos_cia_admin_sessions
  set revoked=true
  where user_id=u.id and revoked=false;

  v_token:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
  v_hash:=encode(extensions.digest(v_token,'sha256'),'hex');
  v_exp:=now()+interval '8 hours';

  begin
    insert into public.aos_cia_admin_sessions(token_hash,user_id,usuario,expires_at,source_auth_code_id)
    values(v_hash,u.id,u.nombre,v_exp,c.id);
  exception when unique_violation then
    return jsonb_build_object('ok',false,'error','PROOF_ALREADY_CLAIMED');
  end;

  return jsonb_build_object('ok',true,'token',v_token,'expires_at',v_exp);
end;
$function$;
