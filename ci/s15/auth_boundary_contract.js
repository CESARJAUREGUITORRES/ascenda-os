'use strict'
const fs=require('fs'),path=require('path')
const root=path.resolve(__dirname,'../..')
const migration=fs.readFileSync(path.join(root,'supabase/migrations/20260817235500_s15_notification_auth_boundary.sql'),'utf8')
const rollback=fs.readFileSync(path.join(root,'supabase/rollback/20260817235500_s15_notification_auth_boundary_rollback.sql'),'utf8')
const currentRuntime=path.join(root,'app/server-f17-current.js')
const serverPath=fs.existsSync(currentRuntime)?currentRuntime:path.join(root,'app/server-f17.js')
const server=fs.readFileSync(serverPath,'utf8')
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
  'public.aos_notification_mark_read_actor_v1(jsonb)',
  'public.aos_list_notificaciones(text,date)',
  'public.aos_mark_notif_read(uuid)',
  'public.aos_admin_notificaciones_v1(integer)',
  'public.aos_mis_notificaciones_v1(text,integer)'
]) ok(migration.includes('revoke all on function '+sig+' from public,anon,authenticated'),'public/anon revoke missing: '+sig)
ok(migration.includes('grant execute on function public.aos_notification_inbox_actor_v1(jsonb) to service_role'),'actor inbox must be service-role only')
ok(migration.includes('grant execute on function public.aos_notification_mark_read_actor_v1(jsonb) to service_role'),'actor read must be service-role only')

ok(server.includes('/api/notifications/inbox'),'F17 notification inbox endpoint missing')
ok(server.includes('/api/notifications/read'),'F17 notification read endpoint missing')
ok(server.includes('/api/notifications/health'),'F17 deploy health endpoint missing')
ok(server.includes('verifyApp('),'F17 notification endpoints must verify application token')
ok(server.includes('strongToken(req)')||server.includes("req.headers['x-aos-app-token']"),'F17 notification endpoint must derive application token server-side')
ok(server.includes('actor_id:actor.actor_id')||server.includes('actor_id: actor.actor_id'),'F17 must derive notification identity from verified actor')
ok(server.includes("serviceRpc('aos_notification_inbox_actor_v1'"),'F17 actor inbox service call missing')
ok(server.includes("serviceRpc('aos_notification_mark_read_actor_v1'"),'F17 actor read service call missing')
if(fs.existsSync(currentRuntime)){
  ok(server.includes("spawn(process.execPath,['server-phase-s.js']"),'effective F17 runtime must preserve Phase S')
  ok(server.includes("runtime:'F17_CURRENT'")||server.includes("runtime: 'F17_CURRENT'"),'notification health must identify CURRENT runtime')
}

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

console.log('S15.1 actor-bound notification authorization contract PASS on '+path.basename(serverPath))
