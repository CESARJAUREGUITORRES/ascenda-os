-- ASCENDA OS · P0 #432 · DB hot-path refresh removal V1
-- Scope: remove ONLY the legacy per-INSERT materialized-view refresh trigger.
-- Preserve aos_llamadas_ultimo plus explicit refresh functions/RPCs.
-- No business-rule, write-authority, timeout, or data mutation changes.

do $$
begin
  if to_regclass('public.aos_llamadas_ultimo') is null then
    raise exception 'P0432_EXPECTED_MATVIEW_MISSING';
  end if;
  if to_regprocedure('public.fn_refresh_llammap()') is null then
    raise exception 'P0432_EXPECTED_TRIGGER_FUNCTION_MISSING';
  end if;
  if to_regprocedure('public.aos_refresh_llammap()') is null then
    raise exception 'P0432_EXPECTED_EXPLICIT_REFRESH_RPC_MISSING';
  end if;
end
$$;

-- This trigger used to execute REFRESH MATERIALIZED VIEW CONCURRENTLY
-- public.aos_llamadas_ultimo after every INSERT statement on aos_llamadas.
-- That full-view rebuild is intentionally removed from the synchronous
-- Call Center write path; explicit legacy refresh mechanisms remain available.
drop trigger if exists trg_refresh_llammap on public.aos_llamadas;
