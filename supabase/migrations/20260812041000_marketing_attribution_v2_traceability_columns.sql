-- ASCENDA OS — Marketing Attribution V2 traceability foundation
-- Backward-compatible: all columns are nullable and no current flow is replaced.

alter table public.aos_llamadas
  add column if not exists lead_id_origen bigint;

alter table public.aos_agenda_citas
  add column if not exists lead_id_origen bigint,
  add column if not exists llamada_id_origen bigint;

alter table public.aos_leads_en_curso
  add column if not exists lead_id_origen bigint;

alter table public.aos_seguimientos
  add column if not exists lead_id_origen bigint;

create index if not exists idx_aos_llamadas_lead_id_origen
  on public.aos_llamadas (lead_id_origen)
  where lead_id_origen is not null;

create index if not exists idx_aos_agenda_lead_id_origen
  on public.aos_agenda_citas (lead_id_origen)
  where lead_id_origen is not null;

create index if not exists idx_aos_agenda_llamada_id_origen
  on public.aos_agenda_citas (llamada_id_origen)
  where llamada_id_origen is not null;

create index if not exists idx_aos_leads_en_curso_lead_id_origen
  on public.aos_leads_en_curso (lead_id_origen)
  where lead_id_origen is not null;

create index if not exists idx_aos_seguimientos_lead_id_origen
  on public.aos_seguimientos (lead_id_origen)
  where lead_id_origen is not null;
