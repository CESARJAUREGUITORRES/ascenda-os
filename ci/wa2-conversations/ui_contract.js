'use strict';
const fs=require('fs');
const html=fs.readFileSync('app/public/admin-whatsapp.html','utf8');
const required=[
  'aos_wa_inbox_v1','aos_wa_conversation_v1','aos_wa_mark_inbox_read_v1','aos_wa_close_conversation_v1',
  '/api/wa/send','X-AOS-App-Token','idempotency_key','admin-chats',
  'setInterval(loadInbox,4000)','setInterval(function(){loadConversation(false)},3000)',
  '72h candidata activa','24h servicio activa','Sin conversaciones'
];
for(const needle of required){if(!html.includes(needle))throw new Error('Missing WA-2 UI contract: '+needle);}
const forbidden=[
  '/rest/v1/aos_wa_conversations_v1','/rest/v1/aos_wa_conversation_events_v1',
  'SUPABASE_SERVICE_ROLE_KEY','WHATSAPP_APP_SECRET','WHATSAPP_ACCESS_TOKEN'
];
for(const needle of forbidden){if(html.includes(needle))throw new Error('Forbidden WA-2 browser contract: '+needle);}
if(!html.includes("sessionStorage.getItem('aos_si_token')")&&!html.includes("sessionStorage.getItem('aos_app_token')"))throw new Error('Strong app token bridge missing');
console.log('WA-2 live inbox UI contracts OK');
