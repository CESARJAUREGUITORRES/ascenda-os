'use strict'
const fs=require('fs'),path=require('path')
const root=path.resolve(__dirname,'../..')
const migration=fs.readFileSync(path.join(root,'supabase/migrations/20260817235500_s15_notification_auth_boundary.sql'),'utf8')
const pending=fs.readFileSync(path.join(root,'supabase/pending/s15_notification_legacy_acl_cutover_after_s15_2.sql'),'utf8')
const rollback=fs.readFileSync(path.join(root,'supabase/rollback/20260817235500_s15_notification_auth_boundary_rollback.sql'),'utf8')
const server=fs.readFileSync(path.join(root,'app/server-f17.js'),'utf8')
const sw=fs.readFileSync(path.join(root,'app/public/phase2-service-worker.js'),'utf8')
const center=fs.readFileSync(path.join(root,'app/public/notification-center-s15.js'),'utf8')
const pushClient=fs.readFileSync(path.join(root,'app/public/notification-push-s14.js'),'utf8')
function ok(v,m){if(!v){console.error('S15.1 AUTH CONTRACT FAIL:',m);process.exit(1)}}

ok(migration.includes('create or replace function public.aos_notification_inbox_actor_v1'),'actor inbox RPC missing')
ok(migration.includes('create or replace function public.aos_notification_mark_read_actor_v1'),'actor mark-read RPC missing')
ok(migration.includes("begin uid:=(p_payload->>'actor_id')::uuid"),'actor inbox must bind to UUID supplied by trusted server')
ok(migration.includes("x.para_user_id=uid")||migration.includes('n.para_user_id=uid'),'actor visibility must include canonical user UUID')
ok(migration.includes('NOTIFICATION_NOT_VISIBLE_TO_ACTOR'),'mark-read must enforce recipient visibility')
for(const sig of [
  'public.aos_notification_inbox_actor_v1(jsonb)',
  'public.aos_notification_mark_read_actor_v1(jsonb)'
]) ok(migration.includes('revoke all on function '+sig+' from public,anon,authenticated'),'new actor RPC must be server-only: '+sig)
ok(migration.includes('grant execute on function public.aos_notification_inbox_actor_v1(jsonb) to service_role'),'actor inbox must be service-role only')
ok(migration.includes('grant execute on function public.aos_notification_mark_read_actor_v1(jsonb) to service_role'),'actor read must be service-role only')
ok(!migration.includes('revoke all on function public.aos_list_notificaciones(text,date) from public,anon,authenticated'),'legacy list revoke must not happen before S15.2 live smoke')
ok(!migration.includes('revoke all on function public.aos_mark_notif_read(uuid) from public,anon,authenticated'),'legacy read revoke must not happen before S15.2 live smoke')
for(const sig of [
  'public.aos_list_notificaciones(text,date)',
  'public.aos_mark_notif_read(uuid)',
  'public.aos_admin_notificaciones_v1(integer)',
  'public.aos_mis_notificaciones_v1(text,integer)'
]) {
  ok(pending.includes('revoke all on function '+sig+' from public,anon,authenticated'),'pending final ACL revoke missing: '+sig)
  ok(pending.includes('grant execute on function '+sig+' to service_role'),'pending service-role grant missing: '+sig)
}
ok(pending.includes('DO NOT apply before'),'pending ACL cutover must be explicitly gated')
ok(pending.includes('/api/notifications/health'),'pending ACL cutover must require production health smoke')

ok(server.includes("url.pathname === '/api/notifications/inbox'"),'F17 notification inbox endpoint missing')
ok(server.includes("url.pathname === '/api/notifications/read'"),'F17 notification read endpoint missing')
ok(server.includes("url.pathname === '/api/notifications/health'"),'F17 deploy health endpoint missing')
ok(server.includes("verifyApp(req.headers['x-aos-app-token'], false)"),'F17 notification endpoints must verify application token')
ok(server.includes("actor_id: actor.actor_id"),'F17 must derive notification identity from verified actor')
ok(server.includes("serviceRpc('aos_notification_inbox_actor_v1'"),'F17 actor inbox service call missing')
ok(server.includes("serviceRpc('aos_notification_mark_read_actor_v1'"),'F17 actor read service call missing')

ok(sw.includes("u.pathname.indexOf('/api/notifications/')===0"),'service worker token bridge must cover notification APIs')
ok(sw.includes("rm[1]==='aos_list_notificaciones'"),'topbar legacy list RPC interception missing')
ok(sw.includes("notificationApi('/api/notifications/inbox?limit=30','GET')"),'topbar list must route to actor-bound F17')
ok(sw.includes("rm[1]==='aos_mark_notif_read'"),'topbar legacy mark-read interception missing')
ok(sw.includes("notificationApi('/api/notifications/read','POST',{id:p.p_id})"),'topbar read must route to actor-bound F17')

ok(center.includes("api('/api/notifications/inbox?limit=50')"),'unified center must use same-origin actor inbox')
ok(center.includes("api('/api/notifications/read',{method:'POST',body:{id:id}})"),'unified center must use actor-bound mark-read endpoint')
ok(!center.includes('supabase.co'),'unified center must not directly call Supabase')
ok(!center.includes('eyJhbGciOi'),'unified center must not embed anon JWT')
ok(!center.includes('aos_admin_notificaciones_v1'),'new admin center must not trust direct legacy reader')
ok(pushClient.includes('/notification-center-s15.js?v=20260817-s15-auth-p02'),'auth-hardened notification center cache version missing')
ok(sw.includes('/notification-push-s14.js?v=20260817-push-s15-auth-p02'),'service-worker client cache version missing')

ok(rollback.includes('drop function if exists public.aos_notification_inbox_actor_v1(jsonb)'),'actor inbox rollback missing')
ok(rollback.includes('grant execute on function public.aos_list_notificaciones(text,date) to anon,authenticated,service_role'),'compatibility rollback grant missing')

console.log('S15.1 staged actor-bound notification authorization contract PASS')