-- ASCENDA OS · Marketing P0.5
-- Preserve the canonical monthly summary JSON while avoiding the full lead-detail
-- materialization used only to answer two boolean counters.

create or replace function public.aos_marketing_period_summary_v2(
  p_fecha_desde date,
  p_fecha_hasta date
)
returns jsonb
language sql
stable
security definer
set search_path to 'public'
as $function$
with params as (
  select p_fecha_desde::date d,p_fecha_hasta::date h
),
period_seed as materialized (
  select l.id,l.fecha,l.numero_limpio,l.tratamiento,l.hora_ingreso,l.created_at
  from public.aos_leads l,params p
  where l.fecha between p.d and p.h
    and l.numero_limpio is not null
    and l.numero_limpio<>''
),
phones as materialized (
  select distinct numero_limpio
  from period_seed
),
timeline as materialized (
  select
    l.id,
    l.fecha,
    l.numero_limpio,
    l.tratamiento,
    public.aos_lead_event_ts(l.fecha,l.hora_ingreso,l.created_at) lead_ts,
    lead(public.aos_lead_event_ts(l.fecha,l.hora_ingreso,l.created_at)) over(
      partition by l.numero_limpio
      order by public.aos_lead_event_ts(l.fecha,l.hora_ingreso,l.created_at),l.id
    ) next_lead_ts
  from public.aos_leads l
  join phones p using(numero_limpio)
),
period_leads as materialized (
  select t.*
  from timeline t,params p
  where t.fecha between p.d and p.h
),
cohort as materialized (
  select numero_limpio,min(fecha) first_lead_date
  from period_seed
  group by numero_limpio
),
person_flags as materialized (
  select
    c.numero_limpio,
    exists(
      select 1
      from public.aos_llamadas l,params p
      where l.numero_limpio=c.numero_limpio
        and l.fecha between c.first_lead_date and p.h
    ) managed,
    exists(
      select 1
      from public.aos_llamadas l,params p
      where l.numero_limpio=c.numero_limpio
        and l.fecha between c.first_lead_date and p.h
        and upper(l.estado)='CITA CONFIRMADA'
    ) cita_tel,
    exists(
      select 1
      from public.aos_agenda_citas a,params p
      where a.numero_limpio=c.numero_limpio
        and a.fecha_cita between c.first_lead_date and p.h
    ) con_cita,
    exists(
      select 1
      from public.aos_agenda_citas a,params p
      where a.numero_limpio=c.numero_limpio
        and a.fecha_cita between c.first_lead_date and p.h
        and upper(a.estado_cita) in ('ASISTIO','EFECTIVA')
    ) asistio
  from cohort c
),
touch_flags as materialized (
  select
    lp.id,
    exists(
      select 1
      from public.aos_llamadas ll
      where ll.numero_limpio=lp.numero_limpio
        and (
          ll.lead_id_origen=lp.id
          or (
            ll.lead_id_origen is null
            and public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)>=lp.lead_ts
            and (
              lp.next_lead_ts is null
              or public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)<lp.next_lead_ts
            )
          )
        )
    ) has_call,
    exists(
      select 1
      from public.aos_agenda_citas c
      where c.numero_limpio=lp.numero_limpio
        and (
          c.lead_id_origen=lp.id
          or exists(
            select 1
            from public.aos_llamadas llx
            where llx.numero_limpio=lp.numero_limpio
              and llx.lead_id_origen=lp.id
              and upper(coalesce(llx.estado,''))='CITA CONFIRMADA'
              and abs(extract(epoch from(
                public.aos_llamada_event_ts(llx.fecha,llx.hora_llamada,llx.created_at,llx.ult_ts,llx.ts_log)
                -coalesce(c.ts_creado,c.fecha_cita::timestamptz)
              )))<=600
          )
          or (
            c.lead_id_origen is null
            and coalesce(c.ts_creado,c.fecha_cita::timestamptz)>=lp.lead_ts
            and (
              lp.next_lead_ts is null
              or coalesce(c.ts_creado,c.fecha_cita::timestamptz)<lp.next_lead_ts
            )
          )
        )
    ) has_cita
  from period_leads lp
),
attrs_m0 as materialized (
  select a.*
  from public.aos_marketing_attribution_v2_preview(p_fecha_desde,p_fecha_hasta) a
  where a.lead_fecha between p_fecha_desde and p_fecha_hasta
    and a.venta_fecha between p_fecha_desde and p_fecha_hasta
)
select jsonb_build_object(
  'ingresos',(select count(*) from period_seed),
  'personasUnicas',(select count(*) from cohort),
  'reingresos',greatest(0,(select count(*) from period_seed)-(select count(*) from cohort)),
  'personasGestionadas',(select count(*) from person_flags where managed),
  'personasSinGestion',greatest(0,(select count(*) from cohort)-(select count(*) from person_flags where managed)),
  'personasCitaTel',(select count(*) from person_flags where cita_tel),
  'personasConCita',(select count(*) from person_flags where con_cita),
  'personasAsistieron',(select count(*) from person_flags where asistio),
  'touchpointsGestionados',(select count(*) from touch_flags where has_call),
  'touchpointsConCita',(select count(*) from touch_flags where has_cita),
  'clientesM0',(select count(distinct numero_limpio) from attrs_m0),
  'ventasM0',(select count(*) from attrs_m0),
  'factM0',(select coalesce(sum(monto),0) from attrs_m0)
);
$function$;

comment on function public.aos_marketing_period_summary_v2(date,date) is
  'Marketing V4.2 canonical period summary. P0.5 preserves output semantics while limiting lead timeline/detail work to phones participating in the requested period.';
