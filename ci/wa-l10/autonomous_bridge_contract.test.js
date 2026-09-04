'use strict';
const fs=require('fs');
const assert=require('assert');

const server=fs.readFileSync('app/server-wa4.js','utf8');
const bridge=fs.readFileSync('app/wa-l10-autonomous-bridge.js','utf8');
const migration=fs.readFileSync('supabase/migrations/20260904204500_wa_l10_autonomous_bridge_v1.sql','utf8');
const rollback=fs.readFileSync('supabase/rollbacks/20260904204500_wa_l10_autonomous_bridge_v1.rollback.sql','utf8');
const ddl=migration.slice(0,migration.indexOf('create or replace function'));

for(const marker of [
  'aos_wa_l10_bridge_jobs_v1','aos_wa_l10_bridge_attempts_v1','aos_wa_l10_bridge_events_v1',
  'aos_wa_l10_bridge_enqueue_v1','aos_wa_l10_bridge_claim_v1','aos_wa_l10_bridge_pending_v1',
  'aos_wa_l10_return_to_autonomous_canary_v1','aos_wa_l10_bridge_status_v1',
  'WA_L10_EXACT_CONVERSATION_ALLOWLIST_REQUIRED','L10_AUTONOMOUS_RETURN','AI_ACTIVE'
]) assert(migration.includes(marker),`missing bridge marker ${marker}`);

assert(server.includes("require('./wa-l10-autonomous-bridge')"),'WA4 must mount L10 bridge');
assert(server.includes("(p==='/webhook'||p==='/webhook/')&&req.method==='POST'"),'WA4 must intercept signed inbound POST only');
assert(server.includes('bridge.enqueueWebhook(raw)'),'durable enqueue must happen after provider persistence');
assert(server.includes("internalPost('/api/wa/auto-send'"),'autonomous output must reuse canonical L4 endpoint');
assert(server.includes("'x-aos-wa-auto-token'"),'internal AI path must require server-only token');
assert(server.includes('l4.internalTokenValid'),'internal token must be timing-safe validated');
assert(server.includes('effectiveCanary()'),'enqueue failure must distinguish inert SAFE-OFF from active canary');
assert(server.includes('setImmediate'),'AI processing must run after webhook ACK path, not block Meta on model latency');

const claimAt=bridge.indexOf("serviceRpc('aos_wa_l10_bridge_claim_v1'");
const suggestAt=bridge.indexOf('suggestInternal(claim.conversation_id)');
const sendAt=bridge.indexOf('await autoSend({');
assert(claimAt>=0&&suggestAt>claimAt&&sendAt>suggestAt,'claim -> governed suggestion -> L4 send ordering drifted');
assert(bridge.includes('deterministicIdempotency(providerMessageId)'),'provider-message idempotency missing');
assert(!/setInterval\s*\(|setTimeout\s*\(/.test(bridge),'bridge may not poll or schedule retry loops');
assert(!/graph\.facebook\.com|graphSend\s*\(/i.test(bridge),'bridge may not become a second provider sender');
assert(!/while\s*\(/.test(bridge),'bridge may not contain autonomous retry loops');

assert(/subject_kind='CONVERSATION'/.test(migration),'CANARY must be exact-conversation scoped');
assert(/v_conv\.owner_user_id is not null/.test(migration),'human ownership boundary missing');
assert(/v_conv\.human_takeover_at is not null/.test(migration),'human takeover boundary missing');
assert(/update public\.aos_wa_assignments_v1[\s\S]*state='RELEASED'/.test(migration),'return must preserve assignment history by release');
assert(/insert into public\.aos_wa_routing_events_v1/.test(migration),'return transition must be audited');
assert(/force row level security/i.test(migration),'bridge ledgers must FORCE RLS');
assert(!/message_body|raw_webhook|access_token|recipient_address|contact_address/i.test(ddl),'bridge ledger DDL may not store raw content, recipient or secrets');
assert(!/graph\.facebook\.com|graphSend\s*\(/i.test(migration),'SQL may not dispatch provider traffic');
assert(rollback.includes('WA_L10_BRIDGE_RECOVERY_BLOCKED_AUDIT_HISTORY'),'rollback must fail closed after live evidence');

console.log('WA_L10_AUTONOMOUS_BRIDGE_STATIC_CONTRACT=PASS');
