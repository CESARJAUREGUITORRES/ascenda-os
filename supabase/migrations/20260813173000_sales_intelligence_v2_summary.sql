-- ASCENDA OS — Sales Intelligence V2 / Phase A
-- Read-only aggregate RPC. No mutation of sales or financial facts.
-- SECURITY INVOKER: does not elevate caller privileges.

CREATE OR REPLACE FUNCTION public.aos_sales_intelligence_summary(
  p_anio integer,
  p_sede text DEFAULT '',
  p_asesor text DEFAULT ''
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $function$
WITH params AS (
  SELECT p_anio AS anio, coalesce(p_sede,'') AS sede, coalesce(p_asesor,'') AS asesor
), base AS (
  SELECT
    v.*,
    CASE
      WHEN upper(trim(coalesce(v.tratamiento,''))) = 'OTROS' THEN 'SERVICIO'
      ELSE upper(trim(coalesce(v.tipo,'')))
    END AS tipo_norm
  FROM public.aos_ventas v
  CROSS JOIN params p
  WHERE v.fecha BETWEEN make_date(p.anio,1,1) AND make_date(p.anio,12,31)
    AND (p.sede = '' OR v.sede = p.sede)
    AND (p.asesor = '' OR v.asesor = p.asesor)
), cut AS (
  SELECT max(fecha) AS data_through FROM base
), monthly AS (
  SELECT
    extract(month from fecha)::int AS mes,
    count(*) AS n,
    sum(monto) AS facturado,
    CASE WHEN count(*) > 0 THEN round(sum(monto)/count(*),2) ELSE 0 END AS ticket,
    count(*) FILTER (WHERE tipo_norm='SERVICIO') AS n_serv,
    coalesce(sum(monto) FILTER (WHERE tipo_norm='SERVICIO'),0) AS fact_serv,
    count(*) FILTER (WHERE tipo_norm='PRODUCTO') AS n_prod,
    coalesce(sum(monto) FILTER (WHERE tipo_norm='PRODUCTO'),0) AS fact_prod
  FROM base
  GROUP BY 1
), series0 AS (
  SELECT
    m AS mes,
    coalesce(x.n,0) AS n,
    coalesce(x.facturado,0) AS facturado,
    coalesce(x.ticket,0) AS ticket,
    coalesce(x.n_serv,0) AS n_serv,
    coalesce(x.fact_serv,0) AS fact_serv,
    coalesce(x.n_prod,0) AS n_prod,
    coalesce(x.fact_prod,0) AS fact_prod,
    coalesce(mt.meta,0) AS meta
  FROM generate_series(1,12) m
  LEFT JOIN monthly x ON x.mes=m
  LEFT JOIN public.aos_metas_ventas mt
    ON mt.periodo=(SELECT anio::text FROM params)||'-'||lpad(m::text,2,'0')
), series AS (
  SELECT
    s.*,
    CASE
      WHEN lag(s.facturado) OVER (ORDER BY s.mes) > 0
      THEN round((s.facturado/lag(s.facturado) OVER (ORDER BY s.mes)-1)*100,2)
      ELSE NULL
    END AS variacion_pct
  FROM series0 s
), ctx AS (
  SELECT
    data_through,
    extract(month from data_through)::int AS mes_actual,
    extract(day from data_through)::int AS dia_corte,
    extract(day from (date_trunc('month',data_through)+interval '1 month - 1 day'))::int AS dias_mes,
    data_through < (date_trunc('month',data_through)+interval '1 month - 1 day')::date AS parcial
  FROM cut
), cur AS (
  SELECT coalesce(sum(b.monto),0) AS fact_mtd, count(*) AS n_mtd
  FROM base b CROSS JOIN ctx c
  WHERE b.fecha BETWEEN date_trunc('month',c.data_through)::date AND c.data_through
), prev AS (
  SELECT coalesce(sum(b.monto),0) AS fact_prev_same_days
  FROM base b CROSS JOIN ctx c
  WHERE b.fecha BETWEEN (date_trunc('month',c.data_through)-interval '1 month')::date
                    AND least(
                      (date_trunc('month',c.data_through)-interval '1 day')::date,
                      ((date_trunc('month',c.data_through)-interval '1 month')::date + (c.dia_corte-1))
                    )
), ytd AS (
  SELECT
    sum(s.facturado) AS fact_ytd,
    sum(s.n) AS ventas_ytd,
    sum(s.meta) AS meta_ytd,
    sum(s.n_serv) AS n_serv_ytd,
    sum(s.fact_serv) AS fact_serv_ytd,
    sum(s.n_prod) AS n_prod_ytd,
    sum(s.fact_prod) AS fact_prod_ytd
  FROM series s CROSS JOIN ctx c
  WHERE s.mes <= c.mes_actual
), closed AS (
  SELECT s.* FROM series s CROSS JOIN ctx c
  WHERE s.mes<c.mes_actual OR (s.mes=c.mes_actual AND NOT c.parcial)
), best AS (
  SELECT mes,facturado FROM closed ORDER BY facturado DESC LIMIT 1
), closed_ranked AS (
  SELECT c.*, row_number() OVER (ORDER BY c.mes DESC) AS rn FROM closed c
), closed_compare AS (
  SELECT
    max(mes) FILTER (WHERE rn=1) AS mes_ultimo,
    max(facturado) FILTER (WHERE rn=1) AS fact_ultimo,
    max(mes) FILTER (WHERE rn=2) AS mes_anterior,
    max(facturado) FILTER (WHERE rn=2) AS fact_anterior
  FROM closed_ranked
), metas_all AS (
  SELECT coalesce(sum(meta),0) AS meta_anual
  FROM public.aos_metas_ventas
  WHERE periodo LIKE (SELECT anio::text FROM params)||'-%'
)
SELECT CASE
  WHEN c.data_through IS NULL THEN jsonb_build_object(
    'hasData',false,
    'anio',p_anio,
    'serie',(SELECT jsonb_agg(jsonb_build_object('mes',s.mes,'facturado',s.facturado,'meta',s.meta,'ventas',s.n) ORDER BY s.mes) FROM series s)
  )
  ELSE jsonb_build_object(
    'hasData',true,
    'anio',p_anio,
    'dataThrough',c.data_through,
    'mesActual',c.mes_actual,
    'diaCorte',c.dia_corte,
    'diasMes',c.dias_mes,
    'parcial',c.parcial,
    'factYTD',y.fact_ytd,
    'ventasYTD',y.ventas_ytd,
    'ticketYTD',CASE WHEN y.ventas_ytd>0 THEN round(y.fact_ytd/y.ventas_ytd,2) ELSE 0 END,
    'nServYTD',y.n_serv_ytd,
    'factServYTD',y.fact_serv_ytd,
    'nProdYTD',y.n_prod_ytd,
    'factProdYTD',y.fact_prod_ytd,
    'metaYTD',y.meta_ytd,
    'metaAnual',ma.meta_anual,
    'pctMetaYTD',CASE WHEN y.meta_ytd>0 THEN round(y.fact_ytd/y.meta_ytd*100,2) ELSE NULL END,
    'gapYTD',greatest(y.meta_ytd-y.fact_ytd,0),
    'promedioMesesCerrados',(SELECT round(avg(facturado),2) FROM closed),
    'mejorMes',(SELECT jsonb_build_object('mes',mes,'facturado',facturado) FROM best),
    'ultimoMesCerrado',jsonb_build_object(
      'mes',cc.mes_ultimo,
      'facturado',cc.fact_ultimo,
      'mesAnterior',cc.mes_anterior,
      'facturadoAnterior',cc.fact_anterior,
      'variacionPct',CASE WHEN cc.fact_anterior>0 THEN round((cc.fact_ultimo/cc.fact_anterior-1)*100,2) ELSE NULL END
    ),
    'mtdComparable',jsonb_build_object(
      'facturadoActual',cur.fact_mtd,
      'ventasActual',cur.n_mtd,
      'facturadoAnteriorMismosDias',prev.fact_prev_same_days,
      'variacionPct',CASE WHEN prev.fact_prev_same_days>0 THEN round((cur.fact_mtd/prev.fact_prev_same_days-1)*100,2) ELSE NULL END,
      'diasComparados',c.dia_corte
    ),
    'proyeccionMes',jsonb_build_object(
      'facturadoActual',cur.fact_mtd,
      'proyectado',CASE WHEN c.parcial AND c.dia_corte>0 THEN round(cur.fact_mtd/c.dia_corte*c.dias_mes,2) ELSE cur.fact_mtd END,
      'meta',(SELECT meta FROM series WHERE mes=c.mes_actual),
      'faltante',greatest((SELECT meta FROM series WHERE mes=c.mes_actual)-cur.fact_mtd,0),
      'ritmoDiarioActual',CASE WHEN c.dia_corte>0 THEN round(cur.fact_mtd/c.dia_corte,2) ELSE 0 END,
      'ritmoDiarioNecesario',CASE WHEN c.dias_mes-c.dia_corte>0 THEN round(greatest((SELECT meta FROM series WHERE mes=c.mes_actual)-cur.fact_mtd,0)/(c.dias_mes-c.dia_corte),2) ELSE 0 END,
      'diasRestantes',greatest(c.dias_mes-c.dia_corte,0)
    ),
    'serie',(SELECT jsonb_agg(jsonb_build_object(
      'mes',s.mes,
      'facturado',s.facturado,
      'meta',s.meta,
      'pctMeta',CASE WHEN s.meta>0 THEN round(s.facturado/s.meta*100,2) ELSE NULL END,
      'ventas',s.n,
      'ticket',s.ticket,
      'variacionPct',s.variacion_pct,
      'nServ',s.n_serv,
      'factServ',s.fact_serv,
      'nProd',s.n_prod,
      'factProd',s.fact_prod,
      'estado',CASE
        WHEN s.mes<c.mes_actual THEN 'CERRADO'
        WHEN s.mes=c.mes_actual THEN CASE WHEN c.parcial THEN 'PARCIAL' ELSE 'CERRADO' END
        ELSE 'FUTURO'
      END
    ) ORDER BY s.mes) FROM series s)
  )
END
FROM ctx c
CROSS JOIN ytd y
CROSS JOIN cur
CROSS JOIN prev
CROSS JOIN closed_compare cc
CROSS JOIN metas_all ma;
$function$;

COMMENT ON FUNCTION public.aos_sales_intelligence_summary(integer,text,text) IS
'Sales Intelligence V2 aggregate-only summary: annual/meta/YTD, same-days MTD comparison and monthly projection.';
