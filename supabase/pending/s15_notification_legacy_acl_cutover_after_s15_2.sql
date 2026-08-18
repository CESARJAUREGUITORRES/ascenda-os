-- ASCENDA S15.1/S15.2 — FINAL notification ACL cutover.
-- DO NOT apply before all gates below are true:
-- 1) PR S15.2 merged and Railway is serving F17 in the production chain.
-- 2) GET /api/notifications/health => { ok:true, version:'S15.1', auth:'actor-bound' }.
-- 3) VAPID exists and the owner PWA registers a push subscription.
-- 4) Actor-bound inbox/read smoke passes from the authenticated ASCENDA client.
-- 5) Legacy topbar compatibility has been observed through the F17/service-worker bridge.

revoke all on function public.aos_list_notificaciones(text,date) from public,anon,authenticated;
revoke all on function public.aos_mark_notif_read(uuid) from public,anon,authenticated;
revoke all on function public.aos_admin_notificaciones_v1(integer) from public,anon,authenticated;
revoke all on function public.aos_mis_notificaciones_v1(text,integer) from public,anon,authenticated;

grant execute on function public.aos_list_notificaciones(text,date) to service_role;
grant execute on function public.aos_mark_notif_read(uuid) to service_role;
grant execute on function public.aos_admin_notificaciones_v1(integer) to service_role;
grant execute on function public.aos_mis_notificaciones_v1(text,integer) to service_role;

-- Post-cutover verification expected:
-- anon/authenticated/PUBLIC: no EXECUTE on the four legacy readers above.
-- service_role: EXECUTE retained.
