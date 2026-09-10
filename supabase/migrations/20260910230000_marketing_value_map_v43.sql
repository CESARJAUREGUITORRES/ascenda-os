-- ASCENDA OS · Marketing Attribution V4.3
-- Reconciles paid attributed M0 revenue without contaminating acquisition LTV,
-- adds longitudinal post-reactivation value, and exposes masked attribution lineage.
-- Read-only analytics: no historical business rows are rewritten.

create or replace function public.aos_marketing_value_map_public_v43(
  p_anio integer,
  p_mes integer default null
)
returns jsonb
language sql
stable
security definer
set search_path to 'public'
set statement_timeout to '8s'
as $function$
with params as (
  select
    p_anio::int anio,
    p_mes::int selected_mes,
    make_date(p_anio,1,1) y0,
    make_date(p_anio+1,1,1) y1
  where p_anio between 2020 and extract(year from current_date)::int+1
    and (p_mes is null or p_mes between 1 and 12)
),
months as (
  select
    g.m::int mes,
    make_date((select anio from params),g.m,1) cohort_start,
    (make_date((select anio from params),g.m,1)+interval '1 month')::date cohort_next
  from params,generate_series(1,12) g(m)
  where make_date((select anio from params),g.m,1)<=date_trunc('month',current_date)::date
),
attrs as materialized (
  select a.*
  from public.aos_marketing_attribution_v2_preview(
    (select y0 from params),
    (select y1 from params)-1
  ) a
  where a.lead_fecha>=(select y0 from params)
    and a.lead_fecha<(select y1 from params)
),
recon_agg as (
  select
    extract(month from a.lead_fecha)::int mes,
    coalesce(sum(a.monto) filter(where
      a.venta_fecha>=date_trunc('month',a.lead_fecha)::date
      and a.venta_fecha<(date_trunc('month',a.lead_fecha)+interval '1 month')::date
      and upper(coalesce(trim(a.lead_tratamiento),'')) not in ('ORGANICO','ORGÁNICO')
    ),0)::numeric paid_total,
    coalesce(sum(a.monto) filter(where
      a.tipo_atribucion='ADQUISICION'
      and a.venta_fecha>=date_trunc('month',a.lead_fecha)::date
      and a.venta_fecha<(date_trunc('month',a.lead_fecha)+interval '1 month')::date
      and upper(coalesce(trim(a.lead_tratamiento),'')) not in ('ORGANICO','ORGÁNICO')
    ),0)::numeric adquisicion,
    coalesce(sum(a.monto) filter(where
      a.tipo_atribucion='REACTIVACION'
      and a.venta_fecha>=date_trunc('month',a.lead_fecha)::date
      and a.venta_fecha<(date_trunc('month',a.lead_fecha)+interval '1 month')::date
      and upper(coalesce(trim(a.lead_tratamiento),'')) not in ('ORGANICO','ORGÁNICO')
    ),0)::numeric reactivacion,
    coalesce(sum(a.monto) filter(where
      a.tipo_atribucion='SEGUIMIENTO_HISTORICO'
      and a.venta_fecha>=date_trunc('month',a.lead_fecha)::date
      and a.venta_fecha<(date_trunc('month',a.lead_fecha)+interval '1 month')::date
      and upper(coalesce(trim(a.lead_tratamiento),'')) not in ('ORGANICO','ORGÁNICO')
    ),0)::numeric seguimiento,
    count(distinct a.numero_limpio) filter(where
      a.venta_fecha>=date_trunc('month',a.lead_fecha)::date
      and a.venta_fecha<(date_trunc('month',a.lead_fecha)+interval '1 month')::date
      and upper(coalesce(trim(a.lead_tratamiento),'')) not in ('ORGANICO','ORGÁNICO')
    )::bigint clientes,
    count(*) filter(where
      a.venta_fecha>=date_trunc('month',a.lead_fecha)::date
      and a.venta_fecha<(date_trunc('month',a.lead_fecha)+interval '1 month')::date
      and upper(coalesce(trim(a.lead_tratamiento),'')) not in ('ORGANICO','ORGÁNICO')
    )::bigint operaciones,
    count(distinct a.numero_limpio) filter(where
      a.tipo_atribucion='ADQUISICION'
      and a.venta_fecha>=date_trunc('month',a.lead_fecha)::date
      and a.venta_fecha<(date_trunc('month',a.lead_fecha)+interval '1 month')::date
      and upper(coalesce(trim(a.lead_tratamiento),'')) not in ('ORGANICO','ORGÁNICO')
    )::bigint clientes_adquisicion,
    count(distinct a.numero_limpio) filter(where
      a.tipo_atribucion='REACTIVACION'
      and a.venta_fecha>=date_trunc('month',a.lead_fecha)::date
      and a.venta_fecha<(date_trunc('month',a.lead_fecha)+interval '1 month')::date
      and upper(coalesce(trim(a.lead_tratamiento),'')) not in ('ORGANICO','ORGÁNICO')
    )::bigint clientes_reactivacion,
    count(distinct a.numero_limpio) filter(where
      a.tipo_atribucion='SEGUIMIENTO_HISTORICO'
      and a.venta_fecha>=date_trunc('month',a.lead_fecha)::date
      and a.venta_fecha<(date_trunc('month',a.lead_fecha)+interval '1 month')::date
      and upper(coalesce(trim(a.lead_tratamiento),'')) not in ('ORGANICO','ORGÁNICO')
    )::bigint clientes_seguimiento,
    coalesce(sum(a.monto) filter(where
      a.venta_fecha>=date_trunc('month',a.lead_fecha)::date
      and a.venta_fecha<(date_trunc('month',a.lead_fecha)+interval '1 month')::date
      and upper(coalesce(trim(a.lead_tratamiento),'')) in ('ORGANICO','ORGÁNICO')
    ),0)::numeric organic_total
  from attrs a
  group by 1
),
recon_rows as (
  select
    m.mes,(select anio from params) anio,
    coalesce(r.paid_total,0)::numeric revenue_attributed,
    coalesce(r.adquisicion,0)::numeric acquisition,
    coalesce(r.reactivacion,0)::numeric reactivation,
    coalesce(r.seguimiento,0)::numeric historical_followup,
    coalesce(r.organic_total,0)::numeric organic_revenue,
    coalesce(r.clientes,0)::bigint clients,
    coalesce(r.operaciones,0)::bigint operations,
    coalesce(r.clientes_adquisicion,0)::bigint acquisition_clients,
    coalesce(r.clientes_reactivacion,0)::bigint reactivation_clients,
    coalesce(r.clientes_seguimiento,0)::bigint historical_clients,
    (
      coalesce(r.paid_total,0)
      -coalesce(r.adquisicion,0)
      -coalesce(r.reactivacion,0)
      -coalesce(r.seguimiento,0)
    )::numeric reconciliation_delta,
    case when m.cohort_next<=current_date then 'COMPLETE' else 'PARTIAL' end status
  from months m
  left join recon_agg r on r.mes=m.mes
),
react_anchors as materialized (
  select
    date_trunc('month',a.lead_fecha)::date cohort_start,
    a.numero_limpio,
    min(a.venta_fecha) anchor_sale_date
  from attrs a
  where a.tipo_atribucion='REACTIVACION'
    and upper(coalesce(trim(a.lead_tratamiento),'')) not in ('ORGANICO','ORGÁNICO')
  group by 1,2
),
react_agg as (
  select
    extract(month from an.cohort_start)::int mes,
    count(distinct an.numero_limpio)::bigint reactivated_clients,
    count(distinct an.numero_limpio) filter(
      where date_trunc('month',an.anchor_sale_date)::date=an.cohort_start
    )::bigint reactivated_clients_r0,
    coalesce(sum(v.monto) filter(where
      ((extract(year from v.fecha)::int-extract(year from an.cohort_start)::int)*12
      +extract(month from v.fecha)::int-extract(month from an.cohort_start)::int)=0
    ),0)::numeric r0,
    coalesce(sum(v.monto) filter(where
      ((extract(year from v.fecha)::int-extract(year from an.cohort_start)::int)*12
      +extract(month from v.fecha)::int-extract(month from an.cohort_start)::int)=1
    ),0)::numeric r1,
    coalesce(sum(v.monto) filter(where
      ((extract(year from v.fecha)::int-extract(year from an.cohort_start)::int)*12
      +extract(month from v.fecha)::int-extract(month from an.cohort_start)::int)=2
    ),0)::numeric r2,
    coalesce(sum(v.monto) filter(where
      ((extract(year from v.fecha)::int-extract(year from an.cohort_start)::int)*12
      +extract(month from v.fecha)::int-extract(month from an.cohort_start)::int)=3
    ),0)::numeric r3,
    coalesce(sum(v.monto) filter(where
      ((extract(year from v.fecha)::int-extract(year from an.cohort_start)::int)*12
      +extract(month from v.fecha)::int-extract(month from an.cohort_start)::int)>=4
    ),0)::numeric r4plus,
    coalesce(sum(v.monto),0)::numeric value_total
  from react_anchors an
  left join public.aos_ventas v
    on v.numero_limpio=an.numero_limpio
   and v.fecha>=an.anchor_sale_date
  group by 1
),
react_rows as (
  select
    m.mes,(select anio from params) anio,
    coalesce(r.reactivated_clients,0)::bigint reactivated_clients,
    coalesce(r.reactivated_clients_r0,0)::bigint reactivated_clients_r0,
    coalesce(r.r0,0)::numeric r0,
    case when m.cohort_start+interval '1 month'<=current_date then coalesce(r.r1,0)::numeric else null end r1,
    case when m.cohort_start+interval '2 month'<=current_date then coalesce(r.r2,0)::numeric else null end r2,
    case when m.cohort_start+interval '3 month'<=current_date then coalesce(r.r3,0)::numeric else null end r3,
    case when m.cohort_start+interval '4 month'<=current_date then coalesce(r.r4plus,0)::numeric else null end r4plus,
    coalesce(r.value_total,0)::numeric value_total,
    case when m.cohort_next<=current_date then 'COMPLETE' else 'PARTIAL' end r0_status,
    case
      when m.cohort_start+interval '2 month'<=current_date then 'COMPLETE'
      when m.cohort_start+interval '1 month'<=current_date then 'PARTIAL'
      else 'FUTURE'
    end r1_status,
    case
      when m.cohort_start+interval '3 month'<=current_date then 'COMPLETE'
      when m.cohort_start+interval '2 month'<=current_date then 'PARTIAL'
      else 'FUTURE'
    end r2_status,
    case
      when m.cohort_start+interval '4 month'<=current_date then 'COMPLETE'
      when m.cohort_start+interval '3 month'<=current_date then 'PARTIAL'
      else 'FUTURE'
    end r3_status,
    case when m.cohort_start+interval '4 month'<=current_date then 'PARTIAL' else 'FUTURE' end r4plus_status
  from months m
  left join react_agg r on r.mes=m.mes
),
lineage_rows as (
  select
    right(a.numero_limpio,4) telefono_ult4,
    a.tipo_atribucion,
    a.lead_id,
    a.lead_fecha,
    a.lead_tratamiento campana,
    a.lead_anuncio anuncio,
    count(*)::bigint operaciones,
    sum(a.monto)::numeric facturacion,
    count(distinct a.llamada_id) filter(where a.llamada_id is not null)::bigint llamadas_vinculadas,
    count(distinct a.cita_id) filter(where a.cita_id is not null)::bigint citas_vinculadas,
    max(a.confidence)::int confidence,
    string_agg(
      distinct case
        when a.metodo_match='SAME_MONTH_UNIQUE_NEW_CUSTOMER' then 'SAME_MONTH_UNIQUE_LEAD'
        else a.metodo_match
      end,
      ', ' order by case
        when a.metodo_match='SAME_MONTH_UNIQUE_NEW_CUSTOMER' then 'SAME_MONTH_UNIQUE_LEAD'
        else a.metodo_match
      end
    ) metodo_match,
    case
      when count(a.llamada_id)>0 and count(a.cita_id)>0 then 'LEAD_CALL_APPOINTMENT'
      when count(a.llamada_id)>0 then 'LEAD_CALL'
      when count(a.cita_id)>0 then 'LEAD_APPOINTMENT'
      when max(a.confidence)>=80 then 'STRONG_INFERRED'
      else 'INFERRED'
    end lineage_strength
  from attrs a,params p
  where p.selected_mes is not null
    and extract(month from a.lead_fecha)::int=p.selected_mes
    and date_trunc('month',a.venta_fecha)=date_trunc('month',a.lead_fecha)
    and upper(coalesce(trim(a.lead_tratamiento),'')) not in ('ORGANICO','ORGÁNICO')
  group by 1,2,3,4,5,6
)
select case
  when not exists(select 1 from params) then
    jsonb_build_object('version','MKT-V4.3','error','INVALID_PERIOD')
  else jsonb_build_object(
    'version','MKT-V4.3',
    'reconciliation',(
      select coalesce(jsonb_agg(to_jsonb(x) order by x.mes),'[]'::jsonb)
      from recon_rows x
    ),
    'acquisitionLtv',(
      select coalesce(jsonb_agg(to_jsonb(x) order by x.mes),'[]'::jsonb)
      from public.aos_marketing_cohortes_ltv_v2_preview((select anio from params)) x
    ),
    'reactivationLtv',(
      select coalesce(jsonb_agg(to_jsonb(x) order by x.mes),'[]'::jsonb)
      from react_rows x
    ),
    'lineage',(
      select coalesce(jsonb_agg(to_jsonb(x) order by x.facturacion desc,x.lead_id),'[]'::jsonb)
      from lineage_rows x
    )
  )
end
$function$;

revoke all on function public.aos_marketing_value_map_public_v43(integer,integer)
from public;
grant execute on function public.aos_marketing_value_map_public_v43(integer,integer)
to anon,authenticated,service_role;

comment on function public.aos_marketing_value_map_public_v43(integer,integer)
is 'Marketing V4.3 read-only value map: paid M0 revenue reconciliation, acquisition LTV, post-reactivation value and masked lineage audit.';

select pg_notify('pgrst','reload schema');
