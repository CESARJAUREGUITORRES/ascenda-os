-- ASCENDA OS
-- Hotfix already applied to production as Supabase migration 20260813164711_fix_otros_service_type.
-- Business invariant: tratamiento OTROS is always SERVICIO.

DO $$
DECLARE
  v_bad integer;
BEGIN
  SELECT count(*) INTO v_bad
  FROM public.aos_ventas
  WHERE upper(trim(coalesce(tratamiento,''))) = 'OTROS'
    AND upper(trim(coalesce(tipo,''))) <> 'SERVICIO';

  IF v_bad > 25 THEN
    RAISE EXCEPTION 'Aborting OTROS hotfix: unexpected affected row count % (>25)', v_bad;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_normalizar_tipo_venta_otros()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF upper(trim(coalesce(NEW.tratamiento,''))) = 'OTROS' THEN
    NEW.tipo := 'SERVICIO';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_normalizar_tipo_venta_otros ON public.aos_ventas;
CREATE TRIGGER trg_normalizar_tipo_venta_otros
BEFORE INSERT OR UPDATE OF tratamiento, tipo ON public.aos_ventas
FOR EACH ROW
EXECUTE FUNCTION public.fn_normalizar_tipo_venta_otros();

CREATE OR REPLACE FUNCTION public.aos_editar_venta(
  p_venta_id bigint,
  p_campos jsonb,
  p_editado_por text,
  p_rol text DEFAULT 'asesor'::text,
  p_origen text DEFAULT 'manual'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_venta_asesor text;
  v_key text;
  v_new_value text;
  v_old_value text;
  v_cambios jsonb := '[]'::jsonb;
  v_allowed text[] := ARRAY[
    'fecha','nombres','apellidos','dni','celular','tratamiento','descripcion',
    'pago','monto','estado_pago','asesor','atendio','sede','numero_limpio',
    'nro_doc','estado_doc','tipo_comprobante','tipo'
  ];
BEGIN
  SELECT asesor INTO v_venta_asesor
  FROM public.aos_ventas
  WHERE id = p_venta_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Venta no encontrada');
  END IF;

  IF p_rol <> 'ADMIN' AND p_rol <> 'admin' THEN
    IF upper(coalesce(v_venta_asesor,'')) <> upper(p_editado_por) THEN
      RETURN jsonb_build_object('ok', false, 'error', 'Sin permiso para editar esta venta');
    END IF;
  END IF;

  FOR v_key IN SELECT jsonb_object_keys(p_campos) LOOP
    IF NOT (v_key = ANY(v_allowed)) THEN
      CONTINUE;
    END IF;

    v_new_value := p_campos->>v_key;

    EXECUTE format('SELECT %I::text FROM public.aos_ventas WHERE id = $1', v_key)
      INTO v_old_value
      USING p_venta_id;

    IF v_new_value IS DISTINCT FROM v_old_value THEN
      IF v_key = 'fecha' THEN
        UPDATE public.aos_ventas
        SET fecha = v_new_value::date, updated_at = now()
        WHERE id = p_venta_id;
      ELSIF v_key = 'monto' THEN
        UPDATE public.aos_ventas
        SET monto = v_new_value::numeric, updated_at = now()
        WHERE id = p_venta_id;
      ELSE
        EXECUTE format('UPDATE public.aos_ventas SET %I = $1, updated_at = now() WHERE id = $2', v_key)
          USING v_new_value, p_venta_id;
      END IF;

      INSERT INTO public.aos_auditoria_ediciones
        (tabla, registro_id, campo, valor_anterior, valor_nuevo, editado_por, origen)
      VALUES
        ('aos_ventas', p_venta_id::text, v_key, v_old_value, v_new_value, p_editado_por, p_origen);

      v_cambios := v_cambios || jsonb_build_object(
        'campo', v_key,
        'antes', v_old_value,
        'despues', v_new_value
      );
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'cambios', v_cambios,
    'total_cambios', jsonb_array_length(v_cambios)
  );
END;
$function$;

INSERT INTO public.aos_auditoria_ediciones
  (tabla, registro_id, campo, valor_anterior, valor_nuevo, editado_por, origen)
SELECT
  'aos_ventas', v.id::text, 'tipo', v.tipo, 'SERVICIO', 'SYSTEM',
  'migration_fix_otros_service_20260813'
FROM public.aos_ventas v
WHERE upper(trim(coalesce(v.tratamiento,''))) = 'OTROS'
  AND upper(trim(coalesce(v.tipo,''))) <> 'SERVICIO'
  AND NOT EXISTS (
    SELECT 1
    FROM public.aos_auditoria_ediciones a
    WHERE a.tabla = 'aos_ventas'
      AND a.registro_id = v.id::text
      AND a.campo = 'tipo'
      AND a.origen = 'migration_fix_otros_service_20260813'
  );

UPDATE public.aos_ventas
SET tipo = 'SERVICIO', updated_at = now()
WHERE upper(trim(coalesce(tratamiento,''))) = 'OTROS'
  AND upper(trim(coalesce(tipo,''))) <> 'SERVICIO';

DO $$
DECLARE
  v_remaining integer;
BEGIN
  SELECT count(*) INTO v_remaining
  FROM public.aos_ventas
  WHERE upper(trim(coalesce(tratamiento,''))) = 'OTROS'
    AND upper(trim(coalesce(tipo,''))) <> 'SERVICIO';

  IF v_remaining <> 0 THEN
    RAISE EXCEPTION 'OTROS invariant failed: % rows remain non-SERVICIO', v_remaining;
  END IF;
END;
$$;

COMMENT ON FUNCTION public.fn_normalizar_tipo_venta_otros() IS
'ASCENDA business invariant: tratamiento OTROS is always SERVICIO. Prevents legacy/import/editor misclassification.';