-- ASCENDA OS
-- Fix: cohort revenue must never include sales that happened before the lead cohort.
-- Scope: aos_marketing_dashboard + aos_ltv_cohortes
-- Baseline validated against August/July 2026 before applying.

DO $patch$
DECLARE
  v_oid oid;
  v_def text;
  v_count integer;
BEGIN
  SELECT p.oid INTO STRICT v_oid
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'aos_marketing_dashboard'
    AND p.pronargs = 2;

  v_def := pg_get_functiondef(v_oid);

  -- 1) "Fuera del mes" must mean AFTER the cohort month, never before it.
  v_count := (length(v_def)-length(replace(v_def,$s$v.fecha NOT BETWEEN v_desde AND v_hasta$s$,''))) / length($s$v.fecha NOT BETWEEN v_desde AND v_hasta$s$);
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'aos_marketing_dashboard: expected 1 ventasLeadsFuera date predicate, found %', v_count;
  END IF;
  v_def := replace(v_def,$s$v.fecha NOT BETWEEN v_desde AND v_hasta$s$,$s$v.fecha > v_hasta$s$);

  -- 2) Campaign accumulated revenue starts at cohort month.
  v_count := (length(v_def)-length(replace(v_def,$s$SELECT COALESCE(SUM(v.monto),0) INTO v_fact_acum FROM aos_ventas v WHERE v.numero_limpio IN$s$,''))) / length($s$SELECT COALESCE(SUM(v.monto),0) INTO v_fact_acum FROM aos_ventas v WHERE v.numero_limpio IN$s$);
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'aos_marketing_dashboard: expected 1 global fact_acum expression, found %', v_count;
  END IF;
  v_def := replace(
    v_def,
    $s$SELECT COALESCE(SUM(v.monto),0) INTO v_fact_acum FROM aos_ventas v WHERE v.numero_limpio IN$s$,
    $s$SELECT COALESCE(SUM(v.monto),0) INTO v_fact_acum FROM aos_ventas v WHERE v.fecha >= v_desde AND v.numero_limpio IN$s$
  );

  -- 3) Top Anuncios accumulated revenue starts at cohort month.
  v_count := (length(v_def)-length(replace(v_def,$s$FROM aos_ventas vx WHERE vx.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN v_desde AND v_hasta AND anuncio=sub.nombre)) as fact_acum$s$,''))) / length($s$FROM aos_ventas vx WHERE vx.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN v_desde AND v_hasta AND anuncio=sub.nombre)) as fact_acum$s$);
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'aos_marketing_dashboard: expected 1 anuncio fact_acum expression, found %', v_count;
  END IF;
  v_def := replace(
    v_def,
    $s$FROM aos_ventas vx WHERE vx.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN v_desde AND v_hasta AND anuncio=sub.nombre)) as fact_acum$s$,
    $s$FROM aos_ventas vx WHERE vx.fecha >= v_desde AND vx.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN v_desde AND v_hasta AND anuncio=sub.nombre)) as fact_acum$s$
  );

  -- 4) Treatment accumulated revenue and ROAS numerator: same cohort rule.
  v_count := (length(v_def)-length(replace(v_def,$s$FROM aos_ventas vx WHERE vx.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN v_desde AND v_hasta AND UPPER(tratamiento)=sub.nombre))$s$,''))) / length($s$FROM aos_ventas vx WHERE vx.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN v_desde AND v_hasta AND UPPER(tratamiento)=sub.nombre))$s$);
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'aos_marketing_dashboard: expected 3 treatment accumulated expressions, found %', v_count;
  END IF;
  v_def := replace(
    v_def,
    $s$FROM aos_ventas vx WHERE vx.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN v_desde AND v_hasta AND UPPER(tratamiento)=sub.nombre))$s$,
    $s$FROM aos_ventas vx WHERE vx.fecha >= v_desde AND vx.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN v_desde AND v_hasta AND UPPER(tratamiento)=sub.nombre))$s$
  );

  -- 5) Historical/LTV accumulated revenue: do not pull purchases from before each cohort month.
  v_count := (length(v_def)-length(replace(v_def,$s$FROM aos_ventas vx WHERE vx.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN make_date(p_anio,m.mes,1)$s$,''))) / length($s$FROM aos_ventas vx WHERE vx.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN make_date(p_anio,m.mes,1)$s$);
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'aos_marketing_dashboard: expected 2 historical accumulated expressions, found %', v_count;
  END IF;
  v_def := replace(
    v_def,
    $s$FROM aos_ventas vx WHERE vx.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN make_date(p_anio,m.mes,1)$s$,
    $s$FROM aos_ventas vx WHERE vx.fecha >= make_date(p_anio,m.mes,1) AND vx.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN make_date(p_anio,m.mes,1)$s$
  );

  -- 6) Conversion time must use first sale ON/AFTER the lead date.
  v_count := (length(v_def)-length(replace(v_def,$s$v.fecha = (SELECT MIN(v2.fecha) FROM aos_ventas v2 WHERE v2.numero_limpio = ld.numero_limpio);$s$,''))) / length($s$v.fecha = (SELECT MIN(v2.fecha) FROM aos_ventas v2 WHERE v2.numero_limpio = ld.numero_limpio);$s$);
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'aos_marketing_dashboard: expected 1 avg conversion predicate, found %', v_count;
  END IF;
  v_def := replace(
    v_def,
    $s$v.fecha = (SELECT MIN(v2.fecha) FROM aos_ventas v2 WHERE v2.numero_limpio = ld.numero_limpio);$s$,
    $s$v.fecha = (SELECT MIN(v2.fecha) FROM aos_ventas v2 WHERE v2.numero_limpio = ld.numero_limpio AND v2.fecha >= ld.fecha);$s$
  );

  EXECUTE v_def;
END
$patch$;

DO $patch$
DECLARE
  v_oid oid;
  v_def text;
  v_count integer;
BEGIN
  SELECT p.oid INTO STRICT v_oid
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'aos_ltv_cohortes'
    AND p.pronargs = 2;

  v_def := pg_get_functiondef(v_oid);

  -- 7) avgPcts denominator: revenue starts at cohort month.
  v_count := (length(v_def)-length(replace(v_def,$s$COALESCE((SELECT SUM(v.monto) FROM aos_ventas v WHERE v.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN make_date(p_anio,lm.lead_mes,1) AND (make_date(p_anio,lm.lead_mes,1)+interval '1 month'-interval '1 day')::date)), 0) as total_rev$s$,''))) / length($s$COALESCE((SELECT SUM(v.monto) FROM aos_ventas v WHERE v.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN make_date(p_anio,lm.lead_mes,1) AND (make_date(p_anio,lm.lead_mes,1)+interval '1 month'-interval '1 day')::date)), 0) as total_rev$s$);
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'aos_ltv_cohortes: expected 1 total_rev expression, found %', v_count;
  END IF;
  v_def := replace(
    v_def,
    $s$COALESCE((SELECT SUM(v.monto) FROM aos_ventas v WHERE v.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN make_date(p_anio,lm.lead_mes,1) AND (make_date(p_anio,lm.lead_mes,1)+interval '1 month'-interval '1 day')::date)), 0) as total_rev$s$,
    $s$COALESCE((SELECT SUM(v.monto) FROM aos_ventas v WHERE v.fecha >= make_date(p_anio,lm.lead_mes,1) AND v.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN make_date(p_anio,lm.lead_mes,1) AND (make_date(p_anio,lm.lead_mes,1)+interval '1 month'-interval '1 day')::date)), 0) as total_rev$s$
  );

  -- 8) Cohort fact_total: same rule.
  v_count := (length(v_def)-length(replace(v_def,$s$(SELECT COALESCE(SUM(v.monto),0) FROM aos_ventas v WHERE v.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN make_date(p_anio,lm.lead_mes,1) AND (make_date(p_anio,lm.lead_mes,1)+interval '1 month'-interval '1 day')::date)) as fact_total$s$,''))) / length($s$(SELECT COALESCE(SUM(v.monto),0) FROM aos_ventas v WHERE v.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN make_date(p_anio,lm.lead_mes,1) AND (make_date(p_anio,lm.lead_mes,1)+interval '1 month'-interval '1 day')::date)) as fact_total$s$);
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'aos_ltv_cohortes: expected 1 fact_total expression, found %', v_count;
  END IF;
  v_def := replace(
    v_def,
    $s$(SELECT COALESCE(SUM(v.monto),0) FROM aos_ventas v WHERE v.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN make_date(p_anio,lm.lead_mes,1) AND (make_date(p_anio,lm.lead_mes,1)+interval '1 month'-interval '1 day')::date)) as fact_total$s$,
    $s$(SELECT COALESCE(SUM(v.monto),0) FROM aos_ventas v WHERE v.fecha >= make_date(p_anio,lm.lead_mes,1) AND v.numero_limpio IN (SELECT numero_limpio FROM aos_leads WHERE fecha BETWEEN make_date(p_anio,lm.lead_mes,1) AND (make_date(p_anio,lm.lead_mes,1)+interval '1 month'-interval '1 day')::date)) as fact_total$s$
  );

  -- 9) Average conversion days: first purchase on/after each lead date.
  v_count := (length(v_def)-length(replace(v_def,$s$v.fecha=(SELECT MIN(v2.fecha) FROM aos_ventas v2 WHERE v2.numero_limpio=ld.numero_limpio)$s$,''))) / length($s$v.fecha=(SELECT MIN(v2.fecha) FROM aos_ventas v2 WHERE v2.numero_limpio=ld.numero_limpio)$s$);
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'aos_ltv_cohortes: expected 1 avg conversion predicate, found %', v_count;
  END IF;
  v_def := replace(
    v_def,
    $s$v.fecha=(SELECT MIN(v2.fecha) FROM aos_ventas v2 WHERE v2.numero_limpio=ld.numero_limpio)$s$,
    $s$v.fecha=(SELECT MIN(v2.fecha) FROM aos_ventas v2 WHERE v2.numero_limpio=ld.numero_limpio AND v2.fecha>=ld.fecha)$s$
  );

  EXECUTE v_def;
END
$patch$;

-- Post-deploy expectations for 2026-08 cohort at deployment time:
-- ventasLeadsFuera: 0 (no September+ sales exist yet)
-- fact_total cohort Aug: S/1045, not S/2485.50 (which included S/1440.50 pre-August)
-- avgDiasConversion must not be negative due to pre-lead purchases.
