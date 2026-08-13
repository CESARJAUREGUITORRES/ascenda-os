-- ASCENDA OS — Performance Guard v1.1
-- Quarantine rows created by the historical sbPost(..., 'PATCH') bug.
-- No rows are deleted. Valid executions with a non-null flujo_id are untouched.

DO $$
DECLARE
  v_invalid_active bigint;
  v_valid_active bigint;
BEGIN
  SELECT count(*) FILTER (WHERE flujo_id IS NULL),
         count(*) FILTER (WHERE flujo_id IS NOT NULL)
    INTO v_invalid_active, v_valid_active
  FROM public.aos_email_flujo_ejecuciones
  WHERE estado = 'activo';

  INSERT INTO public.aos_log_auditoria
    (timestamp_reg, asesor, accion, referencia, detalle, tabla, usuario, metadata)
  VALUES
    (now(), 'SISTEMA', 'PERFORMANCE_GUARD_V1_1_PRECHECK', 'email_flow_null_leak',
     'Quarantine active email-flow executions without flujo_id; no delete.',
     'aos_email_flujo_ejecuciones', 'ASCENDA_MIGRATION',
     jsonb_build_object('invalid_active_before', v_invalid_active, 'valid_active_before', v_valid_active));
END $$;

UPDATE public.aos_email_flujo_ejecuciones
SET estado = 'cancelado',
    updated_at = now()
WHERE estado = 'activo'
  AND flujo_id IS NULL;

-- Future active executions must always point to a flow. Historical cancelled rows
-- with null flujo_id remain preserved for audit/history.
ALTER TABLE public.aos_email_flujo_ejecuciones
  DROP CONSTRAINT IF EXISTS aos_email_flujo_ejecuciones_active_requires_flow;

ALTER TABLE public.aos_email_flujo_ejecuciones
  ADD CONSTRAINT aos_email_flujo_ejecuciones_active_requires_flow
  CHECK (estado <> 'activo' OR flujo_id IS NOT NULL)
  NOT VALID;

ALTER TABLE public.aos_email_flujo_ejecuciones
  VALIDATE CONSTRAINT aos_email_flujo_ejecuciones_active_requires_flow;

CREATE INDEX IF NOT EXISTS idx_aos_email_flujo_ejecuciones_due_active
  ON public.aos_email_flujo_ejecuciones (proximo_envio)
  WHERE estado = 'activo' AND flujo_id IS NOT NULL;

DO $$
DECLARE
  v_invalid_active bigint;
  v_valid_active bigint;
BEGIN
  SELECT count(*) FILTER (WHERE flujo_id IS NULL),
         count(*) FILTER (WHERE flujo_id IS NOT NULL)
    INTO v_invalid_active, v_valid_active
  FROM public.aos_email_flujo_ejecuciones
  WHERE estado = 'activo';

  IF v_invalid_active <> 0 THEN
    RAISE EXCEPTION 'Performance Guard v1.1 expected 0 active null-flow executions, got %', v_invalid_active;
  END IF;

  INSERT INTO public.aos_log_auditoria
    (timestamp_reg, asesor, accion, referencia, detalle, tabla, usuario, metadata)
  VALUES
    (now(), 'SISTEMA', 'PERFORMANCE_GUARD_V1_1_POSTCHECK', 'email_flow_null_leak',
     'Invalid active null-flow executions quarantined; validity constraint installed.',
     'aos_email_flujo_ejecuciones', 'ASCENDA_MIGRATION',
     jsonb_build_object('invalid_active_after', v_invalid_active, 'valid_active_after', v_valid_active));
END $$;
