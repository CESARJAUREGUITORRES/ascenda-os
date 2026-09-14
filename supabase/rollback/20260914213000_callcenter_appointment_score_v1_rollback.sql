-- Rollback: Call Center appointment score / competitive notifications V1
begin;

delete from public.aos_notification_policies_v1 where event_type='TEAM_APPOINTMENT_SCORE';
update public.aos_notification_policies_v1
set aggregate_seconds=60,description='Admin grouped new appointments',updated_at=now()
where event_type='ADMIN_APPOINTMENT_DIGEST';
update public.aos_notification_policies_v1
set aggregate_seconds=15,description='Advisor new appointment',updated_at=now()
where event_type='APPOINTMENT_CREATED';

drop function if exists public.aos_callcenter_score_latest_v1(date);
drop function if exists public.aos_monitoreo_equipo(date);

create function public.aos_monitoreo_equipo(p_hoy date default current_date)
returns table(nombre text,llamadas bigint,citas bigint,conv_pct integer,ult_num text,ult_hora text,mins_sin integer)
language plpgsql
as $$
begin
  return query
  select
    l.asesor as nombre,
    count(*) as llamadas,
    sum(case when l.estado='CITA CONFIRMADA' then 1 else 0 end) as citas,
    case when count(*)>0
      then (sum(case when l.estado='CITA CONFIRMADA' then 1 else 0 end)*100/count(*))::integer
      else 0 end as conv_pct,
    (select l2.numero_limpio from public.aos_llamadas l2
      where l2.asesor=l.asesor and l2.fecha=p_hoy
      order by l2.hora_llamada desc limit 1) as ult_num,
    (select l2.hora_llamada from public.aos_llamadas l2
      where l2.asesor=l.asesor and l2.fecha=p_hoy
      order by l2.hora_llamada desc limit 1) as ult_hora,
    case when (select l2.hora_llamada from public.aos_llamadas l2
      where l2.asesor=l.asesor and l2.fecha=p_hoy
      order by l2.hora_llamada desc limit 1) is not null
      then extract(epoch from (
        now() at time zone 'America/Lima' -
        (p_hoy::timestamp + (
          select l2.hora_llamada::time from public.aos_llamadas l2
          where l2.asesor=l.asesor and l2.fecha=p_hoy
          order by l2.hora_llamada desc limit 1
        ))
      ))::integer/60
      else null end as mins_sin
  from public.aos_llamadas l
  where l.fecha=p_hoy
  group by l.asesor
  order by llamadas desc;
end;
$$;

grant execute on function public.aos_monitoreo_equipo(date) to anon,authenticated,service_role;

create or replace function public.aos_notification_format_v1(p_event_type text,p_metadata jsonb)
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
begin
  begin c:=greatest(1,coalesce((m->>'count')::integer,1)); exception when others then c:=1; end;
  begin amount:=coalesce((m->>'amount')::numeric,0); exception when others then amount:=0; end;
  begin commission:=coalesce((m->>'commission')::numeric,0); exception when others then commission:=0; end;
  begin adj:=coalesce((m->>'adjustment')::numeric,0); exception when others then adj:=0; end;

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
declare uid uuid; patient text; st text; oldst text; ev text; adm_ev text; adm record;
begin
  uid:=public.aos_notification_resolve_user_v1(coalesce(nullif(new.id_asesor,''),new.asesor));
  patient:=trim(concat_ws(' ',nullif(new.nombre,''),nullif(new.apellido,'')));
  if tg_op='INSERT' then
    if uid is not null then
      perform public.aos_notification_emit_v1(jsonb_build_object(
        'event_type','APPOINTMENT_CREATED','recipient_user_id',uid,'entity_id',new.id,'group_key','advisor',
        'metadata',jsonb_build_object('count',1,'last_patient',patient,'date',coalesce(new.fecha_cita::text,''),'time',coalesce(new.hora_cita,''),'last_sede',coalesce(new.sede,''),'last_treatment',coalesce(new.tratamiento,''))
      ));
    end if;
    for adm in select id from public.aos_usuarios where activo=true and (upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)=1) loop
      perform public.aos_notification_emit_v1(jsonb_build_object(
        'event_type','ADMIN_APPOINTMENT_DIGEST','recipient_user_id',adm.id,'entity_id',new.id,'group_key','all-appointments',
        'metadata',jsonb_build_object('count',1,'last_sede',coalesce(new.sede,''))
      ));
    end loop;
    return new;
  end if;

  st:=upper(trim(coalesce(new.estado_cita,''))); oldst:=upper(trim(coalesce(old.estado_cita,'')));
  if st=oldst then return new; end if;
  if st in ('ASISTIO','EFECTIVA') and oldst not in ('ASISTIO','EFECTIVA') then ev:='APPOINTMENT_ATTENDED'; adm_ev:='ADMIN_ATTENDED_DIGEST';
  elsif st='NO ASISTIO' then ev:='APPOINTMENT_NO_SHOW'; adm_ev:='ADMIN_NO_SHOW_DIGEST';
  elsif st='CANCELADA' then ev:='APPOINTMENT_CANCELLED';
  elsif st='REAGENDADA' then ev:='APPOINTMENT_RESCHEDULED';
  else return new; end if;

  if uid is not null then
    perform public.aos_notification_emit_v1(jsonb_build_object(
      'event_type',ev,'recipient_user_id',uid,'entity_id',new.id,'dedupe_key','agenda:'||lower(ev)||':'||new.id||':'||md5(st),
      'metadata',jsonb_build_object('count',1,'last_patient',patient,'date',coalesce(new.fecha_cita::text,''),'time',coalesce(new.hora_cita,''),'last_sede',coalesce(new.sede,''),'last_treatment',coalesce(new.tratamiento,''))
    ));
  end if;
  if adm_ev is not null then
    for adm in select id from public.aos_usuarios where activo=true and (upper(coalesce(rol,''))='ADMIN' or coalesce(nivel_jerarquia,999)=1) loop
      perform public.aos_notification_emit_v1(jsonb_build_object(
        'event_type',adm_ev,'recipient_user_id',adm.id,'entity_id',new.id,'group_key','all-attendance','metadata',jsonb_build_object('count',1)
      ));
    end loop;
  end if;
  return new;
end;
$$;

drop function if exists public.aos_callcenter_appointment_subtype_v1(text,text,text,bigint);
drop function if exists public.aos_callcenter_appointment_class_v1(text,text,text,bigint);

commit;
