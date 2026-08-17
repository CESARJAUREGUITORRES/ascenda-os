'use strict';
const fs=require('fs');
function ok(v,m){if(!v)throw new Error(m);}
const phase=fs.readFileSync('app/server-phase-s.js','utf8');
const wa3=fs.readFileSync('app/server-wa3.js','utf8');
const native=fs.readFileSync('app/public/wa-native-panel.js','utf8');
ok(phase.includes('handleCustomerWindowSend'),'Phase S window preflight missing');
ok(phase.includes('WA_CUSTOMER_WINDOW_CLOSED'),'closed-window server code missing');
ok(phase.includes('WHATSAPP_24H_CUSTOMER_SERVICE_WINDOW'),'24h policy marker missing');
ok(phase.includes("select=id,owner_user_id,state,last_inbound_at"),'last inbound server read missing');
ok(phase.includes("/send$/i.test(p))return handleCustomerWindowSend"),'send interception missing');
ok(native.includes('Ventana de WhatsApp cerrada (>24 h)'),'native composer window gate missing');
ok(native.includes("24H '+(windowOpen?'ABIERTA':'CERRADA')"),'native window chip missing');
ok(native.includes('r.last_inbound_at'),'native last inbound policy missing');
ok(wa3.includes('metaDetails'),'Meta error details preservation missing');
ok(wa3.includes("mc?('META_'+mc):'META_SEND_REJECTED'"),'Meta provider code preservation missing');
ok(wa3.includes('provider_http_status:e.metaStatus'),'provider HTTP diagnostic missing');
ok(wa3.includes('provider_details:e.metaDetails'),'provider details response missing');
console.log('WA_CUSTOMER_WINDOW_S10_CONTRACT_PASS');
