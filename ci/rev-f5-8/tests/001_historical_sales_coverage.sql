\set ON_ERROR_STOP on

-- REV-F5.8 current coverage contract.
-- This test intentionally fails if a real 2024/2025 transactional source appears,
-- forcing rebaseline instead of silently treating new history as absent/zero.
do $$
begin
  if exists(select 1 from public.aos_ventas where fecha between date '2024-01-01' and date '2025-12-31') then
    raise exception 'F5_8_REBASELINE_REQUIRED_CANONICAL_HISTORICAL_SALES_PRESENT';
  end if;

  if exists(select 1 from public.aos_recon_meses where anio in (2024,2025)) then
    raise exception 'F5_8_REBASELINE_REQUIRED_RECON_HISTORY_PRESENT';
  end if;

  if exists(select 1 from public.aos_ventas_backup_enero_20260812 where extract(year from fecha) in (2024,2025))
     or exists(select 1 from public.aos_ventas_backup_julio_20260808 where extract(year from fecha) in (2024,2025)) then
    raise exception 'F5_8_REBASELINE_REQUIRED_BACKUP_HISTORY_PRESENT';
  end if;

  if exists(select 1 from public.aos_pagos where extract(year from fecha_pago) in (2024,2025))
     or exists(select 1 from public.aos_cotizaciones where extract(year from fecha_creacion) in (2024,2025))
     or exists(select 1 from public.aos_caja_sesiones where extract(year from fecha) in (2024,2025))
     or exists(select 1 from public.aos_recon_visitas where extract(year from fecha) in (2024,2025)) then
    raise exception 'F5_8_REBASELINE_REQUIRED_OTHER_TRANSACTION_HISTORY_PRESENT';
  end if;

  if (select count(*) from public.aos_f5_source_batches_v1 where source_year in (2024,2025)) <> 4 then
    raise exception 'F5_8_PATIENT_HISTORY_BATCH_COUNT_DRIFT';
  end if;

  if (select coalesce(sum(source_rows),0) from public.aos_f5_source_batches_v1 where source_year in (2024,2025)) <> 13501 then
    raise exception 'F5_8_PATIENT_HISTORY_ROW_COUNT_DRIFT';
  end if;

  if exists(
    select 1
    from public.aos_f5_patient_source_rows_v1 r
    cross join lateral jsonb_object_keys(r.raw_payload) k(key)
    where k.key = any(array['venta_id','fecha_venta','monto','monto_venta','moneda','pago','estado_pago','tratamiento','producto','servicio','asesor']::text[])
  ) then
    raise exception 'F5_8_PATIENT_EXPORT_TRANSACTION_KEY_DRIFT';
  end if;
end
$$;
