create extension if not exists pgcrypto;

create table if not exists public.aos_usuarios (
  id uuid primary key default gen_random_uuid(),
  activo boolean not null default true,
  rol text default 'admin',
  nivel_jerarquia integer default 1,
  paneles_acceso text[] default array['admin-chats']::text[]
);
create table if not exists public.aos_app_sessions_v3 (
  token_hash text primary key,
  user_id uuid not null references public.aos_usuarios(id) on delete cascade,
  assurance_level text not null,
  expires_at timestamptz not null,
  revoked boolean not null default false,
  last_used_at timestamptz,
  created_at timestamptz default now()
);
create or replace function public.aos_app_actor_v3(p_token text,p_required_panel text default null,p_require_2fa boolean default false)
returns uuid language sql stable security definer set search_path='' as $function$
 select u.id from public.aos_app_sessions_v3 s join public.aos_usuarios u on u.id=s.user_id
 where s.token_hash=encode(digest(coalesce(p_token,''),'sha256'),'hex') and not s.revoked and s.expires_at>now() and u.activo
   and (not coalesce(p_require_2fa,false) or s.assurance_level='PASSWORD_2FA')
   and (coalesce(trim(p_required_panel),'')='' or coalesce(u.paneles_acceso,'{}') @> array[p_required_panel]::text[] or (lower(coalesce(u.rol,''))='admin' and u.nivel_jerarquia=1))
 limit 1
$function$;

\i ci/wa1-secure-gateway/schema_contract.sql
