begin;

-- BOOKING-V3.14
-- 1) Nursing pool: 30-minute starts, 5 booking places per slot.
-- 2) Advisor-link bookings persist a human-readable advisor name while keeping the
--    canonical advisor UUID in id_asesor.
-- 3) Call monitoring folds ADVISOR_LINK rows into the real user (CESAR, RUVILA, etc.)
--    and keeps pure company web traffic under WEB / ORGÁNICO.

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
  pool_capacity int:=5;
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

    -- Public nursing/team booking: one visible start every 30 minutes.
    step:=interval '30 minutes';

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

        if occupied<pool_capacity then
          slots:=slots||jsonb_build_array(
            jsonb_build_object(
              'hora',to_char(tm,'HH24:MI'),
              'sede',site,
              'disponible',true,
              'libres',pool_capacity-occupied,
              'capacidad',pool_capacity,
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

create or replace function public.aos_agendar_publica_v2(
  p_token text,
  p_nombre text,
  p_apellido text,
  p_telefono text,
  p_treatment_id uuid,
  p_fecha date,
  p_hora text,
  p_sede text,
  p_profesional_id text default null,
  p_dni text default '',
  p_email text default '',
  p_nota text default '',
  p_tipo_cita text default 'CONSULTA NUEVA'
)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  l record;
  t record;
  num text;
  paciente record;
  advisor text;
  advisor_id text;
  advisor_name text;
  site text;
  avail jsonb;
  slot jsonb;
  prof_name text;
  idv text;
  attr jsonb;
  ch text;
  camp text;
begin
  select * into t from public.aos_booking_treatment_ref_v32(p_treatment_id);
  if not found then return jsonb_build_object('ok',false,'error','TREATMENT_NOT_ACTIVE'); end if;

  if coalesce(trim(p_token),'') in ('','__permanent__') then
    advisor:='ORGANICO';
    advisor_id:=null;
    advisor_name:='ORGANICO';
  else
    select * into l
    from public.aos_links_agenda
    where token=p_token and expira_at>now();

    if not found then return jsonb_build_object('ok',false,'error','LINK_INVALID_OR_EXPIRED'); end if;

    advisor_id:=nullif(trim(l.asesor_codigo),'');
    advisor:=coalesce(advisor_id,'ORGANICO');
  end if;

  attr:=public.aos_booking_attribution_v1(p_token);
  ch:=coalesce(attr->>'source_channel','WEB');
  camp:=nullif(attr->>'source_campaign','');

  if upper(ch)='ADVISOR_LINK' then
    advisor_name:=coalesce(
      public.aos_booking_advisor_display_v12(advisor_id,advisor,p_token),
      'LINK PERSONAL'
    );
  else
    advisor_name:='ORGANICO';
    advisor_id:=null;
    advisor:='ORGANICO';
  end if;

  site:=upper(replace(trim(coalesce(p_sede,'')),'_',' '));
  if site not in ('SAN ISIDRO','PUEBLO LIBRE') then return jsonb_build_object('ok',false,'error','SITE_INVALID'); end if;
  if p_fecha<current_date or extract(isodow from p_fecha)=7 then return jsonb_build_object('ok',false,'error','DATE_INVALID'); end if;
  if t.role='DOCTORA' and nullif(trim(p_profesional_id),'') is null then return jsonb_build_object('ok',false,'error','EXACT_PROVIDER_REQUIRED'); end if;

  perform pg_advisory_xact_lock(hashtextextended('public-booking-v314:'||t.role||':'||site||':'||p_fecha::text||':'||p_hora,0));

  avail:=coalesce(
    public.aos_booking_availability_v2(
      p_treatment_id,
      p_fecha,
      site,
      case when t.role='DOCTORA' then p_profesional_id else null end
    ),
    '{}'::jsonb
  );

  if coalesce((avail->>'ok')::boolean,false) is not true then
    return jsonb_build_object(
      'ok',false,
      'error','BOOKING_AUTHORITY_BLOCKED',
      'authority_status',coalesce(avail->>'status','UNKNOWN')
    );
  end if;

  select s into slot
  from jsonb_array_elements(coalesce(avail->'slots','[]'::jsonb)) s
  where s->>'hora'=substring(p_hora from 1 for 5)
    and coalesce((s->>'disponible')::boolean,false)=true
    and (t.role='ENFERMERIA' or s->>'professional_id'=p_profesional_id)
  limit 1;

  if slot is null then return jsonb_build_object('ok',false,'error','SLOT_NO_LONGER_AVAILABLE'); end if;

  prof_name:=case when t.role='DOCTORA' then nullif(slot->>'professional_name','') else 'ENFERMERIA' end;

  num:=regexp_replace(coalesce(p_telefono,''),'[^0-9]','','g');
  if length(num)<7 then return jsonb_build_object('ok',false,'error','PHONE_REQUIRED'); end if;
  if coalesce(trim(p_nombre),'')='' then return jsonb_build_object('ok',false,'error','NAME_REQUIRED'); end if;

  select * into paciente from public.aos_pacientes where numero_limpio=num limit 1;

  if not found then
    insert into public.aos_pacientes(
      numero_limpio,"Nombres","Apellidos","Email","N° documento",
      "ESTADO_PACIENTE","FECHA_REGISTRO","FUENTE"
    )
    values(
      num,upper(trim(p_nombre)),upper(trim(coalesce(p_apellido,''))),
      nullif(trim(p_email),''),nullif(trim(p_dni),''),
      'PROSPECTO',current_date,
      case when upper(ch)='WEB' then 'WEB-PUBLICA' else 'AUTO-AGENDA' end
    );
  else
    update public.aos_pacientes
    set "Email"=case when coalesce(trim(p_email),'')<>'' then trim(p_email) else "Email" end,
        "N° documento"=case when coalesce(trim(p_dni),'')<>'' then trim(p_dni) else "N° documento" end
    where numero_limpio=num;
  end if;

  idv:=gen_random_uuid()::text;

  insert into public.aos_agenda_citas(
    id,fecha_cita,hora_cita,nombre,apellido,dni,correo,numero,numero_limpio,
    tratamiento,sede,doctora,asesor,id_asesor,estado_cita,tipo_cita,tipo_atencion,
    origen_cita,origen,etiqueta_campana,obs,ts_creado,source_channel,source_campaign,source_link_token
  )
  values(
    idv,p_fecha,substring(p_hora from 1 for 5),upper(trim(p_nombre)),upper(trim(coalesce(p_apellido,''))),
    nullif(trim(p_dni),''),nullif(trim(p_email),''),num,num,t.tratamiento,site,
    case when t.role='DOCTORA' then prof_name else null end,
    advisor_name,
    case when upper(ch)='ADVISOR_LINK' then advisor_id else null end,
    'PENDIENTE',upper(trim(coalesce(p_tipo_cita,'CONSULTA NUEVA'))),t.role,
    case when upper(ch)='WEB' then 'WEB-PUBLICA' else 'AUTO-AGENDA' end,
    ch,camp,trim(coalesce(p_nota,'')),now(),ch,camp,
    case when coalesce(trim(p_token),'') in ('','__permanent__') then null else p_token end
  );

  if coalesce(trim(p_token),'') not in ('','__permanent__') then
    update public.aos_links_agenda set usado=true
    where token=p_token and tipo='paciente_especifico';
  end if;

  perform public.aos_google_enqueue_authorized_appointment_v1(idv,'CALENDAR_UPSERT','PUBLIC_BOOKING_V314');

  return jsonb_build_object(
    'ok',true,'status','BOOKED','agenda_id',idv,'fecha',p_fecha,
    'hora',substring(p_hora from 1 for 5),'sede',site,'role',t.role,'mode',t.mode,
    'treatment',t.tratamiento,
    'professional_name',case when t.role='DOCTORA' then prof_name else 'Enfermería' end,
    'source_channel',ch,'source_campaign',camp,
    'advisor_code',advisor_name,
    'email',nullif(trim(p_email),'')
  );
end
$$;

-- Normalize previously-created ADVISOR_LINK appointment labels without changing
-- the canonical source/link/id fields.
update public.aos_agenda_citas a
set asesor=coalesce(
  public.aos_booking_advisor_display_v12(a.id_asesor,a.asesor,a.source_link_token),
  a.asesor
)
where upper(coalesce(a.source_channel,''))='ADVISOR_LINK'
  and public.aos_booking_advisor_display_v12(a.id_asesor,a.asesor,a.source_link_token) is not null;

create or replace function public.aos_monitoreo_equipo(p_hoy date default current_date)
returns table(
  nombre text,
  llamadas bigint,
  citas bigint,
  reactivadas bigint,
  agenda_directa bigint,
  citas_web bigint,
  link_personal bigint,
  conv_pct integer,
  ult_num text,
  ult_hora text,
  mins_sin integer
)
language plpgsql
as $$
begin
 return query
 with appt_norm as (
   select
     a.*,
     case
       when upper(coalesce(a.source_channel,''))='WEB'
            and nullif(trim(a.id_asesor),'') is null
         then 'WEB'
       when upper(coalesce(a.source_channel,''))='ADVISOR_LINK'
         then upper(coalesce(
           public.aos_booking_advisor_display_v12(a.id_asesor,a.asesor,a.source_link_token),
           nullif(trim(a.asesor),''),
           'LINK PERSONAL'
         ))
       else upper(trim(coalesce(a.asesor,'')))
     end as monitor_owner
   from public.aos_agenda_citas a
   where (coalesce(a.ts_creado,a.ts_actualizado) at time zone 'America/Lima')::date=p_hoy
 ), roster as (
   select upper(trim(l.asesor)) asesor
   from public.aos_llamadas l
   where l.fecha=p_hoy and nullif(trim(l.asesor),'') is not null

   union

   select monitor_owner
   from appt_norm
   where nullif(trim(monitor_owner),'') is not null
     and monitor_owner not in ('ORGANICO','ORGÁNICO')
 ), ca as (
   select upper(trim(l.asesor)) asesor,count(*)::bigint llamadas
   from public.aos_llamadas l
   where l.fecha=p_hoy and nullif(trim(l.asesor),'') is not null
   group by 1
 ), aa as (
   select
     a.monitor_owner asesor,
     count(*) filter(
       where public.aos_callcenter_appointment_class_v1(
         a.origen_cita,l.tipo_gestion,l.sub_estado,a.llamada_id_origen
       )='CITA'
       and upper(coalesce(a.source_channel,'')) not in ('WEB','ADVISOR_LINK')
     )::bigint citas,
     count(*) filter(
       where public.aos_callcenter_appointment_class_v1(
         a.origen_cita,l.tipo_gestion,l.sub_estado,a.llamada_id_origen
       )='REACTIVADA'
     )::bigint reactivadas,
     count(*) filter(
       where public.aos_callcenter_appointment_class_v1(
         a.origen_cita,l.tipo_gestion,l.sub_estado,a.llamada_id_origen
       )='AGENDA_DIRECTA'
     )::bigint agenda_directa,
     count(*) filter(
       where upper(coalesce(a.source_channel,'')) in ('WEB','ADVISOR_LINK')
     )::bigint citas_web,
     count(*) filter(
       where upper(coalesce(a.source_channel,''))='ADVISOR_LINK'
     )::bigint link_personal
   from appt_norm a
   left join public.aos_llamadas l on l.id=a.llamada_id_origen
   where nullif(trim(a.monitor_owner),'') is not null
     and a.monitor_owner not in ('ORGANICO','ORGÁNICO')
   group by 1
 )
 select
   r.asesor,
   coalesce(ca.llamadas,0),
   coalesce(aa.citas,0),
   coalesce(aa.reactivadas,0),
   coalesce(aa.agenda_directa,0),
   coalesce(aa.citas_web,0),
   coalesce(aa.link_personal,0),
   case when coalesce(ca.llamadas,0)>0
     then round(coalesce(aa.citas,0)::numeric*100/coalesce(ca.llamadas,0))::integer
     else 0
   end,
   (
     select l2.numero_limpio
     from public.aos_llamadas l2
     where upper(trim(l2.asesor))=r.asesor and l2.fecha=p_hoy
     order by coalesce(l2.ult_ts,l2.created_at) desc nulls last,l2.id desc
     limit 1
   ),
   (
     select l2.hora_llamada
     from public.aos_llamadas l2
     where upper(trim(l2.asesor))=r.asesor and l2.fecha=p_hoy
     order by coalesce(l2.ult_ts,l2.created_at) desc nulls last,l2.id desc
     limit 1
   ),
   case when (
     select l2.hora_llamada
     from public.aos_llamadas l2
     where upper(trim(l2.asesor))=r.asesor and l2.fecha=p_hoy
     order by coalesce(l2.ult_ts,l2.created_at) desc nulls last,l2.id desc
     limit 1
   ) is not null
   then (
     extract(epoch from (
       now() at time zone 'America/Lima' -
       (
         p_hoy::timestamp+
         (
           select l2.hora_llamada::time
           from public.aos_llamadas l2
           where upper(trim(l2.asesor))=r.asesor and l2.fecha=p_hoy
           order by coalesce(l2.ult_ts,l2.created_at) desc nulls last,l2.id desc
           limit 1
         )
       )
     ))::integer/60
   )
   else null end
 from roster r
 left join ca on ca.asesor=r.asesor
 left join aa on aa.asesor=r.asesor
 order by
   coalesce(ca.llamadas,0) desc,
   (coalesce(aa.citas,0)+coalesce(aa.reactivadas,0)+coalesce(aa.agenda_directa,0)+coalesce(aa.citas_web,0)) desc,
   r.asesor;
end
$$;

commit;
