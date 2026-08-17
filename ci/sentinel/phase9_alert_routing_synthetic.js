'use strict';

const assert=require('node:assert/strict');
const {MemoryAlertState}=require('../../sentinel/alerts/memory-alert-state.cjs');
const {AlertRouter}=require('../../sentinel/alerts/alert-router.cjs');
const {AlertDispatcher,renderOwnerEnvelope,renderTelegramEnvelope}=require('../../sentinel/alerts/alert-dispatcher.cjs');
const {FakeTransport}=require('../../sentinel/alerts/fake-transport.cjs');
const {AscendaInAppTransport}=require('../../sentinel/alerts/ascenda-inapp-transport.cjs');

let now='2026-08-16T18:55:00-05:00';
const clock=()=>now;
const state=new MemoryAlertState();
const router=new AlertRouter({state,clock});
const transport=new FakeTransport({clock});
const dispatcher=new AlertDispatcher({router,transport});
const sha='f90542bfa21b7be5e3a306f0d9241c52368fbe19';

function setNow(v){now=v;}
function incident(id,severity,status='OPEN',overrides={}){
  return {
    incident_id:id,severity,status,environment:'production',domain:'WHATSAPP',
    component:'human-outbound',capability:'provider-status-progression',failure_family:'provider-stall',
    updated_at:now,signal_count:2,reopened_count:0,
    correlation:{release:`ascenda-os@${sha}`,commit_sha:sha,deployment_id:'dep-f9-synthetic'},...overrides
  };
}

(async()=>{
  let d=router.route(incident('SEN-2026-1001','P1'));
  assert.equal(d.action,'IMMEDIATE');
  assert.equal(d.channel,'ascenda-in-app');
  let ack=await dispatcher.dispatch(d);
  assert.equal(ack.status,'DELIVERED');
  assert.equal(transport.messages.length,1);
  assert.equal(transport.messages[0].channel,'ascenda-in-app');

  setNow('2026-08-16T18:56:00-05:00');
  d=router.route(incident('SEN-2026-1001','P1'));
  assert.equal(d.action,'SUPPRESSED_COOLDOWN');

  setNow('2026-08-16T18:57:00-05:00');
  d=router.route(incident('SEN-2026-1001','P1','RESOLVED'));
  assert.equal(d.action,'RECOVERY');
  assert.equal(d.channel,'ascenda-in-app');
  const firstRecoveryKey=d.dedup_key;
  ack=await dispatcher.dispatch(d);
  assert.equal(ack.delivered,true);
  d=router.route(incident('SEN-2026-1001','P1','RESOLVED'));
  assert.equal(d.action,'SUPPRESSED_COOLDOWN');

  setNow('2026-08-16T19:00:00-05:00');
  d=router.route(incident('SEN-2026-1001','P1','OPEN',{reopened_count:1}));
  assert.equal(d.action,'IMMEDIATE');
  await dispatcher.dispatch(d);
  setNow('2026-08-16T19:01:00-05:00');
  d=router.route(incident('SEN-2026-1001','P1','RESOLVED',{reopened_count:1}));
  assert.equal(d.action,'RECOVERY');
  assert.notEqual(d.dedup_key,firstRecoveryKey);
  assert.equal((await dispatcher.dispatch(d)).status,'DELIVERED');

  d=router.route(incident('SEN-2026-1002','P3'));
  assert.equal(d.action,'PANEL_ONLY');
  assert.equal((await dispatcher.dispatch(d)).delivered,false);

  const mw=[{starts_at:'2026-08-16T18:50:00-05:00',ends_at:'2026-08-16T19:30:00-05:00',environment:'production',domain:'WHATSAPP',component:'human-outbound'}];
  d=router.route(incident('SEN-2026-1003','P1'),{maintenance_windows:mw});
  assert.equal(d.action,'SUPPRESSED_MAINTENANCE');
  d=router.route(incident('SEN-2026-1004','P0'),{maintenance_windows:mw});
  assert.equal(d.action,'IMMEDIATE');
  assert.equal(d.channel,'ascenda-in-app');

  const unavailable=new FakeTransport({isAvailable:false,clock});
  const unavailableDispatcher=new AlertDispatcher({router,transport:unavailable});
  d=router.route(incident('SEN-2026-1005','P1'));
  assert.equal((await unavailableDispatcher.dispatch(d)).status,'UNAVAILABLE');
  setNow('2026-08-16T19:02:00-05:00');
  d=router.route(incident('SEN-2026-1005','P1'));
  assert.equal(d.action,'IMMEDIATE');

  setNow('2026-08-16T19:05:00-05:00');
  const p2a=router.route(incident('SEN-2026-2001','P2','OPEN',{domain:'EMAIL',component:'resend-gateway',capability:'send-and-webhook-progression'}));
  const p2b=router.route(incident('SEN-2026-2002','P2','OPEN',{domain:'EMAIL',component:'resend-gateway',capability:'send-and-webhook-progression'}));
  assert.equal(p2a.action,'DIGEST_QUEUED');
  assert.equal(p2b.action,'DIGEST_QUEUED');
  assert.equal(p2a.digest_key,p2b.digest_key);
  assert.equal(p2b.queued_count,2);
  setNow('2026-08-16T19:16:00-05:00');
  const digests=router.flushDueDigests();
  assert.equal(digests.length,1);
  assert.equal(digests[0].channel,'ascenda-in-app');
  assert.equal(digests[0].count,2);
  assert.deepEqual(digests[0].incident_ids,['SEN-2026-2001','SEN-2026-2002']);
  assert.equal((await dispatcher.dispatch(digests[0])).status,'DELIVERED');

  setNow('2026-08-16T19:17:00-05:00');
  d=router.route(incident('SEN-2026-3001','P2'));
  assert.equal(d.action,'DIGEST_QUEUED');
  setNow('2026-08-16T19:18:00-05:00');
  d=router.route(incident('SEN-2026-3001','P1'));
  assert.equal(d.action,'IMMEDIATE');

  setNow('2026-08-16T19:20:00-05:00');
  router.route(incident('SEN-2026-4001','P1','OPEN'));
  setNow('2026-08-16T19:21:00-05:00');router.route(incident('SEN-2026-4001','P1','ACK'));
  setNow('2026-08-16T19:22:00-05:00');router.route(incident('SEN-2026-4001','P1','INVESTIGATING'));
  setNow('2026-08-16T19:23:00-05:00');router.route(incident('SEN-2026-4001','P1','MITIGATED'));
  setNow('2026-08-16T19:24:00-05:00');
  d=router.route(incident('SEN-2026-4001','P1','INVESTIGATING'));
  assert.equal(d.action,'FLAPPING_SUMMARY');
  assert.equal(d.channel,'ascenda-in-app');
  assert.match(d.dedup_key,/^SEN-2026-4001:FLAPPING:/);
  assert.equal((await dispatcher.dispatch(d)).status,'DELIVERED');
  setNow('2026-08-16T19:25:00-05:00');
  d=router.route(incident('SEN-2026-4001','P1','MITIGATED'));
  assert.equal(d.action,'SUPPRESSED_FLAPPING');
  setNow('2026-08-16T19:26:00-05:00');
  d=router.route(incident('SEN-2026-4001','P0','INVESTIGATING'));
  assert.equal(d.action,'IMMEDIATE');

  assert.throws(()=>router.route({...incident('SEN-2026-9001','P1'),patient_name:'synthetic'}),/F9_SENSITIVE_INPUT_KEY/);

  const ownerDecision=router.route(incident('SEN-2026-9002','P1'));
  const ownerEnvelope=renderOwnerEnvelope(ownerDecision);
  assert.equal(ownerEnvelope.channel,'ascenda-in-app');
  assert.match(ownerEnvelope.text,/SEN-2026-9002/);
  assert.doesNotMatch(ownerEnvelope.text,/(patient|paciente|telefono|phone|dni|email|token|authorization|cookie|password)\s*:/i);

  const telegramState=new MemoryAlertState();
  const telegramRouter=new AlertRouter({state:telegramState,clock,ownerChannel:'telegram-owner'});
  const telegramDecision=telegramRouter.route(incident('SEN-2026-9003','P1'));
  assert.equal(telegramDecision.channel,'telegram-owner');
  const telegramEnvelope=renderTelegramEnvelope(telegramDecision);
  assert.equal(telegramEnvelope.channel,'telegram-owner');
  assert.match(telegramEnvelope.text,/SEN-2026-9003/);

  const published=[];
  const inapp=new AscendaInAppTransport({clock,publish:async envelope=>{published.push(envelope);return {ok:true,ack_id:'inapp:synthetic-1',at:now};}});
  const inappState=new MemoryAlertState();
  const inappRouter=new AlertRouter({state:inappState,clock});
  const inappDispatcher=new AlertDispatcher({router:inappRouter,transport:inapp});
  const inappDecision=inappRouter.route(incident('SEN-2026-9004','P1'));
  const inappAck=await inappDispatcher.dispatch(inappDecision);
  assert.equal(inappAck.status,'DELIVERED');
  assert.equal(inappAck.provider_message_id,'inapp:synthetic-1');
  assert.equal(published.length,1);
  assert.equal(published[0].channel,'ascenda-in-app');

  console.log(JSON.stringify({ok:true,certificate:'SENTINEL_F9_ALERT_ROUTING_SYNTHETIC_PASS',primary_transport:'ascenda-in-app',p1_immediate:true,cooldown_dedup:true,recovery_once_per_resolve_transition:true,second_recovery_after_reopen:true,p3_panel_only:true,maintenance_suppression:true,p0_maintenance_bypass:true,transport_unavailable_not_false_delivered:true,p2_grouped_digest:true,severity_escalation_immediate:true,flapping_summary_then_suppression:true,p0_flapping_bypass:true,sensitive_key_rejection:true,sanitized_template:true,inapp_persistence_ack_contract:true,telegram_compatible:true,fake_messages_sent:transport.messages.length}));
})().catch(e=>{console.error(e.stack||e);process.exit(1);});
