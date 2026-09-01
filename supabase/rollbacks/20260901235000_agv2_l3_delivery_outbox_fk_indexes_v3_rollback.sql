-- Rollback AGV2 L3-H1 — remove only the two FK covering indexes.
-- Leaves the delivery outbox schema and data untouched.

drop index if exists public.idx_aos_agenda_delivery_outbox_v3_agenda_event_id;
drop index if exists public.idx_aos_agenda_delivery_outbox_v3_operation_id;
