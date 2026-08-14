-- ASCENDA CIA Phase 7 — bind DB-owned lifecycle event emission.
-- Applied live as schema_migrations version 20260813220123.

drop trigger if exists trg_aos_cia_activation_state_event_emit_v2 on public.aos_audiencia_activacion_estado;
create trigger trg_aos_cia_activation_state_event_emit_v2
after insert or update on public.aos_audiencia_activacion_estado
for each row execute function public.aos_cia_activation_state_event_emit_v2();