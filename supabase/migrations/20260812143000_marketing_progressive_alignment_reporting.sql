CREATE OR REPLACE FUNCTION public.aos_marketing_period_summary_v2(
  p_fecha_desde date,
  p_fecha_hasta date
)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path = public
AS $$
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
    (SELECT COUNT(DISTINCT numero_limpio) FROM detail WHERE estado_lead = 'VENDIDO') AS clientes_m0,
    (SELECT COALESCE(SUM(ventas_total),0) FROM detail WHERE estado_lead = 'VENDIDO') AS ventas_m0,
    (SELECT COALESCE(SUM(monto_facturado),0) FROM detail WHERE estado_lead = 'VENDIDO') AS fact_m0
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
$$;

CREATE OR REPLACE FUNCTION public.aos_marketing_historico_aligned_v2(p_anio integer)
RETURNS TABLE(
  mes integer,
  anio integer,
  leads bigint,
  llamados bigint,
  citas bigint,
  asistieron bigint,
  clientes bigint,
  ventas bigint,
  fact numeric,
  fact_acumulado numeric,
  conv numeric,
  ingresos bigint,
  reingresos bigint,
  citas_tel bigint
)
LANGUAGE sql
STABLE
SET search_path = public
AS $$
WITH base AS (
  SELECT * FROM aos_marketing_historico_v2_preview(p_anio)
), cohort AS (
  SELECT
    EXTRACT(MONTH FROM l.fecha)::int AS mes,
    l.numero_limpio,
    MIN(l.fecha) AS first_lead_date
  FROM aos_leads l
  WHERE EXTRACT(YEAR FROM l.fecha)::int = p_anio
    AND l.numero_limpio IS NOT NULL
    AND l.numero_limpio <> ''
  GROUP BY 1,2
)
SELECT
  b.mes,
  b.anio,
  b.personas_unicas::bigint AS leads,
  (SELECT COUNT(*) FROM cohort c
    WHERE c.mes = b.mes
      AND EXISTS (
        SELECT 1 FROM aos_llamadas l
        WHERE l.numero_limpio = c.numero_limpio
          AND l.fecha BETWEEN c.first_lead_date
                          AND (make_date(p_anio,b.mes,1) + interval '1 month - 1 day')::date
      ))::bigint AS llamados,
  (SELECT COUNT(*) FROM cohort c
    WHERE c.mes = b.mes
      AND EXISTS (
        SELECT 1 FROM aos_agenda_citas a
        WHERE a.numero_limpio = c.numero_limpio
          AND a.fecha_cita BETWEEN c.first_lead_date
                              AND (make_date(p_anio,b.mes,1) + interval '1 month - 1 day')::date
      ))::bigint AS citas,
  (SELECT COUNT(*) FROM cohort c
    WHERE c.mes = b.mes
      AND EXISTS (
        SELECT 1 FROM aos_agenda_citas a
        WHERE a.numero_limpio = c.numero_limpio
          AND a.fecha_cita BETWEEN c.first_lead_date
                              AND (make_date(p_anio,b.mes,1) + interval '1 month - 1 day')::date
          AND UPPER(a.estado_cita) IN ('ASISTIO','EFECTIVA')
      ))::bigint AS asistieron,
  b.clientes_m0::bigint AS clientes,
  b.ventas_m0::bigint AS ventas,
  b.fact_m0::numeric AS fact,
  b.fact_acumulado::numeric AS fact_acumulado,
  CASE WHEN b.personas_unicas > 0 THEN ROUND(b.clientes_m0::numeric / b.personas_unicas * 100,2) ELSE 0 END AS conv,
  b.touchpoints_raw::bigint AS ingresos,
  GREATEST(0,b.touchpoints_raw - b.personas_unicas)::bigint AS reingresos,
  (SELECT COUNT(*) FROM cohort c
    WHERE c.mes = b.mes
      AND EXISTS (
        SELECT 1 FROM aos_llamadas l
        WHERE l.numero_limpio = c.numero_limpio
          AND l.fecha BETWEEN c.first_lead_date
                          AND (make_date(p_anio,b.mes,1) + interval '1 month - 1 day')::date
          AND UPPER(l.estado) = 'CITA CONFIRMADA'
      ))::bigint AS citas_tel
FROM base b
ORDER BY b.mes;
$$;

REVOKE ALL ON FUNCTION public.aos_marketing_period_summary_v2(date,date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.aos_marketing_period_summary_v2(date,date) TO anon, authenticated;
REVOKE ALL ON FUNCTION public.aos_marketing_historico_aligned_v2(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.aos_marketing_historico_aligned_v2(integer) TO anon, authenticated;
