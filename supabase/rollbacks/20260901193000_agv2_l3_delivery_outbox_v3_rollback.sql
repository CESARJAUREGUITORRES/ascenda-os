-- ASCENDA OS · WA-AUTO L3 rollback
-- Removes only L3 projection/outbox objects. Does not mutate Agenda appointments or V2 booking/event ledgers.

begin;

drop trigger if exists trg_aos_agenda_delivery_event_v3 on public.aos_agenda_events_v2;

drop function if exists public.aos_agenda_delivery_audit_v3();
drop function if exists public.aos_agenda_delivery_materialize_reminders_v3(timestamptz,integer);
drop function if exists public.aos_agenda_delivery_reconcile_v3(integer);
drop function if exists public.aos_agenda_delivery_event_trigger_v3();
drop function if exists public.aos_agenda_delivery_enqueue_event_v3(uuid);
drop function if exists public.aos_agenda_delivery_insert_intent_v3(uuid,uuid,text,text,text,text,text,text,text,jsonb);

drop table if exists public.aos_agenda_delivery_errors_v3;
drop table if exists public.aos_agenda_delivery_outbox_v3;
drop table if exists public.aos_agenda_delivery_template_registry_v3;

commit;
