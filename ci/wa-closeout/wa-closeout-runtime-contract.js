'use strict';
const assert=require('node:assert/strict');
const fs=require('fs');
const path=require('path');
const root=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const wa=require(path.join(root,'app/wa-gateway.js'));

// WA-1: deterministic signed-ingress normalization and replay identity.
const fixture={object:'whatsapp_business_account',entry:[{changes:[{field:'messages',value:{
  metadata:{display_phone_number:'+51 999 111 222',phone_number_id:'pn-closeout'},
  contacts:[{wa_id:'51999111222',profile:{name:'Canary Closeout'}}],
  messages:[
    {id:'wamid.closeout.img',from:'51999111222',timestamp:'1787610000',type:'image',image:{id:'media-img-1',caption:'Imagen aprobada'},referral:{source_id:'ad-closeout',source_type:'ad',headline:'HIFU'}},
    {id:'wamid.closeout.audio',from:'51999111222',timestamp:'1787610001',type:'audio',audio:{id:'media-audio-1'}},
    {id:'wamid.closeout.doc',from:'51999111222',timestamp:'1787610002',type:'document',document:{id:'media-doc-1',caption:'Brochure'}}
  ]
}}]}]};
const a=wa.extractWebhook(fixture);
const b=wa.extractWebhook(fixture);
assert.equal(a.messages.length,3,'media fixture must normalize three messages');
assert.deepEqual(a.messages.map(x=>x.provider_message_id),b.messages.map(x=>x.provider_message_id),'provider replay identity changed');
assert.deepEqual(a.events.map(x=>x.event_key),b.events.map(x=>x.event_key),'event replay identity changed');
assert.deepEqual(a.messages.map(x=>x.media_id),['media-img-1','media-audio-1','media-doc-1'],'media ids not preserved');
assert.equal(a.messages[0].ad_id,'ad-closeout','explicit referral provenance missing');

// WA-1 outbound payload surface: supported today, without claiming WA-5 private media pipeline.
assert.equal(wa.buildOutboundPayload({to:'51999999999',type:'text',text:'Hola'}).type,'text');
assert.equal(wa.buildOutboundPayload({to:'51999999999',type:'template',template_name:'recordatorio',language:'es_PE'}).template.name,'recordatorio');
assert.equal(wa.buildOutboundPayload({to:'51999999999',type:'image',link:'https://example.test/i.jpg'}).type,'image');
assert.equal(wa.buildOutboundPayload({to:'51999999999',type:'document',link:'https://example.test/d.pdf',filename:'brochure.pdf'}).document.filename,'brochure.pdf');
assert.equal(wa.buildOutboundPayload({to:'51999999999',type:'audio',link:'https://example.test/a.ogg'}).type,'audio');
assert.throws(()=>wa.buildOutboundPayload({to:'51999999999',type:'video',link:'https://example.test/v.mp4'}),/UNSUPPORTED_MESSAGE_TYPE/);
assert.equal(wa.canaryAllows('51911111111','true','51911111111'),true);
assert.equal(wa.canaryAllows('51922222222','true','51911111111'),false);

const f4=read('app/server-f4.js');
const phaseS=read('app/server-phase-s.js');
const wa3=read('app/server-wa3.js');
const wa3v2=read('app/server-wa3-v2.js');
const authPrelude=read('app/public/wa-native-bootstrap-prelude.js');
const alerts=read('app/public/wa-human-alerts.js');
const s13=read('app/public/wa-chat-ux-s13.js');
const quota=read('app/supabase-quota-circuit-preload.cjs');
const railway=read('app/railway.json');
const finalMigration=read('supabase/migrations/20260822224500_wa3_presence_handoff_final_v3.sql');
const wa2Migration=read('supabase/migrations/20260815175500_wa2_conversation_live_inbox_v1.sql');

// Outbound exactly-once / ambiguous failure invariants.
for(const needle of [
  'aos_wa_outbound_requests_v1?on_conflict=idempotency_key',
  'resolution=ignore-duplicates,return=representation',
  'if(!reservation.owner)',
  'idempotent:true',
  'e.definite===true',
  'ambiguous_pending',
  "status:ambiguous?'PENDING':'FAILED'",
  'retry_safe:false'
]) assert(f4.includes(needle),'WA-1 outbound invariant missing: '+needle);
for(const needle of ["st.status==='sent'","st.status==='delivered'","st.status==='read'","st.status==='failed'"])
  assert(f4.includes(needle),'WA delivery projection missing: '+needle);

// Strong-session / human-send boundary stays fail-closed.
assert(phaseS.includes('aos_wa3_actor_v1'),'WA3 server-side actor authority missing');
assert(phaseS.includes('WA_CUSTOMER_WINDOW_CLOSED'),'24h customer-window gate missing');
assert(phaseS.includes('human_send_enabled:false'),'human-send degraded default must remain false');
assert(phaseS.includes('auto_routing_enabled:false'),'auto-routing degraded default must remain false');
assert(phaseS.includes('ai_send_enabled:false'),'AI-send degraded default must remain false');
assert(wa3.includes('WA3_NOT_OWNER'),'WA3 ownership boundary missing: WA3_NOT_OWNER');
for(const needle of ['/api/wa3/claim-next','/api/wa3/queue-summary','/api/wa3/team-summary'])
  assert(wa3v2.includes(needle),'WA3 V2 invariant missing: '+needle);

// Canonical state model and explicit human handoff.
for(const state of ['NEW','AI_ACTIVE','HUMAN_REQUESTED','HUMAN_ACTIVE','AI_COPILOT','WAITING_CUSTOMER','CLOSED'])
  assert(wa2Migration.includes("'"+state+"'"),'canonical conversation state missing: '+state);
for(const needle of ['aos_wa3_handoff_request_v1','aos_wa3_effective_presence_v2','HUMAN_REQUESTED','handoff_requested_at'])
  assert(finalMigration.includes(needle),'final presence/handoff invariant missing: '+needle);

// 2FA continuity bridge must never downgrade durable auth storage.
assert(authPrelude.includes("caches.open('aos-phase2-auth')"),'Auth V3 cache bridge missing');
assert(authPrelude.includes("c.match('/__aos_app_token')"),'canonical strong-token cache key missing');
assert(authPrelude.includes("sessionStorage.setItem('aos_app_token',t)"),'session-scoped recovery missing');
assert(!authPrelude.includes("localStorage.setItem('aos_app_token'"),'strong token must not move to localStorage');

// Alerts and timeline remain exact-owner, inbound-human, sanitized and status-aware.
assert(alerts.includes('r.owner_user_id===S.actorId'),'human alert exact-owner gate missing');
assert(alerts.includes("r.state==='HUMAN_ACTIVE'"),'human alert state gate missing');
assert(alerts.includes("r.last_message_direction==='INBOUND'"),'human alert direction gate missing');
assert(alerts.includes('body:safePreview(r)'),'human alert sanitizer missing');
assert(s13.includes("status==='delivered'")&&s13.includes("status==='read'"),'delivery/read UX missing');

// 402 containment is project-host scoped and credential-agnostic. Fair Use 402 is
// project-wide, so the current hardened preload intentionally covers every request
// to the configured Supabase host instead of maintaining a legacy WA User-Agent list.
assert(quota.includes('isConfiguredSupabaseRequest(args, configuredHost)'),'quota breaker must classify by configured Supabase host');
assert(quota.includes("scope: 'ALL_CONFIGURED_SUPABASE_RUNTIME_REQUESTS'"),'project-wide 402 breaker scope must remain explicit');
assert(quota.includes('configuredHost'),'quota breaker host scope missing');
assert(!quota.includes('userAgentRe'),'project-wide quota breaker must not depend on legacy User-Agent allowlists');
assert(!quota.includes('SUPABASE_SERVICE_ROLE_KEY'),'quota breaker must not inspect service-role credential');
assert(railway.includes('--require ./supabase-quota-circuit-preload.cjs'),'Railway quota preload missing');

console.log('WA_CLOSEOUT_RUNTIME_CONTRACT_PASS');