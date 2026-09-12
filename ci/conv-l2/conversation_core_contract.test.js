'use strict';

const assert=require('node:assert/strict');
const fs=require('node:fs');

function read(p){return fs.readFileSync(p,'utf8');}

const core=read('app/conversation-core.js');
const wa3=read('app/server-wa3.js');
const native=read('app/public/wa-native-panel.js');
const standalone=read('app/public/admin-whatsapp-wa3.html');
const multi=read('app/public/wa-multiagent-final-panel.js');
const lock=read('docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md');
const l2=read('docs/control/ASCENDA_CONVERSATIONS_L2_READINESS_CURRENT.md');

assert(core.includes("CORE_VERSION='CONV-L2-V1'"),'L2 core version missing');
assert(core.includes('text/event-stream'),'conversation event stream missing');
assert(core.includes("'conversation.invalidate'"),'invalidation event missing');
assert(core.includes("'conversation.ownership'"),'ownership event missing');
assert(core.includes("'message.accepted'"),'message event missing');
assert(!core.includes('contact_number')&&!core.includes('message_body'),'event stream must not expose message/phone content');

assert(wa3.includes("require('./conversation-core')"),'WA3 must delegate event transport to Conversation Core');
assert(wa3.includes('/api/wa3/events'),'authenticated L2 event endpoint missing');
assert(wa3.includes("core.emit('provider.webhook'"),'provider webhook invalidation missing');
assert(wa3.includes("core.emit('message.accepted'"),'human send invalidation missing');
assert(wa3.includes('fallback_after_ms:30000'),'bounded inbox fallback contract missing');
assert(wa3.includes("'/api/wa/meta/dispatch-internal'"),'certified Meta boundary must remain the only provider dispatch');

assert(native.includes("fetch('/api/wa3/events'"),'native panel event transport missing');
assert(native.includes('AbortController'),'native panel stream cancellation missing');
assert(native.includes('scheduleFallback'),'native panel bounded fallback missing');
assert(!native.includes("setInterval(function(){heartbeat(false);},2500)"),'legacy 2.5s inbox poll still active');
assert(native.includes("CustomEvent('aos:wa3-core-event'"),'native panel core-event fanout missing');

assert(standalone.includes("fetch('/api/wa3/events'"),'standalone panel event transport missing');
assert(!standalone.includes('setInterval(function(){if(document.hidden||S.busy)return;refreshInbox()'),'standalone 3s poll still active');

assert(multi.includes("'aos:wa3-core-event'"),'supervisor panel must consume core invalidation events');
assert(multi.includes('scheduleRefresh(45000)'),'supervisor bounded fallback must be 45s');
assert(!multi.includes('X.pollDelayMs=8000'),'legacy 8s supervisor baseline still active');

assert(lock.includes('CONV-L3 #507 — SALES AGENT RUNTIME'),'post-L2 L3 workstream lock missing');
assert(l2.includes('CONV-L2 #506'),'L2 readiness missing');
assert(l2.includes('**AI autonomy:** SAFE-OFF'),'L2 safety boundary missing');\nassert(l2.includes('CLOSED'),'L2 certified closeout marker missing');

console.log('CONV_L2_CONVERSATION_CORE_CONTRACT_PASS');
