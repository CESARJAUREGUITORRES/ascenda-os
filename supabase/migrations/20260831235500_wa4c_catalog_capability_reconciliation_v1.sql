-- WA-4C catalog capability reconciliation V1
-- Explicit, auditable bridge from detailed catalog service -> Panel Equipo skill authority.
-- Only deterministic aliases are seeded. Unknown/ambiguous services remain fail-closed.

begin;

create table if not exists public.aos_booking_capability_map_v1 (
  service_name_norm text primary key,
  capability text not null,
  evidence_ref text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.aos_booking_capability_map_v1 is
'Governed exact-name bridge from aos_catalogo_servicios to Panel Equipo skill authority. No fuzzy clinical inference is allowed here.';

insert into public.aos_booking_capability_map_v1(service_name_norm,capability,evidence_ref,active)
values
  (public.aos_booking_norm_v1('ENZIMAS CORP BRAZOS x1'),'ENZIMAS CORPORALES','CATALOG_NAME_EXACT:ENZIMAS_CORP_BRAZOS',true),
  (public.aos_booking_norm_v1('ENZIMAS CORP BRAZOS x3'),'ENZIMAS CORPORALES','CATALOG_NAME_EXACT:ENZIMAS_CORP_BRAZOS',true),
  (public.aos_booking_norm_v1('MCCM EXO TRX x1'),'EXOSOMAS','CATALOG_NAME_EXACT:MCCM_EXO_TRX',true),
  (public.aos_booking_norm_v1('MCCM EXO TRX x3'),'EXOSOMAS','CATALOG_NAME_EXACT:MCCM_EXO_TRX',true)
on conflict(service_name_norm) do update
set capability=excluded.capability,
    evidence_ref=excluded.evidence_ref,
    active=excluded.active,
    updated_at=now();

create or replace function public.aos_booking_capability_for_service_v1(p_treatment_id uuid)
returns text
language plpgsql
stable
security definer
set search_path='public'
as $$
declare
  v_t public.aos_catalogo_servicios%rowtype;
  v_cap text;
  v_name text;
  v_cat text;
begin
  select * into v_t
  from public.aos_catalogo_servicios
  where id=p_treatment_id
    and upper(coalesce(estado,'ACTIVO'))='ACTIVO'
    and upper(coalesce(tipo,'SERVICIO'))='SERVICIO';
  if not found then return null; end if;

  v_name:=public.aos_booking_norm_v1(v_t.nombre);
  v_cat:=public.aos_booking_norm_v1(v_t.categoria);

  -- Highest authority: explicit exact-name reconciliation table.
  select m.capability into v_cap
  from public.aos_booking_capability_map_v1 m
  where m.active=true and m.service_name_norm=v_name
  limit 1;
  if v_cap is not null then return v_cap; end if;

  -- Existing governed broad treatment authority.
  select c.tratamiento into v_cap
  from public.aos_cat_tratamientos c
  where upper(coalesce(c.estado,'ACTIVO'))='ACTIVO'
    and (
      v_name=public.aos_booking_norm_v1(c.tratamiento)
      or v_name like '%'||public.aos_booking_norm_v1(c.tratamiento)||'%'
      or v_cat=public.aos_booking_norm_v1(c.tratamiento)
    )
  order by
    case
      when v_name=public.aos_booking_norm_v1(c.tratamiento) then 0
      when v_name like '%'||public.aos_booking_norm_v1(c.tratamiento)||'%' then 1
      else 2
    end,
    length(public.aos_booking_norm_v1(c.tratamiento)) desc
  limit 1;
  if v_cap is not null then return v_cap; end if;

  -- Conservative aliases only. Anything else remains fail-closed.
  if v_cat='RF FRACCIONADA' then return 'RADIOFRECUENCIA FRACCIONADA'; end if;
  if v_cat='TOXINA' then return 'TOXINA'; end if;
  if v_cat='BIOESTIMULADOR' then return 'BIOESTIMULADOR'; end if;
  if v_cat='CRIOLIPOLISIS' then return 'CRIOLIPOLISIS'; end if;
  if v_cat='HIFU' then return 'HIFU'; end if;
  if v_cat='CONSULTA' and v_name like '%CONSULTA%' then return 'CONSULTA MEDICA'; end if;
  if v_cat='ENZIMAS' and v_name like '%FACIAL%' then return 'ENZIMAS FACIALES'; end if;
  if v_cat='ENZIMAS' and (v_name like '%CORP%' or v_name like '%SHAPE%') then return 'ENZIMAS CORPORALES'; end if;
  if v_cat='MESOTERAPIA' and v_name like '%CAPILAR%' then return 'MESOTERAPIA CAPILAR'; end if;
  if v_cat='MESOTERAPIA' and v_name like '%PLASMA%' then return 'PRP FACIAL'; end if;
  if v_cat='FACIALES' and v_name like '%HIDRO%' then return 'HIDROFACIAL'; end if;
  return null;
end
$$;

revoke all on function public.aos_booking_capability_for_service_v1(uuid) from public;
grant execute on function public.aos_booking_capability_for_service_v1(uuid) to anon,authenticated,service_role;

create or replace function public.aos_booking_capability_audit_v1()
returns jsonb
language sql
stable
security definer
set search_path='public'
as $$
  with x as (
    select s.id,s.nombre,s.categoria,s.requiere_doctora,s.requiere_enfermeria,
           public.aos_booking_capability_for_service_v1(s.id) capability
    from public.aos_catalogo_servicios s
    where upper(coalesce(s.estado,'ACTIVO'))='ACTIVO'
      and upper(coalesce(s.tipo,'SERVICIO'))='SERVICIO'
  )
  select jsonb_build_object(
    'total_active_services',count(*),
    'mapped_capability',count(*) filter(where capability is not null),
    'unmapped_capability',count(*) filter(where capability is null),
    'single_role_mapped',count(*) filter(where capability is not null and (coalesce(requiere_doctora,false) <> coalesce(requiere_enfermeria,false))),
    'dual_role_human',count(*) filter(where coalesce(requiere_doctora,false) and coalesce(requiere_enfermeria,false)),
    'role_unspecified_human',count(*) filter(where not coalesce(requiere_doctora,false) and not coalesce(requiere_enfermeria,false))
  )
  from x;
$$;

revoke all on function public.aos_booking_capability_audit_v1() from public,anon;
grant execute on function public.aos_booking_capability_audit_v1() to authenticated,service_role;

revoke all on table public.aos_booking_capability_map_v1 from public,anon,authenticated;
grant select,insert,update,delete on table public.aos_booking_capability_map_v1 to service_role;

commit;
