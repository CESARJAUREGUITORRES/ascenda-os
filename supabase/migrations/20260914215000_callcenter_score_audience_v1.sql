-- Restrict competitive appointment Push to users who actually operate Call Center.
begin;

create or replace function public.aos_notification_agenda_trigger_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  uid uuid;
  patient text;
  st text;
  oldst text;
  ev text;
  adm_ev text;
  adm record;
  peer record;
  tg text;
  substate text;
  cls text;
  subtype text;
  daily_total integer:=1;
  advisor_name text;
  meta jsonb;
begin
  uid:=public.aos_notification_resolve_user_v1(coalesce(nullif(new.id_asesor,''),new.asesor));
  patient:=trim(concat_ws(' ',nullif(new.nombre,''),nullif(new.apellido,'')));

  if tg_op='INSERT' then
    if new.llamada_id_origen is not null then
      select l.tipo_gestion,l.sub_estado into tg,substate
      from public.aos_llamadas l where l.id=new.llamada_id_origen;
    end if;

    cls:=public.aos_callcenter_appointment_class_v1(new.origen_cita,tg,substate,new.llamada_id_origen);
    subtype:=public.aos_callcenter_appointment_subtype_v1(new.origen_cita,tg,substate,new.llamada_id_origen);
    advisor_name:=upper(trim(coalesce(nullif(new.asesor,''),nullif(new.id_asesor,''),'ASCENDA')));

    if cls<>'IGNORAR' and nullif(advisor_name,'') is not null then
      select count(*) into daily_total
      from public.aos_agenda_citas a
      left join public.aos_llamadas l on l.id=a.llamada_id_origen
      where (coalesce(a.ts_creado,a.ts_actualizado) at time zone 'America/Lima')::date=(now() at time zone 'America/Lima')::date
        and (
          (nullif(new.id_asesor,'') is not null and a.id_asesor=new.id_asesor)
          or (nullif(new.id_asesor,'') is null and upper(trim(coalesce(a.asesor,'')))=upper(trim(coalesce(new.asesor,''))))
        )
        and public.aos_callcenter_appointment_class_v1(a.origen_cita,l.tipo_gestion,l.sub_estado,a.llamada_id_origen)=cls;

      meta:=jsonb_build_object(
        'count',1,
        'last_patient',patient,
        'date',coalesce(new.fecha_cita::text,''),
        'time',coalesce(new.hora_cita,''),
        'last_sede',coalesce(new.sede,''),
        'last_treatment',coalesce(new.tratamiento,''),
        'advisor_name',advisor_name,
        'appointment_class',cls,
        'appointment_subtype',subtype,
        'daily_total',greatest(1,daily_total)
      );
    else
      meta:=jsonb_build_object(
        'count',1,
        'last_patient',patient,
        'date',coalesce(new.fecha_cita::text,''),
        'time',coalesce(new.hora_cita,''),
        'last_sede',coalesce(new.sede,''),
        'last_treatment',coalesce(new.tratamiento,'')
      );
    end if;

    if uid is not null then
      perform public.aos_notification_emit_v1(jsonb_build_object(
        'event_type','APPOINTMENT_CREATED',
        'recipient_user_id',uid,
        'entity_id',new.id,
        'group_key',case when cls='IGNORAR' then 'advisor' else null end,
        'metadata',meta
      ));
    end if;

    for adm in
      select id from public.aos_usuarios
      where activo=true
        and (upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)<=2)
        and (uid is null or id<>uid)
    loop
      perform public.aos_notification_emit_v1(jsonb_build_object(
        'event_type','ADMIN_APPOINTMENT_DIGEST',
        'recipient_user_id',adm.id,
        'entity_id',new.id,
        'dedupe_key','admin-appointment-score:'||new.id||':'||adm.id::text,
        'metadata',meta
      ));
    end loop;

    if cls<>'IGNORAR' then
      for peer in
        select id from public.aos_usuarios
        where activo=true
          and lower(coalesce(rol,''))='asesor'
          and coalesce(paneles_acceso,'{}'::text[]) @> array['advisor-calls']::text[]
          and (uid is null or id<>uid)
      loop
        perform public.aos_notification_emit_v1(jsonb_build_object(
          'event_type','TEAM_APPOINTMENT_SCORE',
          'recipient_user_id',peer.id,
          'entity_id',new.id,
          'dedupe_key','team-appointment-score:'||new.id||':'||peer.id::text,
          'metadata',meta
        ));
      end loop;
    end if;

    return new;
  end if;

  st:=upper(trim(coalesce(new.estado_cita,'')));
  oldst:=upper(trim(coalesce(old.estado_cita,'')));
  if st=oldst then return new; end if;

  if st in ('ASISTIO','EFECTIVA') and oldst not in ('ASISTIO','EFECTIVA') then
    ev:='APPOINTMENT_ATTENDED'; adm_ev:='ADMIN_ATTENDED_DIGEST';
  elsif st='NO ASISTIO' then
    ev:='APPOINTMENT_NO_SHOW'; adm_ev:='ADMIN_NO_SHOW_DIGEST';
  elsif st='CANCELADA' then
    ev:='APPOINTMENT_CANCELLED';
  elsif st='REAGENDADA' then
    ev:='APPOINTMENT_RESCHEDULED';
  else
    return new;
  end if;

  if uid is not null then
    perform public.aos_notification_emit_v1(jsonb_build_object(
      'event_type',ev,'recipient_user_id',uid,'entity_id',new.id,
      'dedupe_key','agenda:'||lower(ev)||':'||new.id||':'||md5(st),
      'metadata',jsonb_build_object(
        'count',1,'last_patient',patient,'date',coalesce(new.fecha_cita::text,''),
        'time',coalesce(new.hora_cita,''),'last_sede',coalesce(new.sede,''),
        'last_treatment',coalesce(new.tratamiento,'')
      )
    ));
  end if;

  if adm_ev is not null then
    for adm in
      select id from public.aos_usuarios
      where activo=true and (upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)=1)
    loop
      perform public.aos_notification_emit_v1(jsonb_build_object(
        'event_type',adm_ev,'recipient_user_id',adm.id,'entity_id',new.id,
        'group_key','all-attendance','metadata',jsonb_build_object('count',1)
      ));
    end loop;
  end if;

  return new;
end;
$$;

commit;
