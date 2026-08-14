-- ASCENDA OS — Zero-Cost Staging immutable fixture schema.
-- PII-free and isolated from public production-like objects.

CREATE SCHEMA zcs;

CREATE VIEW zcs.aos_ventas AS
WITH groups(mes, dia_ini, dia_fin, cantidad, total, tipo, tratamiento, offset_n) AS (
  VALUES
    (1,1,28,139,84354.60::numeric,'SERVICIO','SERVICIO SINTETICO',0),
    (1,1,28,52,6675.00::numeric,'PRODUCTO','COMPRA DE PRODUCTO',139),
    (2,1,28,130,73479.62::numeric,'SERVICIO','SERVICIO SINTETICO',0),
    (2,1,28,36,5255.00::numeric,'PRODUCTO','COMPRA DE PRODUCTO',130),
    (3,1,28,96,55470.65::numeric,'SERVICIO','SERVICIO SINTETICO',0),
    (3,1,28,60,8211.00::numeric,'PRODUCTO','COMPRA DE PRODUCTO',96),
    (4,1,28,105,52925.95::numeric,'SERVICIO','SERVICIO SINTETICO',0),
    (4,1,28,47,6571.00::numeric,'PRODUCTO','COMPRA DE PRODUCTO',105),
    (5,1,28,125,71911.85::numeric,'SERVICIO','SERVICIO SINTETICO',0),
    (5,1,28,54,7314.00::numeric,'PRODUCTO','COMPRA DE PRODUCTO',125),
    (6,1,28,124,55684.75::numeric,'SERVICIO','SERVICIO SINTETICO',0),
    (6,1,28,35,5456.00::numeric,'PRODUCTO','COMPRA DE PRODUCTO',124),
    (7,1,12,60,25000.00::numeric,'SERVICIO','SERVICIO SINTETICO',0),
    (7,1,12,34,7839.05::numeric,'PRODUCTO','COMPRA DE PRODUCTO',60),
    (7,13,30,52,27613.95::numeric,'SERVICIO','SERVICIO SINTETICO',94),
    (7,13,30,43,4662.05::numeric,'PRODUCTO','COMPRA DE PRODUCTO',146),
    (8,1,12,51,51598.80::numeric,'SERVICIO','SERVICIO SINTETICO',0),
    (8,1,12,32,5350.00::numeric,'PRODUCTO','COMPRA DE PRODUCTO',51)
), expanded AS (
  SELECT
    g.mes,
    s.n,
    make_date(2026, g.mes, g.dia_ini + ((s.n - 1) % (g.dia_fin - g.dia_ini + 1))) AS fecha,
    CASE WHEN s.n = g.cantidad
      THEN g.total - trunc(g.total / g.cantidad, 2) * (g.cantidad - 1)
      ELSE trunc(g.total / g.cantidad, 2)
    END::numeric(14,2) AS monto,
    g.tipo,
    g.tratamiento,
    CASE WHEN (s.n + g.offset_n) % 2 = 1 THEN 'SAN ISIDRO' ELSE 'PUEBLO LIBRE' END AS sede,
    CASE WHEN (s.n + g.offset_n) % 3 = 0 THEN 'ASESOR B' ELSE 'CARMEN' END AS asesor
  FROM groups g
  CROSS JOIN LATERAL generate_series(1, g.cantidad) AS s(n)
)
SELECT row_number() OVER (ORDER BY mes, fecha, tipo, n)::bigint AS id,
       fecha, monto, tipo, tratamiento, sede, asesor
FROM expanded;

CREATE VIEW zcs.aos_metas_ventas AS
SELECT '2026-' || lpad(m::text,2,'0') AS periodo,
       100000.00::numeric(14,2) AS meta
FROM generate_series(1,8) AS m;
