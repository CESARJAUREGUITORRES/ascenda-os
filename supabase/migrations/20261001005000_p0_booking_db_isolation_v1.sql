-- ASCENDA OS · P0 Booking DB Isolation V1
-- Goal: keep commercial/booking writes independent from CIA aggregate recounts.
-- The previous statement trigger called aos_cia_catalog_recount_if_dirty_v1(0)
-- synchronously after every write on hot commercial tables. Under DB pressure this
-- made agenda/call/lead/sale writes wait behind an audience-wide aggregate.
--
-- This hotfix preserves row-level contact freshness and only marks the preset
-- catalog dirty at statement end. Aggregate recount remains available through
-- aos_cia_catalog_recount_if_dirty_v1() / aos_cia_catalog_recount_runtime_v1(),
-- but it is no longer in the booking transaction critical path.

begin;

create or replace function public.aos_cia_runtime_recount_statement_v1()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_now timestamptz := statement_timestamp();
begin
  insert into public.aos_cia_runtime_freshness_v1(
    singleton_id,
    catalog_dirty,
    dirty_since,
    last_mark_at,
    pending_marks,
    last_reason,
    updated_at
  )
  values(
    1,
    true,
    v_now,
    v_now,
    1,
    left('STATEMENT:' || coalesce(tg_table_name,'UNKNOWN'),120),
    v_now
  )
  on conflict(singleton_id) do update set
    catalog_dirty = true,
    dirty_since = coalesce(public.aos_cia_runtime_freshness_v1.dirty_since, excluded.dirty_since),
    last_mark_at = excluded.last_mark_at,
    pending_marks = public.aos_cia_runtime_freshness_v1.pending_marks + 1,
    last_reason = excluded.last_reason,
    updated_at = excluded.updated_at;

  return null;
end
$function$;

revoke all on function public.aos_cia_runtime_recount_statement_v1() from public,anon,authenticated;

-- Explicit deferred entry point. It is intentionally NOT called by source-table
-- triggers. Operators/read paths may coalesce refreshes through this function.
create or replace function public.aos_cia_catalog_refresh_deferred_v1(
  p_min_interval_seconds integer default 60
)
returns jsonb
language sql
security definer
set search_path to ''
as $function$
  select public.aos_cia_catalog_recount_if_dirty_v1(
    greatest(15, least(3600, coalesce(p_min_interval_seconds,60)))
  );
$function$;

revoke all on function public.aos_cia_catalog_refresh_deferred_v1(integer) from public,anon,authenticated;

commit;
