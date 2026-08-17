'use strict';

const assert=require('node:assert/strict');
const {MemoryAlertState}=require('../../sentinel/alerts/memory-alert-state.cjs');
const {AlertRouter}=require('../../sentinel/alerts/alert-router.cjs');
const {AlertDispatcher,renderTelegramEnvelope}=require('../../sentinel/alerts/alert-dispatcher.cjs');
const {FakeTransport}=require('../../sentinel/alerts/fake-transport.cjs');

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
    incident_id:id,
    severity,
    status,
    environment:'production',
    domain:'WHATSAPP',
    component:'human-outbound',
    capability:'provider-status-progression',
    failure_family:'provider-stall',
    updated_at:now,
    signal_count:2,
    reopened_count:0,
    correlation:{release:`ascenda-os@${sha}`,commit_sha:sha,deployment_id:'dep-f9-synthetic'},
    ...overrides
  };
}

(async()=>{
  let d=router.route(incident('SEN-2026-1001','P1'));
  assert.equal(d.action,'IMMEDIATE');
  let ack=await dispatcher.dispatch(d);
  assert.equal(ack.status,'DELIVERED');
  assert.equal(transport.messages.length,1);
  setNow('2026-08-16T18:56:00-05:00');
  d=router.route(incident('SEN-2026-1001','P1'));
  assert.equal(d.action,'SUPPRESSED_COOLDOWN');

  // Recovery is emitted once per distinct resolve transition.
  setNow('2026-08-16T18:57:00-05:00');
  d=router.route(incident('SEN-2026-1001','P1','RESOLVED'));
  assert.equal(d.action,'RECOVERY');
  const firstRecoveryKey=d.dedup_key;
  ack=await dispatcher.dispatch(d);
  assert.equal(ack.delivered,true);
  d=router.route(incident('SEN-2026-1001','P1','RESOLVED'));
  assert.equal(d.action,'SUPPRESSED_COOLDOWN');

  // Reopen + later resolve must emit a second recovery with a different durable key.
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
  setNow('2026-08-16T19:21:00-05:00');
  router.route(incident('SEN-2026-4001','P1','ACK'));
  setNow('2026-08-16T19:22:00-05:00');
  router.route(incident('SEN-2026-4001','P1','INVESTIGATING'));
  setNow('2026-08-16T19:23:00-05:00');
  router.route(incident('SEN-2026-4001','P1','MITIGATED'));
  setNow('2026-08-16T19:24:00-05:00');
  d=router.route(incident('SEN-2026-4001','P1','INVESTIGATING'));
  assert.equal(d.action,'FLAPPING_SUMMARY');
  assert.match(d.dedup_key,/^SEN-2026-4001:FLAPPING:/);
  assert.equal((await dispatcher.dispatch(d)).status,'DELIVERED');
  setNow('2026-08-16T19:25:00-05:00');
  d=router.route(incident('SEN-2026-4001','P1','MITIGATED'));
  assert.equal(d.action,'SUPPRESSED_FLAPPING');

  setNow('2026-08-16T19:26:00-05:00');
  d=router.route(incident('SEN-2026-4001','P0','INVESTIGATING'));
  assert.equal(d.action,'IMMEDIATE');

  assert.throws(()=>router.route({...incident('SEN-2026-9001','P1'),patient_name:'synthetic'}),/F9_SENSITIVE_INPUT_KEY/);

  const rendered=renderTelegramEnvelope(router.route(incident('SEN-2026-9002','P1')));
  assert.match(rendered.text,/SEN-2026-9002/);
  assert.doesNotMatch(rendered.text,/(patient|paciente|telefono|phone|dni|email|token|authorization|cookie|password)\s*:/i);

  console.log(JSON.stringify({
    ok:true,
    certificate:'SENTINEL_F9_ALERT_ROUTING_SYNTHETIC_PASS',
    p1_immediate:true,
    cooldown_dedup:true,
    recovery_once_per_resolve_transition:true,
    second_recovery_after_reopen:true,
    p3_panel_only:true,
    maintenance_suppression:true,
    p0_maintenance_bypass:true,
    transport_unavailable_not_false_delivered:true,
    p2_grouped_digest:true,
    severity_escalation_immediate:true,
    flapping_summary_then_suppression:true,
    flapping_summary_has_durable_key:true,
    p0_flapping_bypass:true,
    sensitive_key_rejection:true,
    sanitized_template:true,
    fake_messages_sent:transport.messages.length
  }));
})().catch(e=>{console.error(e.stack||e);process.exit(1);});
