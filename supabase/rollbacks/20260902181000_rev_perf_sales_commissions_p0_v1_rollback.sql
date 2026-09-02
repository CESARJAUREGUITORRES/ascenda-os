-- ASCENDA OS · REV-PERF P0 rollback
-- Restores the three pre-P0 read functions exactly in behavior.

CREATE OR REPLACE FUNCTION public.aos_comisiones_asesor(p_asesor text, p_id_asesor text, p_mes integer, p_anio integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_mes_inicio date;
  v_mes_fin date;
  v_detalle jsonb;
  v_anual jsonb;
  v_top jsonb;
  v_ranking jsonb;
  v_com_total numeric := 0;
  v_com_serv numeric := 0;
  v_com_prod numeric := 0;
  v_fact_total numeric := 0;
  v_n_ventas integer := 0;
  v_n_serv integer := 0;
  v_n_prod integer := 0;
  v_puesto integer := 1;
BEGIN
  v_mes_inicio := make_date(p_anio, p_mes, 1);
  v_mes_fin := (v_mes_inicio + interval '1 month' - interval '1 day')::date;
  SELECT COALESCE(jsonb_agg(row_to_json(d)::jsonb ORDER BY d.fecha DESC), '[]'::jsonb)
  INTO v_detalle
  FROM (
    SELECT v.fecha::text, v.nombres, v.apellidos, v.numero_limpio,
      v.tratamiento, v.descripcion, v.monto::numeric, v.tipo, v.sede, v.pago, v.estado_pago,
      CASE WHEN v.tipo = 'SERVICIO' THEN ROUND(v.monto::numeric * 0.005, 2)
        WHEN v.tipo = 'PRODUCTO' THEN (
          SELECT COALESCE(MAX(tc.comision::numeric), 0) FROM aos_tabla_comisiones tc
          WHERE tc.tipo = 'PRODUCTO' AND tc.monto_min::numeric <= v.monto::numeric AND tc.activo = true
        ) ELSE 0 END as comision_calculada
    FROM aos_ventas v
    WHERE v.asesor = p_asesor AND v.fecha >= v_mes_inicio AND v.fecha <= v_mes_fin
  ) d;
  SELECT COUNT(*), SUM(monto::numeric),
    SUM(CASE WHEN tipo='SERVICIO' THEN ROUND(monto::numeric * 0.005, 2) ELSE 0 END),
    SUM(CASE WHEN tipo='PRODUCTO' THEN (
      SELECT COALESCE(MAX(tc.comision::numeric), 0) FROM aos_tabla_comisiones tc
      WHERE tc.tipo = 'PRODUCTO' AND tc.monto_min::numeric <= v.monto::numeric AND tc.activo = true
    ) ELSE 0 END),
    COUNT(*) FILTER (WHERE tipo='SERVICIO'), COUNT(*) FILTER (WHERE tipo='PRODUCTO')
  INTO v_n_ventas, v_fact_total, v_com_serv, v_com_prod, v_n_serv, v_n_prod
  FROM aos_ventas v
  WHERE v.asesor = p_asesor AND v.fecha >= v_mes_inicio AND v.fecha <= v_mes_fin;
  v_com_total := COALESCE(v_com_serv, 0) + COALESCE(v_com_prod, 0);
  SELECT COALESCE(jsonb_agg(row_to_json(h)::jsonb ORDER BY h.mes_num), '[]'::jsonb)
  INTO v_anual
  FROM (
    SELECT EXTRACT(MONTH FROM v.fecha)::integer as mes_num, TO_CHAR(v.fecha, 'TMMonth') as mes_nombre,
      SUM(v.monto::numeric) as facturado,
      SUM(CASE WHEN v.tipo = 'SERVICIO' THEN ROUND(v.monto::numeric * 0.005, 2)
        WHEN v.tipo = 'PRODUCTO' THEN (
          SELECT COALESCE(MAX(tc.comision::numeric), 0) FROM aos_tabla_comisiones tc
          WHERE tc.tipo = 'PRODUCTO' AND tc.monto_min::numeric <= v.monto::numeric AND tc.activo = true
        ) ELSE 0 END) as comision,
      SUM(CASE WHEN v.tipo = 'SERVICIO' THEN ROUND(v.monto::numeric * 0.005, 2) ELSE 0 END) as com_serv,
      SUM(CASE WHEN v.tipo = 'PRODUCTO' THEN (
        SELECT COALESCE(MAX(tc.comision::numeric), 0) FROM aos_tabla_comisiones tc
        WHERE tc.tipo = 'PRODUCTO' AND tc.monto_min::numeric <= v.monto::numeric AND tc.activo = true
      ) ELSE 0 END) as com_prod, COUNT(*) as n_ventas
    FROM aos_ventas v WHERE v.asesor = p_asesor AND EXTRACT(YEAR FROM v.fecha) = p_anio
    GROUP BY EXTRACT(MONTH FROM v.fecha), TO_CHAR(v.fecha, 'TMMonth')
  ) h;
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.total DESC), '[]'::jsonb)
  INTO v_top
  FROM (
    SELECT (COALESCE(v.nombres,'') || ' ' || COALESCE(v.apellidos,'')) as cliente,
      v.numero_limpio as num, SUM(v.monto::numeric) as total, COUNT(*) as compras, MAX(v.fecha::text) as ult_fecha
    FROM aos_ventas v
    WHERE v.asesor = p_asesor AND EXTRACT(YEAR FROM v.fecha) = p_anio
      AND v.numero_limpio IS NOT NULL AND v.numero_limpio != ''
    GROUP BY v.nombres, v.apellidos, v.numero_limpio ORDER BY SUM(v.monto::numeric) DESC LIMIT 5
  ) t;
  SELECT COALESCE(rk.pos, 1) INTO v_puesto
  FROM (
    SELECT asesor, ROW_NUMBER() OVER (ORDER BY SUM(
      CASE WHEN tipo='SERVICIO' THEN ROUND(monto::numeric*0.005,2)
        WHEN tipo='PRODUCTO' THEN (SELECT COALESCE(MAX(tc.comision::numeric),0) FROM aos_tabla_comisiones tc WHERE tc.tipo='PRODUCTO' AND tc.monto_min::numeric<=v.monto::numeric AND tc.activo=true)
        ELSE 0 END
    ) DESC) as pos
    FROM aos_ventas v
    WHERE fecha >= v_mes_inicio AND fecha <= v_mes_fin
      AND asesor NOT IN ('NO APLICA','DRA CAROLINA','DRA YESSICA','VINO SOLA(O)')
    GROUP BY asesor
  ) rk WHERE rk.asesor = p_asesor;
  RETURN jsonb_build_object(
    'comTotal', v_com_total,'comServ', v_com_serv,'comProd', v_com_prod,
    'factTotal', COALESCE(v_fact_total, 0),'nVentas', COALESCE(v_n_ventas, 0),
    'nServ', COALESCE(v_n_serv, 0),'nProd', COALESCE(v_n_prod, 0),'ranking', v_puesto,
    'meta', 100,'pct', ROUND(COALESCE(v_com_total,0) / 100.0 * 100, 1),
    'detalle', v_detalle,'anual', v_anual,'topClientes', v_top
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.aos_ventas_admin(p_mes integer, p_anio integer, p_sede text DEFAULT ''::text, p_asesor text DEFAULT ''::text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
AS $function$
DECLARE v_desde date; v_hasta date; v_periodo text;
BEGIN
  v_desde := make_date(p_anio, p_mes, 1);
  v_hasta := (v_desde + interval '1 month' - interval '1 day')::date;
  v_periodo := p_anio || '-' || LPAD(p_mes::text, 2, '0');
  RETURN jsonb_build_object(
    'factTotal', (SELECT COALESCE(SUM(monto),0) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'nVentas', (SELECT COUNT(*) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'ticketProm', (SELECT CASE WHEN COUNT(*)>0 THEN ROUND(SUM(monto)/COUNT(*)) ELSE 0 END FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'nServ', (SELECT COUNT(*) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND tipo='SERVICIO' AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'factServ', (SELECT COALESCE(SUM(monto),0) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND tipo='SERVICIO' AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'nProd', (SELECT COUNT(*) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND tipo='PRODUCTO' AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'factProd', (SELECT COALESCE(SUM(monto),0) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND tipo='PRODUCTO' AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'nPagoCompleto', (SELECT COUNT(*) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND estado_pago='PAGO COMPLETO' AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'nAdelanto', (SELECT COUNT(*) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND estado_pago='ADELANTO' AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'factAdelanto', (SELECT COALESCE(SUM(monto),0) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND estado_pago='ADELANTO' AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'nSinDefinir', (SELECT COUNT(*) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND (estado_pago IS NULL OR estado_pago NOT IN ('PAGO COMPLETO','ADELANTO')) AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'meta', (SELECT COALESCE(meta,0) FROM aos_metas_ventas WHERE periodo=v_periodo),
    'detalle', COALESCE((SELECT jsonb_agg(row_to_json(d) ORDER BY d.fecha DESC, d.id DESC) FROM (
      SELECT v.id, v.fecha::text, v.monto, v.tipo, v.tratamiento, v.descripcion, v.pago, v.sede, v.estado_pago, v.atendio, v.numero_limpio, v.asesor, v.nombres, v.apellidos,
        CASE WHEN v.asesor='NO APLICA' THEN 0 WHEN v.tipo='SERVICIO' THEN ROUND(v.monto*0.005,2) WHEN v.tipo='PRODUCTO' THEN COALESCE((SELECT MAX(tc.comision::numeric) FROM aos_tabla_comisiones tc WHERE tc.tipo='PRODUCTO' AND tc.monto_min::numeric<=v.monto AND tc.activo=true),0) ELSE 0 END as comision
      FROM aos_ventas v WHERE v.fecha BETWEEN v_desde AND v_hasta AND (p_sede='' OR v.sede=p_sede) AND (p_asesor='' OR v.asesor=p_asesor)) d), '[]'::jsonb),
    'porAsesor', COALESCE((SELECT jsonb_agg(row_to_json(a) ORDER BY a.total DESC) FROM (
      SELECT asesor, COUNT(*) as n, SUM(monto) as total,
        SUM(CASE WHEN tipo='SERVICIO' THEN ROUND(monto*0.005,2) WHEN tipo='PRODUCTO' THEN COALESCE((SELECT MAX(tc.comision::numeric) FROM aos_tabla_comisiones tc WHERE tc.tipo='PRODUCTO' AND tc.monto_min::numeric<=v.monto AND tc.activo=true),0) ELSE 0 END) as comision
      FROM aos_ventas v WHERE fecha BETWEEN v_desde AND v_hasta AND (p_sede='' OR sede=p_sede) AND asesor!='NO APLICA' GROUP BY asesor) a), '[]'::jsonb),
    'noAplica', (SELECT jsonb_build_object('n',COUNT(*),'total',COALESCE(SUM(monto),0)) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND asesor='NO APLICA' AND (p_sede='' OR sede=p_sede)),
    'porSede', COALESCE((SELECT jsonb_agg(row_to_json(s) ORDER BY s.total DESC) FROM (SELECT sede, COUNT(*) as n, SUM(monto) as total, COUNT(*) FILTER(WHERE tipo='SERVICIO') as n_serv, COUNT(*) FILTER(WHERE tipo='PRODUCTO') as n_prod FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND (p_asesor='' OR asesor=p_asesor) GROUP BY sede) s), '[]'::jsonb),
    'porMetodoPago', COALESCE((SELECT jsonb_agg(row_to_json(mp) ORDER BY mp.total DESC) FROM (SELECT pago as metodo, COUNT(*) as n, SUM(monto) as total FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor) GROUP BY pago) mp), '[]'::jsonb),
    'porMetodoPagoSede', COALESCE((SELECT jsonb_agg(row_to_json(mp) ORDER BY mp.total DESC) FROM (SELECT pago as metodo, sede, COUNT(*) as n, SUM(monto) as total FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND (p_asesor='' OR asesor=p_asesor) GROUP BY pago, sede) mp), '[]'::jsonb),
    'porTratamiento', COALESCE((SELECT jsonb_agg(row_to_json(t) ORDER BY t.total DESC) FROM (SELECT tratamiento, COUNT(*) as n, SUM(monto) as total FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor) GROUP BY tratamiento ORDER BY SUM(monto) DESC LIMIT 10) t), '[]'::jsonb),
    'anual', COALESCE((SELECT jsonb_agg(row_to_json(m) ORDER BY m.mes_num) FROM (SELECT EXTRACT(MONTH FROM fecha)::int as mes_num, SUM(monto) as facturado, COUNT(*) as n_ventas FROM aos_ventas WHERE EXTRACT(YEAR FROM fecha)=p_anio AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor) GROUP BY EXTRACT(MONTH FROM fecha)) m), '[]'::jsonb),
    'metodos', (SELECT COALESCE(jsonb_agg(row_to_json(mp) ORDER BY mp.orden), '[]'::jsonb) FROM (SELECT id, nombre, moneda, activo, orden, sede FROM aos_metodos_pago ORDER BY orden) mp),
    'metas', (SELECT COALESCE(jsonb_agg(row_to_json(mt) ORDER BY mt.periodo DESC), '[]'::jsonb) FROM (SELECT id, periodo, meta, moneda, descripcion FROM aos_metas_ventas ORDER BY periodo DESC) mt)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.aos_ventas_admin_anio(p_anio integer, p_sede text DEFAULT ''::text, p_asesor text DEFAULT ''::text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
AS $function$
DECLARE v_desde date; v_hasta date;
BEGIN
  v_desde := make_date(p_anio, 1, 1); v_hasta := make_date(p_anio, 12, 31);
  RETURN jsonb_build_object(
    'factTotal', (SELECT COALESCE(SUM(monto),0) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'nVentas', (SELECT COUNT(*) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'ticketProm', (SELECT CASE WHEN COUNT(*)>0 THEN ROUND(SUM(monto)/COUNT(*)) ELSE 0 END FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'nServ', (SELECT COUNT(*) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND tipo='SERVICIO' AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'factServ', (SELECT COALESCE(SUM(monto),0) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND tipo='SERVICIO' AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'nProd', (SELECT COUNT(*) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND tipo='PRODUCTO' AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'factProd', (SELECT COALESCE(SUM(monto),0) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND tipo='PRODUCTO' AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'nPagoCompleto', (SELECT COUNT(*) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND estado_pago='PAGO COMPLETO' AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'nAdelanto', (SELECT COUNT(*) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND estado_pago='ADELANTO' AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'factAdelanto', (SELECT COALESCE(SUM(monto),0) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND estado_pago='ADELANTO' AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'nSinDefinir', (SELECT COUNT(*) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND (estado_pago IS NULL OR estado_pago NOT IN ('PAGO COMPLETO','ADELANTO')) AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor)),
    'detalle', COALESCE((SELECT jsonb_agg(row_to_json(d) ORDER BY d.fecha DESC, d.id DESC) FROM (SELECT v.id, v.fecha::text, v.monto, v.tipo, v.tratamiento, v.descripcion, v.pago, v.sede, v.estado_pago, v.atendio, v.numero_limpio, v.asesor, v.nombres, v.apellidos, CASE WHEN v.asesor='NO APLICA' THEN 0 WHEN v.tipo='SERVICIO' THEN ROUND(v.monto*0.005,2) WHEN v.tipo='PRODUCTO' THEN COALESCE((SELECT MAX(tc.comision::numeric) FROM aos_tabla_comisiones tc WHERE tc.tipo='PRODUCTO' AND tc.monto_min::numeric<=v.monto AND tc.activo=true),0) ELSE 0 END as comision FROM aos_ventas v WHERE v.fecha BETWEEN v_desde AND v_hasta AND (p_sede='' OR v.sede=p_sede) AND (p_asesor='' OR v.asesor=p_asesor)) d), '[]'::jsonb),
    'porAsesor', COALESCE((SELECT jsonb_agg(row_to_json(a) ORDER BY a.total DESC) FROM (SELECT asesor, COUNT(*) as n, SUM(monto) as total, SUM(CASE WHEN tipo='SERVICIO' THEN ROUND(monto*0.005,2) WHEN tipo='PRODUCTO' THEN COALESCE((SELECT MAX(tc.comision::numeric) FROM aos_tabla_comisiones tc WHERE tc.tipo='PRODUCTO' AND tc.monto_min::numeric<=v.monto AND tc.activo=true),0) ELSE 0 END) as comision FROM aos_ventas v WHERE fecha BETWEEN v_desde AND v_hasta AND (p_sede='' OR sede=p_sede) AND asesor!='NO APLICA' GROUP BY asesor) a), '[]'::jsonb),
    'noAplica', (SELECT jsonb_build_object('n',COUNT(*),'total',COALESCE(SUM(monto),0)) FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND asesor='NO APLICA' AND (p_sede='' OR sede=p_sede)),
    'porSede', COALESCE((SELECT jsonb_agg(row_to_json(s) ORDER BY s.total DESC) FROM (SELECT sede, COUNT(*) as n, SUM(monto) as total, COUNT(*) FILTER(WHERE tipo='SERVICIO') as n_serv, COUNT(*) FILTER(WHERE tipo='PRODUCTO') as n_prod FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND (p_asesor='' OR asesor=p_asesor) GROUP BY sede) s), '[]'::jsonb),
    'porMetodoPago', COALESCE((SELECT jsonb_agg(row_to_json(mp) ORDER BY mp.total DESC) FROM (SELECT pago as metodo, COUNT(*) as n, SUM(monto) as total FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor) GROUP BY pago) mp), '[]'::jsonb),
    'porMetodoPagoSede', COALESCE((SELECT jsonb_agg(row_to_json(mp) ORDER BY mp.total DESC) FROM (SELECT pago as metodo, sede, COUNT(*) as n, SUM(monto) as total FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND (p_asesor='' OR asesor=p_asesor) GROUP BY pago, sede) mp), '[]'::jsonb),
    'porTratamiento', COALESCE((SELECT jsonb_agg(row_to_json(t) ORDER BY t.total DESC) FROM (SELECT tratamiento, COUNT(*) as n, SUM(monto) as total FROM aos_ventas WHERE fecha BETWEEN v_desde AND v_hasta AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor) GROUP BY tratamiento ORDER BY SUM(monto) DESC LIMIT 10) t), '[]'::jsonb),
    'anual', COALESCE((SELECT jsonb_agg(row_to_json(m) ORDER BY m.mes_num) FROM (SELECT EXTRACT(MONTH FROM fecha)::int as mes_num, SUM(monto) as facturado, COUNT(*) as n_ventas FROM aos_ventas WHERE EXTRACT(YEAR FROM fecha)=p_anio AND (p_sede='' OR sede=p_sede) AND (p_asesor='' OR asesor=p_asesor) GROUP BY EXTRACT(MONTH FROM fecha)) m), '[]'::jsonb)
  );
END;
$function$;
