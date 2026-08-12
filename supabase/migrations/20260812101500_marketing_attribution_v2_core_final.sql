-- ASCENDA OS — Marketing Attribution V2 canonical core state
-- Final-state migration generated from validated production definitions.

create or replace function public.aos_llamada_event_ts(
  p_fecha date,
  p_hora text,
  p_created timestamptz,
  p_ult timestamptz,
  p_log timestamptz
)
returns timestamptz
language sql
stable
as $$
select case
  when p_fecha is not null and coalesce(trim(p_hora),'') ~ '^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$'
    then ((p_fecha::text || ' ' || case when length(trim(p_hora))=5 then trim(p_hora)||':00' else trim(p_hora) end)::timestamp at time zone 'America/Lima')
  else coalesce(p_created,p_ult,p_log,p_fecha::timestamptz)
end;
$$;

create or replace function public.aos_lead_event_ts(
  p_fecha date,
  p_hora_ingreso timestamptz,
  p_created timestamptz
)
returns timestamptz
language sql
stable
as $$
select case
  when p_fecha is null then coalesce(p_hora_ingreso,p_created)
  when p_hora_ingreso is not null then
    ((p_fecha::text || ' ' || to_char(p_hora_ingreso at time zone 'America/Lima','HH24:MI:SS.US'))::timestamp at time zone 'America/Lima')
  when p_created is not null and (p_created at time zone 'America/Lima')::date=p_fecha then p_created
  else (p_fecha::timestamp at time zone 'America/Lima')
end;
$$;

create or replace function public.aos_marketing_touchpoints_v2(
  p_desde date default null,
  p_hasta date default null
)
returns table(
  lead_id bigint,
  numero_limpio text,
  fecha date,
  hora_ingreso timestamptz,
  tratamiento text,
  anuncio text,
  lead_ts timestamptz,
  next_lead_ts timestamptz,
  es_duplicado_tecnico_probable boolean,
  duplicate_rank bigint
)
language sql
stable
as $$
with base as (
  select l.*,
         public.aos_lead_event_ts(l.fecha,l.hora_ingreso,l.created_at) as _lead_ts,
         row_number() over(
           partition by l.numero_limpio,l.fecha,l.hora_ingreso,coalesce(l.tratamiento,''),coalesce(l.anuncio,''),l.created_at
           order by l.id
         ) as _dup_rank
  from public.aos_leads l
  where l.numero_limpio is not null and l.numero_limpio<>''
), timeline as (
  select b.*,
         lead(b._lead_ts) over(partition by b.numero_limpio order by b._lead_ts,b.id) as _next_lead_ts
  from base b
  where b._dup_rank=1
)
select b.id::bigint,b.numero_limpio,b.fecha,b.hora_ingreso,b.tratamiento,b.anuncio,b._lead_ts,
       case when b._dup_rank=1 then t._next_lead_ts else null end,
       (b._dup_rank>1),b._dup_rank::bigint
from base b
left join timeline t on t.id=b.id
where (p_desde is null or b.fecha>=p_desde)
  and (p_hasta is null or b.fecha<=p_hasta)
order by b.fecha,b._lead_ts,b.id;
$$;

create or replace function public.aos_marketing_leads_detalle_v2(p_fecha_desde date default null,p_fecha_hasta date default null)
returns table(
  lead_id bigint,fecha date,hora_ingreso timestamptz,celular text,numero_limpio text,tratamiento text,anuncio text,preguntas text,
  llamadas_total bigint,ultima_llamada timestamptz,ultimo_estado text,ultimo_asesor text,citas_total bigint,proxima_cita_fecha date,
  proxima_cita_estado text,ventas_total bigint,monto_facturado numeric,estado_lead text
)
language sql
stable
as $$
with params as (
  select coalesce(p_fecha_desde,date_trunc('month',current_date)::date) d,coalesce(p_fecha_hasta,current_date) h
), lead_timeline as (
  select l.*,
         public.aos_lead_event_ts(l.fecha,l.hora_ingreso,l.created_at) as lead_ts,
         lead(public.aos_lead_event_ts(l.fecha,l.hora_ingreso,l.created_at)) over(
           partition by l.numero_limpio
           order by public.aos_lead_event_ts(l.fecha,l.hora_ingreso,l.created_at),l.id
         ) as next_lead_ts
  from public.aos_leads l
  where l.numero_limpio is not null and l.numero_limpio<>''
), lp as (
  select lt.* from lead_timeline lt,params p where lt.fecha between p.d and p.h
)
select lp.id::bigint,lp.fecha,lp.hora_ingreso,lp.celular,lp.numero_limpio,lp.tratamiento,lp.anuncio,lp.preguntas,
       coalesce(la.total_llam,0)::bigint,la.ultima_ts,la.ult_estado,la.ult_asesor,
       coalesce(ca.total_citas,0)::bigint,ca.prox_fecha,ca.prox_estado,
       coalesce(va.total_ventas,0)::bigint,coalesce(va.monto_total,0)::numeric,
       case when coalesce(va.total_ventas,0)>0 then 'VENDIDO'
            when coalesce(ca.total_citas,0)>0 then 'CON CITA'
            when coalesce(la.total_llam,0)>0 then 'EN GESTION'
            else 'SIN CONTACTO' end::text
from lp
left join lateral (
  select count(*) total_llam,
         max(public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)) ultima_ts,
         (array_agg(ll.estado order by public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log) desc nulls last,ll.id desc))[1] ult_estado,
         (array_agg(ll.asesor order by public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log) desc nulls last,ll.id desc))[1] ult_asesor
  from public.aos_llamadas ll
  where ll.numero_limpio=lp.numero_limpio
    and (ll.lead_id_origen=lp.id or (ll.lead_id_origen is null
      and public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)>=lp.lead_ts
      and (lp.next_lead_ts is null or public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)<lp.next_lead_ts)))
) la on true
left join lateral (
  select count(*) total_citas,
         min(c.fecha_cita) filter(where c.fecha_cita>=current_date) prox_fecha,
         (array_agg(c.estado_cita order by coalesce(c.ts_creado,c.fecha_cita::timestamptz) desc nulls last))[1] prox_estado
  from public.aos_agenda_citas c
  where c.numero_limpio=lp.numero_limpio
    and (c.lead_id_origen=lp.id or (c.lead_id_origen is null
      and coalesce(c.ts_creado,c.fecha_cita::timestamptz)>=lp.lead_ts
      and (lp.next_lead_ts is null or coalesce(c.ts_creado,c.fecha_cita::timestamptz)<lp.next_lead_ts)))
) ca on true
left join lateral (
  select count(*) total_ventas,coalesce(sum(coalesce(v.monto::numeric,0)),0) monto_total
  from public.aos_ventas v
  where v.numero_limpio=lp.numero_limpio
    and v.fecha>=lp.fecha
    and (lp.next_lead_ts is null or v.fecha<lp.next_lead_ts::date)
) va on true
order by lp.fecha desc,lp.hora_ingreso desc nulls last,lp.id desc;
$$;

create or replace function public.aos_marketing_call_cita_match_v2(
  p_desde date default null,
  p_hasta date default null
)
returns table(
  cita_id text,numero_limpio text,asesor text,cita_ts timestamptz,llamada_id bigint,llamada_ts timestamptz,
  diferencia_segundos numeric,candidatos_10m bigint,metodo_match text,confidence integer
)
language sql
stable
as $$
with citas as (
  select c.id,c.numero_limpio,c.asesor,coalesce(c.ts_creado,c.fecha_cita::timestamptz) as cita_ts
  from public.aos_agenda_citas c
  where upper(coalesce(c.origen_cita,''))='CALL_CENTER'
    and c.numero_limpio is not null and c.numero_limpio<>''
    and (p_desde is null or c.fecha_cita>=p_desde)
    and (p_hasta is null or c.fecha_cita<=p_hasta)
), candidates as (
  select c.id cita_id,c.numero_limpio,c.asesor,c.cita_ts,ll.id llamada_id,
         public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log) llamada_ts,
         abs(extract(epoch from (public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)-c.cita_ts)))::numeric diferencia_segundos,
         count(*) over(partition by c.id) candidatos_10m,
         row_number() over(
           partition by c.id
           order by abs(extract(epoch from (public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)-c.cita_ts))),ll.id desc
         ) rn
  from citas c
  join public.aos_llamadas ll
    on ll.numero_limpio=c.numero_limpio
   and upper(coalesce(ll.asesor,''))=upper(coalesce(c.asesor,''))
   and upper(coalesce(ll.estado,''))='CITA CONFIRMADA'
   and abs(extract(epoch from (public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)-c.cita_ts)))<=600
), best as (select * from candidates where rn=1)
select c.id::text,c.numero_limpio,c.asesor,c.cita_ts,b.llamada_id,b.llamada_ts,b.diferencia_segundos,
       coalesce(b.candidatos_10m,0)::bigint,
       case when b.llamada_id is null then 'SIN_MATCH'
            when b.candidatos_10m=1 then 'CALL_CITA_UNICO_10M'
            else 'CALL_CITA_AMBIGUO_10M' end,
       case when b.llamada_id is null then 0
            when b.candidatos_10m=1 then 95
            else 40 end
from citas c
left join best b on b.cita_id=c.id
order by c.cita_ts,c.id;
$$;

create or replace function public.aos_marketing_call_lead_match_v2(
  p_desde date default null,
  p_hasta date default null
)
returns table(
  cita_id text,llamada_id bigint,llamada_ts timestamptz,numero_limpio text,lead_id bigint,lead_ts timestamptz,
  candidatos_previos bigint,candidatos_tratamiento bigint,metodo_match text,confidence integer
)
language sql
stable
as $$
with chain as (
  select m.cita_id,m.llamada_id,m.llamada_ts,m.numero_limpio,ll.lead_id_origen,ll.tratamiento
  from public.aos_marketing_call_cita_match_v2(p_desde,p_hasta) m
  join public.aos_llamadas ll on ll.id=m.llamada_id
  where m.metodo_match='CALL_CITA_UNICO_10M'
), counts as (
  select c.*,
    (select count(*) from public.aos_marketing_touchpoints_v2(null,null) l
      where l.numero_limpio=c.numero_limpio and not l.es_duplicado_tecnico_probable and l.lead_ts<=c.llamada_ts) as n_prior,
    (select count(*) from public.aos_marketing_touchpoints_v2(null,null) l
      where l.numero_limpio=c.numero_limpio and not l.es_duplicado_tecnico_probable and l.lead_ts<=c.llamada_ts
        and nullif(trim(c.tratamiento),'') is not null and upper(coalesce(l.tratamiento,''))=upper(c.tratamiento)) as n_trat
  from chain c
), resolved as (
  select c.*,
    case
      when c.lead_id_origen is not null then c.lead_id_origen
      when c.n_prior=1 then (
        select l.lead_id from public.aos_marketing_touchpoints_v2(null,null) l
        where l.numero_limpio=c.numero_limpio and not l.es_duplicado_tecnico_probable and l.lead_ts<=c.llamada_ts
        order by l.lead_ts desc,l.lead_id desc limit 1)
      when c.n_prior>1 and c.n_trat=1 then (
        select l.lead_id from public.aos_marketing_touchpoints_v2(null,null) l
        where l.numero_limpio=c.numero_limpio and not l.es_duplicado_tecnico_probable and l.lead_ts<=c.llamada_ts
          and nullif(trim(c.tratamiento),'') is not null and upper(coalesce(l.tratamiento,''))=upper(c.tratamiento)
        order by l.lead_ts desc,l.lead_id desc limit 1)
      else null end as resolved_lead_id
  from counts c
)
select r.cita_id,r.llamada_id,r.llamada_ts,r.numero_limpio,r.resolved_lead_id,l.lead_ts,r.n_prior::bigint,r.n_trat::bigint,
       case when r.lead_id_origen is not null then 'DIRECT_LEAD_ID'
            when r.n_prior=1 then 'UNIQUE_PRIOR_LEAD'
            when r.n_prior>1 and r.n_trat=1 then 'UNIQUE_PRIOR_BY_TREATMENT'
            when r.n_prior=0 then 'NO_PRIOR_MARKETING_LEAD'
            else 'AMBIGUOUS_PRIOR_LEAD' end,
       case when r.lead_id_origen is not null then 100
            when r.n_prior=1 then 90
            when r.n_prior>1 and r.n_trat=1 then 85
            when r.n_prior=0 then 0
            else 40 end
from resolved r
left join public.aos_marketing_touchpoints_v2(null,null) l on l.lead_id=r.resolved_lead_id
order by r.llamada_ts,r.llamada_id;
$$;

create or replace function public.aos_marketing_sale_attribution_v2(
  p_desde date default null,
  p_hasta date default null
)
returns table(
  venta_pk bigint,venta_id text,venta_fecha date,monto numeric,tratamiento_compra text,numero_limpio text,
  lead_id bigint,lead_fecha date,lead_anuncio text,lead_tratamiento text,llamada_id bigint,cita_id text,cita_estado text,
  metodo_match text,confidence integer,anomaly_code text
)
language sql
stable
as $$
with ventas as (
  select v.* from public.aos_ventas v
  where v.numero_limpio is not null and v.numero_limpio<>''
    and (p_desde is null or v.fecha>=p_desde)
    and (p_hasta is null or v.fecha<=p_hasta)
), candidates as (
  select v.id venta_pk,c.id cita_id,c.estado_cita,cl.llamada_id,cl.lead_id,cl.confidence lead_confidence,
         count(*) over(partition by v.id) candidate_citas,
         row_number() over(partition by v.id order by cl.confidence desc,c.id) rn
  from ventas v
  join public.aos_agenda_citas c on c.numero_limpio=v.numero_limpio and c.fecha_cita=v.fecha and upper(coalesce(c.origen_cita,''))='CALL_CENTER'
  join public.aos_marketing_call_lead_match_v2(null,null) cl on cl.cita_id=c.id and cl.lead_id is not null and cl.confidence>=85
), best as (select * from candidates where rn=1)
select v.id::bigint,v.venta_id,v.fecha,v.monto,v.tratamiento,v.numero_limpio,
  case when b.candidate_citas=1 then b.lead_id else null end,
  case when b.candidate_citas=1 then l.fecha else null end,
  case when b.candidate_citas=1 then l.anuncio else null end,
  case when b.candidate_citas=1 then l.tratamiento else null end,
  case when b.candidate_citas=1 then b.llamada_id else null end,
  case when b.candidate_citas=1 then b.cita_id else null end,
  case when b.candidate_citas=1 then b.estado_cita else null end,
  case when b.venta_pk is null then 'SIN_MATCH'
       when b.candidate_citas>1 then 'AMBIGUOUS_CITA_SAME_DAY'
       when upper(coalesce(b.estado_cita,'')) in ('ASISTIO','EFECTIVA') then 'CALL_CITA_ATTENDED_SAME_DAY'
       when upper(coalesce(b.estado_cita,''))='NO ASISTIO' then 'CALL_CITA_NO_SHOW_WITH_SALE'
       else 'CALL_CITA_OTHER_STATUS_WITH_SALE' end,
  case when b.venta_pk is null then 0
       when b.candidate_citas>1 then 40
       when upper(coalesce(b.estado_cita,'')) in ('ASISTIO','EFECTIVA') then least(b.lead_confidence,90)
       when upper(coalesce(b.estado_cita,''))='NO ASISTIO' then least(b.lead_confidence,80)
       else least(b.lead_confidence,60) end,
  case when b.venta_pk is null then null
       when b.candidate_citas>1 then 'MULTIPLE_CITAS_SAME_DAY'
       when upper(coalesce(b.estado_cita,''))='NO ASISTIO' then 'NO_SHOW_WITH_SAME_DAY_SALE'
       when upper(coalesce(b.estado_cita,'')) not in ('ASISTIO','EFECTIVA') then 'NON_ATTENDED_STATUS_WITH_SALE'
       else null end
from ventas v
left join best b on b.venta_pk=v.id
left join public.aos_leads l on l.id=b.lead_id
order by v.fecha,v.id;
$$;

create or replace function public.aos_marketing_attribution_v2_preview(
  p_desde date default null,
  p_hasta date default null
)
returns table(
  venta_pk bigint,venta_id text,venta_fecha date,monto numeric,tratamiento_compra text,numero_limpio text,
  lead_id bigint,lead_fecha date,lead_anuncio text,lead_tratamiento text,llamada_id bigint,cita_id text,
  metodo_match text,confidence integer,tipo_atribucion text,anomaly_code text
)
language sql
stable
as $$
with strong as materialized (
  select a.* from public.aos_marketing_sale_attribution_v2(p_desde,p_hasta) a
  where a.confidence>=80 and a.lead_id is not null
), effective_touchpoints as materialized (
  select * from public.aos_marketing_touchpoints_v2(null,null) where not es_duplicado_tecnico_probable
), fallback_candidates as (
  select v.id venta_pk,count(t.lead_id) n_candidates,min(t.lead_id) candidate_lead_id
  from public.aos_ventas v
  join effective_touchpoints t on t.numero_limpio=v.numero_limpio
   and date_trunc('month',t.fecha)=date_trunc('month',v.fecha) and t.fecha<=v.fecha
  left join strong s on s.venta_pk=v.id
  where s.venta_pk is null and v.numero_limpio is not null and v.numero_limpio<>''
    and (p_desde is null or v.fecha>=p_desde) and (p_hasta is null or v.fecha<=p_hasta)
    and not exists(select 1 from public.aos_leads old where old.numero_limpio=v.numero_limpio and old.fecha<date_trunc('month',v.fecha)::date)
  group by v.id
), fallback as (
  select v.id::bigint venta_pk,v.venta_id,v.fecha venta_fecha,v.monto,v.tratamiento tratamiento_compra,v.numero_limpio,
         t.lead_id,t.fecha lead_fecha,t.anuncio lead_anuncio,t.tratamiento lead_tratamiento,
         null::bigint llamada_id,null::text cita_id,'SAME_MONTH_UNIQUE_NEW_CUSTOMER'::text metodo_match,70::integer confidence,null::text anomaly_code
  from fallback_candidates fc
  join public.aos_ventas v on v.id=fc.venta_pk
  join effective_touchpoints t on t.lead_id=fc.candidate_lead_id
  where fc.n_candidates=1
), combined as (
  select s.venta_pk,s.venta_id,s.venta_fecha,s.monto,s.tratamiento_compra,s.numero_limpio,
         s.lead_id,s.lead_fecha,s.lead_anuncio,s.lead_tratamiento,s.llamada_id,s.cita_id,s.metodo_match,s.confidence,s.anomaly_code
  from strong s
  union all
  select f.* from fallback f
)
select c.venta_pk,c.venta_id,c.venta_fecha,c.monto,c.tratamiento_compra,c.numero_limpio,
       c.lead_id,c.lead_fecha,c.lead_anuncio,c.lead_tratamiento,c.llamada_id,c.cita_id,c.metodo_match,c.confidence,
       case when not exists(select 1 from public.aos_ventas pv where pv.numero_limpio=c.numero_limpio and pv.fecha<c.venta_fecha) then 'ADQUISICION'
            when c.lead_fecha>(select max(pv.fecha) from public.aos_ventas pv where pv.numero_limpio=c.numero_limpio and pv.fecha<c.venta_fecha) then 'REACTIVACION'
            else 'SEGUIMIENTO_HISTORICO' end::text,
       c.anomaly_code
from combined c
order by c.venta_fecha,c.venta_pk;
$$;

create or replace function public.aos_marketing_attribution_review_v2(
  p_desde date default null,
  p_hasta date default null
)
returns table(anomaly_code text,entity_type text,entity_id text,event_date date,severity text,confidence integer,context jsonb)
language sql
stable
as $$
with strong_sales as materialized (
  select * from public.aos_marketing_sale_attribution_v2(p_desde,p_hasta)
), duplicate_touchpoints as (
  select 'PROBABLE_TECHNICAL_DUPLICATE_LEAD'::text,'LEAD'::text,t.lead_id::text,t.fecha,'MEDIUM'::text,95::integer,
         jsonb_build_object('duplicate_rank',t.duplicate_rank,'tratamiento',t.tratamiento,'anuncio',t.anuncio)
  from public.aos_marketing_touchpoints_v2(p_desde,p_hasta) t where t.es_duplicado_tecnico_probable
), call_cita as (
  select case when m.metodo_match='CALL_CITA_AMBIGUO_10M' then 'AMBIGUOUS_CALL_TO_APPOINTMENT' else 'NO_CALL_MATCH_FOR_CALLCENTER_APPOINTMENT' end::text,
         'CITA'::text,m.cita_id::text,(m.cita_ts at time zone 'America/Lima')::date,
         case when m.metodo_match='CALL_CITA_AMBIGUO_10M' then 'HIGH' else 'MEDIUM' end::text,m.confidence::integer,
         jsonb_build_object('candidatos_10m',m.candidatos_10m,'metodo',m.metodo_match)
  from public.aos_marketing_call_cita_match_v2(p_desde,p_hasta) m where m.metodo_match in ('CALL_CITA_AMBIGUO_10M','SIN_MATCH')
), lead_ambiguous as (
  select 'AMBIGUOUS_PRIOR_MARKETING_LEAD'::text,'LLAMADA'::text,m.llamada_id::text,(m.llamada_ts at time zone 'America/Lima')::date,
         'HIGH'::text,m.confidence::integer,jsonb_build_object('cita_id',m.cita_id,'candidatos_previos',m.candidatos_previos,'candidatos_tratamiento',m.candidatos_tratamiento)
  from public.aos_marketing_call_lead_match_v2(p_desde,p_hasta) m where m.metodo_match='AMBIGUOUS_PRIOR_LEAD'
), sale_anomalies as (
  select a.anomaly_code::text,'VENTA'::text,a.venta_pk::text,a.venta_fecha,
         case when a.anomaly_code='MULTIPLE_CITAS_SAME_DAY' then 'HIGH' else 'MEDIUM' end::text,a.confidence::integer,
         jsonb_build_object('cita_id',a.cita_id,'lead_id',a.lead_id,'metodo',a.metodo_match,'estado_cita',a.cita_estado)
  from strong_sales a where a.anomaly_code is not null
), month_first_lead as materialized (
  select date_trunc('month',fecha)::date month_start,numero_limpio,min(fecha) first_lead_date
  from public.aos_leads where numero_limpio is not null and numero_limpio<>'' group by 1,2
), sale_before_lead as (
  select 'SALE_BEFORE_FIRST_LEAD_OF_MONTH'::text,'VENTA'::text,v.id::text,v.fecha,'HIGH'::text,100::integer,
         jsonb_build_object('first_lead_date',m.first_lead_date,'sale_amount',v.monto)
  from public.aos_ventas v join month_first_lead m on m.numero_limpio=v.numero_limpio and m.month_start=date_trunc('month',v.fecha)::date
  where v.fecha<m.first_lead_date and (p_desde is null or v.fecha>=p_desde) and (p_hasta is null or v.fecha<=p_hasta)
), prior_history as materialized (
  select m.month_start,m.numero_limpio,count(*) prior_leads
  from month_first_lead m join public.aos_leads old on old.numero_limpio=m.numero_limpio and old.fecha<m.month_start
  group by m.month_start,m.numero_limpio
), reentry_uncertain as (
  select 'SAME_MONTH_SALE_WITH_PRIOR_MARKETING_HISTORY'::text,'VENTA'::text,v.id::text,v.fecha,'MEDIUM'::text,60::integer,
         jsonb_build_object('same_month_first_lead',m.first_lead_date,'prior_leads',p.prior_leads)
  from public.aos_ventas v
  join month_first_lead m on m.numero_limpio=v.numero_limpio and m.month_start=date_trunc('month',v.fecha)::date and v.fecha>=m.first_lead_date
  join prior_history p on p.numero_limpio=v.numero_limpio and p.month_start=m.month_start
  left join strong_sales s on s.venta_pk=v.id and s.confidence>=80
  where s.venta_pk is null and (p_desde is null or v.fecha>=p_desde) and (p_hasta is null or v.fecha<=p_hasta)
)
select * from duplicate_touchpoints
union all select * from call_cita
union all select * from lead_ambiguous
union all select * from sale_anomalies
union all select * from sale_before_lead
union all select * from reentry_uncertain
order by event_date,anomaly_code,entity_id;
$$;

create or replace function public.aos_marketing_touchpoint_classification_v2(
  p_desde date default null,
  p_hasta date default null
)
returns table(
  lead_id bigint,numero_limpio text,fecha date,lead_ts timestamptz,tratamiento text,anuncio text,classification text,
  had_prior_lead boolean,had_prior_sale boolean,prior_leads bigint,duplicate_rank bigint
)
language sql
stable
as $$
with tp as materialized (select * from public.aos_marketing_touchpoints_v2(p_desde,p_hasta))
select t.lead_id,t.numero_limpio,t.fecha,t.lead_ts,t.tratamiento,t.anuncio,
  case when t.es_duplicado_tecnico_probable then 'DUPLICADO_TECNICO_PROBABLE'
       when exists(select 1 from public.aos_ventas v where v.numero_limpio=t.numero_limpio and v.fecha<t.fecha) then 'REINGRESO_CLIENTE_EXISTENTE'
       when exists(select 1 from public.aos_leads p where p.numero_limpio=t.numero_limpio and p.id<>t.lead_id and public.aos_lead_event_ts(p.fecha,p.hora_ingreso,p.created_at)<t.lead_ts) then
         case when exists(select 1 from public.aos_leads p where p.numero_limpio=t.numero_limpio and p.id<>t.lead_id
                          and date_trunc('month',p.fecha)=date_trunc('month',t.fecha)
                          and public.aos_lead_event_ts(p.fecha,p.hora_ingreso,p.created_at)<t.lead_ts)
              then 'REINGRESO_PROSPECTO_MISMO_MES' else 'REINGRESO_PROSPECTO_HISTORICO' end
       else 'PRIMER_TOUCH' end::text,
  exists(select 1 from public.aos_leads p where p.numero_limpio=t.numero_limpio and p.id<>t.lead_id and public.aos_lead_event_ts(p.fecha,p.hora_ingreso,p.created_at)<t.lead_ts),
  exists(select 1 from public.aos_ventas v where v.numero_limpio=t.numero_limpio and v.fecha<t.fecha),
  (select count(*) from public.aos_leads p where p.numero_limpio=t.numero_limpio and p.id<>t.lead_id and public.aos_lead_event_ts(p.fecha,p.hora_ingreso,p.created_at)<t.lead_ts)::bigint,
  t.duplicate_rank
from tp t
order by t.fecha,t.lead_ts,t.lead_id;
$$;

-- Internal reconstruction / preview functions stay private.
revoke execute on function public.aos_llamada_event_ts(date,text,timestamptz,timestamptz,timestamptz) from public,anon,authenticated;
revoke execute on function public.aos_lead_event_ts(date,timestamptz,timestamptz) from public,anon,authenticated;
revoke execute on function public.aos_marketing_touchpoints_v2(date,date) from public,anon,authenticated;
revoke execute on function public.aos_marketing_call_cita_match_v2(date,date) from public,anon,authenticated;
revoke execute on function public.aos_marketing_call_lead_match_v2(date,date) from public,anon,authenticated;
revoke execute on function public.aos_marketing_sale_attribution_v2(date,date) from public,anon,authenticated;
revoke execute on function public.aos_marketing_attribution_v2_preview(date,date) from public,anon,authenticated;
revoke execute on function public.aos_marketing_attribution_review_v2(date,date) from public,anon,authenticated;
revoke execute on function public.aos_marketing_touchpoint_classification_v2(date,date) from public,anon,authenticated;
