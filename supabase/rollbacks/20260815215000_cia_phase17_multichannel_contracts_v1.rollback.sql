-- CIA V3 F17 multichannel contracts v1 rollback
-- Removes only F17 additive objects. Existing WA-1..WA-4 and F16 objects remain untouched.

drop function if exists public.aos_cia_f18_readiness_v1();
drop function if exists public.aos_cia_channel_set_release_gate_v1(text,boolean,text);
drop function if exists public.aos_cia_channel_record_event_v1(jsonb);
drop function if exists public.aos_cia_channel_prepare_send_v1(jsonb);
drop view if exists public.aos_cia_whatsapp_bridge_v1;
drop table if exists public.aos_cia_channel_send_events_v1;
drop table if exists public.aos_cia_channel_inbound_facts_v1;
drop table if exists public.aos_cia_channel_send_requests_v1;
drop table if exists public.aos_cia_channel_recipient_controls_v1;
drop table if exists public.aos_cia_channel_release_state;