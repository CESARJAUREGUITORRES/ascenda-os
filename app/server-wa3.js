'use strict';
// ASCENDA Conversations — WA-3 outer proxy: boxes, routing, ownership and human handoff.
const http=require('http');
const https=require('https');
const fs=require('fs');
const path=require('path');
const {spawn}=require('child_process');
const wa=require('./wa-gateway');

const EXTERNAL_PORT=parseInt(process.env.PORT||'4173',10);
const INNER_PORT=EXTERNAL_PORT===4196?4197:4196;
const SB_URL=process.env.SUPABASE_URL||'https://ituyqwstonmhnfshnaqz.supabase.co';
const SB_ANON_KEY=process.env.SUPABASE_ANON_KEY||'';
const SB_SERVICE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY||'';
const WA_ACCESS_TOKEN=process.env.WHATSAPP_ACCESS_TOKEN||'';
const WA_PHONE_NUMBER_ID=process.env.WHATSAPP_PHONE_NUMBER_ID||'';
const WA_GRAPH_VERSION=process.env.WHATSAPP_GRAPH_VERSION||'';
const WA_CANARY_MODE=process.env.WA_CANARY_MODE||'true';
const WA_CANARY_ALLOW_TO=process.env.WA_CANARY_ALLOW_TO||'';
const UUID_RE=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const child=spawn(process.execPath,['server-wa2.js'],{cwd:__dirname,env:Object.assign({},process.env,{PORT:String(INNER_PORT)}),stdio:['ignore','inherit','inherit']});
child.on('exit',(code,signal)=>{console.error('[WA3] server-wa2 exited',{code,signal});process.exit(code==null?1:code);});

function writeJson(res,status,obj){res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','X-Ascenda-WA3-Routing':'v1'});res.end(JSON.stringify(obj));}
function readJson(req,maxBytes=256*1024){return new Promise((resolve,reject)=>{let raw='',overflow=false;req.on('data',c=>{if(overflow)return;raw+=c;if(Buffer.byteLength(raw)>maxBytes)overflow=true;});req.on('end',()=>{if(overflow)return reject(Object.assign(new Error('PAYLOAD_TOO_LARGE'),{status:413}));try{resolve(JSON.parse(raw||'{}'));}catch(e){reject(Object.assign(new Error('INVALID_JSON'),{status:400}));}});req.on('error',reject);});}
function strongToken(req){const t=String(req.headers['x-aos-app-token']||'').trim();return t.length>=32?t:'';}
function parseData(raw){try{return raw?JSON.parse(raw):null}catch(e){return null}}
function sbRequest(method,endpoint,body,useService,prefer){return new Promise((resolve,reject)=>{
  const key=useService?SB_SERVICE_KEY:SB_ANON_KEY;if(!key)return reject(Object.assign(new Error(useService?'SUPABASE_SERVICE_ROLE_NOT_CONFIGURED':'SUPABASE_ANON_KEY_NOT_CONFIGURED'),{status:503}));
  let sb;try{sb=new URL(SB_URL)}catch(e){return reject(e)}const data=body==null?'':JSON.stringify(body);const headers={apikey:key,Authorization:'Bearer '+key,'Content-Type':'application/json','User-Agent':'AscendaOS-WA3/1.0'};if(data)headers['Content-Length']=Buffer.byteLength(data);if(prefer)headers.Prefer=prefer;
  const q=https.request({hostname:sb.hostname,port:sb.port||443,path:endpoint,method,headers,timeout:12000},r=>{let raw='';r.on('data',c=>raw+=c);r.on('end',()=>{const out={status:r.statusCode||502,data:parseData(raw),raw};if(out.status>=200&&out.status<300)resolve(out);else reject(Object.assign(new Error('WA3_DB_UNAVAILABLE'),{status:502,upstreamStatus:out.status,data:out.data}));});});q.on('timeout',()=>q.destroy(new Error('WA3_DB_TIMEOUT')));q.on('error',reject);if(data)q.write(data);q.end();
});}
function sbRpc(name,payload){return sbRequest('POST','/rest/v1/rpc/'+name,payload,false);}
function serviceRpc(name,payload){return sbRequest('POST','/rest/v1/rpc/'+name,payload,true);}
function serviceGet(endpoint){return sbRequest('GET',endpoint,null,true);}
async function actor(req){const token=strongToken(req);if(!token)return null;try{const out=await sbRpc('aos_wa3_actor_v1',{p_token:token});const a=out.data;return a&&a.ok===true&&UUID_RE.test(String(a.actor_id||''))?a:null}catch(e){return null}}
async function requireActor(req,res,adminOnly){const a=await actor(req);if(!a){writeJson(res,403,{ok:false,error:'WA3_2FA_PANEL_REQUIRED'});return null}if(adminOnly&&a.is_admin!==true){writeJson(res,403,{ok:false,error:'WA3_ADMIN_REQUIRED'});return null}return a;}
function safeLimit(v,max,def){const n=parseInt(v,10);return Number.isFinite(n)&&n>0?Math.min(n,max):def;}

async function bootstrap(req,res){const a=await requireActor(req,res,false);if(!a)return;try{
  const [control,boxes,members,users]=await Promise.all([
    serviceGet('/rest/v1/aos_wa_routing_control_v1?select=auto_routing_enabled,human_send_enabled,ai_send_enabled,updated_at&id=eq.1'),
    serviceGet('/rest/v1/aos_wa_boxes_v1?select=id,code,name,status,routing_strategy,is_default,priority,updated_at&order=is_default.desc,priority.desc,name.asc'),
    serviceGet('/rest/v1/aos_wa_box_members_v1?select=box_id,user_id,active,max_active,priority,last_assigned_at&order=priority.desc,last_assigned_at.asc.nullsfirst'),
    serviceGet('/rest/v1/aos_usuarios?select=id,nombre,rol,cargo,sede,activo,nivel_jerarquia,paneles_acceso&activo=eq.true&order=nombre.asc')
  ]);
  let boxRows=Array.isArray(boxes.data)?boxes.data:[],memberRows=Array.isArray(members.data)?members.data:[],userRows=Array.isArray(users.data)?users.data:[];
  if(a.is_admin!==true){memberRows=memberRows.filter(m=>m.user_id===a.actor_id&&m.active===true);const ids=new Set(memberRows.map(m=>m.box_id));boxRows=boxRows.filter(b=>ids.has(b.id));userRows=userRows.filter(u=>u.id===a.actor_id);}
  const me=userRows.find(u=>u.id===a.actor_id)||{id:a.actor_id};
  if(a.is_admin!==true)userRows=userRows.map(u=>({id:u.id,nombre:u.nombre,rol:u.rol,cargo:u.cargo,sede:u.sede,activo:u.activo,nivel_jerarquia:u.nivel_jerarquia}));
  writeJson(res,200,{ok:true,version:'WA3-V1',actor:{id:a.actor_id,is_admin:a.is_admin===true,name:me.nombre||null},control:(Array.isArray(control.data)?control.data[0]:null)||{},boxes:boxRows,members:memberRows,users:userRows,canary:{enabled:String(WA_CANARY_MODE).toLowerCase()==='true',allowlist_count:String(WA_CANARY_ALLOW_TO).split(',').filter(Boolean).length}});
}catch(e){console.error('[WA3] bootstrap',e.message);writeJson(res,503,{ok:false,error:'WA3_BOOTSTRAP_UNAVAILABLE'});}}

const CONV_SELECT='id,contact_number,contact_name,phone_number_id,state,last_message_id,last_message_direction,last_message_type,last_message_preview,last_message_status,last_message_at,unread_count,message_count,first_inbound_at,first_outbound_at,last_inbound_at,last_outbound_at,last_read_at,campaign_source,ad_id,lead_id,opened_at,closed_at,version,box_id,owner_user_id,ownership_version,handoff_requested_at,human_takeover_at,updated_at';
async function inbox(req,res,u){const a=await requireActor(req,res,false);if(!a)return;const limit=safeLimit(u.searchParams.get('limit'),150,80);let ep='/rest/v1/aos_wa_conversations_v1?select='+CONV_SELECT+'&order=last_message_at.desc.nullslast,updated_at.desc&limit='+limit;if(a.is_admin!==true)ep+='&owner_user_id=eq.'+encodeURIComponent(a.actor_id);try{const out=await serviceGet(ep);writeJson(res,200,{ok:true,rows:Array.isArray(out.data)?out.data:[],actor:{id:a.actor_id,is_admin:a.is_admin===true},poll_after_ms:2500});}catch(e){writeJson(res,503,{ok:false,error:'WA3_INBOX_UNAVAILABLE'});}}
async function canReadConversation(a,id){const out=await serviceGet('/rest/v1/aos_wa_conversations_v1?id=eq.'+encodeURIComponent(id)+'&select=id,owner_user_id,box_id,state&limit=1');const row=Array.isArray(out.data)?out.data[0]||null:null;if(!row)return {ok:false,row:null};return {ok:a.is_admin===true||row.owner_user_id===a.actor_id,row};}
async function messages(req,res,id,u){const a=await requireActor(req,res,false);if(!a)return;if(!UUID_RE.test(id))return writeJson(res,400,{ok:false,error:'INVALID_CONVERSATION_ID'});try{const read=await canReadConversation(a,id);if(!read.row)return writeJson(res,404,{ok:false,error:'CONVERSATION_NOT_FOUND'});if(!read.ok)return writeJson(res,403,{ok:false,error:'WA3_NOT_OWNER'});const limit=safeLimit(u.searchParams.get('limit'),300,200);const out=await serviceGet('/rest/v1/aos_wa_messages_v1?conversation_id=eq.'+encodeURIComponent(id)+'&select=id,provider_message_id,direction,from_number,to_number,contact_name,message_type,message_body,status,actor_id,provider_timestamp,received_at,sent_at,delivered_at,read_at,failed_at,created_at&order=provider_timestamp.asc.nullsfirst,created_at.asc&limit='+limit);writeJson(res,200,{ok:true,conversation:read.row,messages:Array.isArray(out.data)?out.data:[]});}catch(e){writeJson(res,503,{ok:false,error:'WA3_MESSAGES_UNAVAILABLE'});}}

async function mutation(req,res,rpc,payload,adminOnly){const a=await requireActor(req,res,!!adminOnly);if(!a)return;payload=Object.assign({},payload||{}, {p_actor_id:a.actor_id});try{const out=await serviceRpc(rpc,payload);const d=out.data||{};writeJson(res,d.ok===false?409:200,d);}catch(e){console.error('[WA3] mutation',rpc,e.message);writeJson(res,503,{ok:false,error:'WA3_MUTATION_UNAVAILABLE'});}}
async function boxUpsert(req,res,body){await mutation(req,res,'aos_wa3_box_upsert_v1',{p_box_id:body.box_id||null,p_code:String(body.code||''),p_name:String(body.name||''),p_strategy:String(body.strategy||'MANUAL').toUpperCase(),p_status:String(body.status||'ACTIVE').toUpperCase(),p_is_default:body.is_default===true,p_priority:Number.isFinite(Number(body.priority))?Number(body.priority):0},true);}
async function memberSet(req,res,body){if(!UUID_RE.test(String(body.box_id||''))||!UUID_RE.test(String(body.user_id||'')))return writeJson(res,400,{ok:false,error:'INVALID_MEMBER_INPUT'});await mutation(req,res,'aos_wa3_box_member_set_v1',{p_box_id:body.box_id,p_user_id:body.user_id,p_active:body.active!==false,p_max_active:body.max_active==null?null:Number(body.max_active),p_priority:Number.isFinite(Number(body.priority))?Number(body.priority):0},true);}
async function setControl(req,res,body){await mutation(req,res,'aos_wa3_admin_set_control_v1',{p_auto_routing_enabled:typeof body.auto_routing_enabled==='boolean'?body.auto_routing_enabled:null,p_human_send_enabled:typeof body.human_send_enabled==='boolean'?body.human_send_enabled:null},true);}
async function route(req,res,id,body){if(!UUID_RE.test(id)||!UUID_RE.test(String(body.box_id||'')))return writeJson(res,400,{ok:false,error:'INVALID_ROUTE_INPUT'});const owner=body.owner_user_id||null;if(owner&&!UUID_RE.test(String(owner)))return writeJson(res,400,{ok:false,error:'INVALID_OWNER'});await mutation(req,res,'aos_wa3_route_v1',{p_conversation_id:id,p_box_id:body.box_id,p_owner_user_id:owner,p_reason:String(body.reason||'ADMIN_ROUTE').slice(0,160)},true);}
async function claimNext(req,res,body){if(!UUID_RE.test(String(body.box_id||'')))return writeJson(res,400,{ok:false,error:'INVALID_BOX_ID'});await mutation(req,res,'aos_wa3_claim_next_v1',{p_box_id:body.box_id},false);}
async function release(req,res,id,body){if(!UUID_RE.test(id))return writeJson(res,400,{ok:false,error:'INVALID_CONVERSATION_ID'});await mutation(req,res,'aos_wa3_release_v1',{p_conversation_id:id,p_reason:String(body.reason||'HUMAN_RELEASE').slice(0,160)},false);}
async function setMode(req,res,id,body){if(!UUID_RE.test(id))return writeJson(res,400,{ok:false,error:'INVALID_CONVERSATION_ID'});await mutation(req,res,'aos_wa3_set_mode_v1',{p_conversation_id:id,p_mode:String(body.mode||'').toUpperCase()},false);}

function waConfigReadyOutbound(){return !!(WA_ACCESS_TOKEN&&WA_PHONE_NUMBER_ID&&/^v\d+\.\d+$/.test(WA_GRAPH_VERSION)&&SB_SERVICE_KEY);}
function graphSend(payload){return new Promise((resolve,reject)=>{if(!waConfigReadyOutbound())return reject(Object.assign(new Error('WA_OUTBOUND_NOT_CONFIGURED'),{status:503,definite:true}));const data=JSON.stringify(payload);const q=https.request({hostname:'graph.facebook.com',path:'/'+WA_GRAPH_VERSION+'/'+encodeURIComponent(WA_PHONE_NUMBER_ID)+'/messages',method:'POST',headers:{Authorization:'Bearer '+WA_ACCESS_TOKEN,'Content-Type':'application/json','Content-Length':Buffer.byteLength(data),'User-Agent':'AscendaOS-WA3/1.0'},timeout:15000},r=>{let raw='';r.on('data',c=>raw+=c);r.on('end',()=>{const d=parseData(raw)||{};if(r.statusCode>=200&&r.statusCode<300)resolve(d);else reject(Object.assign(new Error('META_SEND_REJECTED'),{status:502,definite:true,metaStatus:r.statusCode}));});});q.on('timeout',()=>q.destroy(Object.assign(new Error('META_SEND_TIMEOUT'),{status:504,ambiguous:true})));q.on('error',e=>reject(Object.assign(e,{status:e.status||502,ambiguous:e.definite!==true})));q.write(data);q.end();});}
async function reserveOutbound(key,actorId,payload){const created=await sbRequest('POST','/rest/v1/aos_wa_outbound_requests_v1?on_conflict=idempotency_key',{idempotency_key:key,actor_id:actorId,to_number:payload.to,message_type:payload.type,state:'PENDING',updated_at:new Date().toISOString()},true,'resolution=ignore-duplicates,return=representation');if(Array.isArray(created.data)&&created.data.length===1)return {owner:true,row:created.data[0]};const existing=await serviceGet('/rest/v1/aos_wa_outbound_requests_v1?idempotency_key=eq.'+encodeURIComponent(key)+'&select=idempotency_key,state,provider_message_id,error_code&limit=1');return {owner:false,row:Array.isArray(existing.data)?existing.data[0]||null:null};}
async function ownedSend(req,res,id,body){if(!UUID_RE.test(id))return writeJson(res,400,{ok:false,error:'INVALID_CONVERSATION_ID'});const token=strongToken(req);if(!token)return writeJson(res,403,{ok:false,error:'WA3_2FA_PANEL_REQUIRED'});if(!wa.validIdempotencyKey(body&&body.idempotency_key))return writeJson(res,400,{ok:false,error:'IDEMPOTENCY_KEY_REQUIRED'});const text=String(body&&body.text||'').trim().slice(0,4096);if(!text)return writeJson(res,400,{ok:false,error:'TEXT_REQUIRED'});if(!waConfigReadyOutbound())return writeJson(res,503,{ok:false,error:'WA_OUTBOUND_NOT_CONFIGURED'});
  let auth;try{const out=await sbRpc('aos_wa3_human_send_authorize_v1',{p_token:token,p_conversation_id:id});auth=out.data||{};}catch(e){return writeJson(res,503,{ok:false,error:'WA3_SEND_AUTH_UNAVAILABLE'});}if(auth.ok!==true)return writeJson(res,403,{ok:false,error:auth.error||'WA3_SEND_FORBIDDEN'});
  let payload;try{payload=wa.buildOutboundPayload({to:auth.to_number,type:'text',text});}catch(e){return writeJson(res,e.status||400,{ok:false,error:e.message});}if(!wa.canaryAllows(payload.to,WA_CANARY_MODE,WA_CANARY_ALLOW_TO))return writeJson(res,403,{ok:false,error:'WA_CANARY_RECIPIENT_BLOCKED'});
  let reservation;try{reservation=await reserveOutbound(String(body.idempotency_key),auth.actor_id,payload);if(!reservation.owner){const row=reservation.row||{};return writeJson(res,row.state==='FAILED'?409:200,{ok:row.state!=='FAILED',idempotent:true,message_id:row.provider_message_id||null,status:row.state||'PENDING',error:row.state==='FAILED'?(row.error_code||'PREVIOUS_SEND_FAILED'):undefined});}
    const meta=await graphSend(payload);const messageId=meta&&meta.messages&&meta.messages[0]&&meta.messages[0].id;if(!messageId)throw Object.assign(new Error('META_MESSAGE_ID_MISSING'),{status:502,ambiguous:true});const now=new Date().toISOString();
    await sbRequest('PATCH','/rest/v1/aos_wa_outbound_requests_v1?idempotency_key=eq.'+encodeURIComponent(body.idempotency_key),{state:'ACCEPTED',provider_message_id:String(messageId),error_code:null,updated_at:now},true,'return=minimal');
    await sbRequest('POST','/rest/v1/aos_wa_messages_v1?on_conflict=provider_message_id',{provider_message_id:String(messageId),idempotency_key:String(body.idempotency_key),conversation_id:id,direction:'OUTBOUND',from_number:null,to_number:payload.to,phone_number_id:WA_PHONE_NUMBER_ID,contact_name:null,message_type:'text',message_body:payload.text.body,media_id:null,status:'accepted',actor_id:auth.actor_id,received_at:now,updated_at:now},true,'resolution=merge-duplicates,return=minimal');
    await sbRequest('POST','/rest/v1/aos_wa_events_v1?on_conflict=event_key',{event_key:'outbound:'+String(messageId),event_type:'message.accepted',provider_message_id:String(messageId),status:'accepted',payload:{actor_id:auth.actor_id,message_type:'text',conversation_id:id,source:'WA3_OWNED_HUMAN'}},true,'resolution=ignore-duplicates,return=minimal');
    await sbRequest('POST','/rest/v1/aos_wa_routing_events_v1',{conversation_id:id,box_id:auth.box_id||null,event_type:'message.human_accepted',actor_id:auth.actor_id,payload:{provider_message_id:String(messageId),idempotency_key:String(body.idempotency_key)}},true,'return=minimal');
    writeJson(res,200,{ok:true,idempotent:false,message_id:String(messageId),status:'ACCEPTED',conversation_id:id,canary:String(WA_CANARY_MODE).toLowerCase()==='true'});
  }catch(e){if(reservation&&reservation.owner&&e.definite===true){try{await sbRequest('PATCH','/rest/v1/aos_wa_outbound_requests_v1?idempotency_key=eq.'+encodeURIComponent(body.idempotency_key),{state:'FAILED',error_code:String(e.message||'WA3_SEND_FAILED').slice(0,128),updated_at:new Date().toISOString()},true,'return=minimal')}catch(_e){}}
    const ambiguous=!!(reservation&&reservation.owner&&e.definite!==true);console.error('[WA3] outbound',e.message,ambiguous?'ambiguous_pending':'definite_failure');writeJson(res,e.status||502,{ok:false,error:e.message||'WA3_SEND_FAILED',status:ambiguous?'PENDING':'FAILED',retry_safe:false});}
}

const buckets=new Map();function rateAllowed(req){const key=String(req.socket.remoteAddress||'unknown');const now=Date.now();let b=buckets.get(key);if(!b||now-b.start>60000){b={start:now,n:0};buckets.set(key,b)}b.n++;if(buckets.size>2000){for(const [k,v] of buckets)if(now-v.start>120000)buckets.delete(k)}return b.n<=300;}
function serveWa3Page(res){const file=path.join(__dirname,'public','admin-whatsapp-wa3.html');fs.stat(file,(err,st)=>{if(err||!st.isFile())return writeJson(res,503,{ok:false,error:'WA3_UI_UNAVAILABLE'});res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','X-Ascenda-WA3-Routing':'v1'});fs.createReadStream(file).pipe(res);});}
function proxy(req,res){const headers=Object.assign({},req.headers,{host:'127.0.0.1:'+INNER_PORT});const p=http.request({hostname:'127.0.0.1',port:INNER_PORT,path:req.url,method:req.method,headers},r=>{res.writeHead(r.statusCode||502,r.headers);r.pipe(res);});p.on('error',e=>{console.error('[WA3] proxy',e.message);if(!res.headersSent)writeJson(res,502,{ok:false,error:'WA3_INNER_UNAVAILABLE'});else res.end();});req.pipe(p);}

const server=http.createServer(async(req,res)=>{let u;try{u=new URL(req.url,'http://localhost')}catch(e){return writeJson(res,400,{ok:false,error:'INVALID_URL'})}const p=u.pathname;if(req.method==='GET'&&p==='/admin-whatsapp.html'){serveWa3Page(res);return}if(p.startsWith('/api/wa3/')){if(!rateAllowed(req))return writeJson(res,429,{ok:false,error:'WA3_RATE_LIMIT'});try{
  if(req.method==='GET'&&p==='/api/wa3/bootstrap')return await bootstrap(req,res);
  if(req.method==='GET'&&p==='/api/wa3/inbox')return await inbox(req,res,u);
  const mm=p.match(/^\/api\/wa3\/conversations\/([0-9a-f-]+)\/messages$/i);if(req.method==='GET'&&mm)return await messages(req,res,mm[1],u);
  const body=req.method==='POST'?await readJson(req):{};
  if(req.method==='POST'&&p==='/api/wa3/boxes/upsert')return await boxUpsert(req,res,body);
  if(req.method==='POST'&&p==='/api/wa3/boxes/member')return await memberSet(req,res,body);
  if(req.method==='POST'&&p==='/api/wa3/control')return await setControl(req,res,body);
  if(req.method==='POST'&&p==='/api/wa3/claim-next')return await claimNext(req,res,body);
  const mr=p.match(/^\/api\/wa3\/conversations\/([0-9a-f-]+)\/route$/i);if(req.method==='POST'&&mr)return await route(req,res,mr[1],body);
  const mx=p.match(/^\/api\/wa3\/conversations\/([0-9a-f-]+)\/release$/i);if(req.method==='POST'&&mx)return await release(req,res,mx[1],body);
  const mo=p.match(/^\/api\/wa3\/conversations\/([0-9a-f-]+)\/mode$/i);if(req.method==='POST'&&mo)return await setMode(req,res,mo[1],body);
  const ms=p.match(/^\/api\/wa3\/conversations\/([0-9a-f-]+)\/send$/i);if(req.method==='POST'&&ms)return await ownedSend(req,res,ms[1],body);
  return writeJson(res,404,{ok:false,error:'WA3_ROUTE_NOT_FOUND'});
}catch(e){console.error('[WA3] route',p,e.message);return writeJson(res,e.status||500,{ok:false,error:e.message||'WA3_REQUEST_FAILED'})}}
proxy(req,res);});
server.listen(EXTERNAL_PORT,'0.0.0.0',()=>console.log('[WA3] routing/handoff proxy listening on',EXTERNAL_PORT,'-> WA2',INNER_PORT));
function shutdown(sig){console.log('[WA3] shutdown',sig);try{child.kill(sig)}catch(e){}server.close(()=>process.exit(0));setTimeout(()=>process.exit(1),5000).unref();}
process.on('SIGTERM',()=>shutdown('SIGTERM'));process.on('SIGINT',()=>shutdown('SIGINT'));
