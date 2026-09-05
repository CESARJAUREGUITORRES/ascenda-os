-- ASCENDA OS · P0 #432 · Call-ledger materialized-view refresh decoupling V1
-- Scope: remove only the legacy AFTER INSERT statement trigger that refreshes
-- aos_llamadas_ultimo synchronously inside every aos_llamadas INSERT.
--
-- Preserved intentionally:
--   * public.aos_llamadas_ultimo materialized view + unique index
--   * public.fn_refresh_llammap()
--   * public.aos_refresh_llammap() explicit refresh RPC for legacy sync jobs
--   * every Loop6 governed-write / commercial-policy / audit / cleanup trigger
--
-- Reliability doctrine: do not hide pressure by increasing statement_timeout.

DO $p0432_guard$
DECLARE
  v_trigger_def text;
BEGIN
  SELECT pg_catalog.pg_get_triggerdef(t.oid)
    INTO v_trigger_def
  FROM pg_catalog.pg_trigger t
  JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
  JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public'
    AND c.relname='aos_llamadas'
    AND t.tgname='trg_refresh_llammap'
    AND NOT t.tgisinternal;

  IF v_trigger_def IS NULL THEN
    RAISE EXCEPTION 'P0432_EXPECTED_REFRESH_TRIGGER_MISSING';
  END IF;

  IF v_trigger_def NOT ILIKE '%AFTER INSERT ON public.aos_llamadas FOR EACH STATEMENT%fn_refresh_llammap%' THEN
    RAISE EXCEPTION 'P0432_REFRESH_TRIGGER_DRIFT:%',v_trigger_def;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_trigger t
    JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname='aos_llamadas'
      AND t.tgname='trg_000_aos_loop6_governed_call_v22' AND NOT t.tgisinternal
  ) THEN
    RAISE EXCEPTION 'P0432_GOVERNED_WRITE_GUARD_MISSING';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_trigger t
    JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname='aos_llamadas'
      AND t.tgname='trg_aos_hotfix_call_guard_v1' AND NOT t.tgisinternal
  ) THEN
    RAISE EXCEPTION 'P0432_COMMERCIAL_POLICY_GUARD_MISSING';
  END IF;
END
$p0432_guard$;

DROP TRIGGER trg_refresh_llammap ON public.aos_llamadas;

COMMENT ON FUNCTION public.fn_refresh_llammap() IS
  'Legacy explicit materialized-view refresh implementation. P0 #432 removed its per-INSERT trigger; retained for explicit refresh compatibility.';

COMMENT ON FUNCTION public.aos_refresh_llammap() IS
  'Explicit compatibility refresh for aos_llamadas_ultimo. P0 #432 decoupled this work from the aos_llamadas INSERT hot path.';
