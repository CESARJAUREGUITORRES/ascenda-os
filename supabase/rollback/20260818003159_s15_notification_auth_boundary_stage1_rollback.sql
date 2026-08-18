-- ASCENDA S15.1 Stage 1 rollback — restore the pre-hardening compatibility state.

drop function if exists public.aos_notification_inbox_actor_v1(jsonb);
drop function if exists public.aos_notification_mark_read_actor_v1(jsonb);

-- Legacy readers were intentionally not revoked by Stage 1. These grants are idempotent safety restoration.
grant execute on function public.aos_list_notificaciones(text,date) to anon,authenticated,service_role;
grant execute on function public.aos_mark_notif_read(uuid) to anon,authenticated,service_role;
grant execute on function public.aos_admin_notificaciones_v1(integer) to anon,authenticated,service_role;
grant execute on function public.aos_mis_notificaciones_v1(text,integer) to anon,authenticated,service_role;