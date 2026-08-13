BEGIN;

SELECT plan(37);

SELECT is((SELECT count(*) FROM zcs.aos_ventas), 1275::bigint, 'fixture has certified sale count');
SELECT is((SELECT sum(monto) FROM zcs.aos_ventas), 555373.27::numeric, 'fixture has certified billed total');
SELECT is((SELECT count(*) FROM zcs.aos_ventas WHERE tipo='SERVICIO'), 882::bigint, 'fixture service count certified');
SELECT is((SELECT sum(monto) FROM zcs.aos_ventas WHERE tipo='SERVICIO'), 498040.17::numeric, 'fixture service amount certified');
SELECT is((SELECT count(*) FROM zcs.aos_ventas WHERE tipo='PRODUCTO'), 393::bigint, 'fixture product count certified');
SELECT is((SELECT sum(monto) FROM zcs.aos_ventas WHERE tipo='PRODUCTO'), 57333.10::numeric, 'fixture product amount certified');
SELECT is((SELECT max(fecha) FROM zcs.aos_ventas), date '2026-08-12', 'fixture cutoff is 2026-08-12');
SELECT is((SELECT sum(monto) FROM zcs.aos_ventas WHERE fecha BETWEEN date '2026-07-01' AND date '2026-07-12'), 32839.05::numeric, 'July same-days baseline certified');

WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j->>'hasData')::boolean, true, 'summary reports data') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j->>'ventasYTD')::bigint, 1275::bigint, 'YTD sale count') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j->>'factYTD')::numeric, 555373.27::numeric, 'YTD billed amount') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j->>'ticketYTD')::numeric, 435.59::numeric, 'YTD average ticket') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j->>'nServYTD')::bigint, 882::bigint, 'YTD service count') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j->>'factServYTD')::numeric, 498040.17::numeric, 'YTD service amount') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j->>'nProdYTD')::bigint, 393::bigint, 'YTD product count') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j->>'factProdYTD')::numeric, 57333.10::numeric, 'YTD product amount') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j->>'metaYTD')::numeric, 800000.00::numeric, 'YTD target') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j->>'pctMetaYTD')::numeric, 69.42::numeric, 'YTD target attainment') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j->>'gapYTD')::numeric, 244626.73::numeric, 'YTD target gap') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j->>'dataThrough')::date, date '2026-08-12', 'summary cutoff') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j#>>'{mtdComparable,facturadoActual}')::numeric, 56948.80::numeric, 'August MTD') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j#>>'{mtdComparable,facturadoAnteriorMismosDias}')::numeric, 32839.05::numeric, 'July same-days MTD') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j#>>'{mtdComparable,variacionPct}')::numeric, 73.42::numeric, 'MTD comparable growth') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j#>>'{proyeccionMes,proyectado}')::numeric, 147117.73::numeric, 'month projection') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j#>>'{proyeccionMes,ritmoDiarioNecesario}')::numeric, 2265.85::numeric, 'daily pace required for target') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j#>>'{mejorMes,mes}')::int, 1, 'best closed month is January') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j#>>'{mejorMes,facturado}')::numeric, 91029.60::numeric, 'best closed month amount') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j#>>'{ultimoMesCerrado,mes}')::int, 7, 'last closed month is July') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((j#>>'{ultimoMesCerrado,variacionPct}')::numeric, 6.50::numeric, 'July vs June variation') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is(jsonb_array_length(j->'serie'), 12, 'series always has 12 months') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((SELECT x->>'estado' FROM jsonb_array_elements(j->'serie') x WHERE (x->>'mes')::int=8), 'PARCIAL', 'August is partial') FROM d;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','') AS j)
SELECT is((SELECT x->>'estado' FROM jsonb_array_elements(j->'serie') x WHERE (x->>'mes')::int=9), 'FUTURO', 'September is future') FROM d;
SELECT is((SELECT prosecdef FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='zcs' AND p.proname='aos_sales_intelligence_summary' LIMIT 1), false, 'RPC is SECURITY INVOKER');
SELECT is((SELECT provolatile FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='zcs' AND p.proname='aos_sales_intelligence_summary' LIMIT 1), 's'::"char", 'RPC is STABLE');
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'SAN ISIDRO','') AS j), q AS (SELECT count(*) n, sum(monto) s FROM zcs.aos_ventas WHERE sede='SAN ISIDRO')
SELECT is((d.j->>'ventasYTD')::bigint, q.n, 'sede filter count matches source') FROM d,q;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2026,'','CARMEN') AS j), q AS (SELECT count(*) n FROM zcs.aos_ventas WHERE asesor='CARMEN')
SELECT is((d.j->>'ventasYTD')::bigint, q.n, 'advisor filter count matches source') FROM d,q;
WITH d AS (SELECT zcs.aos_sales_intelligence_summary(2025,'','') AS j)
SELECT is((j->>'hasData')::boolean, false, 'empty year returns hasData false') FROM d;

SELECT * FROM finish();
ROLLBACK;
