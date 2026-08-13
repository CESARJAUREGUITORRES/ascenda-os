-- CIA Phase 5 — private ADMIN session used only by Bases & Audiencias.
begin;
create table if not exists public.aos_cia_admin_sessions(
  token_hash text primary key,user_id uuid not null,usuario text not null,expires_at timestamptz not null,
  last_used_at timestamptz,revoked boolean not null default false,created_at timestamptz not null default now()
);
alter table public.aos_cia_admin_sessions enable row level security;
revoke all on public.aos_cia_admin_sessions from public,anon,authenticated;
grant select,insert,update,delete on public.aos_cia_admin_sessions to service_role;

create or replace function public.aos_cia_issue_admin_session_v1(p_identity text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare u record;v_token text;v_hash text;v_exp timestamptz;
begin
 select id,nombre into u from public.aos_usuarios
 where activo=true and lower(coalesce(rol,''))='admin' and upper(nombre)=upper(p_identity) limit 1;
 if not found then return jsonb_build_object('ok',false,'eligible',false);end if;
 v_token:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
 v_hash:=encode(digest(v_token,'sha256'),'hex');v_exp:=now()+interval '8 hours';
 insert into public.aos_cia_admin_sessions(token_hash,user_id,usuario,expires_at) values(v_hash,u.id,u.nombre,v_exp);
 return jsonb_build_object('ok',true,'eligible',true,'token',v_token,'expires_at',v_exp);
end;$$;

create or replace function public.aos_cia_verify_admin_session_v1(p_token text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_hash text;v_user_id uuid;v_usuario text;v_exp timestamptz;
begin
 if p_token is null or length(p_token)<48 then return jsonb_build_object('ok',false);end if;
 v_hash:=encode(digest(p_token,'sha256'),'hex');
 select s.user_id,s.usuario,s.expires_at into v_user_id,v_usuario,v_exp
 from public.aos_cia_admin_sessions s join public.aos_usuarios u on u.id=s.user_id
 where s.token_hash=v_hash and not s.revoked and s.expires_at>now()
   and u.activo=true and lower(coalesce(u.rol,''))='admin' limit 1;
 if v_user_id is null then return jsonb_build_object('ok',false);end if;
 update public.aos_cia_admin_sessions set last_used_at=now() where token_hash=v_hash;
 return jsonb_build_object('ok',true,'user_id',v_user_id,'usuario',v_usuario,'expires_at',v_exp);
end;$$;

-- Claim only after the existing ASCENDA 2FA verifier marked a recent code as used.
create or replace function public.aos_cia_claim_admin_session_v1(p_usuario text,p_codigo text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare c record;u record;v_token text;v_hash text;v_exp timestamptz;
begin
 select id,usuario into c from public.aos_auth_codes
 where upper(usuario)=upper(p_usuario) and codigo=p_codigo and usado=true
   and created_at>now()-interval '5 minutes' and expira_at>now()-interval '5 minutes'
 order by created_at desc limit 1;
 if c.id is null then return jsonb_build_object('ok',false,'error','PROOF_INVALID');end if;
 select id,nombre into u from public.aos_usuarios
 where activo=true and lower(coalesce(rol,''))='admin' and upper(nombre)=upper(c.usuario) limit 1;
 if u.id is null then return jsonb_build_object('ok',false,'error','ADMIN_REQUIRED');end if;
 delete from public.aos_cia_admin_sessions where user_id=u.id and revoked=false;
 v_token:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
 v_hash:=encode(digest(v_token,'sha256'),'hex');v_exp:=now()+interval '8 hours';
 insert into public.aos_cia_admin_sessions(token_hash,user_id,usuario,expires_at) values(v_hash,u.id,u.nombre,v_exp);
 return jsonb_build_object('ok',true,'token',v_token,'expires_at',v_exp);
end;$$;

revoke all on function public.aos_cia_issue_admin_session_v1(text),public.aos_cia_verify_admin_session_v1(text) from public,anon,authenticated;
grant execute on function public.aos_cia_issue_admin_session_v1(text),public.aos_cia_verify_admin_session_v1(text) to service_role;
revoke all on function public.aos_cia_claim_admin_session_v1(text,text) from public;
grant execute on function public.aos_cia_claim_admin_session_v1(text,text) to anon,authenticated,service_role;
commit;
