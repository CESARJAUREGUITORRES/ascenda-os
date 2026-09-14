-- ASCENDA Call Center — appointment score / competitive notifications V1
-- Adds shared classification for Citas / Reactivadas / Agenda directa,
-- enriches team Push and expands monitoring without touching sales/WhatsApp/calendar sync.

begin;

create or replace function public.aos_callcenter_appointment_class_v1(
  p_origen_cita text,
  p_tipo_gestion text,
  p_sub_estado text,
  p_llamada_id bigint
)
returns text
language plpgsql
immutable
as $$
declare
  oc text:=upper(trim(coalesce(p_origen_cita,'')));
  tg text:=upper(trim(coalesce(p_tipo_gestion,'')));
  se text:=upper(trim(coalesce(p_sub_estado,'')));
begin
  -- A pure reschedule is not a new competitive booking.
  if oc='REAGENDADA' and p_llamada_id is null then return 'IGNORAR'; end if;

  -- Recovery/reactivation flows are credited separately.
  if oc in ('CALL_CENTER_RECUPERACION','CALL_CENTER_REAGENDADO')
     or oc like '%RECUPERACION%'
     or tg='REACTIVACION'
     or tg like 'RECUPERACION_%'
     or se like 'RECUPERACION_%'
     or se like 'REAGENDADO_%'
  then return 'REACTIVADA'; end if;

  -- A booking created without a source call is a direct agenda action.
  if oc='AGENDA' and p_llamada_id is null then return 'AGENDA_DIRECTA'; end if;

  return 'CITA';
end
$$;

create or replace function public.aos_callcenter_appointment_subtype_v1(
  p_origen_cita text,
  p_tipo_gestion text,
  p_sub_estado text,
  p_llamada_id bigint
)
returns text
language plpgsql
immutable
as $$
declare
  cls text:=public.aos_callcenter_appointment_class_v1(p_origen_cita,p_tipo_gestion,p_sub_estado,p_llamada_id);
  tg text:=upper(trim(coalesce(p_tipo_gestion,'')));
begin
  if cls='REACTIVADA' then return 'REACTIVACION'; end if;
  if cls='AGENDA_DIRECTA' then return 'AGENDA_DIRECTA'; end if;
  if cls='IGNORAR' then return 'IGNORAR'; end if;
  if tg='CALLBACK_INBOUND' then return 'CALLBACK'; end if;
  if tg='FOLLOWUP_CONVERSION' then return 'SEGUIMIENTO'; end if;
  if tg='LLAMADA_MANUAL_COMERCIAL' then return 'LLAMADA_COMERCIAL'; end if;
  return 'CITA_NUEVA';
end
$$;

drop function if exists public.aos_monitoreo_equipo(date);

create function public.aos_monitoreo_equipo(p_hoy date default current_date)
returns table(
  nombre text,
  llamadas bigint,
  citas bigint,
  reactivadas bigint,
  agenda_directa bigint,
  conv_pct integer,
  ult_num text,
  ult_hora text,
  mins_sin integer
)
language plpgsql
as $$
begin
  return query
  with roster as (
    select upper(trim(l.asesor)) as asesor
    from public.aos_llamadas l
    where l.fecha=p_hoy and nullif(trim(l.asesor),'') is not null
    union
    select upper(trim(a.asesor)) as asesor
    from public.aos_agenda_citas a
    where (coalesce(a.ts_creado,a.ts_actualizado) at time zone 'America/Lima')::date=p_hoy
      and nullif(trim(a.asesor),'') is not null
  ),
  ca as (
    select upper(trim(l.asesor)) as asesor, count(*)::bigint as llamadas
    from public.aos_llamadas l
    where l.fecha=p_hoy and nullif(trim(l.asesor),'') is not null
    group by 1
  ),
  aa as (
    select upper(trim(a.asesor)) as asesor,
      count(*) filter (
        where public.aos_callcenter_appointment_class_v1(a.origen_cita,l.tipo_gestion,l.sub_estado,a.llamada_id_origen)='CITA'
      )::bigint as citas,
      count(*) filter (
        where public.aos_callcenter_appointment_class_v1(a.origen_cita,l.tipo_gestion,l.sub_estado,a.llamada_id_origen)='REACTIVADA'
      )::bigint as reactivadas,
      count(*) filter (
        where public.aos_callcenter_appointment_class_v1(a.origen_cita,l.tipo_gestion,l.sub_estado,a.llamada_id_origen)='AGENDA_DIRECTA'
      )::bigint as agenda_directa
    from public.aos_agenda_citas a
    left join public.aos_llamadas l on l.id=a.llamada_id_origen
    where (coalesce(a.ts_creado,a.ts_actualizado) at time zone 'America/Lima')::date=p_hoy
      and nullif(trim(a.asesor),'') is not null
    group by 1
  )
  select
    r.asesor as nombre,
    coalesce(ca.llamadas,0)::bigint as llamadas,
    coalesce(aa.citas,0)::bigint as citas,
    coalesce(aa.reactivadas,0)::bigint as reactivadas,
    coalesce(aa.agenda_directa,0)::bigint as agenda_directa,
    case when coalesce(ca.llamadas,0)>0
      then round(coalesce(aa.citas,0)::numeric*100/coalesce(ca.llamadas,0))::integer
      else 0 end as conv_pct,
    (select l2.numero_limpio from public.aos_llamadas l2
      where upper(trim(l2.asesor))=r.asesor and l2.fecha=p_hoy
      order by coalesce(l2.ult_ts,l2.created_at) desc nulls last,l2.id desc limit 1) as ult_num,
    (select l2.hora_llamada from public.aos_llamadas l2
      where upper(trim(l2.asesor))=r.asesor and l2.fecha=p_hoy
      order by coalesce(l2.ult_ts,l2.created_at) desc nulls last,l2.id desc limit 1) as ult_hora,
    case when (select l2.hora_llamada from public.aos_llamadas l2
      where upper(trim(l2.asesor))=r.asesor and l2.fecha=p_hoy
      order by coalesce(l2.ult_ts,l2.created_at) desc nulls last,l2.id desc limit 1) is not null
      then (
        extract(epoch from (
          now() at time zone 'America/Lima'
          - (p_hoy::timestamp + (
            select l2.hora_llamada::time from public.aos_llamadas l2
            where upper(trim(l2.asesor))=r.asesor and l2.fecha=p_hoy
            order by coalesce(l2.ult_ts,l2.created_at) desc nulls last,l2.id desc limit 1
          ))
        ))::integer / 60
      )
      else null
    end as mins_sin
  from roster r
  left join ca on ca.asesor=r.asesor
  left join aa on aa.asesor=r.asesor
  order by coalesce(ca.llamadas,0) desc,
           (coalesce(aa.citas,0)+coalesce(aa.reactivadas,0)+coalesce(aa.agenda_directa,0)) desc,
           r.asesor;
end;
$$;

grant execute on function public.aos_monitoreo_equipo(date) to anon,authenticated,service_role;

create or replace function public.aos_callcenter_score_latest_v1(p_fecha date default ((now() at time zone 'America/Lima')::date))
returns jsonb
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
declare
  rec record;
  cls text;
  subtyp text;
  total integer:=0;
begin
  select a.*,l.tipo_gestion,l.sub_estado
  into rec
  from public.aos_agenda_citas a
  left join public.aos_llamadas l on l.id=a.llamada_id_origen
  where (coalesce(a.ts_creado,a.ts_actualizado) at time zone 'America/Lima')::date=p_fecha
    and nullif(trim(a.asesor),'') is not null
    and public.aos_callcenter_appointment_class_v1(a.origen_cita,l.tipo_gestion,l.sub_estado,a.llamada_id_origen)<>'IGNORAR'
  order by coalesce(a.ts_creado,a.ts_actualizado) desc nulls last
  limit 1;

  if rec.id is null then return jsonb_build_object('ok',true,'row',null); end if;

  cls:=public.aos_callcenter_appointment_class_v1(rec.origen_cita,rec.tipo_gestion,rec.sub_estado,rec.llamada_id_origen);
  subtyp:=public.aos_callcenter_appointment_subtype_v1(rec.origen_cita,rec.tipo_gestion,rec.sub_estado,rec.llamada_id_origen);

  select count(*) into total
  from public.aos_agenda_citas a
  left join public.aos_llamadas l on l.id=a.llamada_id_origen
  where (coalesce(a.ts_creado,a.ts_actualizado) at time zone 'America/Lima')::date=p_fecha
    and (
      (nullif(rec.id_asesor,'') is not null and a.id_asesor=rec.id_asesor)
      or (nullif(rec.id_asesor,'') is null and upper(trim(coalesce(a.asesor,'')))=upper(trim(coalesce(rec.asesor,''))))
    )
    and public.aos_callcenter_appointment_class_v1(a.origen_cita,l.tipo_gestion,l.sub_estado,a.llamada_id_origen)=cls;

  return jsonb_build_object('ok',true,'row',jsonb_build_object(
    'id',rec.id,
    'asesor',upper(trim(coalesce(rec.asesor,'ASCENDA'))),
    'class',cls,
    'subtype',subtyp,
    'daily_total',total,
    'treatment',coalesce(rec.tratamiento,''),
    'date',coalesce(rec.fecha_cita::text,''),
    'time',coalesce(rec.hora_cita,'')
  ));
end;
$$;

grant execute on function public.aos_callcenter_score_latest_v1(date) to anon,authenticated,service_role;

insert into public.aos_notification_policies_v1(
  event_type,channel,enabled,in_app_enabled,web_push_enabled,priority,aggregate_seconds,icon,route,description,updated_at
) values (
  'TEAM_APPOINTMENT_SCORE','AGENDA',true,true,true,'NORMAL',0,'📅','/app.html',
  'Competitive appointment score update for advisors/admins',now()
)
on conflict(event_type) do update set
  channel=excluded.channel,
  enabled=excluded.enabled,
  in_app_enabled=excluded.in_app_enabled,
  web_push_enabled=excluded.web_push_enabled,
  priority=excluded.priority,
  aggregate_seconds=excluded.aggregate_seconds,
  icon=excluded.icon,
  route=excluded.route,
  description=excluded.description,
  updated_at=now();

update public.aos_notification_policies_v1
set aggregate_seconds=0,
    description='Admin immediate appointment score update',
    updated_at=now()
where event_type='ADMIN_APPOINTMENT_DIGEST';

create or replace function public.aos_notification_format_v1(p_event_type text, p_metadata jsonb)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public','pg_temp'
as $$
declare
  e text:=upper(trim(coalesce(p_event_type,'')));
  m jsonb:=coalesce(p_metadata,'{}'::jsonb);
  c integer:=1;
  amount numeric:=0;
  commission numeric:=0;
  adj numeric:=0;
  title text;
  body text;
  patient text:=trim(coalesce(m->>'last_patient',m->>'patient',''));
  treatment text:=trim(coalesce(m->>'last_treatment',m->>'treatment',''));
  sede text:=trim(coalesce(m->>'last_sede',m->>'sede',''));
  dt text:=trim(concat_ws(' ',nullif(m->>'date',''),nullif(m->>'time','')));
  reason text:=trim(coalesce(m->>'reason',''));
  plus text;
  advisor text:=upper(trim(coalesce(m->>'advisor_name','')));
  ap_class text:=upper(trim(coalesce(m->>'appointment_class','')));
  ap_subtype text:=upper(trim(coalesce(m->>'appointment_subtype','')));
  class_label text;
  subtype_label text;
  plural_label text;
  daily_total integer:=1;
begin
  begin c:=greatest(1,coalesce((m->>'count')::integer,1)); exception when others then c:=1; end;
  begin amount:=coalesce((m->>'amount')::numeric,0); exception when others then amount:=0; end;
  begin commission:=coalesce((m->>'commission')::numeric,0); exception when others then commission:=0; end;
  begin adj:=coalesce((m->>'adjustment')::numeric,0); exception when others then adj:=0; end;
  begin daily_total:=greatest(1,coalesce((m->>'daily_total')::integer,1)); exception when others then daily_total:=1; end;

  class_label:=case ap_class when 'REACTIVADA' then 'REACTIVADA' when 'AGENDA_DIRECTA' then 'AGENDA DIRECTA' else 'CITA NUEVA' end;
  plural_label:=case ap_class when 'REACTIVADA' then 'reactivadas' when 'AGENDA_DIRECTA' then 'agendas directas' else 'citas' end;
  subtype_label:=case ap_subtype
    when 'CALLBACK' then 'Callback/entrante'
    when 'SEGUIMIENTO' then 'Seguimiento'
    when 'LLAMADA_COMERCIAL' then 'Llamada comercial'
    when 'REACTIVACION' then 'Recuperación/reactivación'
    when 'AGENDA_DIRECTA' then 'Agenda directa'
    else 'Cita nueva'
  end;

  if e='SALE_ADDED' then
    if c=1 then
      title:='Venta registrada · S/ '||to_char(amount,'FM999999990D00');
      body:=trim(concat_ws(' · ',nullif(patient,''),nullif(treatment,''),'Comisión +S/ '||to_char(commission,'FM999999990D00')));
    else
      title:=c||' ventas registradas · S/ '||to_char(amount,'FM999999990D00');
      body:='Tu comisión aumentó +S/ '||to_char(commission,'FM999999990D00');
    end if;
  elsif e='ADMIN_SALES_DIGEST' then
    title:='Ventas actualizadas · '||c||case when c=1 then ' registro' else ' registros' end;
    body:='S/ '||to_char(amount,'FM999999990D00')||' registrados en el sistema';
  elsif e='COMMISSION_ADJUSTED' then
    plus:=case when adj>=0 then '+' else '' end;
    title:='Comisión ajustada · '||plus||'S/ '||to_char(adj,'FM999999990D00');
    body:=coalesce(nullif(reason,''),'Se actualizó tu comisión');
  elsif e in ('APPOINTMENT_CREATED','ADMIN_APPOINTMENT_DIGEST','TEAM_APPOINTMENT_SCORE')
        and advisor<>'' and ap_class<>'' then
    title:=advisor||' · '||class_label||' +1 · Hoy '||daily_total;
    body:=trim(concat_ws(' · ',subtype_label,nullif(treatment,''),nullif(dt,'')));
  elsif e='APPOINTMENT_CREATED' then
    if c=1 then
      title:='Nueva cita agendada';
      body:=trim(concat_ws(' · ',nullif(patient,''),nullif(dt,''),nullif(sede,'')));
    else
      title:=c||' nuevas citas agendadas';
      body:='Tu agenda fue actualizada';
    end if;
  elsif e='ADMIN_APPOINTMENT_DIGEST' then
    title:='Agenda actualizada · '||c||case when c=1 then ' cita' else ' citas' end;
    body:='Se registraron nuevas citas en el sistema';
  elsif e='APPOINTMENT_ATTENDED' then
    title:='Tu cita asistió';
    body:=trim(concat_ws(' · ',nullif(patient,''),nullif(treatment,''),nullif(sede,'')));
  elsif e='APPOINTMENT_NO_SHOW' then
    title:='Tu cita no asistió';
    body:=trim(concat_ws(' · ',nullif(patient,''),'Revisa el seguimiento'));
  elsif e='APPOINTMENT_CANCELLED' then
    title:='Cita cancelada';
    body:=trim(concat_ws(' · ',nullif(patient,''),nullif(dt,''),nullif(sede,'')));
  elsif e='APPOINTMENT_RESCHEDULED' then
    title:='Cita reagendada';
    body:=trim(concat_ws(' · ',nullif(patient,''),nullif(dt,''),nullif(sede,'')));
  elsif e='ADMIN_ATTENDED_DIGEST' then
    title:='Atenciones · '||c||case when c=1 then ' asistencia' else ' asistencias' end;
    body:='Se actualizaron citas como asistidas';
  elsif e='ADMIN_NO_SHOW_DIGEST' then
    title:='Seguimiento · '||c||case when c=1 then ' inasistencia' else ' inasistencias' end;
    body:='Hay citas no asistidas para revisar';
  elsif e='INTERNAL_CHAT_MESSAGE' then
    title:='Chat · '||coalesce(nullif(m->>'sender',''),'ASCENDA');
    body:=left(regexp_replace(coalesce(m->>'preview','Nuevo mensaje'),'[[:cntrl:]]+',' ','g'),140);
  elsif e='TASK_ASSIGNED' then
    title:='Nueva tarea · '||left(coalesce(nullif(m->>'task_title',''),'Pendiente'),90);
    body:=trim(concat_ws(' · ',nullif('Prioridad '||coalesce(m->>'priority','NORMAL'),'Prioridad '),case when coalesce(m->>'due_date','')<>'' then 'Vence '||m->>'due_date' else null end));
  elsif e='MANUAL_NOTIFICATION' then
    title:=left(coalesce(nullif(m->>'title',''),'Notificación ASCENDA'),120);
    body:=left(coalesce(m->>'body',''),320);
  else
    title:=left(coalesce(nullif(m->>'title',''),'ASCENDA'),120);
    body:=left(coalesce(m->>'body',''),320);
  end if;

  return jsonb_build_object('title',coalesce(nullif(title,''),'ASCENDA'),'body',coalesce(body,''));
end;
$$;

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
