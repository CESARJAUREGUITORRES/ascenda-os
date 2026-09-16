begin;

-- BOOKING-V3.13
-- Fix ENFERMERIA / SITE_POOL availability. The previous function declared a PL/pgSQL
-- record named "h" and reused "h" as a SQL table alias in the nursing branch,
-- causing: record "h" is not assigned yet.
-- This keeps the same scheduling authority/capacity rules and only removes the
-- variable/alias collision.

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
set search_path='public','pg_temp'
as $$
declare
  t record;
  site text;
  latest date;
  slots jsonb:='[]'::jsonb;
  providers jsonb:='[]'::jsonb;
  p record;
  sched record;
  tm time;
  step interval;
  occupied int;
  members int;
  names jsonb;
  min_start time;
  max_end time;
begin
  select * into t
  from public.aos_booking_treatment_ref_v32(p_treatment_id);

  if not found then
    return jsonb_build_object('ok',false,'status','TREATMENT_NOT_ACTIVE');
  end if;

  site:=upper(replace(trim(coalesce(p_sede,'')),'_',' '));

  if p_fecha is null or site not in ('SAN ISIDRO','PUEBLO LIBRE') then
    return jsonb_build_object('ok',false,'status','INVALID_DATE_OR_SITE');
  end if;

  if t.role='DOCTORA' then
    if nullif(trim(p_profesional_id),'') is null then
      return jsonb_build_object('ok',false,'status','EXACT_PROVIDER_REQUIRED');
    end if;

    select max(fecha) into latest
    from public.aos_horarios_personal
    where activo=true and upper(coalesce(rol,''))='DOCTORA';

    if latest is null or latest<p_fecha then
      return jsonb_build_object('ok',false,'status','SCHEDULE_SOURCE_STALE');
    end if;

    step:=interval '30 minutes';

    for p in
      select *
      from public.aos_perfiles_profesional
      where coalesce(visible,true)=true
        and upper(coalesce(tipo,''))='DOCTORA'
        and id::text=p_profesional_id
    loop
      for sched in
        select *
        from public.aos_horarios_personal hp
        where hp.activo=true
          and hp.fecha=p_fecha
          and upper(hp.sede)=site
          and upper(coalesce(hp.rol,''))='DOCTORA'
          and public.aos_booking_norm_v1(hp.personal)
              like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%'
      loop
        tm:=sched.hora_inicio::time;

        while tm+step<=sched.hora_fin::time loop
          select count(*) into occupied
          from public.aos_agenda_citas a
          where a.fecha_cita=p_fecha
            and upper(coalesce(a.sede,''))=site
            and substring(coalesce(a.hora_cita,'') from 1 for 5)=to_char(tm,'HH24:MI')
            and upper(coalesce(a.doctora,'')) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%'
            and upper(coalesce(a.estado_cita,'')) not in ('CANCELADA','CANCELADO');

          if occupied<1 then
            slots:=slots||jsonb_build_array(
              jsonb_build_object(
                'hora',to_char(tm,'HH24:MI'),
                'sede',site,
                'disponible',true,
                'libres',1-occupied,
                'capacidad',1,
                'professional_id',p.id,
                'professional_name',p.nombre_publico,
                'role','DOCTORA',
                'mode','EXACT_PROVIDER'
              )
            );
          end if;

          tm:=tm+step;
        end loop;
      end loop;

      providers:=providers||jsonb_build_array(
        jsonb_build_object('id',p.id,'name',p.nombre_publico,'role','DOCTORA')
      );
    end loop;

  else
    select max(fecha) into latest
    from public.aos_horarios_personal
    where activo=true and upper(coalesce(rol,''))='ENFERMERIA';

    if latest is null or latest<p_fecha then
      return jsonb_build_object('ok',false,'status','SCHEDULE_SOURCE_STALE');
    end if;

    step:=interval '45 minutes';

    select min(hp.hora_inicio::time),max(hp.hora_fin::time)
      into min_start,max_end
    from public.aos_horarios_personal hp
    where hp.activo=true
      and hp.fecha=p_fecha
      and upper(hp.sede)=site
      and upper(coalesce(hp.rol,''))='ENFERMERIA';

    tm:=min_start;

    while tm is not null and max_end is not null and tm+step<=max_end loop
      select count(*),coalesce(jsonb_agg(hp.personal),'[]'::jsonb)
        into members,names
      from public.aos_horarios_personal hp
      where hp.activo=true
        and hp.fecha=p_fecha
        and upper(hp.sede)=site
        and upper(coalesce(hp.rol,''))='ENFERMERIA'
        and tm>=hp.hora_inicio::time
        and tm+step<=hp.hora_fin::time;

      if members>0 then
        select count(*) into occupied
        from public.aos_agenda_citas a
        where a.fecha_cita=p_fecha
          and upper(coalesce(a.sede,''))=site
          and substring(coalesce(a.hora_cita,'') from 1 for 5)=to_char(tm,'HH24:MI')
          and upper(coalesce(a.tipo_atencion,''))='ENFERMERIA'
          and upper(coalesce(a.estado_cita,'')) not in ('CANCELADA','CANCELADO');

        if occupied<members*2 then
          slots:=slots||jsonb_build_array(
            jsonb_build_object(
              'hora',to_char(tm,'HH24:MI'),
              'sede',site,
              'disponible',true,
              'libres',members*2-occupied,
              'capacidad',members*2,
              'member_names',names,
              'professional_id',null,
              'professional_name','Enfermería',
              'role','ENFERMERIA',
              'mode','SITE_POOL'
            )
          );
        end if;
      end if;

      tm:=tm+step;
    end loop;
  end if;

  return jsonb_build_object(
    'ok',true,
    'status',case when jsonb_array_length(slots)>0 then 'REAL_SLOTS_READY' else 'NO_REAL_SLOTS' end,
    'treatment_id',p_treatment_id,
    'treatment',t.tratamiento,
    'role',t.role,
    'mode',t.mode,
    'fecha',p_fecha,
    'sede',site,
    'schedule_source_max_date',latest,
    'eligible_professionals',providers,
    'slots',slots
  );
end
$$;

commit;
