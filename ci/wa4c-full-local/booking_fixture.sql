-- TEST ONLY — synthetic booking authority substrate for WA-4C FULL LOCAL.
create table if not exists public.aos_agenda_citas(
  id text primary key,
  fecha_cita date,
  tratamiento text,
  tipo_cita text,
  sede text,
  numero text,
  nombre text,
  apellido text,
  dni text,
  correo text,
  asesor text,
  id_asesor text,
  estado_cita text,
  venta_id_match text,
  obs text,
  ts_creado timestamptz default now(),
  ts_actualizado timestamptz default now(),
  hora_cita text,
  etiqueta_campana text,
  doctora text,
  tipo_atencion text,
  gcal_event_id text,
  origen_cita text,
  numero_limpio text,
  origen text,
  plan_item_id text,
  cotizacion_item_id text,
  sesion_numero integer,
  lead_id_origen bigint,
  llamada_id_origen bigint
);

create table if not exists public.aos_perfiles_profesional(
  id text primary key,
  codigo_asesor text not null,
  nombre_publico text not null,
  titulo text,
  especialidad text,
  servicios text[] default '{}',
  sede text,
  tipo text not null,
  costo_consulta numeric,
  visible boolean default true,
  orden integer,
  created_at timestamptz default now(),
  cmp text
);

create table if not exists public.aos_horarios_personal(
  id uuid primary key default gen_random_uuid(),
  personal text not null,
  fecha date not null,
  hora_inicio text not null,
  hora_fin text not null,
  sede text not null,
  rol text,
  activo boolean default true
);

-- Compact governed treatment authority required by the canonical booking capability resolver.
-- This remains TEST-only: the selected synthetic service is mirrored 1:1 as its own capability.
create table if not exists public.aos_cat_tratamientos(
  tratamiento text primary key,
  estado text default 'ACTIVO'
);

create table if not exists public.aos_pacientes(
  "ID_PACIENTE" text primary key,
  "Nombres" text,
  "Apellidos" text,
  "Teléfono" text,
  "Email" text,
  "N° documento" text,
  "SEDE_PRINCIPAL" text,
  "ESTADO_PACIENTE" text,
  numero_limpio text
);

create or replace function public.aos_rev_resolve_patient_identity_v2(p_lookup_type text,p_lookup_value text)
returns jsonb
language plpgsql
stable
as $$
begin
  if upper(coalesce(p_lookup_type,''))='PHONE' and regexp_replace(coalesce(p_lookup_value,''),'[^0-9]','','g')='51922222222' then
    return jsonb_build_object('status','IDENTITY_CONFLICT','candidate_count',2,'confidence_band','CONFLICT');
  end if;
  return jsonb_build_object('status','UNRESOLVED','candidate_count',0,'confidence_band','NONE');
end
$$;

grant select,insert,update on public.aos_agenda_citas,public.aos_perfiles_profesional,public.aos_horarios_personal,public.aos_pacientes to service_role;
grant select on public.aos_cat_tratamientos to service_role;
grant execute on function public.aos_rev_resolve_patient_identity_v2(text,text) to service_role;

insert into public.aos_perfiles_profesional(id,codigo_asesor,nombre_publico,sede,tipo,visible,orden)
values('wa4c-doctor-1','WA4C-DOC','DRA. TEST','TODAS','DOCTORA',true,1)
on conflict(id) do update set visible=true,sede='TODAS',tipo='DOCTORA',nombre_publico='DRA. TEST';

with d as (
  select current_date + case extract(isodow from current_date)::int when 6 then 2 when 7 then 1 else 1 end as target_date
)
insert into public.aos_horarios_personal(personal,fecha,hora_inicio,hora_fin,sede,rol,activo)
select 'DRA. TEST',target_date,'10:00','12:00','SAN ISIDRO','DOCTORA',true from d;

-- Keep the freshness watermark beyond the target date.
with d as (
  select current_date + case extract(isodow from current_date)::int when 6 then 2 when 7 then 1 else 1 end + 7 as future_date
)
insert into public.aos_horarios_personal(personal,fecha,hora_inicio,hora_fin,sede,rol,activo)
select 'DRA. TEST',future_date,'10:00','12:00','SAN ISIDRO','DOCTORA',true from d;

create table if not exists public.aos_wa4c_booking_test_fixture(
  id integer primary key,
  treatment_id uuid not null,
  professional_id text not null,
  target_date date not null,
  target_time text not null
);

with svc as (
  select id from public.aos_catalogo_servicios
  where upper(coalesce(tipo,'SERVICIO'))='SERVICIO' and upper(coalesce(estado,'ACTIVO'))='ACTIVO'
  order by nombre,id limit 1
), d as (
  select current_date + case extract(isodow from current_date)::int when 6 then 2 when 7 then 1 else 1 end as target_date
)
insert into public.aos_wa4c_booking_test_fixture(id,treatment_id,professional_id,target_date,target_time)
select 1,svc.id,'wa4c-doctor-1',d.target_date,'10:00' from svc cross join d
on conflict(id) do update set treatment_id=excluded.treatment_id,professional_id=excluded.professional_id,target_date=excluded.target_date,target_time=excluded.target_time;

update public.aos_catalogo_servicios s
set requiere_doctora=true,requiere_enfermeria=false
from public.aos_wa4c_booking_test_fixture f
where f.id=1 and s.id=f.treatment_id;

-- Mirror the exact selected service into the compact treatment authority so the
-- canonical capability resolver is exercised rather than stubbed.
insert into public.aos_cat_tratamientos(tratamiento,estado)
select s.nombre,'ACTIVO'
from public.aos_catalogo_servicios s
join public.aos_wa4c_booking_test_fixture f on f.treatment_id=s.id
where f.id=1
on conflict(tratamiento) do update set estado='ACTIVO';

grant select on public.aos_wa4c_booking_test_fixture to service_role;

create or replace function public.aos_slots_disponibles(p_profesional_id text,p_fecha date,p_sede text default null)
returns json
language plpgsql
as $$
declare
  v_prof public.aos_perfiles_profesional%rowtype;
  v_slots jsonb := '[]'::jsonb;
  v_h time;
  v_end time;
  v_count integer;
begin
  select * into v_prof from public.aos_perfiles_profesional where id=p_profesional_id and coalesce(visible,true)=true;
  if not found then return json_build_object('ok',false,'error','Profesional no encontrado'); end if;
  for v_h,v_end in
    select hora_inicio::time,hora_fin::time from public.aos_horarios_personal
    where activo=true and fecha=p_fecha and upper(personal) like '%TEST%'
      and (p_sede is null or upper(sede)=upper(p_sede))
  loop
    while v_h < v_end loop
      select count(*) into v_count from public.aos_agenda_citas
      where fecha_cita=p_fecha and substring(hora_cita from 1 for 5)=to_char(v_h,'HH24:MI')
        and upper(coalesce(doctora,'')) like '%TEST%' and upper(coalesce(estado_cita,''))<>'CANCELADA';
      if v_count < 5 then
        v_slots := v_slots || jsonb_build_array(jsonb_build_object('hora',to_char(v_h,'HH24:MI'),'sede',upper(coalesce(p_sede,'SAN ISIDRO')),'disponible',true,'libres',5-v_count,'capacidad',5));
      end if;
      v_h := v_h + interval '30 minutes';
    end loop;
  end loop;
  return json_build_object('ok',true,'fecha',p_fecha,'profesional',v_prof.nombre_publico,'slots',v_slots);
end
$$;

grant execute on function public.aos_slots_disponibles(text,date,text) to service_role;