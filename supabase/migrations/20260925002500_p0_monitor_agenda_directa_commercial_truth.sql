-- P0 2026-09-24
-- Agenda Directa is a commercial KPI, not a count of every historical/manual agenda row
-- reinserted today. Only future-or-today CONSULTA NUEVA rows classified as AGENDA_DIRECTA
-- are eligible. This excludes APLICACION / CONTROL / MANTENIMIENTO / REPROGRAMACION and
-- historical backfill rows whose appointment date is already in the past.

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
       and upper(trim(coalesce(a.tipo_cita,'')))='CONSULTA NUEVA'
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
