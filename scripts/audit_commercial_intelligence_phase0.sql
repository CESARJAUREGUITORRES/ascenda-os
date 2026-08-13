-- ASCENDA OS — Commercial Intelligence & Audience OS
-- PHASE 0 reproducible audit
-- READ ONLY. No DDL / DML.
-- Baseline created: 2026-08-13

BEGIN TRANSACTION READ ONLY;

-- ============================================================
-- A. CORE COUNTS / IDENTITY COVERAGE
-- ============================================================
WITH metrics AS (
  SELECT 'aos_pacientes' tabla, count(*)::bigint filas,
         count(DISTINCT NULLIF(numero_limpio,''))::bigint contactos,
         count(*) FILTER (WHERE numero_limpio IS NULL OR numero_limpio='')::bigint sin_clave
  FROM aos_pacientes
  UNION ALL
  SELECT 'aos_leads', count(*), count(DISTINCT NULLIF(numero_limpio,'')),
         count(*) FILTER (WHERE numero_limpio IS NULL OR numero_limpio='') FROM aos_leads
  UNION ALL
  SELECT 'aos_llamadas', count(*), count(DISTINCT NULLIF(numero_limpio,'')),
         count(*) FILTER (WHERE numero_limpio IS NULL OR numero_limpio='') FROM aos_llamadas
  UNION ALL
  SELECT 'aos_agenda_citas', count(*), count(DISTINCT NULLIF(numero_limpio,'')),
         count(*) FILTER (WHERE numero_limpio IS NULL OR numero_limpio='') FROM aos_agenda_citas
  UNION ALL
  SELECT 'aos_ventas', count(*), count(DISTINCT NULLIF(numero_limpio,'')),
         count(*) FILTER (WHERE numero_limpio IS NULL OR numero_limpio='') FROM aos_ventas
  UNION ALL
  SELECT 'aos_seguimientos', count(*),
         count(DISTINCT NULLIF(regexp_replace(coalesce("NUMERO",''),'\D','','g'),'')),
         count(*) FILTER (WHERE "NUMERO" IS NULL OR regexp_replace(coalesce("NUMERO",''),'\D','','g')='')
  FROM aos_seguimientos
  UNION ALL
  SELECT 'aos_base_etiquetas', count(*), count(DISTINCT NULLIF(numero,'')),
         count(*) FILTER (WHERE numero IS NULL OR numero='') FROM aos_base_etiquetas
)
SELECT * FROM metrics ORDER BY tabla;

-- Contact universe over the five core sources.
SELECT count(*) AS contactos_unicos_core
FROM (
  SELECT numero_limpio AS k FROM aos_pacientes WHERE numero_limpio IS NOT NULL AND numero_limpio<>''
  UNION SELECT numero_limpio FROM aos_leads WHERE numero_limpio IS NOT NULL AND numero_limpio<>''
  UNION SELECT numero_limpio FROM aos_llamadas WHERE numero_limpio IS NOT NULL AND numero_limpio<>''
  UNION SELECT numero_limpio FROM aos_agenda_citas WHERE numero_limpio IS NOT NULL AND numero_limpio<>''
  UNION SELECT numero_limpio FROM aos_ventas WHERE numero_limpio IS NOT NULL AND numero_limpio<>''
) u;

-- Patient duplicates by current bridge key.
SELECT count(*) AS numeros_duplicados_en_pacientes,
       sum(n-1)::bigint AS filas_duplicadas_extra
FROM (
  SELECT numero_limpio, count(*) n
  FROM aos_pacientes
  WHERE numero_limpio IS NOT NULL AND numero_limpio<>''
  GROUP BY numero_limpio
  HAVING count(*) > 1
) d;

-- ============================================================
-- B. ENUM / SEMANTIC INVENTORY
-- ============================================================
SELECT 'call.estado' dominio, coalesce(estado,'∅') valor, count(*) n
FROM aos_llamadas GROUP BY 1,2 ORDER BY 3 DESC;

SELECT 'agenda.estado_cita' dominio, coalesce(estado_cita,'∅') valor, count(*) n
FROM aos_agenda_citas GROUP BY 1,2 ORDER BY 3 DESC;

SELECT 'venta.tipo' dominio, coalesce(tipo,'∅') valor, count(*) n
FROM aos_ventas GROUP BY 1,2 ORDER BY 3 DESC;

SELECT 'seguimiento.estado' dominio, coalesce("ESTADO",'∅') valor, count(*) n
FROM aos_seguimientos GROUP BY 1,2 ORDER BY 3 DESC;

SELECT 'paciente.estado' dominio, coalesce("ESTADO_PACIENTE",'∅') valor, count(*) n
FROM aos_pacientes GROUP BY 1,2 ORDER BY 3 DESC;

SELECT 'paciente.score' dominio, coalesce("SCORE_ESTADO",'∅') valor, count(*) n
FROM aos_pacientes GROUP BY 1,2 ORDER BY 3 DESC;

SELECT 'paciente.vip' dominio, coalesce(etiqueta_vip,'∅') valor, count(*) n
FROM aos_pacientes GROUP BY 1,2 ORDER BY 3 DESC;

-- ============================================================
-- C. EMAIL IDENTITY COVERAGE
-- ============================================================
SELECT 'aos_email_flujo_ejecuciones' fuente,
       count(*) filas,
       count(DISTINCT NULLIF(numero_limpio,'')) contactos,
       count(*) FILTER (WHERE numero_limpio IS NULL OR numero_limpio='') sin_contact_key
FROM aos_email_flujo_ejecuciones
UNION ALL
SELECT 'aos_emails_enviados', count(*), count(DISTINCT NULLIF(email_destino,'')),
       count(*) FILTER (WHERE email_destino IS NULL OR email_destino='')
FROM aos_emails_enviados;

-- ============================================================
-- D. ACTIVE USER / PERMISSION BASELINE
-- ============================================================
SELECT rol, area, count(*) AS usuarios,
       count(*) FILTER (WHERE permisos IS NOT NULL AND permisos <> '{}'::jsonb) AS con_permisos,
       count(*) FILTER (WHERE paneles_acceso IS NOT NULL AND cardinality(paneles_acceso)>0) AS con_paneles
FROM aos_usuarios
WHERE activo IS TRUE
GROUP BY rol, area
ORDER BY rol, area;

SELECT DISTINCT u.rol, k.key AS permiso_key
FROM aos_usuarios u
CROSS JOIN LATERAL jsonb_object_keys(COALESCE(u.permisos,'{}'::jsonb)) k(key)
WHERE u.activo IS TRUE
ORDER BY u.rol, k.key;

-- ============================================================
-- E. RELEVANT INDEX INVENTORY
-- ============================================================
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname='public'
  AND tablename IN (
    'aos_pacientes','aos_leads','aos_llamadas','aos_agenda_citas',
    'aos_ventas','aos_seguimientos','aos_base_etiquetas'
  )
ORDER BY tablename,indexname;

-- ============================================================
-- F. PERFORMANCE BASELINE
-- EXPLAIN ANALYZE executes SELECTs only; transaction remains read-only.
-- ============================================================

-- F1: core contact universe
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT count(*) FROM (
  SELECT numero_limpio AS k FROM aos_pacientes WHERE numero_limpio IS NOT NULL AND numero_limpio<>''
  UNION SELECT numero_limpio FROM aos_leads WHERE numero_limpio IS NOT NULL AND numero_limpio<>''
  UNION SELECT numero_limpio FROM aos_llamadas WHERE numero_limpio IS NOT NULL AND numero_limpio<>''
  UNION SELECT numero_limpio FROM aos_agenda_citas WHERE numero_limpio IS NOT NULL AND numero_limpio<>''
  UNION SELECT numero_limpio FROM aos_ventas WHERE numero_limpio IS NOT NULL AND numero_limpio<>''
) u;

-- F2: latest call per contact
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT count(*) FROM (
  SELECT DISTINCT ON (numero_limpio)
         numero_limpio, estado, fecha, created_at
  FROM aos_llamadas
  WHERE numero_limpio IS NOT NULL AND numero_limpio<>''
  ORDER BY numero_limpio, created_at DESC NULLS LAST, fecha DESC, id DESC
) q;

-- F3: representative audience
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
WITH candidatos AS (
  SELECT DISTINCT ld.numero_limpio
  FROM aos_leads ld
  WHERE ld.numero_limpio IS NOT NULL AND ld.numero_limpio<>''
    AND upper(coalesce(ld.tratamiento,'')) LIKE '%ENZIM%'
), ultima_llamada AS (
  SELECT DISTINCT ON (numero_limpio) numero_limpio, fecha
  FROM aos_llamadas
  WHERE numero_limpio IS NOT NULL AND numero_limpio<>''
  ORDER BY numero_limpio, created_at DESC NULLS LAST, fecha DESC, id DESC
)
SELECT count(*)
FROM candidatos c
LEFT JOIN ultima_llamada ul ON ul.numero_limpio=c.numero_limpio
WHERE (ul.numero_limpio IS NULL OR ul.fecha < CURRENT_DATE - 30)
  AND NOT EXISTS (SELECT 1 FROM aos_ventas v WHERE v.numero_limpio=c.numero_limpio)
  AND NOT EXISTS (
    SELECT 1 FROM aos_agenda_citas a
    WHERE a.numero_limpio=c.numero_limpio
      AND a.estado_cita IN ('PENDIENTE','CITA CONFIRMADA')
      AND a.fecha_cita >= CURRENT_DATE
  );

ROLLBACK;
