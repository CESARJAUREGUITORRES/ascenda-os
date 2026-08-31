begin;

drop function if exists public.aos_booking_availability_v2(uuid,date,text,text);
drop function if exists public.aos_booking_capability_for_service_v1(uuid);
drop function if exists public.aos_booking_profile_key_v1(text);
drop function if exists public.aos_booking_norm_v1(text);

-- aos_slots_disponibles is intentionally not dropped by rollback because it predates this migration.
-- Restore from the prior certified migration/backup when an operational rollback is required.

commit;
