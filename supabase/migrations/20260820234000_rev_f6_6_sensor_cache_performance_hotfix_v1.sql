-- REV-F6.6 performance hotfix: bounded zero-PII sensor cache with fail-closed dirty domains.
-- Observation-only. Business tables receive statement-level dirty markers only; no business-row mutation is performed here.

begin;

do $$
begin
  if to_regprocedure('public.aos_sentinel_rev_f6_6_snapshot_full_v1()') is null then
    if to_regprocedure('public.aos_sentinel_rev_f6_6_snapshot_v1()') is null then
      raise exception 'F6_6_BASE_SNAPSHOT_REQUIRED';
    end if;
    alter function public.aos_sentinel_rev_f6_6_snapshot_v1() rename to aos_sentinel_rev_f6_6_snapshot_full_v1;
  end if;
end $$;

create table if not exists public.aos_sentinel_rev_f6_6_sensor_cache_v1(
  singleton boolean primary key default true check (singleton),
  snapshot jsonb,
  dirty_domains text[] not null default '{}'::text[],
  refreshed_at timestamptz,
  refresh_duration_ms numeric,
  constraint aos_sentinel_rev_f6_6_sensor_cache_singleton check (singleton = true)
);

revoke all on table public.aos_sentinel_rev_f6_6_sensor_cache_v1 from public,anon,authenticated;

create or replace function public.aos_sentinel_rev_f6_6_mark_dirty_v1()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_domain text:=pg_catalog.upper(coalesce(tg_argv[0],'UNKNOWN'));
begin
  insert into public.aos_sentinel_rev_f6_6_sensor_cache_v1(singleton,dirty_domains)
  values(true,array[v_domain]::text[])
  on conflict(singleton) do update
  set dirty_domains=case
    when v_domain=any(public.aos_sentinel_rev_f6_6_sensor_cache_v1.dirty_domains)
      then public.aos_sentinel_rev_f6_6_sensor_cache_v1.dirty_domains
    else pg_catalog.array_append(public.aos_sentinel_rev_f6_6_sensor_cache_v1.dirty_domains,v_domain)
  end;
  return null;
end;
$$;

revoke all on function public.aos_sentinel_rev_f6_6_mark_dirty_v1() from public,anon,authenticated;
grant execute on function public.aos_sentinel_rev_f6_6_mark_dirty_v1() to service_role;

-- Statement-level markers keep the health path O(1) while preserving fail-closed semantics.
drop trigger if exists trg_f66_dirty_f5_batches on public.aos_f5_source_batches_v1;
create trigger trg_f66_dirty_f5_batches after insert or update or delete or truncate on public.aos_f5_source_batches_v1 for each statement execute function public.aos_sentinel_rev_f6_6_mark_dirty_v1('F5_SOURCE');
drop trigger if exists trg_f66_dirty_f5_source_rows on public.aos_f5_patient_source_rows_v1;
create trigger trg_f66_dirty_f5_source_rows after insert or update or delete or truncate on public.aos_f5_patient_source_rows_v1 for each statement execute function public.aos_sentinel_rev_f6_6_mark_dirty_v1('F5_SOURCE');
drop trigger if exists trg_f66_dirty_f5_members on public.aos_f5_identity_cluster_members_v1;
create trigger trg_f66_dirty_f5_members after insert or update or delete or truncate on public.aos_f5_identity_cluster_members_v1 for each statement execute function public.aos_sentinel_rev_f6_6_mark_dirty_v1('F5_MEMBERSHIP');
drop trigger if exists trg_f66_dirty_f5_classification on public.aos_f5_canonical_classification_v1;
create trigger trg_f66_dirty_f5_classification after insert or update or delete or truncate on public.aos_f5_canonical_classification_v1 for each statement execute function public.aos_sentinel_rev_f6_6_mark_dirty_v1('F5_IDENTITY');
drop trigger if exists trg_f66_dirty_f5_apply on public.aos_f5_canonical_apply_events_v1;
create trigger trg_f66_dirty_f5_apply after insert or update or delete or truncate on public.aos_f5_canonical_apply_events_v1 for each statement execute function public.aos_sentinel_rev_f6_6_mark_dirty_v1('F5_APPLY');
drop trigger if exists trg_f66_dirty_f5_preview on public.aos_f5_enrichment_preview_v1;
create trigger trg_f66_dirty_f5_preview after insert or update or delete or truncate on public.aos_f5_enrichment_preview_v1 for each statement execute function public.aos_sentinel_rev_f6_6_mark_dirty_v1('F5_APPLY');
drop trigger if exists trg_f66_dirty_patients on public.aos_pacientes;
create trigger trg_f66_dirty_patients after insert or update or delete or truncate on public.aos_pacientes for each statement execute function public.aos_sentinel_rev_f6_6_mark_dirty_v1('IDENTITY_LIFECYCLE');
drop trigger if exists trg_f66_dirty_sales on public.aos_ventas;
create trigger trg_f66_dirty_sales after insert or update or delete or truncate on public.aos_ventas for each statement execute function public.aos_sentinel_rev_f6_6_mark_dirty_v1('SALES');
drop trigger if exists trg_f66_dirty_product_fact on public.aos_product_sale_fact_v1;
create trigger trg_f66_dirty_product_fact after insert or update or delete or truncate on public.aos_product_sale_fact_v1 for each statement execute function public.aos_sentinel_rev_f6_6_mark_dirty_v1('PRODUCT');
drop trigger if exists trg_f66_dirty_product_identity on public.aos_product_identity_v1;
create trigger trg_f66_dirty_product_identity after insert or update or delete or truncate on public.aos_product_identity_v1 for each statement execute function public.aos_sentinel_rev_f6_6_mark_dirty_v1('PRODUCT');
drop trigger if exists trg_f66_dirty_f4 on public.aos_cartera_reconciliacion;
create trigger trg_f66_dirty_f4 after insert or update or delete or truncate on public.aos_cartera_reconciliacion for each statement execute function public.aos_sentinel_rev_f6_6_mark_dirty_v1('FINANCE');
drop trigger if exists trg_f66_dirty_pagos on public.aos_pagos;
create trigger trg_f66_dirty_pagos after insert or update or delete or truncate on public.aos_pagos for each statement execute function public.aos_sentinel_rev_f6_6_mark_dirty_v1('FINANCE');
drop trigger if exists trg_f66_dirty_cotizaciones on public.aos_cotizaciones;
create trigger trg_f66_dirty_cotizaciones after insert or update or delete or truncate on public.aos_cotizaciones for each statement execute function public.aos_sentinel_rev_f6_6_mark_dirty_v1('FINANCE');
drop trigger if exists trg_f66_dirty_dashboard_cache on public.aos_rev_si_dashboard_cache_v1;
create trigger trg_f66_dirty_dashboard_cache after insert or update or delete or truncate on public.aos_rev_si_dashboard_cache_v1 for each statement execute function public.aos_sentinel_rev_f6_6_mark_dirty_v1('READMODEL');
drop trigger if exists trg_f66_dirty_historical_manifest on public.aos_rev_historical_source_manifest_v1;
create trigger trg_f66_dirty_historical_manifest after insert or update or delete or truncate on public.aos_rev_historical_source_manifest_v1 for each statement execute function public.aos_sentinel_rev_f6_6_mark_dirty_v1('HISTORICAL');
drop trigger if exists trg_f66_dirty_agenda on public.aos_agenda_citas;
create trigger trg_f66_dirty_agenda after insert or update or delete or truncate on public.aos_agenda_citas for each statement execute function public.aos_sentinel_rev_f6_6_mark_dirty_v1('LIFECYCLE');

create or replace function public.aos_sentinel_rev_f6_6_refresh_cache_v1()
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_t0 timestamptz:=pg_catalog.clock_timestamp();
  v_snapshot jsonb;
  v_ms numeric;
begin
  v_snapshot:=public.aos_sentinel_rev_f6_6_snapshot_full_v1();
  v_ms:=extract(epoch from (pg_catalog.clock_timestamp()-v_t0))*1000;
  insert into public.aos_sentinel_rev_f6_6_sensor_cache_v1(singleton,snapshot,dirty_domains,refreshed_at,refresh_duration_ms)
  values(true,v_snapshot,'{}'::text[],pg_catalog.clock_timestamp(),v_ms)
  on conflict(singleton) do update
  set snapshot=excluded.snapshot,
      dirty_domains='{}'::text[],
      refreshed_at=excluded.refreshed_at,
      refresh_duration_ms=excluded.refresh_duration_ms;
  return pg_catalog.jsonb_build_object('ok',true,'cache_state','CURRENT','refresh_duration_ms',pg_catalog.round(v_ms,3),'refreshed_at',pg_catalog.clock_timestamp());
end;
$$;

revoke all on function public.aos_sentinel_rev_f6_6_refresh_cache_v1() from public,anon,authenticated;
grant execute on function public.aos_sentinel_rev_f6_6_refresh_cache_v1() to service_role;
revoke all on function public.aos_sentinel_rev_f6_6_snapshot_full_v1() from public,anon,authenticated;
grant execute on function public.aos_sentinel_rev_f6_6_snapshot_full_v1() to service_role;

-- Prime the private cache once. This slow refresh is explicitly outside the health hot path.
select public.aos_sentinel_rev_f6_6_refresh_cache_v1();

create or replace function public.aos_sentinel_rev_f6_6_snapshot_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_snapshot jsonb;
  v_dirty text[];
  v_refreshed_at timestamptz;
begin
  select c.snapshot,c.dirty_domains,c.refreshed_at
  into v_snapshot,v_dirty,v_refreshed_at
  from public.aos_sentinel_rev_f6_6_sensor_cache_v1 c
  where c.singleton=true;

  if v_snapshot is null then
    return pg_catalog.jsonb_build_object(
      'contract','REV-F6.6_SAFE_AGGREGATE_SNAPSHOT_V1',
      'captured_at',pg_catalog.clock_timestamp(),
      'cache_state','EMPTY',
      'cache_dirty_domains','[]'::jsonb,
      'limitations',pg_catalog.jsonb_build_array('SENSOR_CACHE_EMPTY_FAIL_CLOSED')
    );
  end if;

  v_snapshot:=pg_catalog.jsonb_set(v_snapshot,'{captured_at}',pg_catalog.to_jsonb(pg_catalog.clock_timestamp()),true)
    || pg_catalog.jsonb_build_object(
      'cache_state',case when coalesce(pg_catalog.array_length(v_dirty,1),0)=0 then 'CURRENT' else 'STALE' end,
      'cache_dirty_domains',pg_catalog.to_jsonb(coalesce(v_dirty,'{}'::text[])),
      'cache_refreshed_at',v_refreshed_at
    );

  if 'F5_SOURCE'=any(coalesce(v_dirty,'{}'::text[])) then
    v_snapshot:=v_snapshot-'f5_source'-'f5_membership'-'identity_bridge'-'patient360'-'f6_coverage';
  end if;
  if 'F5_MEMBERSHIP'=any(coalesce(v_dirty,'{}'::text[])) then
    v_snapshot:=v_snapshot-'f5_membership'-'identity_bridge'-'patient360'-'f6_coverage';
  end if;
  if 'F5_IDENTITY'=any(coalesce(v_dirty,'{}'::text[])) then
    v_snapshot:=v_snapshot-'identity_bridge'-'patient360'-'f6_coverage';
  end if;
  if 'IDENTITY_LIFECYCLE'=any(coalesce(v_dirty,'{}'::text[])) then
    v_snapshot:=v_snapshot-'identity_bridge'-'patient360'-'f6_coverage';
  end if;
  if 'F5_APPLY'=any(coalesce(v_dirty,'{}'::text[])) then
    v_snapshot:=v_snapshot-'f5_apply';
  end if;
  if 'SALES'=any(coalesce(v_dirty,'{}'::text[])) then
    v_snapshot:=v_snapshot-'product_sale'-'reconciliation'-'f6_readmodel'-'f6_coverage';
  end if;
  if 'PRODUCT'=any(coalesce(v_dirty,'{}'::text[])) then
    v_snapshot:=v_snapshot-'product_sale'-'f6_readmodel'-'f6_coverage';
  end if;
  if 'FINANCE'=any(coalesce(v_dirty,'{}'::text[])) then
    v_snapshot:=v_snapshot-'reconciliation'-'f6_readmodel'-'f6_coverage';
  end if;
  if 'READMODEL'=any(coalesce(v_dirty,'{}'::text[])) then
    v_snapshot:=v_snapshot-'f6_readmodel';
  end if;
  if 'HISTORICAL'=any(coalesce(v_dirty,'{}'::text[])) then
    v_snapshot:=v_snapshot-'f6_coverage';
  end if;
  if 'LIFECYCLE'=any(coalesce(v_dirty,'{}'::text[])) then
    v_snapshot:=v_snapshot-'f6_coverage';
  end if;

  return v_snapshot;
end;
$$;

revoke all on function public.aos_sentinel_rev_f6_6_snapshot_v1() from public,anon,authenticated;
grant execute on function public.aos_sentinel_rev_f6_6_snapshot_v1() to service_role;

comment on table public.aos_sentinel_rev_f6_6_sensor_cache_v1 is 'REV-F6.6 private aggregate sensor cache. No PII/PHI; dirty domains fail closed until service-role refresh.';
comment on function public.aos_sentinel_rev_f6_6_snapshot_full_v1() is 'REV-F6.6 slow full aggregate snapshot retained only for controlled cache refresh and certification.';
comment on function public.aos_sentinel_rev_f6_6_refresh_cache_v1() is 'REV-F6.6 controlled slow refresh. Health/evaluator hot path never calls this function.';
comment on function public.aos_sentinel_rev_f6_6_snapshot_v1() is 'REV-F6.6 bounded cached snapshot. Dirty source domains remove dependent telemetry so evaluator returns UNKNOWN rather than false OK.';

commit;
