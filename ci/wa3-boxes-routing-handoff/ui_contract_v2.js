'use strict';
const fs = require('fs');
const assert = require('assert');
function read(p){ return fs.readFileSync(p,'utf8'); }
const shell = read('app/public/wa-shell-integration.js');
const panel = read('app/public/wa-multiagent-v2-panel.js');
const server = read('app/server-wa3-v2.js');
const wa4 = read('app/server-wa4.js');

assert(shell.includes("MULTI_SRC='/wa-multiagent-v2-panel.js?v=20260822-wa3-multiagent-v2-p01'"));
assert(shell.includes('function ensureMulti()'));
assert(shell.includes('return ensureMulti();'));
assert(shell.includes("PUSH_SRC='/notification-push-s14.js?v=20260818-s15-5-shell-mount-p01'"));
assert(shell.includes('ensurePush().catch'));

for (const token of ['AVAILABLE','AWAY','OFFLINE','/api/wa3/queue-summary','/api/wa3/presence','/api/wa3/claim-next','/api/wa3/team-summary','Tomar siguiente','Equipo WA']) {
  assert(panel.includes(token), token);
}
for (const forbidden of ['contact_number','message_body','conversation_id']) {
  assert(!panel.includes(forbidden), forbidden);
}

assert(server.includes("['server-wa3.js']"));
assert(server.includes("'/api/wa3/queue-summary'"));
assert(server.includes("'/api/wa3/team-summary'"));
assert(server.includes("'/api/wa3/presence'"));
assert(server.includes("'/api/wa3/claim-next'"));
assert(server.includes('requireActor(req,res,true)'));
assert(server.includes("privacy:'NO_CUSTOMER_DATA'"));
assert(!server.includes('contact_number'));
assert(!server.includes('message_body'));
assert(wa4.includes("['server-wa3-v2.js']"));
assert(wa4.includes('Copilot only'));
console.log('WA-3 V2 UI/boundary contract: PASS');
