'use strict';
const fs=require('fs');
const assert=require('assert');
function read(p){return fs.readFileSync(p,'utf8');}
function count(s,n){return s.split(n).length-1;}

const shell=read('app/public/wa-shell-integration.js');
const panel=read('app/public/wa-multiagent-final-panel.js');
const p2=read('app/public/wa-revenue-inbox-closeout.js');
const patient=read('supabase/migrations/20260821032000_rev_f6_1_patient_360_current_v3.sql');
const p0=read('ci/wa3-5-revenue-inbox/p0_contract.js');
const p1=read('ci/wa3-5-advisor-productivity/p1a_contract.js');

// Loader order + cache invalidation: certified P0/P1 must actually reach browsers.
assert(shell.includes("MULTI_SRC='/wa-multiagent-final-panel.js?v=20260824-wa35-p1a-p01'"));
assert(shell.includes("CLOSEOUT_SRC='/wa-revenue-inbox-closeout.js?v=20260824-wa35-closeout-p01'"));
assert(shell.includes('function ensureCloseout()'));
assert(shell.includes('return ensureCloseout();'));
assert(shell.indexOf('return ensureMulti();') < shell.indexOf('return ensureCloseout();'));
assert(shell.includes('__wa35CloseoutP2'));

// P0 + P1 remain additive foundations.
assert(panel.includes('__wa35RevenueInboxP0=true'));
assert(panel.includes('__wa35AdvisorProductivityP1=true'));
assert(p0.includes('WA35_REVENUE_INBOX_P0_CONTRACT_PASS'));
assert(p1.includes('WA35_ADVISOR_PRODUCTIVITY_P1A_CONTRACT_PASS'));

// P2 right-panel target is explicit.
for(const token of ['DETAILS','CUSTOMER 360','CAMPAIGN','ACTIVITY','COPILOT','wa35-context-toggle','wa35-context-open']) assert(p2.includes(token),token);
assert(p2.includes('@media(max-width:900px)'));

// Customer 360 is canonical, role-gated and ON-DEMAND only.
assert(p2.includes("window._rpc('aos_patient_search_v2'"));
assert(p2.includes("window._rpc('aos_patient_360_current_v3'"));
assert(p2.includes("S.tab==='customer'"));
assert(p2.includes('canPatient360()'));
assert(p2.includes("p.indexOf('advisor-patients')"));
assert(p2.includes("p.indexOf('admin-patients')"));
assert(p2.includes("search.lookup_status==='IDENTITY_CONFLICT'"));
assert(patient.includes('create or replace function public.aos_patient_360_current_v3'));
assert(patient.includes("aos_app_actor_v3(p_token,'advisor-patients',true)"));
assert(patient.includes("aos_app_actor_v3(p_token,'admin-patients',true)"));
assert(patient.includes("'clinical_access',(v_admin is not null)"));

// WA projects a deliberately narrow commercial subset; no clinical notes/docs/PII expansion.
for(const forbidden of ['d.notas','d.documentos','p.dni','p.correo','p.notas','p.trat_principal','p.contacto_emergencia']) assert(!p2.includes(forbidden),forbidden);
assert(p2.includes('Sin notas clínicas, documentos ni PHI adicional'));

// Campaign provenance remains factual and hands expansion to WA-7A.
for(const token of ['campaign_source','ad_id','lead_id','Boundary WA-7A','no infiere atribución por teléfono']) assert(p2.includes(token),token);

// Activity uses canonical conversation milestones only.
for(const token of ['opened_at','first_inbound_at','first_outbound_at','handoff_requested_at','human_takeover_at','last_inbound_at','last_outbound_at','last_read_at','closed_at','updated_at']) assert(p2.includes(token),token);

// Copilot is a visible boundary, not a hidden AI feature.
for(const token of ["kv('ai_send','false')","kv('copilot','false')","kv('auto_reply','false')",'WA-4A → WA-4B → WA-4C','COPILOT SAFE-OFF']) assert(p2.includes(token),token);
assert(!p2.includes('auto_reply=true'));
assert(!p2.includes('ai_send=true'));
assert(!p2.includes('copilot=true'));

// P2 owns no transport/provider/backend loop. The one setInterval is bounded startup enhancement retry only.
assert(!p2.includes('fetch('));
assert(!p2.includes('/api/'));
assert(!p2.includes('SUPABASE_SERVICE_ROLE_KEY'));
assert(!p2.includes('WHATSAPP_ACCESS_TOKEN'));
assert(!p2.includes('graph.facebook.com'));
assert(count(p2,'setInterval(')===1,'P2 may only use the bounded startup enhancement retry');
assert(p2.includes('tries>60'));
assert(p2.includes("window.addEventListener('aos:wa3-inbox'"));
assert(p2.includes('getInboxSnapshot'));

// Internal notes are intentionally not browser truth.
assert(!p2.includes('aos_wa_note'));
assert(!p2.includes('internal_note'));

console.log('WA35_CLOSEOUT_P2_CONTRACT_PASS');
