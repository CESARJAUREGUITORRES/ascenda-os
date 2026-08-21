-- REV-F6.6 performance hotfix recovery: restore original full snapshot and remove cache/dirty markers.
begin;

do $$
declare
  r record;
begin
  for r in
    select * from (values
      ('public.aos_f5_source_batches_v1','trg_f66_dirty_f5_batches'),
      ('public.aos_f5_patient_source_rows_v1','trg_f66_dirty_f5_source_rows'),
      ('public.aos_f5_identity_cluster_members_v1','trg_f66_dirty_f5_members'),
      ('public.aos_f5_canonical_classification_v1','trg_f66_dirty_f5_classification'),
      ('public.aos_f5_canonical_apply_events_v1','trg_f66_dirty_f5_apply'),
      ('public.aos_f5_enrichment_preview_v1','trg_f66_dirty_f5_preview'),
      ('public.aos_pacientes','trg_f66_dirty_patients'),
      ('public.aos_ventas','trg_f66_dirty_sales'),
      ('public.aos_product_sale_fact_v1','trg_f66_dirty_product_fact'),
      ('public.aos_product_identity_v1','trg_f66_dirty_product_identity'),
      ('public.aos_cartera_reconciliacion','trg_f66_dirty_f4'),
      ('public.aos_pagos','trg_f66_dirty_pagos'),
      ('public.aos_cotizaciones','trg_f66_dirty_cotizaciones'),
      ('public.aos_rev_si_dashboard_cache_v1','trg_f66_dirty_dashboard_cache'),
      ('public.aos_rev_historical_source_manifest_v1','trg_f66_dirty_historical_manifest'),
      ('public.aos_agenda_citas','trg_f66_dirty_agenda')
    ) as x(rel_name,trg_name)
  loop
    if to_regclass(r.rel_name) is not null then
      execute pg_catalog.format('drop trigger if exists %I on %s',r.trg_name,r.rel_name);
    end if;
  end loop;
end $$;

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
