'use strict';

const fs=require('fs');
const assert=require('assert');
const panel=fs.readFileSync('app/public/wa-multiagent-final-panel.js','utf8');

function count(s,n){return s.split(n).length-1;}

// P0 remains present while P1 is additive.
assert(panel.includes('WA-3.5 P0 Revenue Inbox UX'));
assert(panel.includes('__wa35RevenueInboxP0=true'));
assert(panel.includes('__wa35AdvisorProductivityP1=true'));

// Quick replies are composition helpers only; none performs an automatic send.
for(const token of ['Saludo','Objetivo','Horario','Seguimiento','QUICK_REPLIES','insertQuickReply'])assert(panel.includes(token),token);
assert(panel.includes('ta.dispatchEvent(new Event(\'input\',{bubbles:true}))'));
assert(!/function insertQuickReply[\s\S]*?\/api\/wa3\/conversations\//.test(panel),'quick reply must not send automatically');
assert(!panel.includes('precio desde'));
assert(!panel.includes('disponibilidad confirmada'));

// Drafts are scoped by authenticated actor + conversation, bounded and expiring.
assert(panel.includes("'aos_wa_draft_v1:'+String(X.actor&&X.actor.id||'unknown')+':'+String(id||'')"));
assert(panel.includes('Date.now()-ts>86400000'));
assert(panel.includes('.slice(0,4096)'));
assert(panel.includes('localStorage.removeItem(draftKey(id))'));
assert(!panel.includes('aos_app_token') && !panel.includes('aos_si_token'),'draft layer must not read/store auth token');

// Keyboard productivity is explicit and cannot bypass native send governance.
assert(panel.includes("(e.ctrlKey||e.metaKey)&&key==='k'"));
assert(panel.includes("e.altKey&&!e.ctrlKey&&!e.metaKey&&/^[1-4]$/.test"));
assert(panel.includes('Ctrl/⌘+K buscar'));

// P1 must stay on the existing read owner and timer budget.
assert(panel.includes('getInboxSnapshot'));
assert(panel.includes("window.addEventListener('aos:wa3-inbox'"));
assert(!panel.includes("api('/api/wa3/inbox"));
assert(count(panel,'setInterval(')===2,'P1 must not add polling timers');

// Existing authority/security must remain visible in source.
for(const token of ['WA3_NOT_OWNER','/api/wa3/claim-next','/api/wa3/bootstrap','HUMAN_REQUESTED','WAITING_CUSTOMER'])assert(panel.includes(token),token);

// Responsive behavior is basic but explicit.
assert(panel.includes('@media(max-width:900px)'));
assert(panel.includes('@media(max-width:680px)'));

// P1A intentionally does NOT create browser-only internal notes or business truth.
for(const forbidden of ['SUPABASE_SERVICE_ROLE_KEY','/rest/v1/','/rpc/','graph.facebook.com','WHATSAPP_ACCESS_TOKEN','create table','alter table'])assert(!panel.includes(forbidden),forbidden);

console.log('WA35_ADVISOR_PRODUCTIVITY_P1A_CONTRACT_PASS');
