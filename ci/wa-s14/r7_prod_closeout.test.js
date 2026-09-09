'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('fs');
const path=require('path');
const webpush=require('../../app/node_modules/web-push');
const {createPushService}=require('../../app/push-notifications-s14');

const root=path.resolve(__dirname,'../..');
const migration=fs.readFileSync(path.join(root,'supabase/migrations/20260909234000_wa_s14_event_push_priority_v2.sql'),'utf8');
const preload=fs.readFileSync(path.join(root,'app/business-priority-preload.js'),'utf8');
const pushSource=fs.readFileSync(path.join(root,'app/push-notifications-s14.js'),'utf8');

test('R7 event-driven WhatsApp Push uses runtime VAPID and V2 target RPCs',()=>{
  assert.ok(pushSource.includes("aos_push_vapid_runtime_config_v2"));
  assert.ok(pushSource.includes("aos_push_targets_for_wa_v2"));
  assert.ok(pushSource.includes("aos_push_targets_for_wa_v1"),'legacy target fallback retained during rollout');
});

test('foreground shield keeps generic notification polling suppressed but does not classify the R7 runtime VAPID RPC',()=>{
  assert.ok(preload.includes("aos_notification_push_claim_v1"));
  assert.ok(preload.includes("aos_push_vapid_config_v1"));
  assert.equal(preload.includes("aos_push_vapid_runtime_config_v2"),false);
});

test('migration keeps one-recipient bounded queue fallback and service-role-only authority',()=>{
  assert.ok(migration.includes("v_conv.state='HUMAN_REQUESTED'"));
  assert.ok(migration.includes("QUEUE_SUPERVISOR_FALLBACK"));
  assert.ok(migration.includes('limit 1;'));
  assert.ok(migration.includes("grant execute on function public.aos_push_targets_for_wa_v2(jsonb) to service_role"));
  assert.ok(migration.includes("revoke all on function public.aos_push_targets_for_wa_v2(jsonb) from public,anon,authenticated"));
  assert.ok(migration.includes("grant execute on function public.aos_push_vapid_runtime_config_v2(jsonb) to service_role"));
});

test('runtime prefers V2 target and skips delivery cleanly when the governed resolver says ineligible',async()=>{
  const keys=webpush.generateVAPIDKeys();
  const calls=[];
  const svc=createPushService({
    serviceRpc:async(name)=>{
      calls.push(name);
      if(name==='aos_push_vapid_runtime_config_v2') return {ok:true,configured:true,public_key:keys.publicKey,private_key:keys.privateKey};
      if(name==='aos_push_targets_for_wa_v2') return {ok:true,eligible:false,reason:'HUMAN_OWNER_REQUIRED'};
      throw new Error('UNEXPECTED_RPC_'+name);
    },
    vapidSubject:'mailto:test@example.com',
    logger:{error:()=>{}}
  });
  const out=await svc.dispatchWhatsAppEnvelope({messages:[{direction:'INBOUND',provider_message_id:'wamid.r7test',from_number:'51999999999',phone_number_id:'phone-1',message_body:'hola'}]});
  assert.equal(out.inbound,1);
  assert.equal(out.skipped,1);
  assert.equal(out.failed,0);
  assert.deepEqual(calls.slice(0,2),['aos_push_vapid_runtime_config_v2','aos_push_targets_for_wa_v2']);
});
