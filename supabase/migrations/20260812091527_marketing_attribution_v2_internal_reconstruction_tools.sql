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
         coalesce(l.hora_ingreso,l.created_at,l.fecha::timestamptz) as _lead_ts,
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

revoke all on function public.aos_marketing_touchpoints_v2(date,date) from public;

create or replace function public.aos_marketing_call_cita_match_v2(
  p_desde date default null,
  p_hasta date default null
)
returns table(
  cita_id text,
  numero_limpio text,
  asesor text,
  cita_ts timestamptz,
  llamada_id bigint,
  llamada_ts timestamptz,
  diferencia_segundos numeric,
  candidatos_10m bigint,
  metodo_match text,
  confidence integer
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
         coalesce(ll.created_at,ll.ult_ts,ll.ts_log,ll.fecha::timestamptz) llamada_ts,
         abs(extract(epoch from (coalesce(ll.created_at,ll.ult_ts,ll.ts_log,ll.fecha::timestamptz)-c.cita_ts)))::numeric diferencia_segundos,
         count(*) over(partition by c.id) candidatos_10m,
         row_number() over(
           partition by c.id
           order by abs(extract(epoch from (coalesce(ll.created_at,ll.ult_ts,ll.ts_log,ll.fecha::timestamptz)-c.cita_ts))),ll.id desc
         ) rn
  from citas c
  join public.aos_llamadas ll
    on ll.numero_limpio=c.numero_limpio
   and upper(coalesce(ll.asesor,''))=upper(coalesce(c.asesor,''))
   and upper(coalesce(ll.estado,''))='CITA CONFIRMADA'
   and abs(extract(epoch from (coalesce(ll.created_at,ll.ult_ts,ll.ts_log,ll.fecha::timestamptz)-c.cita_ts)))<=600
), best as (
  select * from candidates where rn=1
)
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

revoke all on function public.aos_marketing_call_cita_match_v2(date,date) from public;
