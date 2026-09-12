'use strict';

const https=require('https');
const wa=require('./wa-gateway');
const interactive=require('./wa-interactive');

const SB_URL=String(process.env.SUPABASE_URL||'').replace(/\/$/,'');
const SB_KEY=String(process.env.SUPABASE_SERVICE_ROLE_KEY||'');
const BASE_URL=String(process.env.CONV_L1_BASE_URL||'').replace(/\/$/,'');
const INTERNAL_TOKEN=String(process.env.WA_L4_INTERNAL_TOKEN||'');
const CONVERSATION_ID=String(process.env.CONV_L1_TEST_CONVERSATION_ID||'');
const ACTOR_ID=String(process.env.CONV_L1_TEST_ACTOR_ID||'');
const RUN_KEY=String(process.env.CONV_L1_TEST_RUN_KEY||'');
const TARGET_LABEL=String(process.env.CONV_L1_TARGET_LABEL||'zi vital').trim().toLowerCase();
const ACTION=String(process.env.CONV_L1_REAL_TEST_ACTION||'health').trim().toLowerCase();
const MEDIA_URL=String(process.env.CONV_L1_MEDIA_URL||'https://raw.githubusercontent.com/CESARJAUREGUITORRES/ascenda-os/main/app/public/favicon.png');
const TEMPLATE_NAME=String(process.env.CONV_L1_TEMPLATE_NAME||'').trim();
const TEMPLATE_LANGUAGE=String(process.env.CONV_L1_TEMPLATE_LANGUAGE||'es_PE').trim();

function assertEnv(){
  const missing=[];
  for(const [k,v] of Object.entries({SUPABASE_URL:SB_URL,SUPABASE_SERVICE_ROLE_KEY:SB_KEY,CONV_L1_BASE_URL:BASE_URL,WA_L4_INTERNAL_TOKEN:INTERNAL_TOKEN,CONV_L1_TEST_CONVERSATION_ID:CONVERSATION_ID,CONV_L1_TEST_ACTOR_ID:ACTOR_ID,CONV_L1_TEST_RUN_KEY:RUN_KEY}))if(!v)missing.push(k);
  if(missing.length)throw new Error('MISSING_ENV:'+missing.join(','));
  if(!/^[0-9a-f-]{36}$/i.test(CONVERSATION_ID))throw new Error('INVALID_CONVERSATION_ID');
  if(!/^[0-9a-f-]{36}$/i.test(ACTOR_ID))throw new Error('INVALID_ACTOR_ID');
  if(!/^[A-Za-z0-9._:-]{16,120}$/.test(RUN_KEY))throw new Error('INVALID_RUN_KEY');
  if(!['health','text','image','interactive','template','all'].includes(ACTION))throw new Error('INVALID_ACTION');
}

function requestJson(urlString,options){
  return new Promise((resolve,reject)=>{
    const u=new URL(urlString);const data=options&&options.body!=null?JSON.stringify(options.body):'';
    const headers=Object.assign({'Accept':'application/json'},options&&options.headers||{});
    if(data){headers['Content-Type']='application/json';headers['Content-Length']=Buffer.byteLength(data);}
    const q=https.request({hostname:u.hostname,port:u.port||443,path:u.pathname+u.search,method:(options&&options.method)||'GET',headers,timeout:(options&&options.timeout)||20000},r=>{
      let raw='';r.on('data',c=>raw+=c);r.on('end',()=>{let parsed={};try{parsed=raw?JSON.parse(raw):{};}catch(_){parsed={};}resolve({status:r.statusCode||0,data:parsed});});
    });
    q.on('timeout',()=>q.destroy(new Error('HTTP_TIMEOUT')));q.on('error',reject);if(data)q.write(data);q.end();
  });
}

function sbHeaders(prefer){
  const h={apikey:SB_KEY};
  if(!/^sb_(?:secret|publishable)_/.test(SB_KEY))h.Authorization='Bearer '+SB_KEY;
  if(prefer)h.Prefer=prefer;
  return h;
}
async function sb(method,path,body,prefer){
  const r=await requestJson(SB_URL+path,{method,body,headers:sbHeaders(prefer),timeout:15000});
  if(r.status<200||r.status>=300)throw Object.assign(new Error('SUPABASE_REQUEST_FAILED'),{status:r.status,data:r.data});
  return r.data;
}
async function provider(method,path,body){
  return requestJson(BASE_URL+path,{method,body,headers:{'x-aos-wa-auto-token':INTERNAL_TOKEN},timeout:22000});
}
function redactSummary(obj){
  if(!obj||typeof obj!=='object')return obj;
  return {
    ok:obj.ok===true,diagnosis:obj.diagnosis||null,credentialState:obj.credentialState||null,
    assetState:obj.assetState||null,permissionsState:obj.permissionsState||null,
    businessAccountAvailable:obj.businessAccountAvailable===true,gateway:obj.gateway||null,
    count:Number.isFinite(Number(obj.count))?Number(obj.count):undefined,error:obj.error||null
  };
}
async function safety(){
  const [a,ai,routing,allow]=await Promise.all([
    sb('GET','/rest/v1/aos_wa_auto_authority_v1?select=mode,kill_switch_engaged&id=eq.1'),
    sb('GET','/rest/v1/aos_wa_ai_control_v1?select=auto_reply_enabled&id=eq.1'),
    sb('GET','/rest/v1/aos_wa_routing_control_v1?select=ai_send_enabled,auto_routing_enabled,human_send_enabled&id=eq.1'),
    sb('GET','/rest/v1/aos_wa_auto_allowlist_v1?select=id&active=eq.true')
  ]);
  const out={mode:a&&a[0]&&a[0].mode,kill:!!(a&&a[0]&&a[0].kill_switch_engaged),autoReply:!!(ai&&ai[0]&&ai[0].auto_reply_enabled),aiSend:!!(routing&&routing[0]&&routing[0].ai_send_enabled),autoRouting:!!(routing&&routing[0]&&routing[0].auto_routing_enabled),humanSend:!!(routing&&routing[0]&&routing[0].human_send_enabled),activeAllowlist:Array.isArray(allow)?allow.length:-1};
  if(out.mode!=='AUTO_OFF'||out.kill!==true||out.autoReply!==false||out.aiSend!==false||out.autoRouting!==false||out.humanSend!==true||out.activeAllowlist!==0)throw Object.assign(new Error('AUTONOMY_NOT_SAFE_OFF'),{snapshot:out});
  return out;
}
async function target(){
  const rows=await sb('GET','/rest/v1/aos_wa_conversations_v1?id=eq.'+encodeURIComponent(CONVERSATION_ID)+'&select=id,contact_number,contact_name,state,phone_number_id,last_inbound_at&limit=1');
  const row=Array.isArray(rows)?rows[0]:null;
  if(!row)throw new Error('TEST_CONVERSATION_NOT_FOUND');
  if(String(row.contact_name||'').trim().toLowerCase()!==TARGET_LABEL)throw new Error('TEST_CONVERSATION_LABEL_MISMATCH');
  const to=wa.phoneValue(row.contact_number);if(!to)throw new Error('TEST_CONVERSATION_PHONE_REQUIRED');
  const hours=row.last_inbound_at?(Date.now()-new Date(row.last_inbound_at).getTime())/3600000:null;
  return {id:row.id,to,state:row.state||null,hoursSinceInbound:Number.isFinite(hours)?hours:null};
}
function idempotency(suffix){return ('conv-l1:'+RUN_KEY+':'+suffix).slice(0,120);}
async function reserve(key,target,messageType){
  const payload={idempotency_key:key,actor_id:ACTOR_ID,to_number:target.to,recipient_kind:'PHONE',recipient_address:target.to,message_type:messageType,state:'PENDING',send_origin:'HUMAN',conversation_id:target.id,updated_at:new Date().toISOString()};
  const created=await sb('POST','/rest/v1/aos_wa_outbound_requests_v1?on_conflict=idempotency_key',payload,'resolution=ignore-duplicates,return=representation');
  if(Array.isArray(created)&&created.length===1)return {owner:true,row:created[0]};
  const rows=await sb('GET','/rest/v1/aos_wa_outbound_requests_v1?idempotency_key=eq.'+encodeURIComponent(key)+'&select=idempotency_key,state,provider_message_id,error_code&limit=1');
  return {owner:false,row:Array.isArray(rows)?rows[0]||null:null};
}
async function markRequest(key,state,messageId,error){await sb('PATCH','/rest/v1/aos_wa_outbound_requests_v1?idempotency_key=eq.'+encodeURIComponent(key),{state,provider_message_id:messageId||null,error_code:error||null,updated_at:new Date().toISOString()},'return=minimal');}
async function persistAccepted(key,target,type,body,receipt){
  const now=new Date().toISOString();
  await sb('POST','/rest/v1/aos_wa_messages_v1?on_conflict=provider_message_id',{provider_message_id:receipt.message_id,idempotency_key:key,conversation_id:target.id,direction:'OUTBOUND',from_number:null,to_number:target.to,phone_number_id:receipt.phone_number_id||null,contact_name:null,message_type:type,message_body:body||null,media_id:null,status:'accepted',actor_id:ACTOR_ID,send_origin:'HUMAN',received_at:now,updated_at:now},'resolution=merge-duplicates,return=minimal');
  await sb('POST','/rest/v1/aos_wa_events_v1?on_conflict=event_key',{event_key:'conv-l1-test:'+key,event_type:'message.accepted',provider_message_id:receipt.message_id,status:'accepted',payload:{conversation_id:target.id,source:'CONV_L1_REAL_META_TEST',message_type:type,raw_content_stored:false}},'resolution=ignore-duplicates,return=minimal');
}
async function sendOnce(target,suffix,payload,messageType,messageBody){
  const key=idempotency(suffix);const r=await reserve(key,target,messageType);
  if(!r.owner){const row=r.row||{};if(row.state==='ACCEPTED')return {kind:suffix,idempotent:true,message_id:row.provider_message_id||null,status:'ACCEPTED'};throw new Error('OUTBOUND_RESERVATION_'+String(row.state||'UNKNOWN'));}
  let out;try{out=await provider('POST','/api/wa/meta/dispatch-internal',{payload});}catch(e){throw Object.assign(new Error('PROVIDER_TRANSPORT_AMBIGUOUS'),{cause:e});}
  const d=out.data||{};
  if(out.status>=200&&out.status<300&&d.ok===true&&d.message_id){await markRequest(key,'ACCEPTED',String(d.message_id),null);await persistAccepted(key,target,messageType,messageBody,d);return {kind:suffix,idempotent:false,message_id:String(d.message_id),status:'ACCEPTED',provider_latency_ms:d.provider_latency_ms||0};}
  if(d.ambiguous===true)throw new Error('PROVIDER_AMBIGUOUS_PENDING');
  await markRequest(key,'FAILED',null,String(d.error||'PROVIDER_REJECTED').slice(0,128));
  throw Object.assign(new Error('PROVIDER_REJECTED'),{detail:{status:out.status,error:d.error||null,category:d.category||null}});
}
function hasVariables(tpl){return /\{\{\s*\d+\s*\}\}/.test(JSON.stringify(tpl&&tpl.components||[]));}
async function main(){
  assertEnv();const safe=await safety();
  const health=await provider('GET','/api/wa/meta/health-internal');
  console.log(JSON.stringify({stage:'health',http:health.status,result:redactSummary(health.data),safety:safe}));
  if(health.status<200||health.status>=300||!health.data||health.data.ok!==true)process.exit(3);
  let templateRows=[];const templates=await provider('GET','/api/wa/meta/templates-internal');
  if(templates.status>=200&&templates.status<300&&templates.data&&Array.isArray(templates.data.templates))templateRows=templates.data.templates;
  console.log(JSON.stringify({stage:'templates',http:templates.status,result:redactSummary(Object.assign({},templates.data,{count:templateRows.length})),approved_zero_var:templateRows.filter(t=>String(t.status).toUpperCase()==='APPROVED'&&!hasVariables(t)).map(t=>({name:t.name,language:t.language})).slice(0,20)}));
  if(ACTION==='health')return;
  const t=await target();const results=[];
  if(['text','image','interactive','all'].includes(ACTION)){
    if(!Number.isFinite(t.hoursSinceInbound)||t.hoursSinceInbound>=24)throw new Error('CUSTOMER_WINDOW_CLOSED');
  }
  if(ACTION==='text'||ACTION==='all')results.push(await sendOnce(t,'text',wa.buildOutboundPayload({to:t.to,type:'text',text:'ASCENDA L1 prueba tecnica. Responde L1 OK para validar el inbound del nuevo gateway.'}),'text','ASCENDA L1 prueba tecnica'));
  if(ACTION==='image'||ACTION==='all')results.push(await sendOnce(t,'image',wa.buildOutboundPayload({to:t.to,type:'image',link:MEDIA_URL,caption:'ASCENDA L1 media test'}),'image','ASCENDA L1 media test'));
  if(ACTION==='interactive'||ACTION==='all')results.push(await sendOnce(t,'interactive',interactive.buttons({to:t.to,type:'interactive_buttons',text:'ASCENDA L1 interactive test',buttons:[{id:'conv_l1_ack',title:'L1 OK'}]}),'interactive_buttons','ASCENDA L1 interactive test'));
  if(ACTION==='template'||ACTION==='all'){
    let chosen=null;if(TEMPLATE_NAME)chosen=templateRows.find(x=>x.name===TEMPLATE_NAME&&String(x.status).toUpperCase()==='APPROVED');if(!chosen)chosen=templateRows.find(x=>String(x.status).toUpperCase()==='APPROVED'&&!hasVariables(x));
    if(chosen)results.push(await sendOnce(t,'template',wa.buildOutboundPayload({to:t.to,type:'template',template_name:chosen.name,language:chosen.language||TEMPLATE_LANGUAGE}),'template',null));else console.log(JSON.stringify({stage:'template_send',status:'BLOCKED_NO_APPROVED_ZERO_VARIABLE_TEMPLATE'}));
  }
  console.log(JSON.stringify({stage:'send_complete',action:ACTION,hours_since_inbound:t.hoursSinceInbound==null?null:Number(t.hoursSinceInbound.toFixed(3)),count:results.length,results:results.map(r=>({kind:r.kind,idempotent:r.idempotent,status:r.status,provider_latency_ms:r.provider_latency_ms||0}))}));
}
main().catch(e=>{console.error(JSON.stringify({stage:'fatal',error:String(e.message||e),detail:e.detail||null,safety:e.snapshot||null}));process.exit(2);});
