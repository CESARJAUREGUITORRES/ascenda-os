-- ASCENDA OS CIA V3 — F16 server-only Auth V3 session verification.
-- Used by server-authoritative transactional Email endpoints. Browser roles receive no EXECUTE.

begin;

create or replace function public.aos_cia_verify_app_session_v1(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_hash text;
  v_session record;
  v_user record;
begin
  if coalesce(pg_catalog.length(pg_catalog.btrim(p_token)),0) < 32
     or coalesce(pg_catalog.length(pg_catalog.btrim(p_token)),0) > 512 then
    return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  v_hash := pg_catalog.encode(extensions.digest(pg_catalog.btrim(p_token),'sha256'),'hex');

  select s.user_id,s.assurance_level,s.expires_at,s.revoked
    into v_session
  from public.aos_app_sessions_v3 s
  where s.token_hash=v_hash
    and s.revoked=false
    and s.expires_at>pg_catalog.now()
  limit 1;

  if v_session.user_id is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  select u.id,u.nombre,u.rol,u.activo,u.paneles_acceso
    into v_user
  from public.aos_usuarios u
  where u.id=v_session.user_id and u.activo=true
  limit 1;

  if v_user.id is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  return pg_catalog.jsonb_build_object(
    'ok',true,
    'user_id',v_user.id,
    'nombre',v_user.nombre,
    'rol',v_user.rol,
    'assurance_level',v_session.assurance_level,
    'expires_at',v_session.expires_at,
    'paneles_acceso',pg_catalog.to_jsonb(coalesce(v_user.paneles_acceso,'{}'::text[]))
  );
end
$function$;

revoke all on function public.aos_cia_verify_app_session_v1(text) from public,anon,authenticated;
grant execute on function public.aos_cia_verify_app_session_v1(text) to service_role;

comment on function public.aos_cia_verify_app_session_v1(text) is 'F16 server-only verifier for current Auth V3 opaque app tokens. Hashes token and validates active, unrevoked, unexpired session/user; never exposes token hashes.';

commit;
