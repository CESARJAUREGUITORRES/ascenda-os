'use strict';
const fs=require('fs');
const assert=require('assert');
const read=p=>fs.readFileSync(p,'utf8');

const migration=read('supabase/migrations/20260903194500_wa_l8_security_gate_v1.sql');
const rollback=read('supabase/rollbacks/20260903194500_wa_l8_security_gate_v1.rollback.sql');
const gateway=read('app/wa-gateway.js');
const server=read('app/server-f4.js');
const ai=read('app/ai-router.js');
const copilot=read('app/wa4-copilot.js');
const ui=read('app/public/admin-whatsapp.html');
const low=migration.toLowerCase();

// Safety: L8 installs a gate, never activates autonomy.
for(const forbidden of [
  /auto_reply_enabled\s*=\s*true/i,
  /ai_send_enabled\s*=\s*true/i,
  /auto_routing_enabled\s*=\s*true/i,
  /kill_switch_engaged\s*=\s*false/i,
  /\bmode\s*=\s*['"]canary['"]/i,
  /\bmode\s*=\s*['"]prod['"]/i
]) assert(!forbidden.test(migration),'L8 migration may not activate autonomy');

// P0 #432: no global materialization and no triggers on certified hot ledgers.
assert(!/create\s+materialized\s+view|refresh\s+materialized\s+view/i.test(migration));
for(const hot of ['aos_wa_messages_v1','aos_wa_ai_runs_v1','aos_booking_operations_v2','aos_agenda_citas','aos_ventas','aos_llamadas']){
  assert(!new RegExp(`create\\s+trigger[^;]+on\\s+public\\.${hot}\\b`,'is').test(migration),`L8 trigger forbidden on ${hot}`);
}
for(const ledger of ['aos_pacientes','aos_leads','aos_agenda_citas','aos_ventas','aos_llamadas']){
  assert(!new RegExp(`(?:insert\\s+into|update|delete\\s+from)\\s+public\\.${ledger}\\b`,'i').test(migration),`L8 may not mutate ${ledger}`);
}

// Meta 2026 billing evidence is sanitized, market-specific and fail-closed.
assert(gateway.includes('pricing_type:trimText(pricing.type'));
assert(gateway.includes('pricing_type:row.pricing_type'));
assert(migration.includes('aos_wa_l8_meta_pricing_evidence_v1'));
assert(migration.includes("m.to_number ~ '^51[0-9]{8,12}$' then 'PE'"));
assert(migration.includes("provider<>'META_WHATSAPP' or market_code<>'GLOBAL'"));
assert(migration.includes('aos_wa_l8_meta_monthly_usage_v1'));
assert(migration.includes('provider_nonbillable_messages'));
assert(!/1000\s*(?:free|gratis|service)/i.test(migration),'No unverified monthly allowance may be hard-coded as pricing authority');

// Consent/STOP/business-initiation gate precedes the already-certified L4 authority.
assert(migration.includes('aos_wa_l8_consent_events_v1'));
assert(migration.includes('aos_wa_l8_autonomous_preflight_v1'));
assert(migration.includes('WA_L8_OPT_OUT_ACTIVE'));
assert(migration.includes('WA_L8_TEMPLATE_REQUIRED_OUTSIDE_24H'));
assert(migration.includes('WA_L8_BUSINESS_INITIATED_OPT_IN_REQUIRED'));
assert(migration.includes('aos_wa_l4_authorize_autonomous_send_pre_l8_v1'));
const wrapper=migration.indexOf('v_pre:=public.aos_wa_l8_autonomous_preflight_v1');
const legacy=migration.indexOf('v_l4:=public.aos_wa_l4_authorize_autonomous_send_pre_l8_v1');
assert(wrapper>=0&&legacy>wrapper,'L8 preflight must run before L4 authority');

// Human escalation is still direct and auditable in the provider runtime.
assert(server.includes('aos_wa3_handoff_request_v1'));
assert(server.includes("authority.decision==='HANDOFF'"));

// Signed webhook + reservation-before-send/idempotency remain binding.
assert(server.includes("req.headers['x-hub-signature-256']"));
assert(server.includes('wa.verifyMetaSignature(raw,signature,WA_APP_SECRET)'));
assert(server.includes('reserveOutbound(body.idempotency_key'));
assert(server.indexOf('reserveOutbound(body.idempotency_key')<server.lastIndexOf('graphSend(payload)'));
assert(server.includes("state:'PENDING'"));

// Secrets are server-only; no browser code may receive service/provider credentials.
for(const secret of ['SUPABASE_SERVICE_ROLE_KEY','WHATSAPP_ACCESS_TOKEN','WHATSAPP_APP_SECRET','WA_L4_INTERNAL_TOKEN','GROQ_API_KEY']){
  assert(!ui.includes(secret),`Browser secret reference: ${secret}`);
}

// AI traces remain metadata-only. The runtime redacts direct identifiers from context
// and the SQL canary independently rejects raw prompt/reply columns.
assert(ai.includes('function redactPII'));
assert(copilot.includes('ai.redactPII'));
assert(copilot.includes("servicePost('/rest/v1/aos_wa_ai_runs_v1',p)"));
assert(!/aos_wa_ai_runs_v1[^\n]{0,500}(?:raw_prompt|raw_reply|message_body)/i.test(copilot));

// Least privilege is selective rather than blind RLS churn.
assert(migration.includes('revoke delete,truncate,references,trigger on public.aos_wa_messages_v1 from service_role'));
assert(migration.includes('revoke update,delete,truncate,references,trigger on public.aos_wa_ai_runs_v1 from service_role'));
assert(migration.includes('revoke insert,update,delete,truncate,references,trigger on public.aos_booking_operations_v2 from service_role'));
assert(!/alter\s+table\s+public\.(?:aos_pacientes|aos_ventas|aos_llamadas|aos_leads)\s+.*row\s+level\s+security/is.test(migration));

// Recovery cannot erase consent/security audit history.
assert(rollback.includes('WA_L8_RECOVERY_BLOCKED_AUDIT_HISTORY'));
assert(rollback.includes('Least-privilege revocations are monotonic security hardening'));

// P0 #457: production deploy/readbacks use bounded safety-only status v2.
require('./p0_certification_status_v2_contract');

console.log('WA_L8_STATIC_SECURITY_CONTRACT_PASS');
