-- ASCENDA OS · rollback · P0 #432 call-ledger refresh decoupling V1
-- Restores only the legacy statement-level refresh trigger.

DO $p0432_recovery_guard$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_trigger t
    JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname='aos_llamadas'
      AND t.tgname='trg_refresh_llammap' AND NOT t.tgisinternal
  ) THEN
    RAISE EXCEPTION 'P0432_REFRESH_TRIGGER_ALREADY_PRESENT';
  END IF;

  IF pg_catalog.to_regprocedure('public.fn_refresh_llammap()') IS NULL THEN
    RAISE EXCEPTION 'P0432_REFRESH_FUNCTION_MISSING';
  END IF;
END
$p0432_recovery_guard$;

CREATE TRIGGER trg_refresh_llammap
AFTER INSERT ON public.aos_llamadas
FOR EACH STATEMENT
EXECUTE FUNCTION public.fn_refresh_llammap();

COMMENT ON FUNCTION public.fn_refresh_llammap() IS
  'Legacy trigger implementation: refreshes public.aos_llamadas_ultimo concurrently after aos_llamadas INSERT statements.';

COMMENT ON FUNCTION public.aos_refresh_llammap() IS
  'Explicit compatibility refresh for public.aos_llamadas_ultimo.';
