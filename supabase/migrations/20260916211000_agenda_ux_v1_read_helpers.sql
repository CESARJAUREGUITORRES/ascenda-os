begin;

-- AGENDA-UX-V1 additive read helpers. No changes to canonical booking writes.

create or replace function public.aos_booking_pool_days_v3(
  p_role text,
  p_anio integer,
  p_mes integer,
  p_sede text default 'SAN ISIDRO'
)
returns jsonb
language sql
stable
security definer
set search_path='public','pg_temp'
as $$
  select coalesce(
    jsonb_agg(x.fecha order by x.fecha),
    '[]'::jsonb
  )
  from (
    select distinct h.fecha::text as fecha
    from public.aos_horarios_personal h
    where h.activo=true
      and extract(year from h.fecha)=p_anio
      and extract(month from h.fecha)=p_mes
      and upper(coalesce(h.rol,''))=upper(trim(coalesce(p_role,'')))
      and upper(coalesce(h.sede,''))=upper(trim(coalesce(p_sede,'SAN ISIDRO')))
      and h.fecha>=current_date
  ) x;
$$;

revoke all on function public.aos_booking_pool_days_v3(text,integer,integer,text) from public;
grant execute on function public.aos_booking_pool_days_v3(text,integer,integer,text) to anon,authenticated,service_role;

create or replace function public.aos_booking_patient_lookup_v3(p_identity text)
returns jsonb
language plpgsql
stable
security definer
set search_path='public','pg_temp'
as $$
declare
  v_raw text:=trim(coalesce(p_identity,''));
  v_digits text:=regexp_replace(trim(coalesce(p_identity,'')),'[^0-9]','','g');
  v_row record;
begin
  if length(v_digits)<7 then
    return jsonb_build_object('ok',false,'status','IDENTITY_TOO_SHORT');
  end if;

  select
    p."ID_PACIENTE" as patient_id,
    p."Nombres" as nombre,
    p."Apellidos" as apellido,
    coalesce(p.numero_limpio,regexp_replace(coalesce(p."Teléfono",''),'[^0-9]','','g')) as numero,
    p."N° documento" as documento,
    p."Email" as email
  into v_row
  from public.aos_pacientes p
  where coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
    and (
      coalesce(p.numero_limpio,regexp_replace(coalesce(p."Teléfono",''),'[^0-9]','','g'))=v_digits
      or regexp_replace(coalesce(p."N° documento",''),'[^0-9]','','g')=v_digits
    )
  order by case when coalesce(p."ESTADO_PACIENTE",'')='ACTIVO' then 0 else 1 end,
           p."FECHA_REGISTRO" desc nulls last
  limit 1;

  if v_row.patient_id is null then
    return jsonb_build_object('ok',true,'found',false);
  end if;

  return jsonb_build_object(
    'ok',true,
    'found',true,
    'patient',jsonb_build_object(
      'patient_id',v_row.patient_id,
      'nombre',v_row.nombre,
      'apellido',v_row.apellido,
      'numero',v_row.numero,
      'documento',v_row.documento,
      'email',v_row.email
    )
  );
end
$$;

revoke all on function public.aos_booking_patient_lookup_v3(text) from public;
grant execute on function public.aos_booking_patient_lookup_v3(text) to anon,authenticated,service_role;

commit;