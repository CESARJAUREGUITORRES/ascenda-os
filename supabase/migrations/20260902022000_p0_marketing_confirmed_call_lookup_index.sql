-- ASCENDA OS · Marketing P0.3
-- Read-path only: accelerate Call Center appointment -> confirmed call lookup used by
-- aos_marketing_call_cita_match_v2 / attribution / intent analytics.
-- No business-rule, attribution-formula, timeout, or data mutation change.

create index if not exists idx_aos_llamadas_mkt_confirmed_phone_advisor_v1
  on public.aos_llamadas (
    numero_limpio,
    (upper(coalesce(asesor,'')))
  )
  include (id, lead_id_origen, fecha, hora_llamada, created_at, ult_ts, ts_log)
  where upper(coalesce(estado,''))='CITA CONFIRMADA';

analyze public.aos_llamadas;
