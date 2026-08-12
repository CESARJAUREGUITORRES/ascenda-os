-- ASCENDA OS — Marketing annual lookup performance
-- Applied in production during 2026-08-12 timeout incident.
-- Read-path optimization only; no business-data mutation.

create index if not exists idx_aos_leads_numero_fecha
  on public.aos_leads (numero_limpio, fecha);

create index if not exists idx_aos_llamadas_numero_fecha
  on public.aos_llamadas (numero_limpio, fecha);

create index if not exists idx_aos_agenda_numero_fecha
  on public.aos_agenda_citas (numero_limpio, fecha_cita);

create index if not exists idx_aos_ventas_numero_fecha
  on public.aos_ventas (numero_limpio, fecha);

analyze public.aos_leads;
analyze public.aos_llamadas;
analyze public.aos_agenda_citas;
analyze public.aos_ventas;
