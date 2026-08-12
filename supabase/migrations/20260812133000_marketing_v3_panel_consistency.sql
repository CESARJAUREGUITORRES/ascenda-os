-- ASCENDA OS — Marketing V3 panel consistency
-- 1) Keep M0 metrics strictly within the requested period.
-- 2) Add a fast attribution diagnostics gateway that avoids full-history acquisition recomputation.
-- 3) Bound intent attribution to the only possible sale horizon for the selected lead cohort.
-- 4) Expose a masked, admin-oriented intent detail gateway for auditability.
-- No INSERT/UPDATE/DELETE and no business-data mutation.

CREATE OR REPLACE FUNCTION public.aos_marketing_period_summary_v2(
  p_fecha_desde date,
  p_fecha_hasta date
)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $function$
WITH leads_range AS (
  SELECT *
  FROM aos_leads
  WHERE fecha BETWEEN p_fecha_desde AND p_fecha_hasta
    AND numero_limpio IS NOT NULL
    AND numero_limpio <> ''
), cohort AS (
  SELECT numero_limpio, MIN(fecha) AS first_lead_date
  FROM leads_range
  GROUP BY numero_limpio
), detail AS (
  SELECT *
  FROM aos_marketing_leads_detalle_v2(p_fecha_desde, p_fecha_hasta)
), attrs_m0 AS MATERIALIZED (
  SELECT a.*
  FROM public.aos_marketing_attribution_v2_preview(p_fecha_desde,p_fecha_hasta) a
  WHERE a.lead_fecha BETWEEN p_fecha_desde AND p_fecha_hasta
    AND a.venta_fecha BETWEEN p_fecha_desde AND p_fecha_hasta
), vals AS (
  SELECT
    (SELECT COUNT(*) FROM leads_range) AS ingresos,
    (SELECT COUNT(*) FROM cohort) AS personas_unicas,
    (SELECT COUNT(*) FROM cohort c
      WHERE EXISTS (
        SELECT 1 FROM aos_llamadas l
        WHERE l.numero_limpio = c.numero_limpio
          AND l.fecha BETWEEN c.first_lead_date AND p_fecha_hasta
      )) AS personas_gestionadas,
    (SELECT COUNT(*) FROM cohort c
      WHERE EXISTS (
        SELECT 1 FROM aos_llamadas l
        WHERE l.numero_limpio = c.numero_limpio
          AND l.fecha BETWEEN c.first_lead_date AND p_fecha_hasta
          AND UPPER(l.estado) = 'CITA CONFIRMADA'
      )) AS personas_cita_tel,
    (SELECT COUNT(*) FROM cohort c
      WHERE EXISTS (
        SELECT 1 FROM aos_agenda_citas a
        WHERE a.numero_limpio = c.numero_limpio
          AND a.fecha_cita BETWEEN c.first_lead_date AND p_fecha_hasta
      )) AS personas_con_cita,
    (SELECT COUNT(*) FROM cohort c
      WHERE EXISTS (
        SELECT 1 FROM aos_agenda_citas a
        WHERE a.numero_limpio = c.numero_limpio
          AND a.fecha_cita BETWEEN c.first_lead_date AND p_fecha_hasta
          AND UPPER(a.estado_cita) IN ('ASISTIO','EFECTIVA')
      )) AS personas_asistieron,
    (SELECT COUNT(*) FROM detail WHERE llamadas_total > 0) AS touchpoints_gestionados,
    (SELECT COUNT(*) FROM detail WHERE citas_total > 0) AS touchpoints_con_cita,
    (SELECT COUNT(DISTINCT numero_limpio) FROM attrs_m0) AS clientes_m0,
    (SELECT COUNT(*) FROM attrs_m0) AS ventas_m0,
    (SELECT COALESCE(SUM(monto),0) FROM attrs_m0) AS fact_m0
)
SELECT jsonb_build_object(
  'ingresos', ingresos,
  'personasUnicas', personas_unicas,
  'reingresos', GREATEST(0, ingresos - personas_unicas),
  'personasGestionadas', personas_gestionadas,
  'personasSinGestion', GREATEST(0, personas_unicas - personas_gestionadas),
  'personasCitaTel', personas_cita_tel,
  'personasConCita', personas_con_cita,
  'personasAsistieron', personas_asistieron,
  'touchpointsGestionados', touchpoints_gestionados,
  'touchpointsConCita', touchpoints_con_cita,
  'clientesM0', clientes_m0,
  'ventasM0', ventas_m0,
  'factM0', fact_m0
)
FROM vals;
$function$;

CREATE OR REPLACE FUNCTION public.aos_marketing_attribution_fast_v3_preview(
  p_mes integer,
  p_anio integer
)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $function$
WITH params AS (
  SELECT make_date(p_anio,p_mes,1) d,
         (make_date(p_anio,p_mes,1)+interval '1 month')::date nd
), raw AS MATERIALIZED (
  SELECT *
  FROM public.aos_marketing_touchpoints_v2(
    (SELECT d FROM params),
    ((SELECT nd FROM params)-1)
  )
), eff AS MATERIALIZED (
  SELECT * FROM raw WHERE NOT es_duplicado_tecnico_probable
), classes AS MATERIALIZED (
  SELECT *
  FROM public.aos_marketing_touchpoint_classification_v2(
    (SELECT d FROM params),
    ((SELECT nd FROM params)-1)
  )
), people AS (
  SELECT numero_limpio,count(*) touchpoints
  FROM eff
  GROUP BY numero_limpio
), attrs AS MATERIALIZED (
  SELECT a.*
  FROM params p
  CROSS JOIN LATERAL public.aos_marketing_attribution_v2_preview(p.d,current_date) a
  WHERE a.lead_fecha>=p.d AND a.lead_fecha<p.nd
), anomalies AS MATERIALIZED (
  SELECT *
  FROM public.aos_marketing_attribution_review_v2(
    (SELECT d FROM params),
    ((SELECT nd FROM params)-1)
  )
)
SELECT jsonb_build_object(
  'personasUnicas',(SELECT count(*) FROM people),
  'touchpointsRaw',(SELECT count(*) FROM raw),
  'touchpointsEfectivos',(SELECT count(*) FROM eff),
  'duplicadosTecnicosProbables',(SELECT count(*) FROM classes WHERE classification='DUPLICADO_TECNICO_PROBABLE'),
  'primerosTouchpoints',(SELECT count(*) FROM classes WHERE classification='PRIMER_TOUCH'),
  'reingresosProspectoHistorico',(SELECT count(*) FROM classes WHERE classification='REINGRESO_PROSPECTO_HISTORICO'),
  'reingresosProspectoMismoMes',(SELECT count(*) FROM classes WHERE classification='REINGRESO_PROSPECTO_MISMO_MES'),
  'reingresosClienteExistente',(SELECT count(*) FROM classes WHERE classification='REINGRESO_CLIENTE_EXISTENTE'),
  'personasConMasDeUnTouchpointEnMes',(SELECT count(*) FROM people WHERE touchpoints>1),
  'clientesAdquiridosAtribuidos',(SELECT count(DISTINCT numero_limpio) FROM attrs WHERE tipo_atribucion='ADQUISICION'),
  'clientesAdquiridosM0',(SELECT count(DISTINCT numero_limpio) FROM attrs,params p WHERE tipo_atribucion='ADQUISICION' AND venta_fecha>=p.d AND venta_fecha<p.nd),
  'reactivacionesConfirmadas',(SELECT count(DISTINCT numero_limpio) FROM attrs WHERE tipo_atribucion='REACTIVACION'),
  'revenueReactivacion',(SELECT coalesce(sum(monto),0) FROM attrs WHERE tipo_atribucion='REACTIVACION'),
  'operacionesSeguimiento',(SELECT count(*) FROM attrs WHERE tipo_atribucion='SEGUIMIENTO_HISTORICO'),
  'revenueSeguimiento',(SELECT coalesce(sum(monto),0) FROM attrs WHERE tipo_atribucion='SEGUIMIENTO_HISTORICO'),
  'anomaliasHigh',(SELECT count(*) FROM anomalies WHERE severity='HIGH'),
  'anomaliasMedium',(SELECT count(*) FROM anomalies WHERE severity='MEDIUM')
);
$function$;

CREATE OR REPLACE FUNCTION public.aos_marketing_attribution_public_v3(
  p_mes integer,
  p_anio integer
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF p_mes IS NULL OR p_mes < 1 OR p_mes > 12 THEN
    RAISE EXCEPTION 'Mes fuera de rango';
  END IF;
  IF p_anio IS NULL OR p_anio < 2020 OR p_anio > extract(year from current_date)::integer + 1 THEN
    RAISE EXCEPTION 'Año fuera de rango';
  END IF;
  RETURN public.aos_marketing_attribution_fast_v3_preview(p_mes,p_anio);
END;
$function$;

CREATE OR REPLACE FUNCTION public.aos_marketing_intent_to_purchase_v2_preview(
  p_mes integer,
  p_anio integer
)
RETURNS TABLE(
  tratamiento_interes text,
  tratamiento_compra text,
  clientes bigint,
  operaciones bigint,
  facturacion numeric,
  coincide_intencion boolean,
  porcentaje_facturacion_intencion numeric
)
LANGUAGE sql
STABLE
AS $function$
WITH params AS (
  SELECT make_date(p_anio,p_mes,1) d,
         (make_date(p_anio,p_mes,1)+interval '1 month')::date nd
), attrs AS MATERIALIZED (
  SELECT a.*
  FROM params p
  CROSS JOIN LATERAL public.aos_marketing_attribution_v2_preview(p.d,current_date) a
  WHERE a.lead_fecha>=p.d AND a.lead_fecha<p.nd
), grouped AS (
  SELECT upper(coalesce(nullif(trim(lead_tratamiento),''),'SIN TRATAMIENTO')) tratamiento_interes,
         upper(coalesce(nullif(trim(tratamiento_compra),''),'SIN TRATAMIENTO')) tratamiento_compra,
         count(distinct numero_limpio)::bigint clientes,
         count(*)::bigint operaciones,
         coalesce(sum(monto),0)::numeric facturacion
  FROM attrs
  GROUP BY 1,2
), totals AS (
  SELECT tratamiento_interes,sum(facturacion) total_fact
  FROM grouped
  GROUP BY tratamiento_interes
)
SELECT g.tratamiento_interes,g.tratamiento_compra,g.clientes,g.operaciones,g.facturacion,
       (g.tratamiento_interes=g.tratamiento_compra),
       CASE WHEN t.total_fact>0 THEN round(g.facturacion/t.total_fact*100,2) ELSE 0 END
FROM grouped g
JOIN totals t USING(tratamiento_interes)
ORDER BY g.tratamiento_interes,g.facturacion DESC,g.tratamiento_compra;
$function$;

CREATE OR REPLACE FUNCTION public.aos_marketing_intent_detail_public_v3(
  p_mes integer,
  p_anio integer
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  d date;
  nd date;
  result jsonb;
BEGIN
  IF p_mes IS NULL OR p_mes < 1 OR p_mes > 12 THEN
    RAISE EXCEPTION 'Mes fuera de rango';
  END IF;
  IF p_anio IS NULL OR p_anio < 2020 OR p_anio > extract(year from current_date)::integer + 1 THEN
    RAISE EXCEPTION 'Año fuera de rango';
  END IF;

  d := make_date(p_anio,p_mes,1);
  nd := (d + interval '1 month')::date;

  WITH attrs AS MATERIALIZED (
    SELECT a.*
    FROM public.aos_marketing_attribution_v2_preview(d,current_date) a
    WHERE a.lead_fecha>=d AND a.lead_fecha<nd
  ), grouped AS (
    SELECT
      a.numero_limpio,
      a.lead_id,
      min(a.lead_fecha) lead_fecha,
      max(a.lead_anuncio) lead_anuncio,
      max(a.lead_tratamiento) lead_tratamiento,
      upper(coalesce(nullif(trim(a.tratamiento_compra),''),'SIN TRATAMIENTO')) tratamiento_compra,
      trim(concat_ws(' ',max(v.nombres),max(v.apellidos))) cliente,
      right(coalesce(a.numero_limpio,''),4) telefono_ult4,
      count(*)::bigint operaciones,
      coalesce(sum(a.monto),0)::numeric facturacion,
      string_agg(distinct coalesce(nullif(trim(v.descripcion),''),a.tratamiento_compra), ' · ' order by coalesce(nullif(trim(v.descripcion),''),a.tratamiento_compra)) descripciones,
      string_agg(a.venta_id, ' · ' order by a.venta_fecha,a.venta_pk) venta_ids,
      min(a.confidence)::integer confianza_min,
      bool_or(a.tipo_atribucion='REACTIVACION') tiene_reactivacion
    FROM attrs a
    JOIN public.aos_ventas v ON v.id=a.venta_pk
    GROUP BY a.numero_limpio,a.lead_id,upper(coalesce(nullif(trim(a.tratamiento_compra),''),'SIN TRATAMIENTO'))
  )
  SELECT coalesce(jsonb_agg(to_jsonb(g) ORDER BY g.cliente,g.lead_id,g.tratamiento_compra),'[]'::jsonb)
  INTO result
  FROM grouped g;

  RETURN result;
END;
$function$;

REVOKE ALL ON FUNCTION public.aos_marketing_attribution_public_v3(integer,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.aos_marketing_intent_detail_public_v3(integer,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.aos_marketing_attribution_public_v3(integer,integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.aos_marketing_intent_detail_public_v3(integer,integer) TO anon, authenticated;

COMMENT ON FUNCTION public.aos_marketing_attribution_public_v3(integer,integer)
IS 'Fast monthly Marketing V3 attribution diagnostics. Full cohort acquisition totals remain sourced from the LTV cohort gateway.';
COMMENT ON FUNCTION public.aos_marketing_intent_detail_public_v3(integer,integer)
IS 'Masked client-level audit detail for Marketing intent-to-purchase. No DNI or full phone is returned.';
