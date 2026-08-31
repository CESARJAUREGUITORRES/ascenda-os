-- WA-4C booking authority V2
-- Panel Equipo = skill authority (aos_perfiles_profesional.servicios)
-- Catalog = clinical-role authority (aos_catalogo_servicios)
-- Horarios = date/site presence authority (aos_horarios_personal)
-- DOCTORA = exact provider; ENFERMERIA = site pool with capacity 2 per eligible nurse.
-- Production remains HUMAN_ONLY / SAFE-OFF.

begin;

create or replace function public.aos_booking_norm_v1(p_value text)
returns text
language sql
immutable
parallel safe
as $$
  select trim(regexp_replace(
    upper(translate(coalesce(p_value,''),'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNAEIOUUN')),
    '[^A-Z0-9]+',' ','g'
  ));
$$;

create or replace function public.aos_booking_profile_key_v1(p_name text)
returns text
language sql
immutable
parallel safe
as $$
  select split_part(
    regexp_replace(public.aos_booking_norm_v1(p_name),'^(DRA|DR|LIC|ENF) ',''),
    ' ',1
  );
$$;

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

create or replace function public.aos_booking_availability_v2(
  p_treatment_id uuid,
  p_fecha date,
  p_sede text,
  p_profesional_id text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path='public'
as $$
declare
  v_t public.aos_catalogo_servicios%rowtype;
  v_role text;
  v_mode text;
  v_capability text;
  v_site text;
  v_latest date;
  v_slots jsonb := '[]'::jsonb;
  v_providers jsonb := '[]'::jsonb;
  v_p record;
  v_h record;
  v_time time;
  v_min_start time;
  v_max_end time;
  v_members int;
  v_capacity int;
  v_occupied int;
  v_names jsonb;
  v_step interval;
begin
  v_site:=upper(replace(trim(coalesce(p_sede,'')),'_',' '));
  if p_fecha is null or v_site not in ('SAN ISIDRO','PUEBLO LIBRE') then
    return jsonb_build_object('ok',false,'status','INVALID_DATE_OR_SITE');
  end if;

  select * into v_t
  from public.aos_catalogo_servicios
  where id=p_treatment_id
    and upper(coalesce(estado,'ACTIVO'))='ACTIVO'
    and upper(coalesce(tipo,'SERVICIO'))='SERVICIO';
  if not found then
    return jsonb_build_object('ok',false,'status','TREATMENT_NOT_ACTIVE');
  end if;

  if coalesce(v_t.requiere_doctora,false) and coalesce(v_t.requiere_enfermeria,false) then
    return jsonb_build_object('ok',false,'status','COMPLEX_ROLE_REQUIRES_HUMAN','treatment_id',v_t.id,'treatment',v_t.nombre);
  elsif coalesce(v_t.requiere_doctora,false) then
    v_role:='DOCTORA'; v_mode:='EXACT_PROVIDER';
  elsif coalesce(v_t.requiere_enfermeria,false) then
    v_role:='ENFERMERIA'; v_mode:='SITE_POOL';
  else
    return jsonb_build_object('ok',false,'status','ROLE_UNSPECIFIED','treatment_id',v_t.id,'treatment',v_t.nombre);
  end if;

  v_capability:=public.aos_booking_capability_for_service_v1(v_t.id);
  if v_capability is null then
    return jsonb_build_object('ok',false,'status','CAPABILITY_UNMAPPED','role',v_role,'mode',v_mode,'treatment_id',v_t.id,'treatment',v_t.nombre);
  end if;

  select max(fecha) into v_latest
  from public.aos_horarios_personal
  where activo=true and upper(coalesce(rol,''))=v_role;
  if v_latest is null or v_latest < p_fecha then
    return jsonb_build_object('ok',false,'status','SCHEDULE_SOURCE_STALE','role',v_role,'mode',v_mode,'capability',v_capability,'schedule_source_max_date',v_latest);
  end if;

  if v_role='DOCTORA' then
    v_step:=interval '30 minutes';
    for v_p in
      select p.*
      from public.aos_perfiles_profesional p
      where coalesce(p.visible,true)=true
        and upper(coalesce(p.tipo,''))='DOCTORA'
        and (p_profesional_id is null or p.id=p_profesional_id)
        and exists (
          select 1 from unnest(coalesce(p.servicios,array[]::text[])) s
          where public.aos_booking_norm_v1(s)=public.aos_booking_norm_v1(v_capability)
        )
        and exists (
          select 1 from public.aos_horarios_personal h
          where h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site
            and upper(coalesce(h.rol,''))='DOCTORA'
            and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%'
        )
      order by p.orden nulls last,p.nombre_publico
    loop
      v_providers:=v_providers||jsonb_build_array(jsonb_build_object(
        'id',v_p.id,'name',v_p.nombre_publico,'role','DOCTORA','capability',v_capability
      ));
      for v_h in
        select h.* from public.aos_horarios_personal h
        where h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site
          and upper(coalesce(h.rol,''))='DOCTORA'
          and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(v_p.nombre_publico)||'%'
      loop
        v_time:=v_h.hora_inicio::time;
        while v_time + v_step <= v_h.hora_fin::time loop
          select count(*) into v_occupied
          from public.aos_agenda_citas a
          where a.fecha_cita=p_fecha
            and upper(coalesce(a.sede,''))=v_site
            and substring(coalesce(a.hora_cita,'') from 1 for 5)=to_char(v_time,'HH24:MI')
            and upper(coalesce(a.doctora,'')) like '%'||public.aos_booking_profile_key_v1(v_p.nombre_publico)||'%'
            and upper(coalesce(a.estado_cita,'')) not in ('CANCELADA','CANCELADO');
          -- Preserve existing doctor capacity semantics; provider is still exact.
          if v_occupied < 5 then
            v_slots:=v_slots||jsonb_build_array(jsonb_build_object(
              'hora',to_char(v_time,'HH24:MI'),'sede',v_site,'disponible',true,
              'libres',5-v_occupied,'capacidad',5,
              'professional_id',v_p.id,'professional_name',v_p.nombre_publico,
              'role','DOCTORA','mode','EXACT_PROVIDER'
            ));
          end if;
          v_time:=v_time+v_step;
        end loop;
      end loop;
    end loop;
  else
    v_step:=interval '45 minutes';

    select min(h.hora_inicio::time),max(h.hora_fin::time)
      into v_min_start,v_max_end
    from public.aos_perfiles_profesional p
    join public.aos_horarios_personal h
      on h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site
     and upper(coalesce(h.rol,''))='ENFERMERIA'
     and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%'
    where coalesce(p.visible,true)=true and upper(coalesce(p.tipo,''))='ENFERMERIA'
      and exists (
        select 1 from unnest(coalesce(p.servicios,array[]::text[])) s
        where public.aos_booking_norm_v1(s)=public.aos_booking_norm_v1(v_capability)
      );

    select coalesce(jsonb_agg(distinct jsonb_build_object('id',p.id,'name',p.nombre_publico,'role','ENFERMERIA','capability',v_capability)),'[]'::jsonb)
      into v_providers
    from public.aos_perfiles_profesional p
    join public.aos_horarios_personal h
      on h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site
     and upper(coalesce(h.rol,''))='ENFERMERIA'
     and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%'
    where coalesce(p.visible,true)=true and upper(coalesce(p.tipo,''))='ENFERMERIA'
      and exists (
        select 1 from unnest(coalesce(p.servicios,array[]::text[])) s
        where public.aos_booking_norm_v1(s)=public.aos_booking_norm_v1(v_capability)
      );

    if v_min_start is not null and v_max_end is not null then
      v_time:=v_min_start;
      while v_time + v_step <= v_max_end loop
        select count(distinct p.id),
               coalesce(jsonb_agg(distinct p.nombre_publico),'[]'::jsonb)
          into v_members,v_names
        from public.aos_perfiles_profesional p
        join public.aos_horarios_personal h
          on h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site
         and upper(coalesce(h.rol,''))='ENFERMERIA'
         and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%'
        where coalesce(p.visible,true)=true and upper(coalesce(p.tipo,''))='ENFERMERIA'
          and exists (
            select 1 from unnest(coalesce(p.servicios,array[]::text[])) s
            where public.aos_booking_norm_v1(s)=public.aos_booking_norm_v1(v_capability)
          )
          and v_time >= h.hora_inicio::time
          and v_time + v_step <= h.hora_fin::time;

        if coalesce(v_members,0)>0 then
          v_capacity:=v_members*2;
          select count(*) into v_occupied
          from public.aos_agenda_citas a
          where a.fecha_cita=p_fecha
            and upper(coalesce(a.sede,''))=v_site
            and substring(coalesce(a.hora_cita,'') from 1 for 5)=to_char(v_time,'HH24:MI')
            and upper(coalesce(a.tipo_atencion,''))='ENFERMERIA'
            and upper(coalesce(a.estado_cita,'')) not in ('CANCELADA','CANCELADO');
          if v_occupied < v_capacity then
            v_slots:=v_slots||jsonb_build_array(jsonb_build_object(
              'hora',to_char(v_time,'HH24:MI'),'sede',v_site,'disponible',true,
              'libres',v_capacity-v_occupied,'capacidad',v_capacity,
              'member_count',v_members,'member_names',v_names,
              'professional_id',null,'professional_name','Enfermería',
              'role','ENFERMERIA','mode','SITE_POOL'
            ));
          end if;
        end if;
        v_time:=v_time+v_step;
      end loop;
    end if;
  end if;

  return jsonb_build_object(
    'ok',true,
    'status',case when jsonb_array_length(v_slots)>0 then 'REAL_SLOTS_READY' else 'NO_REAL_SLOTS' end,
    'treatment_id',v_t.id,'treatment',v_t.nombre,'capability',v_capability,
    'role',v_role,'mode',v_mode,'fecha',p_fecha,'sede',v_site,
    'schedule_source_max_date',v_latest,
    'eligible_professionals',v_providers,'slots',v_slots
  );
end
$$;

revoke all on function public.aos_booking_availability_v2(uuid,date,text,text) from public;
grant execute on function public.aos_booking_availability_v2(uuid,date,text,text) to anon,authenticated,service_role;

-- Compatibility hardening for legacy consumers: capacity 2 per nurse and no slot may overrun the attention window.
create or replace function public.aos_slots_disponibles(p_profesional_id text, p_fecha date, p_sede text default null)
returns json
language plpgsql
as $$
declare
  v_prof record;
  v_turno record;
  v_slots json[];
  v_hora time;
  v_ocupados_count int;
  v_cap int;
  v_nombre_match text;
  v_step interval;
begin
  select * into v_prof from public.aos_perfiles_profesional where id=p_profesional_id;
  if not found then return json_build_object('ok',false,'error','Profesional no encontrado'); end if;
  v_nombre_match:=public.aos_booking_profile_key_v1(v_prof.nombre_publico);
  if upper(coalesce(v_prof.tipo,''))='DOCTORA' then v_cap:=5; v_step:=interval '30 minutes';
  else v_cap:=2; v_step:=interval '45 minutes'; end if;
  v_slots:=array[]::json[];
  for v_turno in
    select hora_inicio,hora_fin,sede from public.aos_horarios_personal
    where activo=true and fecha=p_fecha
      and public.aos_booking_norm_v1(personal) like '%'||v_nombre_match||'%'
      and (p_sede is null or upper(sede)=upper(p_sede))
  loop
    v_hora:=v_turno.hora_inicio::time;
    while v_hora + v_step <= v_turno.hora_fin::time loop
      select count(*) into v_ocupados_count
      from public.aos_agenda_citas
      where fecha_cita=p_fecha
        and substring(coalesce(hora_cita,'') from 1 for 5)=to_char(v_hora,'HH24:MI')
        and (upper(coalesce(doctora,'')) like '%'||v_nombre_match||'%' or upper(coalesce(asesor,'')) like '%'||v_nombre_match||'%')
        and upper(coalesce(estado_cita,'')) not in ('CANCELADA','CANCELADO');
      if v_ocupados_count < v_cap then
        v_slots:=v_slots||json_build_object('hora',to_char(v_hora,'HH24:MI'),'sede',v_turno.sede,'disponible',true,'libres',v_cap-v_ocupados_count,'capacidad',v_cap)::json;
      end if;
      v_hora:=v_hora+v_step;
    end loop;
  end loop;
  return json_build_object('ok',true,'fecha',p_fecha,'profesional',v_prof.nombre_publico,'slots',coalesce(array_to_json(v_slots),'[]'::json));
end
$$;

commit;
