begin;

drop function if exists public.aos_booking_capability_audit_v1();
drop table if exists public.aos_booking_capability_map_v1;

-- Restore the capability function to the pre-reconciliation V2 definition.
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

commit;
