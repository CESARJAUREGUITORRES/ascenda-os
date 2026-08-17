-- ASCENDA S15 topbar bridge rollback.
drop function if exists public.aos_list_notificaciones(text,date);
drop function if exists public.aos_mark_notif_read(uuid);
