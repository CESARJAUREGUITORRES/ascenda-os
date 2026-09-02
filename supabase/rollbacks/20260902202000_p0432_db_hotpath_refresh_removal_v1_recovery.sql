-- ASCENDA OS · P0 #432 · DB hot-path refresh removal V1 · RECOVERY
-- Exact rollback: restore the legacy AFTER INSERT / FOR EACH STATEMENT trigger.
-- The trigger function and materialized view are expected to remain present.

do $$
begin
  if to_regclass('public.aos_llamadas_ultimo') is null then
    raise exception 'P0432_EXPECTED_MATVIEW_MISSING';
  end if;
  if to_regprocedure('public.fn_refresh_llammap()') is null then
    raise exception 'P0432_EXPECTED_TRIGGER_FUNCTION_MISSING';
  end if;
end
$$;

drop trigger if exists trg_refresh_llammap on public.aos_llamadas;
create trigger trg_refresh_llammap
after insert on public.aos_llamadas
for each statement
execute function public.fn_refresh_llammap();
