begin;

-- P0 2026-09-23
-- Historical appointment rows were backfilled during the day with a fresh ts_creado.
-- Operational monitoring must not count those past appointments as today's direct agenda,
-- and INSERT-side appointment notifications must not fan out for historical backfill rows.

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
       and a.fecha_cita>=p_hoy
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
     select l2.numero_limpio from public.aos_llamadas l2
     where upper(trim(l2.asesor))=r.asesor and l2.fecha=p_hoy
     order by coalesce(l2.ult_ts,l2.created_at) desc nulls last,l2.id desc limit 1
   ),
   (
     select l2.hora_llamada from public.aos_llamadas l2
     where upper(trim(l2.asesor))=r.asesor and l2.fecha=p_hoy
     order by coalesce(l2.ult_ts,l2.created_at) desc nulls last,l2.id desc limit 1
   ),
   case when (
     select l2.hora_llamada from public.aos_llamadas l2
     where upper(trim(l2.asesor))=r.asesor and l2.fecha=p_hoy
     order by coalesce(l2.ult_ts,l2.created_at) desc nulls last,l2.id desc limit 1
   ) is not null then (
     extract(epoch from (
       now() at time zone 'America/Lima' -
       (p_hoy::timestamp + (
         select l2.hora_llamada::time from public.aos_llamadas l2
         where upper(trim(l2.asesor))=r.asesor and l2.fecha=p_hoy
         order by coalesce(l2.ult_ts,l2.created_at) desc nulls last,l2.id desc limit 1
       ))
     ))::integer/60
   ) else null end
 from roster r
 left join ca on ca.asesor=r.asesor
 left join aa on aa.asesor=r.asesor
 order by
   coalesce(ca.llamadas,0) desc,
   (coalesce(aa.citas,0)+coalesce(aa.reactivadas,0)+coalesce(aa.agenda_directa,0)+coalesce(aa.citas_web,0)) desc,
   r.asesor;
end
$$;

create or replace function public.aos_notification_agenda_trigger_v1()
returns trigger
language plpgsql
security definer
set search_path='public','pg_temp'
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
  src text;
  camp text;
  src_label text;
begin
  uid:=public.aos_notification_resolve_user_v1(coalesce(nullif(new.id_asesor,''),new.asesor));
  patient:=trim(concat_ws(' ',nullif(new.nombre,''),nullif(new.apellido,'')));

  if tg_op='INSERT' then
    if new.fecha_cita is not null
       and new.fecha_cita < (now() at time zone 'America/Lima')::date then
      return new;
    end if;

    if new.llamada_id_origen is not null then
      select l.tipo_gestion,l.sub_estado into tg,substate
      from public.aos_llamadas l
      where l.id=new.llamada_id_origen;
    end if;

    cls:=public.aos_callcenter_appointment_class_v1(new.origen_cita,tg,substate,new.llamada_id_origen);
    subtype:=public.aos_callcenter_appointment_subtype_v1(new.origen_cita,tg,substate,new.llamada_id_origen);
    advisor_name:=public.aos_booking_advisor_display_v12(new.id_asesor,new.asesor,new.source_link_token);
    src:=coalesce(nullif(new.source_channel,''),case
      when new.origen_cita='WEB-PUBLICA' then 'WEB'
      when new.origen_cita='AUTO-AGENDA' then 'ADVISOR_LINK'
      else coalesce(new.origen_cita,'OTHER') end);
    camp:=nullif(new.source_campaign,'');
    src_label:=public.aos_booking_source_label_v1(src,camp,advisor_name);

    if cls<>'IGNORAR' and nullif(advisor_name,'') is not null then
      select count(*) into daily_total
      from public.aos_agenda_citas a
      left join public.aos_llamadas l on l.id=a.llamada_id_origen
      where (coalesce(a.ts_creado,a.ts_actualizado) at time zone 'America/Lima')::date=(now() at time zone 'America/Lima')::date
        and a.fecha_cita >= (now() at time zone 'America/Lima')::date
        and ((nullif(new.id_asesor,'') is not null and a.id_asesor=new.id_asesor)
          or (nullif(new.id_asesor,'') is null and upper(trim(coalesce(a.asesor,'')))=upper(trim(coalesce(new.asesor,'')))))
        and public.aos_callcenter_appointment_class_v1(a.origen_cita,l.tipo_gestion,l.sub_estado,a.llamada_id_origen)=cls;
    end if;

    meta:=jsonb_build_object(
      'count',1,'last_patient',patient,'date',coalesce(new.fecha_cita::text,''),
      'time',coalesce(new.hora_cita,''),'last_sede',coalesce(new.sede,''),
      'last_treatment',coalesce(new.tratamiento,''),
      'advisor_name',coalesce(advisor_name,case when upper(coalesce(src,''))='WEB' then 'WEB' else 'ASCENDA' end),
      'appointment_class',cls,'appointment_subtype',subtype,'daily_total',greatest(1,daily_total),
      'source_channel',src,'source_campaign',camp,'source_label',src_label
    );

    if uid is not null then
      perform public.aos_notification_emit_v1(jsonb_build_object(
        'event_type','APPOINTMENT_CREATED','recipient_user_id',uid,'entity_id',new.id,
        'group_key',case when cls='IGNORAR' then 'advisor' else null end,'metadata',meta));
    end if;

    for adm in select id from public.aos_usuarios
      where activo=true and (upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)<=2)
        and (uid is null or id<>uid)
    loop
      perform public.aos_notification_emit_v1(jsonb_build_object(
        'event_type','ADMIN_APPOINTMENT_DIGEST','recipient_user_id',adm.id,'entity_id',new.id,
        'dedupe_key','admin-appointment-score:'||new.id||':'||adm.id::text,'metadata',meta));
    end loop;

    if cls<>'IGNORAR' then
      for peer in select id from public.aos_usuarios
        where activo=true and lower(coalesce(rol,''))='asesor'
          and coalesce(paneles_acceso,'{}'::text[]) @> array['advisor-calls']::text[]
          and (uid is null or id<>uid)
      loop
        perform public.aos_notification_emit_v1(jsonb_build_object(
          'event_type','TEAM_APPOINTMENT_SCORE','recipient_user_id',peer.id,'entity_id',new.id,
          'dedupe_key','team-appointment-score:'||new.id||':'||peer.id::text,'metadata',meta));
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
      'metadata',jsonb_build_object('count',1,'last_patient',patient,'date',coalesce(new.fecha_cita::text,''),
        'time',coalesce(new.hora_cita,''),'last_sede',coalesce(new.sede,''),'last_treatment',coalesce(new.tratamiento,''))));
  end if;

  if adm_ev is not null then
    for adm in select id from public.aos_usuarios
      where activo=true and (upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)=1)
    loop
      perform public.aos_notification_emit_v1(jsonb_build_object(
        'event_type',adm_ev,'recipient_user_id',adm.id,'entity_id',new.id,
        'group_key','all-attendance','metadata',jsonb_build_object('count',1)));
    end loop;
  end if;
  return new;
end
$$;

update public.aos_notificaciones n
set push_status='SKIPPED',
    push_claimed_at=null,
    updated_at=now(),
    metadata=coalesce(n.metadata,'{}'::jsonb)||jsonb_build_object('skip_reason','HISTORICAL_APPOINTMENT_BACKFILL')
from public.aos_agenda_citas a
where a.id=n.entity_id
  and a.fecha_cita < (now() at time zone 'America/Lima')::date
  and n.event_type in ('APPOINTMENT_CREATED','TEAM_APPOINTMENT_SCORE','ADMIN_APPOINTMENT_DIGEST')
  and n.push_status in ('PENDING','CLAIMED');

commit;
