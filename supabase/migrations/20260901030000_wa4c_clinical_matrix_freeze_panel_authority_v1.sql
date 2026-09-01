-- WA-4C.1 — Clinical Matrix Freeze + Panel Authority V1
-- 1) Freeze the currently approved professional/procedure matrix.
-- 2) Make Team > Roles & Permissions the explicit source of panel visibility.
-- 3) Route privilege-sensitive Team writes through a 2FA + hierarchy governed RPC.

-- ---------------------------------------------------------------------------
-- A. Freeze current clinical child-procedure inheritance without changing truth
-- ---------------------------------------------------------------------------
with selected_capabilities as (
  select distinct
    p.codigo_asesor,
    upper(trim(svc)) as capability
  from public.aos_perfiles_profesional p
  cross join lateral unnest(coalesce(p.servicios,'{}'::text[])) svc
  where p.visible is true
    and p.codigo_asesor in ('ZIV-002','ZIV-003','ZIV-004','ZIV-006','ZIV-007','ZIV-008')
),
procedures as (
  select distinct
    upper(trim(m.capability)) as capability,
    m.procedure_key,
    m.procedure_name
  from public.aos_booking_procedure_map_v1 m
  where m.active is true
),
capabilities_without_existing_scope as (
  select s.codigo_asesor,s.capability
  from selected_capabilities s
  where exists (
    select 1 from procedures p where p.capability=s.capability
  )
    and not exists (
      select 1
      from public.aos_professional_procedure_scope_v1 x
      where x.codigo_asesor=s.codigo_asesor
        and upper(trim(x.capability))=s.capability
    )
)
insert into public.aos_professional_procedure_scope_v1(
  codigo_asesor,capability,procedure_key,procedure_name,enabled,source,updated_at
)
select
  c.codigo_asesor,
  c.capability,
  p.procedure_key,
  p.procedure_name,
  true,
  'CLINICAL_MATRIX_FREEZE_V1',
  now()
from capabilities_without_existing_scope c
join procedures p on p.capability=c.capability
on conflict (codigo_asesor,capability,procedure_key) do nothing;

-- ---------------------------------------------------------------------------
-- B. Register admin surfaces that existed in the shell but were not selectable
-- ---------------------------------------------------------------------------
insert into public.aos_paneles_disponibles(id,nombre,icono,categoria,descripcion,orden)
values
  ('admin-catalogo','Catálogo Admin','📚','admin','Administración del catálogo y conocimiento comercial.',16),
  ('admin-inventario','Inventario Admin','📦','admin','Administración de inventario.',17),
  ('admin-studio','Ascenda Studio','◉','admin','Herramientas internas de Ascenda Studio.',18),
  ('admin-sentinel','Sentinel','◉','admin','Observabilidad y seguridad para owner/admin autorizado.',79)
on conflict (id) do update
set nombre=excluded.nombre,
    icono=excluded.icono,
    categoria=excluded.categoria,
    descripcion=excluded.descripcion,
    orden=excluded.orden;

-- Preserve the surfaces that level-1/2 admins already saw before this migration.
-- After this point they become removable/assignable explicitly from Team.
update public.aos_usuarios u
set paneles_acceso=(
      select array_agg(distinct x order by x)
      from unnest(
        coalesce(u.paneles_acceso,'{}'::text[])
        || array['admin-catalogo','admin-inventario','admin-studio','admin-sentinel']::text[]
      ) x
    ),
    updated_at=now()
where u.activo is true
  and coalesce(u.nivel_jerarquia,99)<=2;

-- ---------------------------------------------------------------------------
-- C. Govern privilege-sensitive Team writes
-- ---------------------------------------------------------------------------
create or replace function public.aos_team_set_access_v1(
  p_token text,
  p_target_user_id uuid,
  p_paneles text[],
  p_nivel integer
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid;
  v_actor_level integer;
  v_target_level integer;
  v_target_code text;
  v_target_role text;
  v_target_cargo text;
  v_target_area text;
  v_panels text[] := coalesce(p_paneles,'{}'::text[]);
  v_invalid text[];
  v_new_role text;
begin
  v_actor:=public.aos_app_actor_v3(p_token,'admin-team',true);
  if v_actor is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','TEAM_2FA_ADMIN_REQUIRED');
  end if;

  select u.nivel_jerarquia
    into v_actor_level
  from public.aos_usuarios u
  where u.id=v_actor and u.activo is true;

  if coalesce(v_actor_level,99)>2 then
    return pg_catalog.jsonb_build_object('ok',false,'error','TEAM_ADMIN_LEVEL_REQUIRED');
  end if;

  select u.nivel_jerarquia,u.codigo_asesor,u.rol,u.cargo,u.area
    into v_target_level,v_target_code,v_target_role,v_target_cargo,v_target_area
  from public.aos_usuarios u
  where u.id=p_target_user_id
  for update;

  if v_target_code is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','TARGET_NOT_FOUND');
  end if;

  if p_nivel is null or p_nivel<1 or p_nivel>5 then
    return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_HIERARCHY_LEVEL');
  end if;

  -- Level 1 is unique/supreme through this UI. It cannot be delegated.
  if p_nivel=1 and not (v_actor_level=1 and p_target_user_id=v_actor and coalesce(v_target_level,99)=1) then
    return pg_catalog.jsonb_build_object('ok',false,'error','SUPER_ADMIN_NOT_DELEGABLE');
  end if;
  if v_actor_level=1 and p_target_user_id=v_actor and p_nivel<>1 then
    return pg_catalog.jsonb_build_object('ok',false,'error','SUPER_ADMIN_SELF_DEMOTION_BLOCKED');
  end if;

  -- Level 2 cannot edit peers/superiors or promote into admin authority.
  if v_actor_level=2 and (coalesce(v_target_level,99)<=2 or p_nivel<=2) then
    return pg_catalog.jsonb_build_object('ok',false,'error','HIERARCHY_DENIED');
  end if;

  select array_agg(x)
    into v_invalid
  from (
    select distinct trim(p) as x
    from unnest(v_panels) p
    where coalesce(trim(p),'')<>''
      and not exists (
        select 1 from public.aos_paneles_disponibles d where d.id=trim(p)
      )
  ) q;
  if coalesce(pg_catalog.array_length(v_invalid,1),0)>0 then
    return pg_catalog.jsonb_build_object('ok',false,'error','UNKNOWN_PANEL','panels',to_jsonb(v_invalid));
  end if;

  -- Administration surfaces belong only to level 1/2 accounts.
  if p_nivel>2 and exists (
    select 1
    from unnest(v_panels) p
    join public.aos_paneles_disponibles d on d.id=trim(p)
    where d.categoria='admin'
  ) then
    return pg_catalog.jsonb_build_object('ok',false,'error','ADMIN_PANEL_REQUIRES_ADMIN_LEVEL');
  end if;

  -- Sales Intelligence remains owner-only by its certified contract.
  if p_nivel>1 and 'admin-sales-intelligence'=any(v_panels) then
    return pg_catalog.jsonb_build_object('ok',false,'error','SALES_INTELLIGENCE_OWNER_ONLY');
  end if;

  -- Keep the supreme account recoverable from Team even if every other panel is removed.
  if p_nivel=1 and not ('admin-team'=any(v_panels)) then
    v_panels:=v_panels||array['admin-team']::text[];
  end if;

  select coalesce(array_agg(distinct trim(x) order by trim(x)),'{}'::text[])
    into v_panels
  from unnest(v_panels) x
  where coalesce(trim(x),'')<>'';

  v_new_role:=case
    when p_nivel<=2 then 'admin'
    when upper(coalesce(v_target_cargo,'')) like '%MÉDIC%'
      or upper(coalesce(v_target_cargo,'')) like '%MEDIC%'
      or upper(coalesce(v_target_area,'')) in ('MÉDICA','MEDICA') then 'doctora'
    else coalesce(nullif(v_target_role,'admin'),'asesor')
  end;

  update public.aos_usuarios
  set paneles_acceso=v_panels,
      nivel_jerarquia=p_nivel,
      rol=v_new_role,
      updated_at=now()
  where id=p_target_user_id;

  insert into public.aos_log_auditoria(
    timestamp_reg,asesor,accion,referencia,detalle,tabla,usuario,registro_id,datos_new,metadata
  )
  select
    now(),
    coalesce(a.nombre,a.codigo_asesor,'ADMIN'),
    'TEAM_ACCESS_UPDATE',
    v_target_code,
    'Paneles y jerarquía actualizados desde Team con sesión 2FA gobernada',
    'aos_usuarios',
    coalesce(a.codigo_asesor,a.nombre),
    p_target_user_id::text,
    pg_catalog.jsonb_build_object('paneles_acceso',to_jsonb(v_panels),'nivel_jerarquia',p_nivel,'rol',v_new_role),
    pg_catalog.jsonb_build_object('source','TEAM_PANEL_AUTHORITY_V1','actor_id',v_actor)
  from public.aos_usuarios a
  where a.id=v_actor;

  return pg_catalog.jsonb_build_object(
    'ok',true,
    'target_user_id',p_target_user_id,
    'codigo_asesor',v_target_code,
    'paneles_acceso',to_jsonb(v_panels),
    'nivel_jerarquia',p_nivel,
    'rol',v_new_role
  );
end
$$;

revoke all on function public.aos_team_set_access_v1(text,uuid,text[],integer) from public;
grant execute on function public.aos_team_set_access_v1(text,uuid,text[],integer) to anon, authenticated, service_role;

-- Direct browser writes may still update non-sensitive profile fields for legacy
-- compatibility, but role/panel/hierarchy changes must pass through the RPC above.
create or replace function public.aos_guard_user_access_direct_write_v1()
returns trigger
language plpgsql
set search_path=''
as $$
begin
  if current_user in ('anon','authenticated') and (
    old.paneles_acceso is distinct from new.paneles_acceso
    or old.nivel_jerarquia is distinct from new.nivel_jerarquia
    or old.rol is distinct from new.rol
  ) then
    raise exception using errcode='42501', message='AOS_TEAM_ACCESS_RPC_REQUIRED';
  end if;
  return new;
end
$$;

drop trigger if exists trg_aos_guard_user_access_direct_write_v1 on public.aos_usuarios;
create trigger trg_aos_guard_user_access_direct_write_v1
before update of paneles_acceso,nivel_jerarquia,rol on public.aos_usuarios
for each row execute function public.aos_guard_user_access_direct_write_v1();
