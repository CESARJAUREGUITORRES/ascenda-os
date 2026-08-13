-- ASCENDA OS — Performance Guard
-- Fixes aos_agente_logs trigger failures caused by casting numeric costo_acumulado to text.
-- Backward-compatible function replacement; no table/data rewrite.

CREATE OR REPLACE FUNCTION public.fn_actualizar_agente_desde_log()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  UPDATE public.aos_agentes SET
    ultima_actividad = NEW.created_at,
    total_ejecuciones = total_ejecuciones + 1,
    total_tokens_usados = COALESCE(total_tokens_usados, 0)
      + COALESCE(NEW.tokens_input, 0)
      + COALESCE(NEW.tokens_output, 0),
    costo_acumulado = COALESCE(costo_acumulado, 0) + COALESCE(NEW.costo_usd, 0),
    estado = CASE WHEN NEW.exitoso THEN 'idle' ELSE 'error' END,
    eficiencia = CASE
      WHEN NEW.exitoso THEN LEAST(100, COALESCE(eficiencia, 100) + 1)
      ELSE GREATEST(0, COALESCE(eficiencia, 100) - 5)
    END
  WHERE id = NEW.agente_id;

  RETURN NEW;
END
$function$;
