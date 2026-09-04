'use strict';
const fs=require('fs');
const assert=require('assert');

const migration=fs.readFileSync('supabase/migrations/20260904014500_wa_l10_canary_observability_v1.sql','utf8');
const rollback=fs.readFileSync('supabase/rollbacks/20260904014500_wa_l10_canary_observability_v1.rollback.sql','utf8');
const both=migration+'\n'+rollback;

for(const marker of [
  'aos_wa_l10_canary_runs_v1',
  'aos_wa_l10_canary_scope_v1',
  'aos_wa_l10_prepare_run_v1',
  'aos_wa_l10_attach_scope_v1',
  'aos_wa_l10_status_v1',
  'RUN_SCOPED_BOUNDED_V1',
  'WA_L10_SAFE_OFF_REQUIRED',
  'WA_L10_ACTIVE_ALLOWLIST_MUST_BE_EMPTY_DURING_PREP',
  "'activation_authorized',false",
  'WA_L10_RECOVERY_BLOCKED_AUDIT_HISTORY'
]) assert(both.includes(marker),`missing L10 marker: ${marker}`);

assert(!/graph\.facebook\.com|graphSend\s*\(|reserveOutbound\s*\(/i.test(migration),'L10-A must not contain provider dispatch');
assert(!/aos_wa_l4_set_control_v1\s*\(/i.test(migration),'L10-A must not mutate L4 authority');
assert(!/aos_wa_l4_allowlist_set_v1\s*\(/i.test(migration),'L10-A must not mutate L4 allowlist');
assert(!/(insert\s+into|update|delete\s+from)\s+public\.(aos_wa_messages_v1|aos_wa_outbound_requests_v1|aos_wa_auto_authority_v1|aos_wa_auto_allowlist_v1|aos_pacientes|aos_leads|aos_agenda_citas|aos_ventas|aos_llamadas)/i.test(migration),'L10-A may not mutate existing authority/provider/business ledgers');
assert(!/create\s+materialized\s+view|refresh\s+materialized\s+view/i.test(migration),'L10-A may not add analytical materialization');
assert(!/(?:set|alter[^;]*)\s+statement_timeout/i.test(migration),'L10-A may not inflate statement_timeout');
assert(!/setInterval\s*\(|setTimeout\s*\(|fetch\s*\(/i.test(migration),'L10-A SQL must not introduce polling/network retry behavior');
assert(/force row level security/i.test(migration),'L10 tables must FORCE RLS');
assert(/recipient_hash[^\n]+\^\[a-f0-9\]\{64\}\$/i.test(migration),'candidate scope must be hash-only');
assert(!/recipient_(phone|number)|raw_content|message_body/i.test(migration),'L10 evidence must not store raw recipient/content');
assert(/grant execute on function public\.aos_wa_l10_status_v1\(text\) to service_role/i.test(migration));
assert(/revoke all on function public\.aos_wa_l10_status_v1\(text\) from public,anon,authenticated/i.test(migration));

console.log('WA_L10_SAFE_OFF_STATIC_CONTRACT=PASS');
