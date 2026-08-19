-- MKT-INTEGRITY-HOTFIX-V3 / LOOP 2
-- Shadow/read-only Marketing V3. No business-table DML. V2 remains production.

create or replace function public.aos_marketing_treatment_family_v3(p_text text)
returns text language sql immutable parallel safe as $$
select case
  when nullif(btrim(coalesce(p_text,'')),'') is null then null
  when upper(p_text) like '%CAPIL%' or upper(p_text) like '%EXOSOM%' then 'CAPILAR'
  when upper(p_text) like '%BIO%ESTIM%' then 'BIOESTIMULADOR'
  when upper(p_text) like '%ENZIM%' then 'ENZIMAS'
  when upper(p_text) like '%HIFU%' then 'HIFU'
  when upper(p_text) like '%TOXIN%' then 'TOXINA'
  when upper(p_text) like '%HIALUR%' then 'ACIDO_HIALURONICO'
  when upper(p_text) like '%CRIOLIP%' then 'CRIOLIPOLISIS'
  when upper(p_text) like '%HIDRO%' then 'HIDROFACIAL'
  when upper(p_text) like '%VITAM%' then 'VITAMINAS'
  when upper(p_text) like '%PINK%' or upper(p_text) like '%INTIMATE%' then 'PINK_INTIMATE'
  when upper(p_text) like '%RADIOFRECUENCIA%' then 'RADIOFRECUENCIA'
  else upper(regexp_replace(btrim(p_text),'\s+',' ','g'))
end;
$$;

create or replace function public.aos_marketing_call_lead_match_v3_preview(p_desde date default null, p_hasta date default null)
returns table(llamada_id bigint,llamada_ts timestamptz,numero_limpio text,llamada_tratamiento text,lead_id bigint,lead_ts timestamptz,lead_tratamiento text,metodo_match text,confidence integer,temporal_relation text,review_code text)
language sql stable as $$
with tp as materialized (
  select * from public.aos_marketing_touchpoints_v2(null,null) where not es_duplicado_tecnico_probable
), calls as materialized (
  select ll.id llamada_id,public.aos_llamada_event_ts(ll.fecha,ll.hora_llamada,ll.created_at,ll.ult_ts,ll.ts_log) llamada_ts,
         ll.numero_limpio,ll.tratamiento llamada_tratamiento,public.aos_marketing_treatment_family_v3(ll.tratamiento) llamada_family,ll.lead_id_origen
  from public.aos_llamadas ll
  where ll.numero_limpio is not null and ll.numero_limpio<>'' and (p_desde is null or ll.fecha>=p_desde) and (p_hasta is null or ll.fecha<=p_hasta)
), prior_ranked as (
  select c.llamada_id,t.lead_id,t.lead_ts,t.tratamiento lead_tratamiento,public.aos_marketing_treatment_family_v3(t.tratamiento) lead_family,
         row_number() over(partition by c.llamada_id order by t.lead_ts desc,t.lead_id desc) rn
  from calls c join tp t on t.numero_limpio=c.numero_limpio and t.lead_ts<=c.llamada_ts where c.lead_id_origen is null
), prior_best as (select * from prior_ranked where rn=1),
future_candidates as (
  select c.llamada_id,t.lead_id,t.lead_ts,t.tratamiento lead_tratamiento,count(*) over(partition by c.llamada_id) n_compatible,
         row_number() over(partition by c.llamada_id order by t.lead_ts,t.lead_id) rn
  from calls c
  left join prior_best pb on pb.llamada_id=c.llamada_id
  join tp t on t.numero_limpio=c.numero_limpio and t.lead_ts>c.llamada_ts and t.lead_ts<=c.llamada_ts+interval '12 hours'
           and (t.lead_ts at time zone 'America/Lima')::date=(c.llamada_ts at time zone 'America/Lima')::date
  where c.lead_id_origen is null
    and (pb.llamada_id is null or (c.llamada_family is not null and pb.lead_family is distinct from c.llamada_family))
    and (c.llamada_family is null or public.aos_marketing_treatment_family_v3(t.tratamiento)=c.llamada_family)
), future_best as (select * from future_candidates where rn=1),
future_any as (
  select c.llamada_id,count(*) n_any
  from calls c join tp t on t.numero_limpio=c.numero_limpio and t.lead_ts>c.llamada_ts and t.lead_ts<=c.llamada_ts+interval '12 hours'
   and (t.lead_ts at time zone 'America/Lima')::date=(c.llamada_ts at time zone 'America/Lima')::date
  group by c.llamada_id
)
select c.llamada_id,c.llamada_ts,c.numero_limpio,c.llamada_tratamiento,
 case when c.lead_id_origen is not null then c.lead_id_origen
      when pb.lead_id is not null and (c.llamada_family is null or pb.lead_family=c.llamada_family) then pb.lead_id
      when fb.n_compatible=1 then fb.lead_id else null end,
 case when c.lead_id_origen is not null then dl.lead_ts
      when pb.lead_id is not null and (c.llamada_family is null or pb.lead_family=c.llamada_family) then pb.lead_ts
      when fb.n_compatible=1 then fb.lead_ts else null end,
 case when c.lead_id_origen is not null then dl.tratamiento
      when pb.lead_id is not null and (c.llamada_family is null or pb.lead_family=c.llamada_family) then pb.lead_tratamiento
      when fb.n_compatible=1 then fb.lead_tratamiento else null end,
 case when c.lead_id_origen is not null then 'DIRECT_LEAD_ID'
      when pb.lead_id is not null and c.llamada_family is not null and pb.lead_family=c.llamada_family then 'TIMELINE_NEAREST_PRIOR_FAMILY'
      when pb.lead_id is not null and c.llamada_family is null then 'TIMELINE_NEAREST_PRIOR'
      when fb.n_compatible=1 then 'LATE_SAME_DAY_COMPATIBLE'
      when coalesce(fb.n_compatible,0)>1 then 'LATE_AMBIGUOUS' else 'NO_MATCH' end,
 case when c.lead_id_origen is not null then 100
      when pb.lead_id is not null and c.llamada_family is not null and pb.lead_family=c.llamada_family then 80
      when pb.lead_id is not null and c.llamada_family is null then 65
      when fb.n_compatible=1 then 75 when coalesce(fb.n_compatible,0)>1 then 40 else 0 end,
 case when c.lead_id_origen is not null then 'DIRECT'
      when pb.lead_id is not null and (c.llamada_family is null or pb.lead_family=c.llamada_family) then 'PRIOR'
      when fb.n_compatible=1 then 'LATE' else 'UNRESOLVED' end,
 case when c.lead_id_origen is not null or (pb.lead_id is not null and (c.llamada_family is null or pb.lead_family=c.llamada_family)) or fb.n_compatible=1 then null
      when coalesce(fb.n_compatible,0)>1 then 'MULTIPLE_LATE_COMPATIBLE'
      when pb.lead_id is not null and c.llamada_family is not null and pb.lead_family is distinct from c.llamada_family then 'PRIOR_TREATMENT_MISMATCH'
      when coalesce(fa.n_any,0)>0 then 'LATE_TREATMENT_MISMATCH' else 'NO_MARKETING_TOUCHPOINT' end
from calls c
left join tp dl on dl.lead_id=c.lead_id_origen
left join prior_best pb on pb.llamada_id=c.llamada_id
left join future_best fb on fb.llamada_id=c.llamada_id
left join future_any fa on fa.llamada_id=c.llamada_id;
$$;

create or replace function public.aos_marketing_agenda_lead_match_v3_preview(p_desde date default null, p_hasta date default null)
returns table(cita_id text,cita_ts timestamptz,fecha_cita date,numero_limpio text,asesor text,cita_tratamiento text,lead_id bigint,llamada_id bigint,metodo_match text,confidence integer,review_code text)
language sql stable as $$
with tp as materialized (select * from public.aos_marketing_touchpoints_v2(null,null) where not es_duplicado_tecnico_probable),
cm as materialized (select * from public.aos_marketing_call_lead_match_v3_preview(null,null)),
citas as materialized (
 select c.id cita_id,coalesce(c.ts_creado,c.fecha_cita::timestamptz) cita_ts,c.fecha_cita,c.numero_limpio,c.asesor,c.tratamiento cita_tratamiento,
        public.aos_marketing_treatment_family_v3(c.tratamiento) cita_family,c.lead_id_origen,c.llamada_id_origen,c.origen_cita,c.origen
 from public.aos_agenda_citas c
 where c.numero_limpio is not null and c.numero_limpio<>'' and (p_desde is null or c.fecha_cita>=p_desde) and (p_hasta is null or c.fecha_cita<=p_hasta)
), near_call_ranked as (
 select c.cita_id,m.llamada_id,m.lead_id,m.metodo_match,m.confidence,row_number() over(partition by c.cita_id order by abs(extract(epoch from(m.llamada_ts-c.cita_ts))),m.confidence desc,m.llamada_id desc) rn
 from citas c join cm m on m.numero_limpio=c.numero_limpio and m.lead_id is not null
 join public.aos_llamadas ll on ll.id=m.llamada_id
 where upper(coalesce(ll.estado,''))='CITA CONFIRMADA' and upper(coalesce(ll.asesor,''))=upper(coalesce(c.asesor,'')) and abs(extract(epoch from(m.llamada_ts-c.cita_ts)))<=600
), near_call as (select * from near_call_ranked where rn=1),
prior_ranked as (
 select c.cita_id,t.lead_id,t.lead_ts,t.tratamiento lead_tratamiento,public.aos_marketing_treatment_family_v3(t.tratamiento) lead_family,
        row_number() over(partition by c.cita_id order by t.lead_ts desc,t.lead_id desc) rn
 from citas c join tp t on t.numero_limpio=c.numero_limpio and t.lead_ts<=c.cita_ts
 where c.lead_id_origen is null and c.llamada_id_origen is null and upper(coalesce(c.origen_cita,'')) in ('CALL_CENTER','CITA_MANUAL','CALL_CENTER_MANUAL')
), prior_best as (select * from prior_ranked where rn=1),
future_candidates as (
 select c.cita_id,t.lead_id,t.lead_ts,t.tratamiento lead_tratamiento,count(*) over(partition by c.cita_id) n_compatible,
        row_number() over(partition by c.cita_id order by t.lead_ts,t.lead_id) rn
 from citas c
 left join prior_best pb on pb.cita_id=c.cita_id
 left join near_call nc on nc.cita_id=c.cita_id
 join tp t on t.numero_limpio=c.numero_limpio and t.lead_ts>c.cita_ts and t.lead_ts<=c.cita_ts+interval '12 hours'
  and (t.lead_ts at time zone 'America/Lima')::date=(c.cita_ts at time zone 'America/Lima')::date
 where c.lead_id_origen is null and c.llamada_id_origen is null and nc.cita_id is null
  and upper(coalesce(c.origen_cita,'')) in ('CALL_CENTER','CITA_MANUAL','CALL_CENTER_MANUAL')
  and (pb.cita_id is null or (c.cita_family is not null and pb.lead_family is distinct from c.cita_family))
  and (c.cita_family is null or public.aos_marketing_treatment_family_v3(t.tratamiento)=c.cita_family)
), future_best as (select * from future_candidates where rn=1)
select c.cita_id,c.cita_ts,c.fecha_cita,c.numero_limpio,c.asesor,c.cita_tratamiento,
 case when c.lead_id_origen is not null then c.lead_id_origen
      when c.llamada_id_origen is not null and dm.lead_id is not null then dm.lead_id
      when nc.lead_id is not null then nc.lead_id
      when pb.lead_id is not null and (c.cita_family is null or pb.lead_family=c.cita_family) then pb.lead_id
      when fb.n_compatible=1 then fb.lead_id else null end,
 case when c.llamada_id_origen is not null then c.llamada_id_origen when nc.llamada_id is not null then nc.llamada_id else null end,
 case when c.lead_id_origen is not null then 'DIRECT_LEAD_ID'
      when c.llamada_id_origen is not null and dm.lead_id is not null then 'DIRECT_LLAMADA_ID'
      when nc.lead_id is not null then 'NEAR_CONFIRMED_CALL'
      when pb.lead_id is not null and (c.cita_family is null or pb.lead_family=c.cita_family) then 'AGENDA_TIMELINE_PRIOR'
      when fb.n_compatible=1 then 'AGENDA_LATE_SAME_DAY_COMPATIBLE'
      when coalesce(fb.n_compatible,0)>1 then 'AGENDA_LATE_AMBIGUOUS' else 'NO_MATCH' end,
 case when c.lead_id_origen is not null then 100
      when c.llamada_id_origen is not null and dm.lead_id is not null then least(dm.confidence,98)
      when nc.lead_id is not null then least(nc.confidence,90)
      when pb.lead_id is not null and (c.cita_family is null or pb.lead_family=c.cita_family) then 60
      when fb.n_compatible=1 then 70 when coalesce(fb.n_compatible,0)>1 then 40 else 0 end,
 case when c.llamada_id_origen is not null and dm.lead_id is null then 'DIRECT_CALL_WITHOUT_LEAD'
      when coalesce(fb.n_compatible,0)>1 then 'MULTIPLE_LATE_COMPATIBLE'
      when pb.lead_id is not null and c.cita_family is not null and pb.lead_family is distinct from c.cita_family and fb.lead_id is null then 'PRIOR_TREATMENT_MISMATCH'
      when c.lead_id_origen is null and c.llamada_id_origen is null and nc.lead_id is null and pb.lead_id is null and fb.lead_id is null and upper(coalesce(c.origen_cita,'')) not in ('CALL_CENTER','CITA_MANUAL','CALL_CENTER_MANUAL') then 'AGENDA_NON_CALLCENTER'
      when c.lead_id_origen is null and coalesce(dm.lead_id,nc.lead_id,case when pb.lead_id is not null and (c.cita_family is null or pb.lead_family=c.cita_family) then pb.lead_id end,case when fb.n_compatible=1 then fb.lead_id end) is null then 'NO_MARKETING_TOUCHPOINT'
      else null end
from citas c
left join cm dm on dm.llamada_id=c.llamada_id_origen
left join near_call nc on nc.cita_id=c.cita_id
left join prior_best pb on pb.cita_id=c.cita_id
left join future_best fb on fb.cita_id=c.cita_id;
$$;

create or replace function public.aos_marketing_acquisition_customers_v3_preview()
returns table(numero_limpio text,lead_id bigint,lead_fecha date,lead_anuncio text,lead_tratamiento text,first_sale_date date,attribution_method text,confidence integer)
language sql stable as $$
with first_sale as materialized (
 select v.numero_limpio,min(v.fecha) first_sale_date from public.aos_ventas v where v.numero_limpio is not null and v.numero_limpio<>'' group by v.numero_limpio
), direct_attrs as materialized (
 select a.* from public.aos_marketing_attribution_v2_preview(null,null) a join first_sale f on f.numero_limpio=a.numero_limpio and a.venta_fecha=f.first_sale_date where a.lead_id is not null
), direct_ranked as (
 select a.*,row_number() over(partition by a.numero_limpio order by a.confidence desc,a.lead_fecha desc,a.lead_id) rn from direct_attrs a
), direct_best as (
 select d.numero_limpio,d.lead_id,d.lead_fecha,d.lead_anuncio,d.lead_tratamiento,f.first_sale_date,d.metodo_match attribution_method,d.confidence from direct_ranked d join first_sale f using(numero_limpio) where d.rn=1
), unresolved as (select f.* from first_sale f left join direct_best d using(numero_limpio) where d.numero_limpio is null),
prior_candidates as (
 select u.numero_limpio,u.first_sale_date,t.lead_id,t.fecha,t.anuncio,t.tratamiento,t.lead_ts,count(*) over(partition by u.numero_limpio) candidate_count,
        row_number() over(partition by u.numero_limpio order by t.lead_ts desc,t.lead_id desc) rn
 from unresolved u join public.aos_marketing_touchpoints_v2(null,null) t on t.numero_limpio=u.numero_limpio and not t.es_duplicado_tecnico_probable and t.fecha<=u.first_sale_date and t.lead_ts<(u.first_sale_date+interval '1 day')
), prior_best as (select * from prior_candidates where rn=1)
select d.numero_limpio,d.lead_id,d.lead_fecha,d.lead_anuncio,d.lead_tratamiento,d.first_sale_date,d.attribution_method,d.confidence from direct_best d
union all
select p.numero_limpio,p.lead_id,p.fecha,p.anuncio,p.tratamiento,p.first_sale_date,case when p.candidate_count=1 then 'HISTORICAL_UNIQUE_MATCH' else 'NEAREST_PRIOR_FIRST_SALE' end,case when p.candidate_count=1 then 60 else 55 end from prior_best p;
$$;

create or replace function public.aos_marketing_attribution_v3_preview(p_desde date default null,p_hasta date default null)
returns table(venta_pk bigint,venta_id text,venta_fecha date,monto numeric,tratamiento_compra text,numero_limpio text,lead_id bigint,lead_fecha date,lead_anuncio text,lead_tratamiento text,llamada_id bigint,cita_id text,metodo_match text,confidence integer,tipo_atribucion text,anomaly_code text)
language sql stable as $$
with base as materialized (select * from public.aos_marketing_attribution_v2_preview(p_desde,p_hasta)),acq as materialized (select * from public.aos_marketing_acquisition_customers_v3_preview()),
fallback as (
 select v.id::bigint,v.venta_id,v.fecha,v.monto,v.tratamiento,v.numero_limpio,a.lead_id,a.lead_fecha,a.lead_anuncio,a.lead_tratamiento,null::bigint,null::text,
        ('ACQUISITION_'||a.attribution_method)::text,least(a.confidence,60)::integer,'ADQUISICION'::text,null::text
 from public.aos_ventas v join acq a on a.numero_limpio=v.numero_limpio and v.fecha=a.first_sale_date left join base b on b.venta_pk=v.id
 where b.venta_pk is null and (p_desde is null or v.fecha>=p_desde) and (p_hasta is null or v.fecha<=p_hasta)
)
select b.venta_pk,b.venta_id,b.venta_fecha,b.monto,b.tratamiento_compra,b.numero_limpio,b.lead_id,b.lead_fecha,b.lead_anuncio,b.lead_tratamiento,b.llamada_id,b.cita_id,b.metodo_match,b.confidence,b.tipo_atribucion,b.anomaly_code from base b
union all select * from fallback;
$$;

create or replace function public.aos_marketing_touchpoint_rollup_v3_preview(p_fecha_desde date default null,p_fecha_hasta date default null)
returns table(lead_id bigint,fecha date,hora_ingreso timestamptz,celular text,numero_limpio text,tratamiento text,anuncio text,preguntas text,llamadas_total bigint,ultima_llamada timestamptz,ultimo_estado text,ultimo_asesor text,llamada_match_method text,llamada_match_confidence integer,citas_total bigint,proxima_cita_fecha date,proxima_cita_estado text,cita_match_method text,cita_match_confidence integer,ventas_total bigint,monto_facturado numeric,venta_match_method text,venta_match_confidence integer,es_llamado boolean,tiene_cita boolean,es_vendido boolean,es_adquisicion boolean,categoria_comercial text,review_required boolean)
language sql stable as $$
with tp as materialized (
 select t.*,l.celular,l.preguntas from public.aos_marketing_touchpoints_v2(p_fecha_desde,p_fecha_hasta) t join public.aos_leads l on l.id=t.lead_id where not t.es_duplicado_tecnico_probable
), cm as materialized (select * from public.aos_marketing_call_lead_match_v3_preview(null,null) where lead_id is not null),
ca as (
 select cm.lead_id,count(*)::bigint total,max(cm.llamada_ts) ultima_ts,(array_agg(ll.estado order by cm.llamada_ts desc,ll.id desc))[1] ultimo_estado,
        (array_agg(ll.asesor order by cm.llamada_ts desc,ll.id desc))[1] ultimo_asesor,(array_agg(cm.metodo_match order by cm.confidence desc,cm.llamada_ts desc))[1] metodo,max(cm.confidence)::integer confidence
 from cm join public.aos_llamadas ll on ll.id=cm.llamada_id group by cm.lead_id
), am as materialized (select * from public.aos_marketing_agenda_lead_match_v3_preview(null,null) where lead_id is not null),
aa as (
 select am.lead_id,count(distinct am.cita_id)::bigint total,min(am.fecha_cita) filter(where am.fecha_cita >= (now() at time zone 'America/Lima')::date) proxima_fecha,
        (array_agg(c.estado_cita order by am.fecha_cita asc,am.cita_ts desc) filter(where am.fecha_cita >= (now() at time zone 'America/Lima')::date))[1] proxima_estado,
        (array_agg(am.metodo_match order by am.confidence desc,am.cita_ts desc))[1] metodo,max(am.confidence)::integer confidence
 from am join public.aos_agenda_citas c on c.id=am.cita_id group by am.lead_id
), sv as materialized (select * from public.aos_marketing_attribution_v3_preview(null,null) where lead_id is not null),
sa as (
 select sv.lead_id,count(distinct sv.venta_pk)::bigint total,coalesce(sum(sv.monto),0)::numeric monto_total,(array_agg(sv.metodo_match order by sv.confidence desc,sv.venta_fecha desc,sv.venta_pk desc))[1] metodo,
        max(sv.confidence)::integer confidence,bool_or(sv.tipo_atribucion='REACTIVACION') has_reactivation,bool_or(sv.tipo_atribucion='SEGUIMIENTO_HISTORICO') has_followup
 from sv group by sv.lead_id
), acq as materialized (select * from public.aos_marketing_acquisition_customers_v3_preview())
select tp.lead_id,tp.fecha,tp.hora_ingreso,tp.celular,tp.numero_limpio,tp.tratamiento,tp.anuncio,tp.preguntas,
 coalesce(ca.total,0),ca.ultima_ts,ca.ultimo_estado,ca.ultimo_asesor,ca.metodo,coalesce(ca.confidence,0),
 coalesce(aa.total,0),aa.proxima_fecha,aa.proxima_estado,aa.metodo,coalesce(aa.confidence,0),
 coalesce(sa.total,0),coalesce(sa.monto_total,0),sa.metodo,coalesce(sa.confidence,0),
 (coalesce(ca.total,0)>0),(coalesce(aa.total,0)>0),(coalesce(sa.total,0)>0),(acq.lead_id is not null),
 case when acq.lead_id is not null then 'ADQUISICION' when coalesce(sa.has_reactivation,false) then 'REACTIVACION' when coalesce(sa.has_followup,false) then 'SEGUIMIENTO_HISTORICO' when coalesce(aa.total,0)>0 then 'RECUPERACION_LEAD' when coalesce(ca.total,0)>0 then 'EN_GESTION' else 'SIN_CONTACTO' end::text,
 ((coalesce(ca.confidence,100)>0 and coalesce(ca.confidence,100)<60) or (coalesce(aa.confidence,100)>0 and coalesce(aa.confidence,100)<60) or (coalesce(sa.confidence,100)>0 and coalesce(sa.confidence,100)<50))::boolean
from tp left join ca on ca.lead_id=tp.lead_id left join aa on aa.lead_id=tp.lead_id left join sa on sa.lead_id=tp.lead_id left join acq on acq.lead_id=tp.lead_id;
$$;

create or replace function public.aos_marketing_leads_detalle_v3_paged(p_fecha_desde date,p_fecha_hasta date,p_search text default null,p_estado text default null,p_limit integer default 50,p_offset integer default 0)
returns table(total_rows bigint,lead_id bigint,fecha date,hora_ingreso timestamptz,celular text,numero_limpio text,tratamiento text,anuncio text,preguntas text,llamadas_total bigint,ultima_llamada timestamptz,ultimo_estado text,ultimo_asesor text,llamada_match_method text,llamada_match_confidence integer,citas_total bigint,proxima_cita_fecha date,proxima_cita_estado text,cita_match_method text,cita_match_confidence integer,ventas_total bigint,monto_facturado numeric,venta_match_method text,venta_match_confidence integer,es_llamado boolean,tiene_cita boolean,es_vendido boolean,es_adquisicion boolean,categoria_comercial text,review_required boolean)
language sql stable as $$
with base as materialized (select * from public.aos_marketing_touchpoint_rollup_v3_preview(p_fecha_desde,p_fecha_hasta)),filtered as (
 select b.* from base b where (coalesce(btrim(p_search),'')='' or coalesce(b.numero_limpio,'') ilike '%'||btrim(p_search)||'%' or coalesce(b.celular,'') ilike '%'||btrim(p_search)||'%' or coalesce(b.tratamiento,'') ilike '%'||btrim(p_search)||'%' or coalesce(b.anuncio,'') ilike '%'||btrim(p_search)||'%' or coalesce(b.ultimo_asesor,'') ilike '%'||btrim(p_search)||'%' or coalesce(b.categoria_comercial,'') ilike '%'||btrim(p_search)||'%')
 and case upper(coalesce(btrim(p_estado),'TODOS')) when '' then true when 'TODOS' then true when 'CON CITA' then b.tiene_cita when 'VENDIDO' then b.es_vendido when 'EN GESTION' then b.es_llamado and not b.tiene_cita and not b.es_vendido when 'SIN CONTACTO' then not b.es_llamado when 'ADQUISICION' then b.es_adquisicion when 'REACTIVACION' then b.categoria_comercial='REACTIVACION' when 'RECUPERACION LEAD' then b.categoria_comercial='RECUPERACION_LEAD' when 'REVIEW' then b.review_required else true end
),ranked as (select f.*,count(*) over() total_rows from filtered f)
select r.total_rows,r.lead_id,r.fecha,r.hora_ingreso,r.celular,r.numero_limpio,r.tratamiento,r.anuncio,r.preguntas,r.llamadas_total,r.ultima_llamada,r.ultimo_estado,r.ultimo_asesor,r.llamada_match_method,r.llamada_match_confidence,r.citas_total,r.proxima_cita_fecha,r.proxima_cita_estado,r.cita_match_method,r.cita_match_confidence,r.ventas_total,r.monto_facturado,r.venta_match_method,r.venta_match_confidence,r.es_llamado,r.tiene_cita,r.es_vendido,r.es_adquisicion,r.categoria_comercial,r.review_required
from ranked r order by r.fecha desc,r.hora_ingreso desc nulls last,r.lead_id desc limit greatest(1,least(coalesce(p_limit,50),200)) offset greatest(coalesce(p_offset,0),0);
$$;

create or replace function public.aos_marketing_leads_detalle_v3_summary(p_fecha_desde date default null,p_fecha_hasta date default null,p_search text default null,p_estado text default null)
returns jsonb language sql stable as $$
with base as materialized (select * from public.aos_marketing_touchpoint_rollup_v3_preview(p_fecha_desde,p_fecha_hasta)),filtered as (
 select b.* from base b where (coalesce(btrim(p_search),'')='' or coalesce(b.numero_limpio,'') ilike '%'||btrim(p_search)||'%' or coalesce(b.celular,'') ilike '%'||btrim(p_search)||'%' or coalesce(b.tratamiento,'') ilike '%'||btrim(p_search)||'%' or coalesce(b.anuncio,'') ilike '%'||btrim(p_search)||'%' or coalesce(b.ultimo_asesor,'') ilike '%'||btrim(p_search)||'%' or coalesce(b.categoria_comercial,'') ilike '%'||btrim(p_search)||'%')
 and case upper(coalesce(btrim(p_estado),'TODOS')) when '' then true when 'TODOS' then true when 'CON CITA' then b.tiene_cita when 'VENDIDO' then b.es_vendido when 'EN GESTION' then b.es_llamado and not b.tiene_cita and not b.es_vendido when 'SIN CONTACTO' then not b.es_llamado when 'ADQUISICION' then b.es_adquisicion when 'REACTIVACION' then b.categoria_comercial='REACTIVACION' when 'RECUPERACION LEAD' then b.categoria_comercial='RECUPERACION_LEAD' when 'REVIEW' then b.review_required else true end
)
select jsonb_build_object('total',count(*),'touchpoints',count(*),'personasUnicas',count(distinct numero_limpio),'llamados',count(*) filter(where es_llamado),'personasLlamadas',count(distinct numero_limpio) filter(where es_llamado),'conCita',count(*) filter(where tiene_cita),'personasConCita',count(distinct numero_limpio) filter(where tiene_cita),'vendidos',count(*) filter(where es_vendido),'personasVendidas',count(distinct numero_limpio) filter(where es_vendido),'sinContacto',count(*) filter(where not es_llamado),'personasSinContacto',count(distinct numero_limpio) filter(where not es_llamado),'adquisiciones',count(*) filter(where es_adquisicion),'personasAdquiridas',count(distinct numero_limpio) filter(where es_adquisicion),'montoFacturado',coalesce(sum(monto_facturado),0),'operacionesVenta',coalesce(sum(ventas_total),0)) from filtered;
$$;

-- Shadow-only ACL: no anon/public frontend access in Loop 2.
revoke all on function public.aos_marketing_treatment_family_v3(text) from public,anon,authenticated;
revoke all on function public.aos_marketing_call_lead_match_v3_preview(date,date) from public,anon,authenticated;
revoke all on function public.aos_marketing_agenda_lead_match_v3_preview(date,date) from public,anon,authenticated;
revoke all on function public.aos_marketing_acquisition_customers_v3_preview() from public,anon,authenticated;
revoke all on function public.aos_marketing_attribution_v3_preview(date,date) from public,anon,authenticated;
revoke all on function public.aos_marketing_touchpoint_rollup_v3_preview(date,date) from public,anon,authenticated;
revoke all on function public.aos_marketing_leads_detalle_v3_paged(date,date,text,text,integer,integer) from public,anon,authenticated;
revoke all on function public.aos_marketing_leads_detalle_v3_summary(date,date,text,text) from public,anon,authenticated;

grant execute on function public.aos_marketing_treatment_family_v3(text) to service_role;
grant execute on function public.aos_marketing_call_lead_match_v3_preview(date,date) to service_role;
grant execute on function public.aos_marketing_agenda_lead_match_v3_preview(date,date) to service_role;
grant execute on function public.aos_marketing_acquisition_customers_v3_preview() to service_role;
grant execute on function public.aos_marketing_attribution_v3_preview(date,date) to service_role;
grant execute on function public.aos_marketing_touchpoint_rollup_v3_preview(date,date) to service_role;
grant execute on function public.aos_marketing_leads_detalle_v3_paged(date,date,text,text,integer,integer) to service_role;
grant execute on function public.aos_marketing_leads_detalle_v3_summary(date,date,text,text) to service_role;

comment on function public.aos_marketing_acquisition_customers_v3_preview() is 'MKT Integrity V3 Loop 2 shadow only; V2 remains production.';
comment on function public.aos_marketing_attribution_v3_preview(date,date) is 'MKT Integrity V3 Loop 2 shadow only; no business-data writes.';
comment on function public.aos_marketing_leads_detalle_v3_paged(date,date,text,text,integer,integer) is 'MKT Integrity V3 Loop 2 server-side paged shadow detail.';
comment on function public.aos_marketing_leads_detalle_v3_summary(date,date,text,text) is 'MKT Integrity V3 Loop 2 full-universe shadow summary.';
