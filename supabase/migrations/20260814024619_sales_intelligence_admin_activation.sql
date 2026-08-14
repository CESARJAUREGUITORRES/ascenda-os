-- ASCENDA OS — Sales Intelligence V2 admin-only activation
-- CRITICAL: protects financial aggregates behind a 2FA-derived opaque session
-- and an authoritative grant table that anon clients cannot modify.

begin;

create unique index if not exists aos_cia_admin_sessions_source_code_uidx
  on public.aos_cia_admin_sessions(source_auth_code_id)
  where source_auth_code_id is not null;

create table if not exists public.aos_sales_intelligence_access (
  user_id uuid primary key references public.aos_usuarios(id) on delete cascade,
  enabled boolean not null default false,
  granted_by uuid references public.aos_usuarios(id),
  granted_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.aos_sales_intelligence_access enable row level security;
revoke all on table public.aos_sales_intelligence_access from public, anon, authenticated;
grant all on table public.aos_sales_intelligence_access to service_role;

insert into public.aos_paneles_disponibles(id,nombre,icono,categoria,orden,descripcion)
values (
  'admin-sales-intelligence',
  'Sales Intelligence V2',
  '📈',
  'admin',
  75,
  'Métricas financieras de solo lectura. Requiere rol administrador, 2FA y autorización explícita.'
)
on conflict (id) do update
set nombre=excluded.nombre,
    icono=excluded.icono,
    categoria=excluded.categoria,
    orden=excluded.orden,
    descripcion=excluded.descripcion;

create or replace function public.aos_sales_intelligence_claim_session(
  p_usuario text,
  p_codigo text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  c record;
  u record;
  v_token text;
  v_hash text;
  v_exp timestamptz;
begin
  select ac.id, ac.usuario
    into c
  from public.aos_auth_codes ac
  where upper(ac.usuario)=upper(p_usuario)
    and ac.codigo=p_codigo
    and ac.usado=true
    and ac.created_at>now()-interval '5 minutes'
    and ac.expira_at>now()-interval '5 minutes'
  order by ac.created_at desc
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

  select au.id, au.nombre
    into u
  from public.aos_usuarios au
  join public.aos_sales_intelligence_access sia
    on sia.user_id=au.id and sia.enabled=true
  where au.activo=true
    and au.two_factor=true
    and au.nivel_jerarquia in (1,2)
    and lower(coalesce(au.rol,''))='admin'
    and coalesce(au.paneles_acceso,'{}'::text[]) @> array['admin-sales-intelligence']::text[]
    and upper(au.nombre)=upper(c.usuario)
  limit 1;

  if u.id is null then
    return jsonb_build_object('ok',false,'error','SALES_INTELLIGENCE_ACCESS_REQUIRED');
  end if;

  update public.aos_cia_admin_sessions
  set revoked=true
  where user_id=u.id and revoked=false;

  v_token:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
  v_hash:=encode(extensions.digest(v_token,'sha256'),'hex');
  v_exp:=now()+interval '8 hours';

  begin
    insert into public.aos_cia_admin_sessions(
      token_hash,user_id,usuario,expires_at,source_auth_code_id
    ) values (
      v_hash,u.id,u.nombre,v_exp,c.id
    );
  exception when unique_violation then
    return jsonb_build_object('ok',false,'error','PROOF_ALREADY_CLAIMED');
  end;

  insert into public.aos_security_log(usuario,accion,detalles)
  values (u.nombre,'SALES_INTELLIGENCE_SESSION_CLAIMED',
          jsonb_build_object('user_id',u.id,'expires_at',v_exp));

  return jsonb_build_object(
    'ok',true,
    'token',v_token,
    'expires_at',v_exp,
    'panel','admin-sales-intelligence'
  );
end;
$function$;

create or replace function public.aos_sales_intelligence_gateway(
  p_token text,
  p_anio integer,
  p_sede text default '',
  p_asesor text default ''
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_hash text;
  v_user_id uuid;
  v_sede text;
  v_result jsonb;
begin
  if coalesce(length(p_token),0)<32 or p_anio not between 2020 and 2100 then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  v_sede:=upper(trim(coalesce(p_sede,'')));
  if v_sede not in ('','SAN ISIDRO','PUEBLO LIBRE') then
    return jsonb_build_object('ok',false,'error','INVALID_FILTER');
  end if;

  v_hash:=encode(extensions.digest(p_token,'sha256'),'hex');

  select s.user_id
    into v_user_id
  from public.aos_cia_admin_sessions s
  join public.aos_usuarios au on au.id=s.user_id
  join public.aos_sales_intelligence_access sia
    on sia.user_id=au.id and sia.enabled=true
  where s.token_hash=v_hash
    and s.revoked=false
    and s.expires_at>now()
    and au.activo=true
    and au.two_factor=true
    and au.nivel_jerarquia in (1,2)
    and lower(coalesce(au.rol,''))='admin'
    and coalesce(au.paneles_acceso,'{}'::text[]) @> array['admin-sales-intelligence']::text[]
  limit 1;

  if v_user_id is null then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  update public.aos_cia_admin_sessions
  set last_used_at=now()
  where token_hash=v_hash;

  v_result:=public.aos_sales_intelligence_summary(
    p_anio,
    v_sede,
    coalesce(p_asesor,'')
  );

  return v_result;
end;
$function$;

create or replace function public.aos_sales_intelligence_set_access(
  p_token text,
  p_target_user_id uuid,
  p_enabled boolean
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_hash text;
  v_actor record;
  v_target record;
begin
  if coalesce(length(p_token),0)<32 or p_target_user_id is null then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  v_hash:=encode(extensions.digest(p_token,'sha256'),'hex');

  select au.id,au.nombre
    into v_actor
  from public.aos_cia_admin_sessions s
  join public.aos_usuarios au on au.id=s.user_id
  join public.aos_sales_intelligence_access sia
    on sia.user_id=au.id and sia.enabled=true
  where s.token_hash=v_hash
    and s.revoked=false
    and s.expires_at>now()
    and au.activo=true
    and au.two_factor=true
    and au.nivel_jerarquia=1
    and lower(coalesce(au.rol,''))='admin'
    and coalesce(au.paneles_acceso,'{}'::text[]) @> array['admin-sales-intelligence']::text[]
  limit 1;

  if v_actor.id is null then
    return jsonb_build_object('ok',false,'error','OWNER_ADMIN_REQUIRED');
  end if;

  select au.id,au.nombre,au.activo,au.two_factor,au.nivel_jerarquia,au.rol
    into v_target
  from public.aos_usuarios au
  where au.id=p_target_user_id
  limit 1
  for update;

  if v_target.id is null then
    return jsonb_build_object('ok',false,'error','TARGET_NOT_FOUND');
  end if;

  if coalesce(p_enabled,false) and not (
    coalesce(v_target.activo,false)
    and coalesce(v_target.two_factor,false)
    and v_target.nivel_jerarquia in (1,2)
    and lower(coalesce(v_target.rol,''))='admin'
  ) then
    return jsonb_build_object('ok',false,'error','TARGET_ADMIN_2FA_REQUIRED');
  end if;

  insert into public.aos_sales_intelligence_access(
    user_id,enabled,granted_by,granted_at,updated_at
  ) values (
    v_target.id,coalesce(p_enabled,false),v_actor.id,now(),now()
  )
  on conflict (user_id) do update
  set enabled=excluded.enabled,
      granted_by=excluded.granted_by,
      granted_at=case
        when excluded.enabled and not public.aos_sales_intelligence_access.enabled
          then now()
        else public.aos_sales_intelligence_access.granted_at
      end,
      updated_at=now();

  if coalesce(p_enabled,false) then
    update public.aos_usuarios
    set paneles_acceso=case
          when coalesce(paneles_acceso,'{}'::text[]) @> array['admin-sales-intelligence']::text[]
            then coalesce(paneles_acceso,'{}'::text[])
          else array_append(coalesce(paneles_acceso,'{}'::text[]),'admin-sales-intelligence')
        end,
        updated_at=now()
    where id=v_target.id;
  else
    update public.aos_usuarios
    set paneles_acceso=array_remove(coalesce(paneles_acceso,'{}'::text[]),'admin-sales-intelligence'),
        updated_at=now()
    where id=v_target.id;

    update public.aos_cia_admin_sessions
    set revoked=true
    where user_id=v_target.id and revoked=false;
  end if;

  insert into public.aos_security_log(usuario,accion,detalles)
  values (
    v_actor.nombre,
    case when coalesce(p_enabled,false)
      then 'SALES_INTELLIGENCE_ACCESS_GRANTED'
      else 'SALES_INTELLIGENCE_ACCESS_REVOKED'
    end,
    jsonb_build_object('actor_id',v_actor.id,'target_user_id',v_target.id)
  );

  return jsonb_build_object(
    'ok',true,
    'enabled',coalesce(p_enabled,false),
    'target_user_id',v_target.id
  );
end;
$function$;

create or replace function public.aos_sales_intelligence_guard_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if not coalesce(new.activo,false)
     or not coalesce(new.two_factor,false)
     or new.nivel_jerarquia not in (1,2)
     or lower(coalesce(new.rol,''))<>'admin'
     or not (
       coalesce(new.paneles_acceso,'{}'::text[]) @>
       array['admin-sales-intelligence']::text[]
     )
  then
    update public.aos_sales_intelligence_access
    set enabled=false,updated_at=now()
    where user_id=new.id and enabled=true;

    update public.aos_cia_admin_sessions
    set revoked=true
    where user_id=new.id and revoked=false;
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_aos_sales_intelligence_guard_user on public.aos_usuarios;
create trigger trg_aos_sales_intelligence_guard_user
after update of activo,two_factor,nivel_jerarquia,rol,paneles_acceso
on public.aos_usuarios
for each row
execute function public.aos_sales_intelligence_guard_user();

revoke all on function public.aos_sales_intelligence_claim_session(text,text) from public;
revoke all on function public.aos_sales_intelligence_gateway(text,integer,text,text) from public;
revoke all on function public.aos_sales_intelligence_set_access(text,uuid,boolean) from public;
grant execute on function public.aos_sales_intelligence_claim_session(text,text) to anon,authenticated,service_role;
grant execute on function public.aos_sales_intelligence_gateway(text,integer,text,text) to anon,authenticated,service_role;
grant execute on function public.aos_sales_intelligence_set_access(text,uuid,boolean) to anon,authenticated,service_role;

revoke execute on function public.aos_sales_intelligence_summary(integer,text,text)
  from public,anon,authenticated;
grant execute on function public.aos_sales_intelligence_summary(integer,text,text)
  to service_role;

with initial_admin as (
  select au.id
  from public.aos_usuarios au
  where au.activo=true
    and au.two_factor=true
    and au.nivel_jerarquia=1
    and lower(coalesce(au.rol,''))='admin'
  order by au.created_at nulls last,au.id
  limit 1
)
insert into public.aos_sales_intelligence_access(
  user_id,enabled,granted_by,granted_at,updated_at
)
select id,true,id,now(),now()
from initial_admin
on conflict (user_id) do update
set enabled=true,granted_by=excluded.granted_by,updated_at=now();

update public.aos_usuarios au
set paneles_acceso=case
      when coalesce(au.paneles_acceso,'{}'::text[]) @> array['admin-sales-intelligence']::text[]
        then coalesce(au.paneles_acceso,'{}'::text[])
      else array_append(coalesce(au.paneles_acceso,'{}'::text[]),'admin-sales-intelligence')
    end,
    updated_at=now()
where au.id in (
  select sia.user_id
  from public.aos_sales_intelligence_access sia
  where sia.enabled=true
);

comment on table public.aos_sales_intelligence_access is
  'Authoritative grants for Sales Intelligence V2. Never writable by anon clients.';
comment on function public.aos_sales_intelligence_gateway(text,integer,text,text) is
  'Read-only Sales Intelligence gateway protected by a 2FA-derived opaque session and explicit admin grant.';

commit;
