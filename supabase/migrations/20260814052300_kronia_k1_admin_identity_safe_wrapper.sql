-- K1 — Browser-safe identity wrapper.
-- The implementation gateway from 522 becomes server-only. Browser callers use
-- this wrapper, which adds a second hierarchy check before delegation and keeps
-- the legacy admin-team create-user response shape without storing plaintext.

begin;

create or replace function public.aos_kronia_admin_identity_safe(
  p_token text,
  p_action text,
  p_target_user_id uuid default null,
  p_params jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = 'pg_catalog','extensions'
as $function$
declare
  v_auth jsonb;
  v_actor public.aos_usuarios%rowtype;
  v_target public.aos_usuarios%rowtype;
  v_action text := lower(trim(coalesce(p_action,'')));
  v_result jsonb;
begin
  v_auth:=public.aos_kronia_verify_token(p_token);
  if not coalesce((v_auth->>'ok')::boolean,false) or upper(coalesce(v_auth->>'rol',''))<>'ADMIN' then
    return jsonb_build_object('ok',false,'error','ADMIN_SESSION_REQUIRED');
  end if;

  select u.* into v_actor
  from public.aos_usuarios u
  where u.codigo_asesor=v_auth->>'id_asesor'
    and u.activo=true
    and lower(coalesce(u.rol,''))='admin'
    and coalesce(u.nivel_jerarquia,99) in (1,2)
  limit 1;
  if v_actor.id is null then return jsonb_build_object('ok',false,'error','ADMIN_IDENTITY_REQUIRED'); end if;

  if v_action not in ('update_profile','set_services','set_2fa','activate_account','change_password','change_username','toggle_active','delete_user','create_user','force_logout') then
    return jsonb_build_object('ok',false,'error','ACTION_NOT_ALLOWED');
  end if;

  if v_action='create_user' then
    if coalesce(nullif(p_params->>'nivel_jerarquia','')::integer,3)=1 and v_actor.nivel_jerarquia<>1 then
      return jsonb_build_object('ok',false,'error','OWNER_LEVEL_REQUIRED');
    end if;
  else
    if p_target_user_id is null then return jsonb_build_object('ok',false,'error','TARGET_REQUIRED'); end if;
    select u.* into v_target from public.aos_usuarios u where u.id=p_target_user_id limit 1;
    if v_target.id is null then return jsonb_build_object('ok',false,'error','TARGET_NOT_FOUND'); end if;
    -- Level 1 is the owner boundary. Level 2 ADMIN may manage ordinary users
    -- but may never mutate the owner account by changing username, password,
    -- activation, services, 2FA, profile or lifecycle state.
    if coalesce(v_target.nivel_jerarquia,99)=1 and v_actor.nivel_jerarquia<>1 then
      return jsonb_build_object('ok',false,'error','OWNER_LEVEL_REQUIRED');
    end if;
  end if;

  if v_action='force_logout' then
    update public.aos_kronia_tokens
    set revocado=true
    where id_asesor=v_target.codigo_asesor and not revocado;
    if to_regclass('public.aos_cia_admin_sessions') is not null then
      execute 'update public.aos_cia_admin_sessions set revoked=true where user_id=$1 and revoked=false'
      using v_target.id;
    end if;
    insert into public.aos_security_log(usuario,accion,detalles,ip)
    values(v_actor.nombre,'K1_ADMIN_IDENTITY_FORCE_LOGOUT',jsonb_build_object('actor_id',v_actor.id,'target_user_id',v_target.id),'k1-admin-gateway');
    return jsonb_build_object('ok',true,'action','force_logout','target_user_id',v_target.id);
  end if;

  v_result:=public.aos_kronia_admin_identity(p_token,v_action,p_target_user_id,coalesce(p_params,'{}'::jsonb));

  if v_action='create_user' and coalesce((v_result->>'ok')::boolean,false) then
    -- Compatibility aliases expected by admin-team.html. The generated password
    -- is returned once to the authorized ADMIN and is never written to RRHH/logs.
    return (v_result - 'temporary_password') || jsonb_build_object(
      'nombre',upper(trim(coalesce(p_params->>'nombre','')))||' '||upper(trim(coalesce(p_params->>'apellido',''))),
      'codigo',v_result->>'codigo_asesor',
      'username',v_result->>'username',
      'password',v_result->>'temporary_password',
      'email',nullif(lower(trim(coalesce(p_params->>'email',''))),'')
    );
  end if;
  return v_result;
end;
$function$;

-- The implementation function must never be directly browser-callable. Only
-- the hierarchy-safe wrapper is exposed to browser roles.
revoke all on function public.aos_kronia_admin_identity(text,text,uuid,jsonb)
  from public,anon,authenticated;
grant execute on function public.aos_kronia_admin_identity(text,text,uuid,jsonb) to service_role;

revoke all on function public.aos_kronia_admin_identity_safe(text,text,uuid,jsonb) from public;
grant execute on function public.aos_kronia_admin_identity_safe(text,text,uuid,jsonb)
  to anon,authenticated,service_role;

comment on function public.aos_kronia_admin_identity_safe(text,text,uuid,jsonb) is
'K1 browser-safe ADMIN identity gateway. Opaque token + live ADMIN hierarchy; owner/level-1 mutations require owner session.';

commit;
