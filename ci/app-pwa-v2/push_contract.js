'use strict'
const fs=require('fs')
const path=require('path')
const root=path.resolve(__dirname,'../..')
function read(p){return fs.readFileSync(path.join(root,p),'utf8')}
function ok(v,m){if(!v)throw new Error(m)}

const mig=read('supabase/migrations/20260912074500_app_pwa_v2_push_device_bridge.sql')
const rb=read('supabase/rollback/20260912074500_app_pwa_v2_push_device_bridge_rollback.sql')
const push=read('app/push-notifications-s14.js')
const client=read('app/public/notification-push-s14.js')
const sw=read('app/public/phase2-service-worker.js')

ok(mig.includes('PUSH_SUBSCRIPTION_RETIRED'),'410/Gone retirement recovery must be preserved')
ok(mig.includes('device_id'),'push subscription device binding missing')
ok(mig.includes('installation_id'),'installation lookup fallback missing')
ok(mig.includes('ACTIVE_DEVICE_REQUIRED'),'cross-device ownership check missing')
ok(mig.includes('grant execute on function public.aos_push_subscription_upsert_v1(jsonb) to service_role'),'push upsert must remain service-role only')
ok(rb.includes('PUSH_SUBSCRIPTION_RETIRED'),'rollback must restore S15.4 recovery semantics')

ok(push.includes('device_id: text(d.device_id, 80)'),'push server must forward device_id')
ok(push.includes('installation_id: text(d.installation_id, 80)'),'push server must forward installation_id')

ok(client.includes("api('/api/devices/register'"),'push client must register authenticated device')
ok(client.includes('function ensureDevice()'),'device registration gate missing')
ok(client.includes('catch(function(){return null;})'),'legacy fail-open fallback missing')
ok(client.includes('body.device_id=dev.device_id'),'push subscription device link missing')
ok(client.includes('PUSH_SUBSCRIPTION_RECOVERY_FAILED'),'retired subscription self-healing must remain')

ok(sw.includes("c.visibilityState==='visible'"),'service worker must inspect visibility')
ok(sw.includes('c.focused===true'),'service worker must inspect focus')
ok(sw.includes("p==='CRITICAL'||p==='URGENTE'||p==='HIGH'||p==='ALTA'"),'critical/high OS notification override missing')
ok(sw.includes('if(!shouldSystemNotify(payload,list))return null'),'foreground suppression policy missing')
ok(!sw.includes("if(list.length){list.forEach(function(c){try{c.postMessage({type:'AOS_PUSH_EVENT'"),'old any-client suppression rule must be removed')

console.log('APP-PWA-V2 #517 push policy contract: PASS')
