// ASCENDA OS — WA-2 Conversation Store & Live Inbox secure outer proxy.
'use strict';
const http=require('http');
const https=require('https');
const {spawn}=require('child_process');

const EXTERNAL_PORT=parseInt(process.env.PORT||'4173',10);
const INNER_PORT=EXTERNAL_PORT===4178?4179:4178;
const SB_URL=process.env.SUPABASE_URL||'https://ituyqwstonmhnfshnaqz.supabase.co';
const SB_ANON_KEY=process.env.SUPABASE_ANON_KEY||'';
const SB_SERVICE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY||'';
const PANEL='admin-whatsapp';
const STATES=new Set(['NEW','AI_ACTIVE','HUMAN_REQUESTED','HUMAN_ACTIVE','AI_COPILOT','WAITING_CUSTOMER','APPOINTMENT_PENDING','APPOINTMENT_BOOKED','WON','LOST','CLOSED']);
const UUID_RE=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

// Keep WA-1 as the canonical ingress/outbound boundary. WA-2 only adds governed inbox reads/actions.
const child=spawn(process.execPath,['server-f4.js'],{
  cwd:__dirname,
  env:Object.assign({},process.env,{PORT:String(INNER_PORT)}),
  stdio:['ignore','inherit','inherit']
});
child.on('exit',(code,signal)=>{console.error('[WA2] server-f4 exited',{code,signal});process.exit(code==null?1:code);});

function writeJson(res,status,obj){
  res.writeHead(status,{
    'Content-Type':'application/json; charset=utf-8',
    'Cache-Control':'no-store',
    'X-Content-Type-Options':'nosniff',
    'X-Ascenda-WA2-Inbox':'v1'
  });
  res.end(JSON.stringify(obj));
}
function strongToken(req){const t=String(req.headers['x-aos-app-token']||'').trim();return t.length>=32?t:'';}
function sbRpc(name,payload){
  return new Promise((resolve,reject)=>{
    if(!SB_ANON_KEY){reject(Object.assign(new Error('SUPABASE_ANON_KEY_NOT_CONFIGURED'),{status:503}));return;}
    let sb;try{sb=new URL(SB_URL);}catch(e){reject(e);return;}
    const data=JSON.stringify(payload||{});
    const q=https.request({hostname:sb.hostname,port:sb.port||443,path:'/rest/v1/rpc/'+name,method:'POST',headers:{apikey:SB_ANON_KEY,Authorization:'Bearer '+SB_ANON_KEY,'Content-Type':'application/json','Content-Length':Buffer.byteLength(data),'User-Agent':'AscendaOS-WA2-Inbox/1.0'},timeout:12000},r=>{
      let out='';r.on('data',c=>out+=c);r.on('end',()=>{let parsed=null;try{parsed=out?JSON.parse(out):null;}catch(e){}resolve({status:r.statusCode||502,data:parsed});});
    });
    q.on('timeout',()=>q.destroy(new Error('WA2_AUTH_TIMEOUT')));q.on('error',reject);q.write(data);q.end();
  });
}
function sbService(method,endpoint,body,prefer){
  return new Promise((resolve,reject)=>{
    if(!SB_SERVICE_KEY){reject(Object.assign(new Error('WA2_SERVICE_ROLE_NOT_CONFIGURED'),{status:503}));return;}
    let sb;try{sb=new URL(SB_URL);}catch(e){reject(e);return;}
    const data=body==null?'':JSON.stringify(body);
    const headers={apikey:SB_SERVICE_KEY,Authorization:'Bearer '+SB_SERVICE_KEY,'Content-Type':'application/json','User-Agent':'AscendaOS-WA2-Inbox/1.0'};
    if(data)headers['Content-Length']=Buffer.byteLength(data);if(prefer)headers.Prefer=prefer;
    const q=https.request({hostname:sb.hostname,port:sb.port||443,path:endpoint,method,headers,timeout:12000},r=>{
      let out='';r.on('data',c=>out+=c);r.on('end',()=>{let parsed=null;try{parsed=out?JSON.parse(out):null;}catch(e){}const result={status:r.statusCode||502,data:parsed};if(result.status>=200&&result.status<300)resolve(result);else reject(Object.assign(new Error('WA2_DB_UNAVAILABLE'),{status:502,upstreamStatus:result.status}));});
    });
    q.on('timeout',()=>q.destroy(new Error('WA2_DB_TIMEOUT')));q.on('error',reject);if(data)q.write(data);q.end();
  });
}
async function authorize(req){
  const token=strongToken(req);if(!token)return null;
  try{
    const out=await sbRpc('aos_app_actor_v3',{p_token:token,p_required_panel:PANEL,p_require_2fa:true});
    if(out.status<200||out.status>=300)return null;
    const actor=out.data;
    if(typeof actor!=='string'||!UUID_RE.test(actor))return null;
    // Defense in depth: a panel assignment alone never upgrades a non-admin into the patient inbox.
    const user=await sbService('GET','/rest/v1/aos_usuarios?id=eq.'+encodeURIComponent(actor)+'&select=id,nivel_jerarquia,activo&limit=1',null);
    const row=Array.isArray(user.data)?user.data[0]||null:null;
    if(!row||row.activo!==true||Number(row.nivel_jerarquia||99)>2)return null;
    return actor;
  }catch(e){return null;}
}
function safeLimit(v,max,def){const n=parseInt(v,10);return Number.isFinite(n)&&n>0?Math.min(n,max):def;}
function cleanQuery(v){return String(v||'').trim().toLowerCase().slice(0,80);}
function matchesQuery(row,q){if(!q)return true;return String(row.contact_number||'').toLowerCase().includes(q)||String(row.contact_name||'').toLowerCase().includes(q)||String(row.last_message_preview||'').toLowerCase().includes(q)||String(row.campaign_source||'').toLowerCase().includes(q)||String(row.ad_id||'').toLowerCase().includes(q);}

async function inboxList(req,res,u){
  const actor=await authorize(req);if(!actor){writeJson(res,403,{ok:false,error:'WA2_ADMIN_2FA_REQUIRED'});return;}
  const state=String(u.searchParams.get('state')||'').trim().toUpperCase();
  const unread=u.searchParams.get('unread')==='1';
  const q=cleanQuery(u.searchParams.get('q'));
  const limit=safeLimit(u.searchParams.get('limit'),100,60);
  let endpoint='/rest/v1/aos_wa_conversations_v1?select=id,contact_number,contact_name,phone_number_id,state,last_message_id,last_message_direction,last_message_type,last_message_preview,last_message_status,last_message_at,unread_count,message_count,first_inbound_at,first_outbound_at,last_inbound_at,last_outbound_at,last_read_at,campaign_source,ad_id,lead_id,opened_at,closed_at,version,updated_at&order=last_message_at.desc.nullslast,updated_at.desc&limit=250';
  if(state&&STATES.has(state))endpoint+='&state=eq.'+encodeURIComponent(state);
  if(unread)endpoint+='&unread_count=gt.0';
  try{
    const out=await sbService('GET',endpoint,null);
    const all=Array.isArray(out.data)?out.data:[];
    const rows=all.filter(r=>matchesQuery(r,q)).slice(0,limit);
    const visibleUnread=rows.reduce((n,r)=>n+(Number(r.unread_count||0)>0?1:0),0);
    writeJson(res,200,{ok:true,rows,meta:{returned:rows.length,matched:all.length,unread_conversations:visibleUnread,poll_after_ms:2500}});
  }catch(e){console.error('[WA2] inbox',e.message);writeJson(res,e.status||503,{ok:false,error:'WA2_INBOX_UNAVAILABLE'});}
}
async function inboxHealth(req,res){
  const actor=await authorize(req);if(!actor){writeJson(res,403,{ok:false,error:'WA2_ADMIN_2FA_REQUIRED'});return;}
  try{
    const out=await sbService('GET','/rest/v1/aos_wa_conversations_v1?select=id,state,unread_count,last_message_at&order=last_message_at.desc.nullslast&limit=1000',null);
    const rows=Array.isArray(out.data)?out.data:[];
    const states={};let unread=0;
    rows.forEach(r=>{states[r.state]=(states[r.state]||0)+1;if(Number(r.unread_count||0)>0)unread++;});
    writeJson(res,200,{ok:true,version:'WA2-V1',conversations:rows.length,unread_conversations:unread,states});
  }catch(e){writeJson(res,e.status||503,{ok:false,error:'WA2_INBOX_UNAVAILABLE'});}
}
async function conversationMessages(req,res,id,u){
  const actor=await authorize(req);if(!actor){writeJson(res,403,{ok:false,error:'WA2_ADMIN_2FA_REQUIRED'});return;}
  if(!UUID_RE.test(id)){writeJson(res,400,{ok:false,error:'INVALID_CONVERSATION_ID'});return;}
  const limit=safeLimit(u.searchParams.get('limit'),300,200);
  try{
    const conv=await sbService('GET','/rest/v1/aos_wa_conversations_v1?id=eq.'+encodeURIComponent(id)+'&select=id,contact_number,contact_name,state,unread_count,message_count,campaign_source,ad_id,lead_id,last_message_at,version&limit=1',null);
    const crow=Array.isArray(conv.data)?conv.data[0]||null:null;
    if(!crow){writeJson(res,404,{ok:false,error:'CONVERSATION_NOT_FOUND'});return;}
    const endpoint='/rest/v1/aos_wa_messages_v1?conversation_id=eq.'+encodeURIComponent(id)+'&select=id,provider_message_id,direction,from_number,to_number,contact_name,message_type,message_body,media_id,status,campaign_source,ad_id,lead_id,actor_id,pricing_category,pricing_model,billable,error_code,error_title,provider_timestamp,received_at,sent_at,delivered_at,read_at,failed_at,created_at&order=provider_timestamp.asc.nullsfirst,created_at.asc&limit='+limit;
    const out=await sbService('GET',endpoint,null);
    writeJson(res,200,{ok:true,conversation:crow,messages:Array.isArray(out.data)?out.data:[]});
  }catch(e){console.error('[WA2] messages',e.message);writeJson(res,e.status||503,{ok:false,error:'WA2_MESSAGES_UNAVAILABLE'});}
}
async function conversationCost(req,res,id){
  const actor=await authorize(req);if(!actor){writeJson(res,403,{ok:false,error:'WA2_ADMIN_2FA_REQUIRED'});return;}
  if(!UUID_RE.test(id)){writeJson(res,400,{ok:false,error:'INVALID_CONVERSATION_ID'});return;}
  try{
    const out=await sbService('POST','/rest/v1/rpc/aos_wa_l7_journey_cost_v1',{p_conversation_id:id});
    const payload=out&&out.data;
    if(!payload||typeof payload!=='object'||Array.isArray(payload)){writeJson(res,502,{ok:false,error:'WA_L7_COST_INVALID_RESPONSE'});return;}
    if(payload.ok===false&&payload.error==='WA_L7_CONVERSATION_NOT_FOUND'){writeJson(res,404,payload);return;}
    writeJson(res,200,payload);
  }catch(e){console.error('[WA-L7] conversation cost',e.message);writeJson(res,e.status||503,{ok:false,error:'WA_L7_COST_UNAVAILABLE'});}
}
async function markRead(req,res,id){
  const actor=await authorize(req);if(!actor){writeJson(res,403,{ok:false,error:'WA2_ADMIN_2FA_REQUIRED'});return;}
  if(!UUID_RE.test(id)){writeJson(res,400,{ok:false,error:'INVALID_CONVERSATION_ID'});return;}
  const now=new Date().toISOString();
  try{
    const patched=await sbService('PATCH','/rest/v1/aos_wa_conversations_v1?id=eq.'+encodeURIComponent(id),{unread_count:0,last_read_at:now,last_read_by:actor,updated_at:now},'return=representation');
    const rows=Array.isArray(patched.data)?patched.data:[];
    if(!rows.length){writeJson(res,404,{ok:false,error:'CONVERSATION_NOT_FOUND'});return;}
    await sbService('POST','/rest/v1/aos_wa_conversation_events_v1',{conversation_id:id,event_type:'conversation.read',actor_id:actor,payload:{source:'WA2_LIVE_INBOX'}},'return=minimal');
    writeJson(res,200,{ok:true,conversation_id:id,unread_count:0,last_read_at:now});
  }catch(e){console.error('[WA2] mark read',e.message);writeJson(res,e.status||503,{ok:false,error:'WA2_MARK_READ_UNAVAILABLE'});}
}

// Basic in-memory abuse guard for admin API polling. It never authorizes; auth remains server-side RPC.
const buckets=new Map();
function rateAllowed(req){
  const key=String(req.socket.remoteAddress||'unknown');const now=Date.now();let b=buckets.get(key);
  if(!b||now-b.start>60000){b={start:now,n:0};buckets.set(key,b);}b.n++;
  if(buckets.size>2000){for(const [k,v] of buckets){if(now-v.start>120000)buckets.delete(k);}}
  return b.n<=240;
}
function proxy(req,res){
  const p=http.request({hostname:'127.0.0.1',port:INNER_PORT,path:req.url,method:req.method,headers:req.headers},r=>{res.writeHead(r.statusCode||502,r.headers);r.pipe(res);});
  p.on('error',e=>{console.error('[WA2] proxy',e.message);if(!res.headersSent)writeJson(res,502,{ok:false,error:'WA2_INNER_UNAVAILABLE'});else res.end();});
  req.pipe(p);
}

const server=http.createServer(async(req,res)=>{
  let u;try{u=new URL(req.url,'http://localhost');}catch(e){writeJson(res,400,{ok:false,error:'INVALID_URL'});return;}
  if(u.pathname.startsWith('/api/wa/inbox')||u.pathname.startsWith('/api/wa/conversations/')){
    if(!rateAllowed(req)){writeJson(res,429,{ok:false,error:'WA2_RATE_LIMIT'});return;}
    if(req.method==='GET'&&u.pathname==='/api/wa/inbox'){await inboxList(req,res,u);return;}
    if(req.method==='GET'&&u.pathname==='/api/wa/inbox/health'){await inboxHealth(req,res);return;}
    const mm=u.pathname.match(/^\/api\/wa\/conversations\/([0-9a-f-]+)\/messages$/i);
    if(req.method==='GET'&&mm){await conversationMessages(req,res,mm[1],u);return;}
    const mc=u.pathname.match(/^\/api\/wa\/conversations\/([0-9a-f-]+)\/cost$/i);
    if(req.method==='GET'&&mc){await conversationCost(req,res,mc[1]);return;}
    const mr=u.pathname.match(/^\/api\/wa\/conversations\/([0-9a-f-]+)\/read$/i);
    if(req.method==='POST'&&mr){await markRead(req,res,mr[1]);return;}
    writeJson(res,404,{ok:false,error:'WA2_ROUTE_NOT_FOUND'});return;
  }
  proxy(req,res);
});
server.listen(EXTERNAL_PORT,'0.0.0.0',()=>console.log('[WA2] Live Inbox proxy listening on',EXTERNAL_PORT,'-> WA1',INNER_PORT));

function shutdown(sig){console.log('[WA2] shutdown',sig);try{child.kill(sig)}catch(e){}server.close(()=>process.exit(0));setTimeout(()=>process.exit(1),5000).unref();}
process.on('SIGTERM',()=>shutdown('SIGTERM'));process.on('SIGINT',()=>shutdown('SIGINT'));