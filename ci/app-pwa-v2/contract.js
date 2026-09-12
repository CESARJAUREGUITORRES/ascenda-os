'use strict'
const fs=require('fs')
const path=require('path')
const root=path.resolve(__dirname,'../..')
function read(p){return fs.readFileSync(path.join(root,p),'utf8')}
function ok(v,m){if(!v)throw new Error(m)}

const migration=read('supabase/migrations/20260912073000_app_pwa_v2_device_registry.sql')
const rollback=read('supabase/rollback/20260912073000_app_pwa_v2_device_registry_rollback.sql')
const runtime=read('app/public/aos-device-runtime-v2.js')
const panel=read('app/public/admin-device-center-v2.html')
const api=read('app/device-api-v2.js')
const contract=read('docs/control/ASCENDA_APP_PWA_V2_CONTRACT_517.md')

ok(migration.includes('create table if not exists public.aos_devices_v1'),'device registry missing')
ok(migration.includes('unique(user_id, installation_id)'),'stable user+installation identity missing')
ok(migration.includes('add column if not exists device_id uuid'),'push->device bridge missing')
ok(migration.includes('create table if not exists public.aos_app_presence_v1'),'app presence table missing')
ok(migration.includes('aos_effective_presence_v1'),'effective presence RPC missing')
ok(migration.includes('HEARTBEAT_STALE'),'stale presence cutoff missing')
ok(migration.includes('revoke all on public.aos_devices_v1 from anon, authenticated'),'device table must not be browser-readable')
ok(migration.includes('grant execute on function public.aos_device_upsert_v1(jsonb) to service_role'),'device upsert must remain service-role only')
ok(migration.includes('aos_devices_actor_v1'),'actor-bound device listing missing')
ok(migration.includes('aos_device_preferences_actor_v1'),'actor-bound preferences missing')

ok(api.includes("b.user_id = a.actor_id"),'registration must overwrite browser user identity')
ok(api.includes("b.actor_id = a.actor_id"),'device mutations must be actor-bound')
ok(api.includes("verifyApp(req.headers['x-aos-app-token'], false)"),'device API must verify ASCENDA app token')
ok(!api.includes('graph.facebook.com'),'device API must not depend on Meta')
ok(!api.includes('/api/wa/send'),'device API must not alter WhatsApp send path')

ok(runtime.includes("localStorage.getItem(KEY)"),'installation identity must persist locally')
ok(runtime.includes("matchMedia('(display-mode: standalone)')"),'PWA installed surface detection missing')
ok(runtime.includes("badge_supported:typeof n.setAppBadge==='function'"),'Badge capability detection missing')
ok(runtime.includes("document.visibilityState==='visible'"),'visibility capability missing')
ok(!runtime.includes('supabase.co'),'browser device runtime must not call Supabase directly')
ok(!runtime.includes('apikey'),'browser device runtime must not embed an API key')

ok(panel.includes('Dispositivos y Notificaciones'),'Spanish panel name missing')
ok(panel.includes("'X-AOS-App-Token'"),'panel must use actor-bound same-origin API')
ok(panel.includes('/api/devices/register'),'device registration UI missing')
ok(panel.includes('/api/devices/preferences'),'device preference UI missing')
ok(!panel.includes('supabase.co'),'device center must not call Supabase directly')
ok(!panel.includes('graph.facebook.com'),'device center must not call Meta')

ok(contract.includes('Notifications are side effects'),'side-effect isolation contract missing')
ok(contract.includes('No mass replay.'),'backlog anti-replay gate missing')
ok(contract.includes('time_outside_app_sec'),'call duration semantics gate missing')

ok(rollback.includes('drop table if exists public.aos_devices_v1'),'device rollback missing')
ok(rollback.includes('drop function if exists public.aos_devices_actor_v1(jsonb)'),'actor RPC rollback missing')

console.log('APP-PWA-V2 #517 contract: PASS')
