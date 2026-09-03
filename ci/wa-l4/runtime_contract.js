'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');

const root=path.resolve(__dirname,'../..');
const server=fs.readFileSync(path.join(root,'app/server-f4.js'),'utf8');
const migration=fs.readFileSync(path.join(root,'supabase/migrations/20260902235500_wa_l4_autonomous_authority_v1.sql'),'utf8');
const rollback=fs.readFileSync(path.join(root,'supabase/rollbacks/20260902235500_wa_l4_autonomous_authority_v1.rollback.sql'),'utf8');
const l4=require(path.join(root,'app/wa-l4-authority.js'));
const wa=require(path.join(root,'app/wa-gateway.js'));

function pos(haystack,needle){const i=haystack.indexOf(needle);assert.notEqual(i,-1,`missing ${needle}`);return i;}

test('L4 helper requires a long timing-safe internal secret',()=>{
  assert.equal(l4.internalTokenValid('x','x'),false);
  const secret='s'.repeat(40);
  assert.equal(l4.internalTokenValid(secret,secret),true);
  assert.equal(l4.internalTokenValid(secret+'x',secret),false);
});

test('L4 authority request hashes provider payload and requires canonical conversation id',()=>{
  const payload=wa.buildOutboundPayload({to:'999111222',type:'text',text:'hola'});
  const a=l4.authorityPayload({conversation_id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',idempotency_key:'ci-runtime-00000001',type:'text'},payload);
  assert.equal(a.p_recipient_kind,'PHONE');
  assert.equal(a.p_recipient_address,'999111222');
  assert.match(a.p_content_hash,/^[a-f0-9]{64}$/);
  assert.equal(a.p_requires_identity,false);
  assert.throws(()=>l4.authorityPayload({conversation_id:'bad',idempotency_key:'ci-runtime-00000002'},payload),/WA_L4_CONVERSATION_ID_REQUIRED/);
});

test('server strips L4 secret from legacy child process',()=>{
  assert.match(server,/const WA_L4_INTERNAL_TOKEN=process\.env\.WA_L4_INTERNAL_TOKEN\|\|''/);
  assert.match(server,/delete childEnv\.WA_L4_INTERNAL_TOKEN/);
});

test('autonomous endpoint is internal POST only and never exposes browser CORS path',()=>{
  assert.match(server,/pathname==='\/api\/wa\/auto-send'&&req\.method==='POST'/);
  assert.match(server,/pathname==='\/api\/wa\/auto-send'\)\{writeJson\(res,405/);
  assert.doesNotMatch(server,/api\/wa\/auto-send[^\n]{0,180}OPTIONS/);
  assert.match(server,/x-aos-wa-auto-token/);
});

test('authority RPC is evaluated before reservation and Meta dispatch',()=>{
  const fnStart=pos(server,'async function handleWaAutoSend');
  const fnEnd=pos(server,'async function handleWaStatus');
  const body=server.slice(fnStart,fnEnd);
  const auth=pos(body,"sbServiceRpc('aos_wa_l4_authorize_autonomous_send_v1'");
  const reserve=pos(body,'reserveOutbound(body.idempotency_key');
  const send=pos(body,'graphSend(payload)');
  assert.ok(auth<reserve&&reserve<send,'authority -> reservation -> provider order required');
  assert.match(body,/authority\.decision!=='ALLOW'/);
  assert.match(body,/authority\.decision==='HANDOFF'/);
  assert.match(body,/requestL4Handoff/);
});

test('human send remains separately 2FA governed and marked HUMAN',()=>{
  const fnStart=pos(server,'async function handleWaSend');
  const fnEnd=pos(server,'async function requestL4Handoff');
  const body=server.slice(fnStart,fnEnd);
  assert.match(body,/authorizeWaSender\(req\)/);
  assert.match(body,/WA_ADMIN_2FA_REQUIRED/);
  assert.match(body,/send_origin:'HUMAN'/);
  assert.match(body,/wa\.canaryAllows/);
});

test('autonomous send preserves existing idempotency ledger and records AUTO lineage',()=>{
  const fnStart=pos(server,'async function handleWaAutoSend');
  const fnEnd=pos(server,'async function handleWaStatus');
  const body=server.slice(fnStart,fnEnd);
  assert.match(body,/reserveOutbound\(body\.idempotency_key,actor,payload,\{send_origin:'AUTO'/);
  assert.match(body,/authority_decision_id:authority\.decision_id/);
  assert.match(body,/conversation_id:authorityRequest\.p_conversation_id/);
  assert.match(body,/auto\.message\.accepted/);
  assert.match(body,/raw_content_stored:false/);
});

test('provider failures never auto retry and force governed handoff',()=>{
  const fnStart=pos(server,'async function handleWaAutoSend');
  const fnEnd=pos(server,'async function handleWaStatus');
  const body=server.slice(fnStart,fnEnd);
  assert.match(body,/recordL4ProviderError/);
  assert.match(body,/requestL4Handoff/);
  assert.match(body,/retry_safe:false/);
  assert.match(body,/ambiguous_pending/);
});

test('SQL contract defaults AUTO_OFF + kill and keeps control server-only',()=>{
  assert.match(migration,/mode text not null default 'AUTO_OFF'/i);
  assert.match(migration,/kill_switch_engaged boolean not null default true/i);
  assert.match(migration,/values\(1,'AUTO_OFF',true\)/i);
  assert.match(migration,/revoke all on function public\.aos_wa_l4_authorize_autonomous_send_v1[\s\S]*from public,anon,authenticated/i);
  assert.doesNotMatch(migration,/grant execute on function public\.aos_wa_l4_authorize_autonomous_send_v1[\s\S]{0,250}to (anon|authenticated)/i);
});

test('SQL contract has safety, identity, template, allowlist and pressure guards',()=>{
  for(const marker of [
    'WA_L4_KILL_SWITCH','WA_L4_CANARY_NOT_ALLOWLISTED','WA_L4_TEMPLATE_NOT_PROVIDER_VERIFIED',
    'WA_L4_IDENTITY_CONFLICT','WA_L4_IDENTITY_REQUIRED','WA_L4_HUMAN_OWNERSHIP_BOUNDARY',
    'WA_L4_DAILY_MESSAGE_LIMIT','WA_L4_MAX_TURNS_HANDOFF','WA_L4_GLOBAL_RATE_LIMIT',
    'WA_L4_CONVERSATION_RATE_LIMIT','WA_L4_COOLDOWN','WA_L4_DUPLICATE_GUARD'
  ])assert.ok(migration.includes(marker),`missing ${marker}`);
  assert.match(migration,/provider_verified is true/i);
  assert.match(migration,/pg_catalog\.pg_advisory_xact_lock/);
});

test('migration does not alter sales/patient/agenda business rows',()=>{
  const executable=migration.replace(/--.*$/gm,'');
  assert.doesNotMatch(executable,/\b(insert into|update|delete from)\s+public\.aos_ventas\b/i);
  assert.doesNotMatch(executable,/\b(insert into|update|delete from)\s+public\.aos_pacientes\b/i);
  assert.doesNotMatch(executable,/\b(insert into|update|delete from)\s+public\.aos_agenda_citas\b/i);
  assert.doesNotMatch(executable,/statement_timeout/i);
});

test('recovery first forces SAFE-OFF and refuses to erase autonomous history',()=>{
  const safe=pos(rollback,"set ai_send_enabled=false,auto_routing_enabled=false,human_send_enabled=true");
  const guard=pos(rollback,'WA_L4_RECOVERY_BLOCKED_AUTO_HISTORY');
  const drops=pos(rollback,'drop table if exists public.aos_wa_auto_decisions_v1');
  assert.ok(safe<guard&&guard<drops);
  assert.match(rollback,/check \(auto_reply_enabled=false\)/i);
  assert.match(rollback,/check \(ai_send_enabled=false\)/i);
});
