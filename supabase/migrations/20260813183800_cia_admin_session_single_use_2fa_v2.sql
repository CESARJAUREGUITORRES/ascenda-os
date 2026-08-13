-- ASCENDA CIA Phase 5 hardening: a used 2FA proof may mint only one CIA admin session.

alter table public.aos_cia_admin_sessions
  add column if not exists source_auth_code_id uuid;

create unique index if not exists aos_cia_admin_sessions_source_auth_code_uidx
  on public.aos_cia_admin_sessions(source_auth_code_id)
  where source_auth_code_id is not null;

create or replace function public.aos_cia_claim_admin_session_v1(p_usuario text, p_codigo text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
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
  v_hash:=encode(digest(v_token,'sha256'),'hex');
  v_exp:=now()+interval '8 hours';

  begin
    insert into public.aos_cia_admin_sessions(token_hash,user_id,usuario,expires_at,source_auth_code_id)
    values(v_hash,u.id,u.nombre,v_exp,c.id);
  exception when unique_violation then
    return jsonb_build_object('ok',false,'error','PROOF_ALREADY_CLAIMED');
  end;

  return jsonb_build_object('ok',true,'token',v_token,'expires_at',v_exp);
end;
$$;

revoke all on function public.aos_cia_claim_admin_session_v1(text,text) from public;
grant execute on function public.aos_cia_claim_admin_session_v1(text,text) to anon, authenticated, service_role;
