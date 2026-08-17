-- ASCENDA S15 legacy notification bridge rollback.
drop trigger if exists trg_aos_notification_legacy_bridge_v1 on public.aos_notificaciones;
drop function if exists public.aos_notification_legacy_bridge_v1();
delete from public.aos_notification_policies_v1 where event_type in ('AGENT_ALERT','LEGACY_NOTIFICATION');
