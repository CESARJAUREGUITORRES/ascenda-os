-- Rollback AGV2 legacy-treatment rebook bridge.
drop function if exists public.aos_agenda_rebook_bridge_v1(text,text,text,jsonb);
drop function if exists public.aos_agenda_rebook_legacy_safe_v1(text,text,text,jsonb);
