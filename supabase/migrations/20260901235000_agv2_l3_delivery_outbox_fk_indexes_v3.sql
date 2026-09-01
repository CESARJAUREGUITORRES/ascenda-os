-- AGV2 L3-H1 — covering indexes for delivery outbox foreign keys.
-- Performance-only hardening. No authority, state, data, RLS, trigger, or dispatch changes.

create index if not exists idx_aos_agenda_delivery_outbox_v3_agenda_event_id
  on public.aos_agenda_delivery_outbox_v3 (agenda_event_id);

create index if not exists idx_aos_agenda_delivery_outbox_v3_operation_id
  on public.aos_agenda_delivery_outbox_v3 (operation_id);
