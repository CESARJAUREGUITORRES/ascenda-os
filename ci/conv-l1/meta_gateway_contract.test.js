'use strict';

const assert=require('node:assert/strict');
const fs=require('node:fs');

function read(p){return fs.readFileSync(p,'utf8');}

const meta=read('app/meta-cloud-adapter.js');
const f4=read('app/server-f4.js');
const wa3=read('app/server-wa3.js');
const gateway=read('app/wa-gateway.js');
const l0=read('docs/control/ASCENDA_CONVERSATIONS_L0_READINESS_CURRENT.md');
const l1=read('docs/control/ASCENDA_CONVERSATIONS_L1_READINESS_CURRENT.md');
const lock=read('docs/control/ASCENDA_WORKSTREAM_LOCK_CURRENT.md');

assert(meta.includes("hostname:'graph.facebook.com'"),'MetaCloudAdapter must own Meta Graph transport');
assert(meta.includes('verifyWebhook'),'MetaCloudAdapter webhook verify contract missing');
assert(meta.includes('normalizeWebhook'),'MetaCloudAdapter normalization contract missing');
assert(meta.includes('sendPayload'),'MetaCloudAdapter dispatch contract missing');
assert(meta.includes('sendText'),'MetaCloudAdapter text contract missing');
assert(meta.includes('sendMedia'),'MetaCloudAdapter media contract missing');
assert(meta.includes('sendTemplate'),'MetaCloudAdapter template contract missing');
assert(meta.includes('sendInteractive'),'MetaCloudAdapter interactive contract missing');
assert(meta.includes('typing'),'MetaCloudAdapter typing contract missing');
assert(meta.includes('listTemplates'),'MetaCloudAdapter template read-model contract missing');
assert(meta.includes('whatsapp_business_management'),'provider permission health contract missing');
assert(meta.includes('whatsapp_business_messaging'),'provider messaging permission health contract missing');
assert(meta.includes('WHATSAPP_BUSINESS_PORTFOLIO_ID'),'Business Portfolio discovery config missing');
assert(meta.includes('owned_whatsapp_business_accounts'),'owned WABA discovery edge missing');
assert(meta.includes('client_whatsapp_business_accounts'),'client WABA discovery edge missing');
assert(meta.includes("'/phone_numbers?fields='"),'WABA phone ownership match missing');
assert(meta.includes('managementReady'),'provider management readiness contract missing');
assert(meta.includes("'131005'"),'Meta 131005 permission classification missing');

assert(!f4.includes("hostname:'graph.facebook.com'"),'F4 may not own direct Meta Graph HTTPS after L1');
assert(f4.includes("require('./meta-cloud-adapter')"),'F4 must delegate to MetaCloudAdapter');
assert(f4.includes('/api/wa/meta/dispatch-internal'),'F4 internal provider dispatch boundary missing');
assert(f4.includes('/api/wa/meta/health-internal'),'F4 internal provider health boundary missing');
assert(f4.includes('/api/wa/meta/templates-internal'),'F4 internal provider template boundary missing');
assert(f4.includes('/api/wa/meta/reconcile-internal'),'F4 internal provider status reconciliation boundary missing');
assert(f4.includes('WA_PROVIDER_STATUS_RANK'),'monotonic provider status policy missing');
assert(f4.includes('reconcileProviderMessage(String(messageId))'),'F4 post-persist status reconciliation missing');
assert(f4.includes('META_ADAPTER.normalizeWebhook'),'F4 inbound normalization must use MetaCloudAdapter');
assert(f4.includes('META_ADAPTER.verifyWebhook'),'F4 signature verification must use MetaCloudAdapter');

assert(!wa3.includes('graph.facebook.com'),'WA3 may not call Meta directly');
assert(!wa3.includes('WHATSAPP_ACCESS_TOKEN'),'WA3 may not read the Meta access token');
assert(!wa3.includes('WHATSAPP_GRAPH_VERSION'),'WA3 may not own Graph version');
assert(wa3.includes('/api/wa/meta/dispatch-internal'),'WA3 human-send compatibility path must use provider boundary');
assert(wa3.includes('/api/wa/meta/health-internal'),'WA3 provider-health compatibility path must use provider boundary');
assert(wa3.includes('/api/wa/meta/templates-internal'),'WA3 template compatibility path must use provider boundary');
assert(wa3.includes('/api/wa/meta/reconcile-internal'),'WA3 post-persist status reconciliation missing');

assert(gateway.includes("['image','document','audio','video']"),'governed media payloads must include video support');
assert(gateway.includes('provider_timestamp:row.provider_timestamp'),'status event must retain provider timestamp for race reconciliation');
assert(l1.includes('CLOSED · PROVIDER CERTIFIED'),'CONV-L1 provider certification marker missing');
assert(lock.includes('CONV-L3 #507 — SALES AGENT RUNTIME'),'post-L2 L3 workstream lock missing');
assert(lock.includes('RUN UNTIL BLOCKED'),'owner execution mode missing');
assert(l0.includes('L1 OWNER AUTHORIZATION RECEIVED / ACTIVE'),'historical L0->L1 authorization transition missing');

console.log('CONV_L1_META_GATEWAY_CONTRACT_PASS');
