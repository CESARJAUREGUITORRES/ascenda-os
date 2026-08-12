-- Keep the M0 summary callable by the browser without exposing internal attribution helpers.
CREATE OR REPLACE FUNCTION public.aos_marketing_period_summary_v2(
  p_fecha_desde date,
  p_fecha_hasta date
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
WITH leads_range AS (
  SELECT * FROM aos_leads
  WHERE fecha BETWEEN p_fecha_desde AND p_fecha_hasta
    AND numero_limpio IS NOT NULL AND numero_limpio <> ''
), cohort AS (
  SELECT numero_limpio, MIN(fecha) AS first_lead_date FROM leads_range GROUP BY numero_limpio
), detail AS (
  SELECT * FROM aos_marketing_leads_detalle_v2(p_fecha_desde, p_fecha_hasta)
), attrs_m0 AS MATERIALIZED (
  SELECT a.*
  FROM public.aos_marketing_attribution_v2_preview(p_fecha_desde,p_fecha_hasta) a
  WHERE a.lead_fecha BETWEEN p_fecha_desde AND p_fecha_hasta
    AND a.venta_fecha BETWEEN p_fecha_desde AND p_fecha_hasta
), vals AS (
  SELECT
    (SELECT COUNT(*) FROM leads_range) AS ingresos,
    (SELECT COUNT(*) FROM cohort) AS personas_unicas,
    (SELECT COUNT(*) FROM cohort c WHERE EXISTS (
      SELECT 1 FROM aos_llamadas l
      WHERE l.numero_limpio=c.numero_limpio AND l.fecha BETWEEN c.first_lead_date AND p_fecha_hasta
    )) AS personas_gestionadas,
    (SELECT COUNT(*) FROM cohort c WHERE EXISTS (
      SELECT 1 FROM aos_llamadas l
      WHERE l.numero_limpio=c.numero_limpio AND l.fecha BETWEEN c.first_lead_date AND p_fecha_hasta
        AND UPPER(l.estado)='CITA CONFIRMADA'
    )) AS personas_cita_tel,
    (SELECT COUNT(*) FROM cohort c WHERE EXISTS (
      SELECT 1 FROM aos_agenda_citas a
      WHERE a.numero_limpio=c.numero_limpio AND a.fecha_cita BETWEEN c.first_lead_date AND p_fecha_hasta
    )) AS personas_con_cita,
    (SELECT COUNT(*) FROM cohort c WHERE EXISTS (
      SELECT 1 FROM aos_agenda_citas a
      WHERE a.numero_limpio=c.numero_limpio AND a.fecha_cita BETWEEN c.first_lead_date AND p_fecha_hasta
        AND UPPER(a.estado_cita) IN ('ASISTIO','EFECTIVA')
    )) AS personas_asistieron,
    (SELECT COUNT(*) FROM detail WHERE llamadas_total>0) AS touchpoints_gestionados,
    (SELECT COUNT(*) FROM detail WHERE citas_total>0) AS touchpoints_con_cita,
    (SELECT COUNT(DISTINCT numero_limpio) FROM attrs_m0) AS clientes_m0,
    (SELECT COUNT(*) FROM attrs_m0) AS ventas_m0,
    (SELECT COALESCE(SUM(monto),0) FROM attrs_m0) AS fact_m0
)
SELECT jsonb_build_object(
  'ingresos',ingresos,'personasUnicas',personas_unicas,
  'reingresos',GREATEST(0,ingresos-personas_unicas),
  'personasGestionadas',personas_gestionadas,
  'personasSinGestion',GREATEST(0,personas_unicas-personas_gestionadas),
  'personasCitaTel',personas_cita_tel,'personasConCita',personas_con_cita,
  'personasAsistieron',personas_asistieron,'touchpointsGestionados',touchpoints_gestionados,
  'touchpointsConCita',touchpoints_con_cita,'clientesM0',clientes_m0,
  'ventasM0',ventas_m0,'factM0',fact_m0
) FROM vals;
$function$;

REVOKE ALL ON FUNCTION public.aos_marketing_period_summary_v2(date,date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.aos_marketing_period_summary_v2(date,date) TO anon, authenticated;
