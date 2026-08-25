'use strict';

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', '..');
const uiPath = path.join(root, 'app', 'public', 'wa-multiagent-final-panel.js');
const nativePath = path.join(root, 'app', 'public', 'wa-native-panel.js');
const previewPath = path.join(root, 'ci', 'wa3-5-revenue-inbox', 'preview.html');

const ui = fs.readFileSync(uiPath, 'utf8');
const native = fs.readFileSync(nativePath, 'utf8');
const preview = fs.readFileSync(previewPath, 'utf8');

function assert(cond, message) {
  if (!cond) {
    console.error('WA35_P0_CONTRACT_FAIL:', message);
    process.exit(1);
  }
}

function occurrences(text, needle) {
  return text.split(needle).length - 1;
}

// Product identity / boundary
assert(ui.includes('WA-3.5 P0 Revenue Inbox UX'), 'missing WA-3.5 P0 identity');
assert(ui.includes('__wa35RevenueInboxP0=true'), 'missing P0 runtime marker');

// Reuse the already-certified inbox transport instead of adding a second inbox poller.
assert(ui.includes("window.addEventListener('aos:wa3-inbox'"), 'must consume native inbox event');
assert(ui.includes('getInboxSnapshot'), 'must reuse native inbox snapshot');
assert(!ui.includes("api('/api/wa3/inbox"), 'multiagent P0 must not fetch inbox directly');
assert(!ui.includes("fetch('/api/wa3/inbox"), 'multiagent P0 must not fetch inbox directly');
assert(occurrences(ui, 'setInterval(') === 2, 'unexpected polling/timer added to multiagent layer');
assert(native.includes("api('/api/wa3/inbox?limit=120')"), 'certified native inbox owner missing');

// Canonical Revenue Inbox filters only.
[
  "['all','Todos']",
  "['mine','Míos']",
  "['handoff','Requieren humano']",
  "['unread','No leídos']",
  "['waiting','Esperando cliente']",
  "['bot','Bot / IA']",
  "['closed','Finalizados']",
  "row.state==='HUMAN_REQUESTED'",
  "row.state==='WAITING_CUSTOMER'",
  "['WON','LOST','CLOSED']",
  "s==='NEW'||s==='AI_ACTIVE'"
].forEach(s => assert(ui.includes(s), 'missing canonical filter contract: ' + s));

// Revenue context must be sourced from existing canonical fields.
[
  'campaign_source',
  'last_message_direction',
  'last_message_at',
  'last_inbound_at',
  'handoff_requested_at',
  'owner_user_id',
  'unread_count'
].forEach(s => assert(ui.includes(s), 'missing canonical inbox field: ' + s));

assert(ui.includes('Todas las campañas'), 'campaign selector missing');
assert(ui.includes('Campaña · '), 'campaign card badge missing');
assert(ui.includes('24H '), '24h window badge missing');
assert(ui.includes('Espera humano'), 'handoff age badge missing');
assert(ui.includes('← Cliente'), 'inbound direction badge missing');
assert(ui.includes('→ Equipo'), 'outbound direction badge missing');

// Existing security/ownership controls remain intact.
assert(ui.includes('WA3_NOT_OWNER'), 'ownership-loss guard removed');
assert(ui.includes('/api/wa3/claim-next'), 'claim flow removed');
assert(ui.includes('/api/wa3/bootstrap'), 'strong WA3 bootstrap removed');

// P0 is UI/read-model only: no direct DB, schema, provider or secret handling.
[
  'SUPABASE_SERVICE_ROLE_KEY',
  '/rest/v1/',
  '/rpc/',
  'graph.facebook.com',
  'WHATSAPP_ACCESS_TOKEN',
  'create table',
  'alter table'
].forEach(s => assert(!ui.includes(s), 'forbidden P0 dependency found: ' + s));

// Offline preview must remain synthetic and cloud-independent.
assert(preview.includes('OFFLINE FIXTURE ONLY'), 'offline preview boundary missing');
assert(preview.includes('HUMAN_REQUESTED'), 'preview lacks human-requested fixture');
assert(preview.includes('WAITING_CUSTOMER'), 'preview lacks waiting-customer fixture');
assert(preview.includes('AI_ACTIVE'), 'preview lacks bot/AI fixture');
assert(preview.includes("state:'WON'"), 'preview lacks finalised fixture');
assert(preview.includes('campaign_source'), 'preview lacks campaign provenance fixture');
[
  'supabase.co',
  'graph.facebook.com',
  'SUPABASE_',
  'WHATSAPP_ACCESS_TOKEN'
].forEach(s => assert(!preview.includes(s), 'offline preview must not depend on cloud/provider: ' + s));

console.log('WA35_REVENUE_INBOX_P0_CONTRACT_PASS');
