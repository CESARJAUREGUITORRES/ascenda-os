-- ASCENDA OS — Direct trace links for validated Calls / Agenda / Marketing cases.

update public.aos_agenda_citas set lead_id_origen=5630,llamada_id_origen=36964 where id='2cc637d6-b5a8-40f3-9689-edad50db7ded';
update public.aos_agenda_citas set lead_id_origen=5644,llamada_id_origen=36948 where id='b693c961-62c1-4f0a-9be1-5e57f39a2cb9';
update public.aos_agenda_citas set lead_id_origen=5655,llamada_id_origen=37020 where id='04b17908-b2f4-4f60-b2a7-3e2d4d7a2779';
update public.aos_agenda_citas set lead_id_origen=null,llamada_id_origen=36968,etiqueta_campana='ORGANICO' where id='a949d259-f8ca-4618-bd1f-c25cb458f402';

create or replace function public.aos_marketing_call_cita_match_v2(p_desde date default null::date,p_hasta date default null::date)
returns table(cita_id text,numero_limpio text,asesor text,cita_ts timestamp with time zone,llamada_id bigint,llamada_ts timestamp with time zone,diferencia_segundos numeric,candidatos_10m bigint,metodo_match text,confidence integer)
language sql stable as $$
with citas as (
 select c.id,c.numero_limpio,c.asesor,coalesce(c.ts_creado,c.fecha_cita::timestamptz)cita_ts,c.llamada_id_origen
 from public.aos_agenda_citas c
 where (upper(coalesce(c.origen_cita,''))='CALL_CENTER' or c.llamada_id_origen is not null or exists(select 1 from public.aos_llamadas lx where lx.numero_limpio=c.numero_limpio and upper(coalesce(lx.asesor,''))=upper(coalesce(c.asesor,'')) and upper(coalesce(lx.estado,''))='CITA CONFIRMADA' and lx.lead_id_origen is not null and abs(extract(epoch from(public.aos_llamada_event_ts(lx.fecha,lx.hora_llamada,lx.created_at,lx.ult_ts,lx.ts_log)-coalesce(c.ts_creado,c.fecha_cita::timestamptz))))<=600))
 and c.numero_limpio is not null and c.numero_limpio<>'' and (p_desde is null or c.fecha_cita>=p_desde) and (p_hasta is null or c.fecha_cita<=p_hasta)
), candidates as (
 select c.id cita_id,c.numero_limpio,c.asesor,c.cita_ts,c.llamada_id_origen,ll.id llamada_id,public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)llamada_ts,
 abs(extract(epoch from(public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)-c.cita_ts)))::numeric diferencia_segundos,
 count(*) over(partition by c.id)candidatos_10m,
 row_number() over(partition by c.id order by case when c.llamada_id_origen=ll.id then 0 else 1 end,abs(extract(epoch from(public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)-c.cita_ts))),ll.id desc)rn
 from citas c join public.aos_llamadas ll on ll.numero_limpio=c.numero_limpio and upper(coalesce(ll.asesor,''))=upper(coalesce(c.asesor,'')) and upper(coalesce(ll.estado,''))='CITA CONFIRMADA'
 and ((c.llamada_id_origen is not null and ll.id=c.llamada_id_origen) or (c.llamada_id_origen is null and abs(extract(epoch from(public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log)-c.cita_ts)))<=600))
),best as(select * from candidates where rn=1)
select c.id::text,c.numero_limpio,c.asesor,c.cita_ts,b.llamada_id,b.llamada_ts,b.diferencia_segundos,coalesce(b.candidatos_10m,0)::bigint,
case when b.llamada_id is null then 'SIN_MATCH' when c.llamada_id_origen=b.llamada_id then 'DIRECT_LLAMADA_ID' when b.candidatos_10m=1 then 'CALL_CITA_UNICO_10M' else 'CALL_CITA_AMBIGUO_10M' end,
case when b.llamada_id is null then 0 when c.llamada_id_origen=b.llamada_id then 100 when b.candidatos_10m=1 then 95 else 40 end
from citas c left join best b on b.cita_id=c.id order by c.cita_ts,c.id;
$$;

create or replace function public.aos_marketing_call_lead_match_v2(p_desde date default null::date,p_hasta date default null::date)
returns table(cita_id text,llamada_id bigint,llamada_ts timestamp with time zone,numero_limpio text,lead_id bigint,lead_ts timestamp with time zone,candidatos_previos bigint,candidatos_tratamiento bigint,metodo_match text,confidence integer)
language sql stable as $$
with tp as materialized(select * from public.aos_marketing_touchpoints_v2(null,null)),chain as materialized(
 select m.cita_id,m.llamada_id,m.llamada_ts,m.numero_limpio,ll.lead_id_origen,ll.tratamiento
 from public.aos_marketing_call_cita_match_v2(p_desde,p_hasta)m join public.aos_llamadas ll on ll.id=m.llamada_id
 where m.metodo_match in('CALL_CITA_UNICO_10M','DIRECT_LLAMADA_ID')
),counts as materialized(
 select c.*,count(t.lead_id)filter(where not t.es_duplicado_tecnico_probable and t.lead_ts<=c.llamada_ts)n_prior,
 count(t.lead_id)filter(where not t.es_duplicado_tecnico_probable and t.lead_ts<=c.llamada_ts and nullif(trim(c.tratamiento),'')is not null and upper(coalesce(t.tratamiento,''))=upper(c.tratamiento))n_trat
 from chain c left join tp t on t.numero_limpio=c.numero_limpio group by c.cita_id,c.llamada_id,c.llamada_ts,c.numero_limpio,c.lead_id_origen,c.tratamiento
),resolved as materialized(
 select c.*,case when c.lead_id_origen is not null then c.lead_id_origen when c.n_prior=1 then(select t.lead_id from tp t where t.numero_limpio=c.numero_limpio and not t.es_duplicado_tecnico_probable and t.lead_ts<=c.llamada_ts order by t.lead_ts desc,t.lead_id desc limit 1) when c.n_prior>1 and c.n_trat=1 then(select t.lead_id from tp t where t.numero_limpio=c.numero_limpio and not t.es_duplicado_tecnico_probable and t.lead_ts<=c.llamada_ts and nullif(trim(c.tratamiento),'')is not null and upper(coalesce(t.tratamiento,''))=upper(c.tratamiento) order by t.lead_ts desc,t.lead_id desc limit 1) else null end resolved_lead_id from counts c
)
select r.cita_id,r.llamada_id,r.llamada_ts,r.numero_limpio,r.resolved_lead_id,l.lead_ts,r.n_prior::bigint,r.n_trat::bigint,
case when r.lead_id_origen is not null then 'DIRECT_LEAD_ID' when r.n_prior=1 then 'UNIQUE_PRIOR_LEAD' when r.n_prior>1 and r.n_trat=1 then 'UNIQUE_PRIOR_BY_TREATMENT' when r.n_prior=0 then 'NO_PRIOR_MARKETING_LEAD' else 'AMBIGUOUS_PRIOR_LEAD' end,
case when r.lead_id_origen is not null then 100 when r.n_prior=1 then 90 when r.n_prior>1 and r.n_trat=1 then 85 when r.n_prior=0 then 0 else 40 end
from resolved r left join tp l on l.lead_id=r.resolved_lead_id order by r.llamada_ts,r.llamada_id;
$$;
