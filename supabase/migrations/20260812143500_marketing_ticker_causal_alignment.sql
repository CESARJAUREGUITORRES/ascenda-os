CREATE OR REPLACE FUNCTION public.aos_ticker_mkt(p_mes_inicio text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_desde date := p_mes_inicio::date;
  v_hasta date := (date_trunc('month', p_mes_inicio::date) + interval '1 month - 1 day')::date;
  s jsonb;
  v_inversion numeric;
  v_mes_num int;
  v_anio int;
BEGIN
  v_mes_num := EXTRACT(MONTH FROM v_desde);
  v_anio := EXTRACT(YEAR FROM v_desde);

  SELECT aos_marketing_period_summary_v2(v_desde, v_hasta) INTO s;

  SELECT COALESCE(SUM(inversion),0) INTO v_inversion
  FROM aos_inversion_campanas
  WHERE mes_num = v_mes_num AND anio = v_anio;

  RETURN jsonb_build_object(
    'leads', COALESCE((s->>'personasUnicas')::int,0),
    'contactados', COALESCE((s->>'personasGestionadas')::int,0),
    'con_cita', COALESCE((s->>'personasCitaTel')::int,0),
    'asistio', COALESCE((s->>'personasAsistieron')::int,0),
    'con_venta', COALESCE((s->>'clientesM0')::int,0),
    'facturacion', COALESCE((s->>'factM0')::numeric,0),
    'inversion', v_inversion,
    'roas', CASE WHEN v_inversion > 0 THEN ROUND(COALESCE((s->>'factM0')::numeric,0) / v_inversion, 1) ELSE 0 END,
    'pct_contacto', CASE WHEN COALESCE((s->>'personasUnicas')::numeric,0) > 0
      THEN ROUND(COALESCE((s->>'personasGestionadas')::numeric,0) / (s->>'personasUnicas')::numeric * 100)
      ELSE 0 END
  );
END;
$function$;
