-- Rollback for Loop 6 V2.3 automatic queue confirmation.
-- Does not touch V2.2 core functions or business data.

drop function if exists public.aos_callcenter_confirm_queue_appointment_v1(text,text,jsonb);
drop function if exists public.aos_callcenter_confirm_queue_core_v1(uuid,text,jsonb,text);
