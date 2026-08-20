-- REV-F6.6 performance hotfix recovery: restore original full snapshot and remove cache/dirty markers.
begin;

drop trigger if exists trg_f66_dirty_f5_batches on public.aos_f5_source_batches_v1;
drop trigger if exists trg_f66_dirty_f5_source_rows on public.aos_f5_patient_source_rows_v1;
drop trigger if exists trg_f66_dirty_f5_members on public.aos_f5_identity_cluster_members_v1;
drop trigger if exists trg_f66_dirty_f5_classification on public.aos_f5_canonical_classification_v1;
drop trigger if exists trg_f66_dirty_f5_apply on public.aos_f5_canonical_apply_events_v1;
drop trigger if exists trg_f66_dirty_f5_preview on public.aos_f5_enrichment_preview_v1;
drop trigger if exists trg_f66_dirty_patients on public.aos_pacientes;
drop trigger if exists trg_f66_dirty_sales on public.aos_ventas;
drop trigger if exists trg_f66_dirty_product_fact on public.aos_product_sale_fact_v1;
drop trigger if exists trg_f66_dirty_product_identity on public.aos_product_identity_v1;
drop trigger if exists trg_f66_dirty_f4 on public.aos_cartera_reconciliacion;
drop trigger if exists trg_f66_dirty_pagos on public.aos_pagos;
drop trigger if exists trg_f66_dirty_cotizaciones on public.aos_cotizaciones;
drop trigger if exists trg_f66_dirty_dashboard_cache on public.aos_rev_si_dashboard_cache_v1;
drop trigger if exists trg_f66_dirty_historical_manifest on public.aos_rev_historical_source_manifest_v1;
drop trigger if exists trg_f66_dirty_agenda on public.aos_agenda_citas;

drop function if exists public.aos_sentinel_rev_f6_6_snapshot_v1();
drop function if exists public.aos_sentinel_rev_f6_6_refresh_cache_v1();
drop function if exists public.aos_sentinel_rev_f6_6_mark_dirty_v1();
drop table if exists public.aos_sentinel_rev_f6_6_sensor_cache_v1;

do $$
begin
  if to_regprocedure('public.aos_sentinel_rev_f6_6_snapshot_full_v1()') is not null then
    alter function public.aos_sentinel_rev_f6_6_snapshot_full_v1() rename to aos_sentinel_rev_f6_6_snapshot_v1;
  end if;
end $$;

commit;
