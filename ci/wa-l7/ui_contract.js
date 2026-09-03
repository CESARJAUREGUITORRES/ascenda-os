'use strict';
const fs=require('fs');
const path=require('path');
const assert=require('assert/strict');
const root=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const server=read('app/server-wa2.js');
const ui=read('app/public/admin-whatsapp.html');
const sql=read('supabase/migrations/20260903183000_wa_l7_cost_intelligence_v1.sql');
const rollback=read('supabase/rollbacks/20260903183000_wa_l7_cost_intelligence_v1.rollback.sql');

// Server boundary: same admin-whatsapp + 2FA authority and exact UUID-scoped endpoint.
assert.ok(server.includes("const PANEL='admin-whatsapp'"));
assert.ok(server.includes('p_required_panel:PANEL')&&server.includes('p_require_2fa:true'));
assert.ok(server.includes('async function conversationCost(req,res,id)'));
assert.ok(server.includes('if(!UUID_RE.test(id))'));
assert.ok(server.includes('/rest/v1/rpc/aos_wa_l7_journey_cost_v1'));
assert.ok(server.includes('{p_conversation_id:id}'));
assert.ok(server.includes('const mc=u.pathname.match')&&server.includes('cost$/i'));
assert.ok(server.includes('await conversationCost(req,res,mc[1])'));
const inboxFn=server.slice(server.indexOf('async function inboxList'),server.indexOf('async function inboxHealth'));
assert.ok(!inboxFn.includes('aos_wa_l7_'),'L7 must not fan-out into inbox list reads');

// Browser never talks to Supabase directly. L7 is optional, lazy enrichment.
for(const forbidden of ['supabase.co','SUPABASE_SERVICE_ROLE_KEY','SUPABASE_ANON_KEY','/rest/v1/','apikey']){
  assert.ok(!ui.includes(forbidden),`frontend leaks/directly depends on ${forbidden}`);
}
assert.ok(ui.includes('/api/wa/conversations/')&&ui.includes('/cost'));
assert.ok(ui.includes('function loadCost(force)'));
assert.ok(ui.includes('Date.now()-S.costFetchedAt<15000'));
assert.ok(ui.includes('Costos temporalmente no disponibles. El inbox y los mensajes siguen operativos.'));
assert.ok(ui.includes('Se carga de forma diferida para no competir con el inbox.'));
assert.ok(ui.includes('WA-L7 es read-only. SAFE-OFF y autoridad de envío siguen separados.'));
// Completeness is server-driven, not hardcoded UI text: exact values are rendered dynamically.
assert.ok(ui.includes("function stateClass(v){v=String(v||'UNKNOWN').toLowerCase();return v==='known'?'known':v==='partial'?'partial':'unknown'}"));
assert.ok(ui.includes("stateClass(t.state)"));
assert.ok(ui.includes("esc(t.state||'UNKNOWN')"));
assert.ok(ui.includes("esc(m.state||'UNKNOWN')"));
assert.ok(ui.includes("esc(a.state||'UNKNOWN')"));
for(const cssState of ['.coststate.known','.coststate.partial','.coststate.unknown'])assert.ok(ui.includes(cssState));
for(const label of ['Costo/booking','Costo/asistencia','Costo/venta','Ingreso/Costo'])assert.ok(ui.includes(label));
assert.ok(ui.includes('var ms=document.hidden?12000:2500'));
assert.ok(ui.includes('if(!S.active||S.costBusy)return'));
assert.ok(ui.includes('loadMessages();loadCost(false)'));

// Database model is derived/scoped, never a hot-path trigger/materialization.
const lower=sql.toLowerCase();
assert.ok(!lower.includes('create materialized view'));
assert.ok(!lower.includes('refresh materialized view'));
for(const hot of ['aos_wa_messages_v1','aos_wa_ai_runs_v1','aos_booking_operations_v2','aos_agenda_citas','aos_ventas']){
  const rx=new RegExp(`create\\s+trigger[^;]+on\\s+public\\.${hot}\\b`,'is');
  assert.ok(!rx.test(lower),`L7 trigger forbidden on ${hot}`);
}
assert.ok(lower.includes('aos_wa_l7_conversation_cost_v1(p_conversation_id uuid)'));
assert.ok(lower.includes('aos_wa_l7_journey_cost_v1(p_conversation_id uuid)'));
assert.ok(lower.includes('where e.conversation_id=p_conversation_id'));
assert.ok(lower.includes('where j.conversation_id=p_conversation_id'));
for(const state of ['known','partial','unknown'])assert.ok(lower.includes(state));
assert.ok(lower.includes('cost_currency_mismatch_requires_fx'));
assert.ok(lower.includes('revenue_cost_currency_mismatch_requires_fx'));
const joinFilterLines=lower.split(/\r?\n/).filter(line=>/\b(join|where)\b/.test(line));
assert.ok(!joinFilterLines.some(line=>/\b(phone|contact_name|username|bsuid)\b/.test(line)),'L7 DB joins/filters must not use soft identity');

// Recovery preserves canonical source ledgers after pricing history exists.
assert.ok(rollback.includes('WA_L7_RECOVERY_BLOCKED_PRICING_HISTORY'));
for(const protectedLedger of ['aos_wa_messages_v1','aos_wa_ai_runs_v1','aos_booking_operations_v2','aos_agenda_citas','aos_ventas']){
  assert.ok(!rollback.includes(protectedLedger),`rollback must not mutate/drop ${protectedLedger}`);
}
console.log('WA-L7 UI/performance isolation contracts: PASS');
