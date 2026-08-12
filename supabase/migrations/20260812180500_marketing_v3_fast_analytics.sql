-- ASCENDA OS — Marketing V3 performance remediation
-- Purpose: remove repeated full touchpoint recomputation that caused statement timeouts
-- in public Marketing reporting gateways. No data mutation; matching semantics preserved.

CREATE OR REPLACE FUNCTION public.aos_marketing_call_lead_match_v2(
  p_desde date DEFAULT NULL::date,
  p_hasta date DEFAULT NULL::date
)
RETURNS TABLE(
  cita_id text,
  llamada_id bigint,
  llamada_ts timestamp with time zone,
  numero_limpio text,
  lead_id bigint,
  lead_ts timestamp with time zone,
  candidatos_previos bigint,
  candidatos_tratamiento bigint,
  metodo_match text,
  confidence integer
)
LANGUAGE sql
STABLE
AS $function$
WITH tp AS MATERIALIZED (
  SELECT *
  FROM public.aos_marketing_touchpoints_v2(NULL,NULL)
), chain AS MATERIALIZED (
  SELECT
    m.cita_id,
    m.llamada_id,
    m.llamada_ts,
    m.numero_limpio,
    ll.lead_id_origen,
    ll.tratamiento
  FROM public.aos_marketing_call_cita_match_v2(p_desde,p_hasta) m
  JOIN public.aos_llamadas ll ON ll.id=m.llamada_id
  WHERE m.metodo_match='CALL_CITA_UNICO_10M'
), counts AS MATERIALIZED (
  SELECT
    c.*,
    count(t.lead_id) FILTER (
      WHERE NOT t.es_duplicado_tecnico_probable
        AND t.lead_ts<=c.llamada_ts
    ) AS n_prior,
    count(t.lead_id) FILTER (
      WHERE NOT t.es_duplicado_tecnico_probable
        AND t.lead_ts<=c.llamada_ts
        AND nullif(trim(c.tratamiento),'') IS NOT NULL
        AND upper(coalesce(t.tratamiento,''))=upper(c.tratamiento)
    ) AS n_trat
  FROM chain c
  LEFT JOIN tp t ON t.numero_limpio=c.numero_limpio
  GROUP BY
    c.cita_id,c.llamada_id,c.llamada_ts,c.numero_limpio,
    c.lead_id_origen,c.tratamiento
), resolved AS MATERIALIZED (
  SELECT
    c.*,
    CASE
      WHEN c.lead_id_origen IS NOT NULL THEN c.lead_id_origen
      WHEN c.n_prior=1 THEN (
        SELECT t.lead_id
        FROM tp t
        WHERE t.numero_limpio=c.numero_limpio
          AND NOT t.es_duplicado_tecnico_probable
          AND t.lead_ts<=c.llamada_ts
        ORDER BY t.lead_ts DESC,t.lead_id DESC
        LIMIT 1
      )
      WHEN c.n_prior>1 AND c.n_trat=1 THEN (
        SELECT t.lead_id
        FROM tp t
        WHERE t.numero_limpio=c.numero_limpio
          AND NOT t.es_duplicado_tecnico_probable
          AND t.lead_ts<=c.llamada_ts
          AND nullif(trim(c.tratamiento),'') IS NOT NULL
          AND upper(coalesce(t.tratamiento,''))=upper(c.tratamiento)
        ORDER BY t.lead_ts DESC,t.lead_id DESC
        LIMIT 1
      )
      ELSE NULL
    END AS resolved_lead_id
  FROM counts c
)
SELECT
  r.cita_id,
  r.llamada_id,
  r.llamada_ts,
  r.numero_limpio,
  r.resolved_lead_id,
  l.lead_ts,
  r.n_prior::bigint,
  r.n_trat::bigint,
  CASE
    WHEN r.lead_id_origen IS NOT NULL THEN 'DIRECT_LEAD_ID'
    WHEN r.n_prior=1 THEN 'UNIQUE_PRIOR_LEAD'
    WHEN r.n_prior>1 AND r.n_trat=1 THEN 'UNIQUE_PRIOR_BY_TREATMENT'
    WHEN r.n_prior=0 THEN 'NO_PRIOR_MARKETING_LEAD'
    ELSE 'AMBIGUOUS_PRIOR_LEAD'
  END,
  CASE
    WHEN r.lead_id_origen IS NOT NULL THEN 100
    WHEN r.n_prior=1 THEN 90
    WHEN r.n_prior>1 AND r.n_trat=1 THEN 85
    WHEN r.n_prior=0 THEN 0
    ELSE 40
  END
FROM resolved r
LEFT JOIN tp l ON l.lead_id=r.resolved_lead_id
ORDER BY r.llamada_ts,r.llamada_id;
$function$;

CREATE OR REPLACE FUNCTION public.aos_marketing_sale_attribution_v2(
  p_desde date DEFAULT NULL::date,
  p_hasta date DEFAULT NULL::date
)
RETURNS TABLE(
  venta_pk bigint,
  venta_id text,
  venta_fecha date,
  monto numeric,
  tratamiento_compra text,
  numero_limpio text,
  lead_id bigint,
  lead_fecha date,
  lead_anuncio text,
  lead_tratamiento text,
  llamada_id bigint,
  cita_id text,
  cita_estado text,
  metodo_match text,
  confidence integer,
  anomaly_code text
)
LANGUAGE sql
STABLE
AS $function$
WITH ventas AS (
  SELECT v.*
  FROM public.aos_ventas v
  WHERE v.numero_limpio IS NOT NULL
    AND v.numero_limpio<>''
    AND (p_desde IS NULL OR v.fecha>=p_desde)
    AND (p_hasta IS NULL OR v.fecha<=p_hasta)
), candidates AS (
  SELECT
    v.id venta_pk,
    c.id cita_id,
    c.estado_cita,
    cl.llamada_id,
    cl.lead_id,
    cl.confidence lead_confidence,
    count(*) OVER (PARTITION BY v.id) candidate_citas,
    row_number() OVER (PARTITION BY v.id ORDER BY cl.confidence DESC,c.id) rn
  FROM ventas v
  JOIN public.aos_agenda_citas c
    ON c.numero_limpio=v.numero_limpio
   AND c.fecha_cita=v.fecha
   AND upper(coalesce(c.origen_cita,''))='CALL_CENTER'
  -- A valid sale/cita candidate must occur on the sale date, so limiting the
  -- call matcher to the same requested date window preserves the original match set.
  JOIN public.aos_marketing_call_lead_match_v2(p_desde,p_hasta) cl
    ON cl.cita_id=c.id
   AND cl.lead_id IS NOT NULL
   AND cl.confidence>=85
), best AS (
  SELECT * FROM candidates WHERE rn=1
)
SELECT
  v.id::bigint,
  v.venta_id,
  v.fecha,
  v.monto,
  v.tratamiento,
  v.numero_limpio,
  CASE WHEN b.candidate_citas=1 THEN b.lead_id ELSE NULL END,
  CASE WHEN b.candidate_citas=1 THEN l.fecha ELSE NULL END,
  CASE WHEN b.candidate_citas=1 THEN l.anuncio ELSE NULL END,
  CASE WHEN b.candidate_citas=1 THEN l.tratamiento ELSE NULL END,
  CASE WHEN b.candidate_citas=1 THEN b.llamada_id ELSE NULL END,
  CASE WHEN b.candidate_citas=1 THEN b.cita_id ELSE NULL END,
  CASE WHEN b.candidate_citas=1 THEN b.estado_cita ELSE NULL END,
  CASE
    WHEN b.venta_pk IS NULL THEN 'SIN_MATCH'
    WHEN b.candidate_citas>1 THEN 'AMBIGUOUS_CITA_SAME_DAY'
    WHEN upper(coalesce(b.estado_cita,'')) IN ('ASISTIO','EFECTIVA') THEN 'CALL_CITA_ATTENDED_SAME_DAY'
    WHEN upper(coalesce(b.estado_cita,''))='NO ASISTIO' THEN 'CALL_CITA_NO_SHOW_WITH_SALE'
    ELSE 'CALL_CITA_OTHER_STATUS_WITH_SALE'
  END,
  CASE
    WHEN b.venta_pk IS NULL THEN 0
    WHEN b.candidate_citas>1 THEN 40
    WHEN upper(coalesce(b.estado_cita,'')) IN ('ASISTIO','EFECTIVA') THEN least(b.lead_confidence,90)
    WHEN upper(coalesce(b.estado_cita,''))='NO ASISTIO' THEN least(b.lead_confidence,80)
    ELSE least(b.lead_confidence,60)
  END,
  CASE
    WHEN b.venta_pk IS NULL THEN NULL
    WHEN b.candidate_citas>1 THEN 'MULTIPLE_CITAS_SAME_DAY'
    WHEN upper(coalesce(b.estado_cita,''))='NO ASISTIO' THEN 'NO_SHOW_WITH_SAME_DAY_SALE'
    WHEN upper(coalesce(b.estado_cita,'')) NOT IN ('ASISTIO','EFECTIVA') THEN 'NON_ATTENDED_STATUS_WITH_SALE'
    ELSE NULL
  END
FROM ventas v
LEFT JOIN best b ON b.venta_pk=v.id
LEFT JOIN public.aos_leads l ON l.id=b.lead_id
ORDER BY v.fecha,v.id;
$function$;

COMMENT ON FUNCTION public.aos_marketing_call_lead_match_v2(date,date)
IS 'Marketing V3 matcher: semantics preserved; touchpoints materialized once per execution to prevent statement timeouts.';
COMMENT ON FUNCTION public.aos_marketing_sale_attribution_v2(date,date)
IS 'Marketing V3 sale attribution: same-date matching semantics preserved; downstream call matcher bounded to requested sale period.';
