'use strict';
const fs = require('fs');
const assert = require('assert');
function read(p){ return fs.readFileSync(p,'utf8'); }
const shell = read('app/public/wa-shell-integration.js');
const panel = read('app/public/wa-multiagent-v2-panel.js');
const server = read('app/server-wa3-v2.js');
const wa4 = read('app/server-wa4.js');

assert(shell.includes("MULTI_SRC='/wa-multiagent-v2-panel.js?v=20260822-wa3-multiagent-v2-p03'"));
assert(shell.includes('function ensureMulti()'));
assert(shell.includes('return ensureMulti();'));
assert(shell.includes("PUSH_SRC='/notification-push-s14.js?v=20260818-s15-5-shell-mount-p01'"));
assert(shell.includes('ensurePush().catch'));

for (const token of ['AVAILABLE','AWAY','OFFLINE','/api/wa3/queue-summary','/api/wa3/presence','/api/wa3/claim-next','/api/wa3/team-summary','Tomar siguiente','Equipo WA','WA3_NOT_OWNER','ownershipLostRemount','wa3v2-owner-chip','Meta aceptó el mensaje','5000','syncChip','desired=o.dataset.baseLabel']) {
  assert(panel.includes(token), token);
}
for (const forbidden of ['contact_number','message_body','conversation_id']) {
  assert(!panel.includes(forbidden), forbidden);
}
assert(panel.includes("d.error==='WA3_NOT_OWNER'"));
assert(panel.includes("new Response(JSON.stringify({ok:true,messages:[],ownership_lost:true})"));
assert(panel.includes("t.classList.contains('ok')&&/^Meta aceptó el mensaje/"));
assert(panel.includes("X.timer=setInterval(function(){if(!document.hidden)refresh();},5000)"));
assert(panel.includes("var disabled=a.effective_status!=='AVAILABLE'&&!o.selected"));
assert(panel.includes("if(o.disabled!==disabled)o.disabled=disabled"));
assert(panel.includes("if(old&&old.textContent===lab.text&&old.className===cls)return"));
assert(panel.includes("if(o.textContent!==desired)o.textContent=desired"));

assert(server.includes("['server-wa3.js']"));
assert(server.includes("'/api/wa3/queue-summary'"));
assert(server.includes("'/api/wa3/team-summary'"));
assert(server.includes("'/api/wa3/presence'"));
assert(server.includes("'/api/wa3/claim-next'"));
assert(server.includes('requireActor(req,res,true)'));
assert(server.includes("privacy:'NO_CUSTOMER_DATA'"));
assert(!server.includes('contact_number'));
assert(!server.includes('message_body'));

assert(server.includes("const crypto=require('crypto')"));
assert(server.includes("crypto.createHash('sha256').update(token)"));
assert(server.includes("const scope=read?'read':'write'"));
assert(server.includes("const limit=read?600:120"));
assert(!server.includes("const key=String(req.socket.remoteAddress||'unknown'),now=Date.now()"));

assert(wa4.includes("['server-wa3-v2.js']"));
assert(wa4.includes('Copilot only'));
console.log('WA-3 V2 UI/boundary contract: PASS');
