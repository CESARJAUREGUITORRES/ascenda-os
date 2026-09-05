'use strict';
// WA-4 outer boundary: human Copilot + server-only L10 autonomous CANARY orchestration.
// L4/L8 remain the sole autonomous send/preflight authority; WA-3 remains human ownership authority.
const http=require('http'),https=require('https'),path=require('path');
const {spawn}=require('child_process');
const ai=require('./ai-router');
const l4=require('./wa-l4-authority');
const {createCopilot}=require('./wa4-copilot');
const {createL5Booking}=require('./wa-l5-booking');
const {createAutonomousBridge}=require('./wa-l10-autonomous-bridge');
const {buildSupabaseHeaders}=require('./supabase-runtime-auth.cjs');

const EXTERNAL_PORT=parseInt(process.env.PORT||'4173',10),INNER_PORT=EXTERNAL_PORT===4198?4199:4198;
const SB_URL=process.env.SUPABASE_URL||'https://ituyqwstonmhnfshnaqz.supabase.co';
const SB_ANON_KEY=process.env.SUPABASE_ANON_KEY||'';
const SB_SERVICE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY||'';
const WA_L4_INTERNAL_TOKEN=process.env.WA_L4_INTERNAL_TOKEN||'';
const WA_ACCESS_TOKEN=process.env.WHATSAPP_ACCESS_TOKEN||'';
const WA_PHONE_NUMBER_ID=process.env.WHATSAPP_PHONE_NUMBER_ID||'';
const WA_GRAPH_VERSION=process.env.WHATSAPP_GRAPH_VERSION||'';
const HOOK=path.join(__dirname,'legacy-groq-model-hook.js');
const UUID_RE=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
let child=null,startupHealth={checked_at:null,configured:false,active:{},legacy_compat_ready:false,copilot_ready:false,error:'NOT_CHECKED'},healthExpiresAt=0;

function writeJson(res,status,obj){res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','X-Ascenda-WA4-AI':'v1'});res.end(JSON.stringify(obj));}
function readJson(req,max=262144){return new Promise((ok,bad)=>{let raw='',over=false;req.on('data',c=>{if(over)return;raw+=c;if(Buffer.byteLength(raw)>max)over=true;});req.on('end',()=>{if(over)return bad(Object.assign(new Error('PAYLOAD_TOO_LARGE'),{status:413}));try{ok(JSON.parse(raw||'{}'));}catch(_){bad(Object.assign(new Error('INVALID_JSON'),{status:400}));}});req.on('error',bad);});}
function readRaw(req,max=1048576){return new Promise((ok,bad)=>{const chunks=[];let total=0,over=false;req.on('data',c=>{if(over)return;total+=c.length;if(total>max){over=true;return;}chunks.push(c);});req.on('end',()=>over?bad(Object.assign(new Error('PAYLOAD_TOO_LARGE'),{status:413})):ok(Buffer.concat(chunks)));req.on('error',bad);});}
function parseData(raw){try{return raw?JSON.parse(raw):null;}catch(_){return null;}}
function sbRequest(method,endpoint,body,service,prefer){return new Promise((ok,bad)=>{const key=service?SB_SERVICE_KEY:SB_ANON_KEY;if(!key)return bad(Object.assign(new Error(service?'SUPABASE_SERVICE_ROLE_NOT_CONFIGURED':'SUPABASE_ANON_KEY_NOT_CONFIGURED'),{status:503}));let u;try{u=new URL(SB_URL);}catch(e){return bad(e);}const data=body==null?'':JSON.stringify(body),headers=buildSupabaseHeaders(key,{'Content-Type':'application/json','User-Agent':'AscendaOS-WA4/1.0'});if(data)headers['Content-Length']=Buffer.byteLength(data);if(prefer)headers.Prefer=prefer;const q=https.request({hostname:u.hostname,port:u.port||443,path:endpoint,method,headers,timeout:12000},r=>{let raw='';r.on('data',c=>raw+=c);r.on('end',()=>{const out={status:r.statusCode||502,data:parseData(raw),raw};if(out.status>=200&&out.status<300)ok(out);else bad(Object.assign(new Error('WA4_DB_UNAVAILABLE'),{status:502,upstreamStatus:out.status,data:out.data}));});});q.on('timeout',()=>q.destroy(new Error('WA4_DB_TIMEOUT')));q.on('error',bad);if(data)q.write(data);q.end();});}
const sbRpc=(n,p)=>sbRequest('POST','/rest/v1/rpc/'+n,p,false);
const serviceRpc=(n,p)=>sbRequest('POST','/rest/v1/rpc/'+n,p,true);
const serviceGet=e=>sbRequest('GET',e,null,true);
const servicePost=(e,b)=>sbRequest('POST',e,b,true,'return=minimal');

function token(req){const t=String(req.headers['x-aos-app-token']||'').trim();return t.length>=32?t:'';}
async function actor(req){const t=token(req);if(!t)return null;try{const o=await sbRpc('aos_wa3_actor_v1',{p_token:t}),a=o.data;return a&&a.ok===true&&UUID_RE.test(String(a.actor_id||''))?a:null;}catch(_){return null;}}
async function requireActor(req,res,admin){const a=await actor(req);if(!a){writeJson(res,403,{ok:false,error:'WA4_2FA_PANEL_REQUIRED'});return null;}if(admin&&a.is_admin!==true){writeJson(res,403,{ok:false,error:'WA4_ADMIN_REQUIRED'});return null;}return a;}

async function getProviderSecret(tipo,nombreLike){const t=String(tipo||'').toLowerCase();if(!/^[a-z0-9_-]{2,32}$/.test(t))return '';try{const o=await serviceGet('/rest/v1/aos_integration_secrets_v1?tipo=eq.'+encodeURIComponent(t)+'&select=api_key,nombre&limit=20'),rows=Array.isArray(o.data)?o.data:[],r=nombreLike?rows.find(x=>String(x.nombre||'').toLowerCase().includes(String(nombreLike).toLowerCase())):rows[0],k=r&&typeof r.api_key==='string'?r.api_key:'';if(k.length>10)return k;}catch(_){}try{const o=await serviceGet('/rest/v1/aos_integraciones?tipo=eq.'+encodeURIComponent(t)+'&estado=eq.conectado&select=api_key,nombre&limit=20'),rows=Array.isArray(o.data)?o.data:[],r=nombreLike?rows.find(x=>String(x.nombre||'').toLowerCase().includes(String(nombreLike).toLowerCase())):rows[0];return r&&typeof r.api_key==='string'&&r.api_key.length>10?r.api_key:'';}catch(_){return '';}}
async function loadSecrets(){const [groq,gemini,openai,resend]=await Promise.all([getProviderSecret('groq'),getProviderSecret('gemini'),getProviderSecret('api','openai'),getProviderSecret('resend')]);return{groq,gemini,openai,resend};}
async function modelHealth(force){const now=Date.now();if(!force&&now<healthExpiresAt)return startupHealth;try{const key=(await loadSecrets()).groq;if(!key)throw new Error('GROQ_KEY_NOT_CONFIGURED');const m=await ai.listModels(key);startupHealth={checked_at:new Date().toISOString(),configured:true,models:ai.MODELS,active:m.active,legacy_compat_ready:m.active.fast===true&&m.active.reasoning===true,copilot_ready:m.active.fast===true&&m.active.reasoning===true&&m.active.safety===true,error:null};}catch(e){startupHealth={checked_at:new Date().toISOString(),configured:false,models:ai.MODELS,active:{},legacy_compat_ready:false,copilot_ready:false,error:String(e&&e.message||'MODEL_HEALTH_FAILED').slice(0,120)};}healthExpiresAt=now+300000;return startupHealth;}

async function effectiveCanary(){
  try{
    const [a,c,r]=await Promise.all([
      serviceGet('/rest/v1/aos_wa_auto_authority_v1?select=mode,kill_switch_engaged&id=eq.1'),
      serviceGet('/rest/v1/aos_wa_ai_control_v1?select=copilot_enabled,auto_reply_enabled&id=eq.1'),
      serviceGet('/rest/v1/aos_wa_routing_control_v1?select=ai_send_enabled,auto_routing_enabled,human_send_enabled&id=eq.1')
    ]);
    const aa=Array.isArray(a.data)?a.data[0]:null,cc=Array.isArray(c.data)?c.data[0]:null,rr=Array.isArray(r.data)?r.data[0]:null;
    return !!(aa&&cc&&rr&&aa.mode==='CANARY'&&aa.kill_switch_engaged===false&&cc.copilot_enabled===true&&cc.auto_reply_enabled===true&&rr.ai_send_enabled===true&&rr.auto_routing_enabled===false&&rr.human_send_enabled===true);
  }catch(_){return false;}
}
async function authorizeInternalCanary(id){
  if(!UUID_RE.test(String(id||'')))return{ok:false,error:'WA_L10_CONVERSATION_ID_REQUIRED'};
  try{
    const [a,c,r,conv,allow]=await Promise.all([
      serviceGet('/rest/v1/aos_wa_auto_authority_v1?select=mode,kill_switch_engaged&id=eq.1'),
      serviceGet('/rest/v1/aos_wa_ai_control_v1?select=copilot_enabled,auto_reply_enabled,max_context_messages,max_catalog_items&id=eq.1'),
      serviceGet('/rest/v1/aos_wa_routing_control_v1?select=ai_send_enabled,auto_routing_enabled,human_send_enabled&id=eq.1'),
      serviceGet('/rest/v1/aos_wa_conversations_v1?id=eq.'+encodeURIComponent(id)+'&select=id,state,owner_user_id,human_takeover_at,handoff_requested_at&limit=1'),
      serviceGet('/rest/v1/aos_wa_auto_allowlist_v1?subject_kind=eq.CONVERSATION&subject_key=eq.'+encodeURIComponent(id)+'&active=eq.true&select=subject_key,expires_at&limit=5')
    ]);
    const aa=Array.isArray(a.data)?a.data[0]:null,cc=Array.isArray(c.data)?c.data[0]:null,rr=Array.isArray(r.data)?r.data[0]:null,cv=Array.isArray(conv.data)?conv.data[0]:null;
    const rows=Array.isArray(allow.data)?allow.data:[],active=rows.some(x=>!x.expires_at||new Date(x.expires_at).getTime()>Date.now());
    if(!(aa&&cc&&rr&&cv&&active))return{ok:false,error:'WA_L10_INTERNAL_CANARY_NOT_SCOPED'};
    if(aa.mode!=='CANARY'||aa.kill_switch_engaged!==false||cc.copilot_enabled!==true||cc.auto_reply_enabled!==true||rr.ai_send_enabled!==true||rr.auto_routing_enabled!==false||rr.human_send_enabled!==true)return{ok:false,error:'WA_L10_INTERNAL_CANARY_NOT_EFFECTIVE'};
    if(cv.state!=='AI_ACTIVE'||cv.owner_user_id!=null||cv.human_takeover_at!=null||cv.handoff_requested_at!=null)return{ok:false,error:'WA_L10_INTERNAL_HUMAN_BOUNDARY_ACTIVE'};
    return{ok:true,actor_id:null,max_context_messages:Number(cc.max_context_messages||24),max_catalog_items:Number(cc.max_catalog_items||12),internal_canary:true};
  }catch(_){return{ok:false,error:'WA_L10_INTERNAL_AUTH_UNAVAILABLE'};}
}
async function authorize(req,id){
  if(l4.internalTokenValid(req&&req.headers&&req.headers['x-aos-wa-auto-token'],WA_L4_INTERNAL_TOKEN))return authorizeInternalCanary(id);
  const t=token(req);if(!t)return{ok:false,error:'WA4_2FA_PANEL_REQUIRED'};
  const o=await sbRpc('aos_wa4_authorize_copilot_v1',{p_token:t,p_conversation_id:id});return o.data||{};
}
async function requireConversationAccess(req,res,id){const a=await requireActor(req,res,false);if(!a)return null;let z;try{z=await authorize(req,id);}catch(_){z=null;}if(!z||z.ok!==true){writeJson(res,403,z||{ok:false,error:'WA5_CONVERSATION_NOT_AUTHORIZED'});return null;}return {actor:a,authorization:z};}

const suggest=createCopilot({serviceGet,servicePost,serviceRpc,authorize,getGroqKey:()=>getProviderSecret('groq'),modelHealth,writeJson});
const l5=createL5Booking({serviceRpc});

async function suggestInternal(conversationId){
  return new Promise(resolve=>{
    let status=200,raw='';let done=false;
    const finish=()=>{if(done)return;done=true;resolve({status,body:parseData(raw)||{}});};
    const req={headers:{'x-aos-wa-auto-token':WA_L4_INTERNAL_TOKEN}};
    const res={writeHead(s){status=Number(s)||500;},end(chunk){if(chunk)raw+=Buffer.isBuffer(chunk)?chunk.toString('utf8'):String(chunk);finish();}};
    Promise.resolve(suggest(req,res,conversationId)).catch(e=>{status=503;raw=JSON.stringify({ok:false,error:String(e&&e.message||'WA4_INTERNAL_SUGGEST_FAILED')});finish();});
  });
}
function internalPost(pathname,body){
  return new Promise((resolve,reject)=>{
    if(WA_L4_INTERNAL_TOKEN.length<32)return reject(new Error('WA_L4_INTERNAL_AUTH_NOT_CONFIGURED'));
    const data=JSON.stringify(body||{});
    const q=http.request({hostname:'127.0.0.1',port:INNER_PORT,path:pathname,method:'POST',headers:{'Content-Type':'application/json','Content-Length':Buffer.byteLength(data),'X-AOS-WA-Auto-Token':WA_L4_INTERNAL_TOKEN,'User-Agent':'AscendaOS-WA-L10/1.0'},timeout:20000},r=>{let raw='';r.on('data',c=>raw+=c);r.on('end',()=>resolve({status:r.statusCode||502,body:parseData(raw)||{}}));});
    q.on('timeout',()=>q.destroy(new Error('WA_L10_INTERNAL_SEND_TIMEOUT')));q.on('error',reject);q.write(data);q.end();
  });
}
async function requestHandoff(conversationId,reason){
  const o=await serviceRpc('aos_wa3_handoff_request_v1',{p_conversation_id:conversationId,p_box_id:null,p_actor_id:null,p_reason:l4.sanitizeReason(reason)});
  return o.data||{};
}
function sendTypingIndicator(providerMessageId){
  return new Promise(resolve=>{
    const messageId=String(providerMessageId||'').trim();
    if(!messageId||!WA_ACCESS_TOKEN||!WA_PHONE_NUMBER_ID||!/^v\d+\.\d+$/.test(WA_GRAPH_VERSION))return resolve({ok:false,skipped:true});
    const payload=JSON.stringify({messaging_product:'whatsapp',status:'read',message_id:messageId,typing_indicator:{type:'text'}});
    const q=https.request({hostname:'graph.facebook.com',path:'/'+WA_GRAPH_VERSION+'/'+encodeURIComponent(WA_PHONE_NUMBER_ID)+'/messages',method:'POST',headers:{Authorization:'Bearer '+WA_ACCESS_TOKEN,'Content-Type':'application/json','Content-Length':Buffer.byteLength(payload),'User-Agent':'AscendaOS-WA-L10-Typing/1.0'},timeout:3000},r=>{r.resume();r.on('end',()=>resolve({ok:r.statusCode>=200&&r.statusCode<300,status:r.statusCode||0}));});
    q.on('timeout',()=>{q.destroy();resolve({ok:false,error:'META_TYPING_TIMEOUT'});});
    q.on('error',()=>resolve({ok:false,error:'META_TYPING_UNAVAILABLE'}));
    q.write(payload);q.end();
  });
}
const bridge=createAutonomousBridge({serviceRpc,suggestInternal,autoSend:body=>internalPost('/api/wa/auto-send',body),requestHandoff,sendTyping:sendTypingIndicator,log:console});

async function bootstrap(req,res){const a=await requireActor(req,res,false);if(!a)return;try{const [c,h]=await Promise.all([serviceGet('/rest/v1/aos_wa_ai_control_v1?select=provider,fast_model,reasoning_model,safety_model,copilot_enabled,auto_reply_enabled,daily_budget_usd,max_context_messages,max_catalog_items,updated_at&id=eq.1'),modelHealth(false)]);writeJson(res,200,{ok:true,version:'WA4-V1',actor:{id:a.actor_id,is_admin:a.is_admin===true},control:Array.isArray(c.data)?c.data[0]||{}:{},health:h,l5:{version:l5.version,autonomous_commit:'L4_GATED',canary_authorized:false}});}catch(_){writeJson(res,503,{ok:false,error:'WA4_BOOTSTRAP_UNAVAILABLE'});}}
async function control(req,res,body){const a=await requireActor(req,res,true);if(!a)return;const h=await modelHealth(false);if(body.copilot_enabled===true&&h.copilot_ready!==true)return writeJson(res,409,{ok:false,error:'WA4_MODELS_NOT_READY',health:h});try{const o=await serviceRpc('aos_wa4_admin_set_control_v1',{p_actor_id:a.actor_id,p_copilot_enabled:typeof body.copilot_enabled==='boolean'?body.copilot_enabled:null,p_daily_budget_usd:body.daily_budget_usd==null?null:Number(body.daily_budget_usd)});writeJson(res,o.data&&o.data.ok===false?409:200,o.data||{ok:false,error:'WA4_CONTROL_EMPTY'});}catch(_){writeJson(res,503,{ok:false,error:'WA4_CONTROL_UNAVAILABLE'});}}
async function book(req,res,conversationId,body){
  const a=await requireActor(req,res,false);if(!a)return;
  const idem=String(body&&body.idempotency_key||'').trim(),payload=body&&body.payload;
  if(idem.length<16||idem.length>160||!payload||typeof payload!=='object'||Array.isArray(payload))return writeJson(res,400,{ok:false,error:'WA4_BOOKING_REQUEST_INVALID'});
  try{const o=await serviceRpc('aos_wa4_commit_booking_v1',{p_actor_id:a.actor_id,p_idempotency_key:idem,p_conversation_id:conversationId,p_payload:payload});const out=o.data||{ok:false,error:'WA4_BOOKING_EMPTY'};return writeJson(res,out.ok===true?200:409,Object.assign({auto_send:false,send_authority:'HUMAN_ONLY'},out));}
  catch(_){return writeJson(res,503,{ok:false,error:'WA4_BOOKING_UNAVAILABLE',auto_send:false,send_authority:'HUMAN_ONLY'});}
}
async function rebook(req,res,conversationId,body){
  const a=await requireActor(req,res,false);if(!a)return;
  const idem=String(body&&body.idempotency_key||'').trim(),appointmentId=String(body&&body.appointment_id||'').trim(),payload=body&&body.payload;
  if(idem.length<16||idem.length>160||!appointmentId||!payload||typeof payload!=='object'||Array.isArray(payload))return writeJson(res,400,{ok:false,error:'WA4_REBOOK_REQUEST_INVALID'});
  try{const o=await serviceRpc('aos_wa4_rebook_booking_v2',{p_actor_id:a.actor_id,p_idempotency_key:idem,p_conversation_id:conversationId,p_appointment_id:appointmentId,p_payload:payload});const out=o.data||{ok:false,error:'WA4_REBOOK_EMPTY'};return writeJson(res,out.ok===true?200:409,Object.assign({auto_send:false,send_authority:'HUMAN_ONLY',booking_contract:'AGV2_V2'},out));}
  catch(_){return writeJson(res,503,{ok:false,error:'WA4_REBOOK_UNAVAILABLE',auto_send:false,send_authority:'HUMAN_ONLY'});}
}
async function l5Call(req,res,id,method,body){
  const access=await requireConversationAccess(req,res,id);if(!access)return;
  try{
    let out;
    if(method==='status')out=await l5.status(id);else if(method==='availability')out=await l5.availability(id,body);else if(method==='verify')out=await l5.verify(id,body);else if(method==='appointments')out=await l5.appointments(id);else if(method==='prepare')out=await l5.prepare(id,body);else if(method==='confirm')out=await l5.confirm(id,body);else return writeJson(res,404,{ok:false,error:'WA5_METHOD_NOT_FOUND'});
    const status=out&&out.ok===false?(String(out.error||'').includes('INVALID')?400:409):200;
    return writeJson(res,status,Object.assign({l5_version:l5.version,auto_send:false,autonomous_commit_authority:'L4_PLUS_AGV2'},out||{ok:false,error:'WA_L5_EMPTY_RESPONSE'}));
  }catch(_){return writeJson(res,503,{ok:false,error:'WA_L5_UNAVAILABLE',l5_version:l5.version,auto_send:false});}
}

function proxy(req,res){const q=http.request({hostname:'127.0.0.1',port:INNER_PORT,path:req.url,method:req.method,headers:Object.assign({},req.headers,{host:'127.0.0.1:'+INNER_PORT})},r=>{res.writeHead(r.statusCode||502,r.headers);r.pipe(res);});q.on('error',()=>{if(!res.headersSent)res.writeHead(502,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'WA4_UPSTREAM_UNAVAILABLE'}));});req.pipe(q);}
function relayBuffered(res,status,headers,body){const h=Object.assign({},headers||{});delete h['transfer-encoding'];delete h['content-length'];h['content-length']=Buffer.byteLength(body||Buffer.alloc(0));res.writeHead(status||502,h);res.end(body);}
function proxyWebhook(req,res,raw){
  return new Promise(resolve=>{
    const headers=Object.assign({},req.headers,{host:'127.0.0.1:'+INNER_PORT,'content-length':raw.length});delete headers['transfer-encoding'];
    const q=http.request({hostname:'127.0.0.1',port:INNER_PORT,path:req.url,method:req.method,headers},r=>{const chunks=[];r.on('data',c=>chunks.push(c));r.on('end',async()=>{const body=Buffer.concat(chunks),status=r.statusCode||502;if(status<200||status>=300){relayBuffered(res,status,r.headers,body);resolve();return;}let queued=[];try{const enq=await bridge.enqueueWebhook(raw);queued=enq.queued||[];}catch(e){const strict=await effectiveCanary();console.error('[WA-L10-BRIDGE] enqueue failed',l4.sanitizeReason(e&&e.message));if(strict){writeJson(res,503,{ok:false,error:'WA_L10_BRIDGE_ENQUEUE_UNAVAILABLE'});resolve();return;}}relayBuffered(res,status,r.headers,body);if(queued.length)setImmediate(()=>bridge.processProviderIds(queued).then(()=>bridge.recoverPending()).catch(e=>console.error('[WA-L10-BRIDGE] async',l4.sanitizeReason(e&&e.message))));resolve();});});
    q.on('error',()=>{if(!res.headersSent)writeJson(res,502,{ok:false,error:'WA4_UPSTREAM_UNAVAILABLE'});resolve();});q.write(raw);q.end();
  });
}

const proxyServer=http.createServer(async(req,res)=>{
  let u;try{u=new URL(req.url,'http://localhost');}catch(_){return writeJson(res,400,{ok:false,error:'INVALID_URL'});}const p=u.pathname;
  if((p==='/webhook'||p==='/webhook/')&&req.method==='POST'){
    try{return proxyWebhook(req,res,await readRaw(req));}catch(e){return writeJson(res,e.status||400,{ok:false,error:e.message||'INVALID_REQUEST'});}
  }
  if(p==='/api/wa4/health'&&req.method==='GET')return writeJson(res,200,{ok:true,version:'WA4-V1',l5_version:l5.version,auto_send:false,autonomous_bridge:'WA-L10-BRIDGE-V1',health:await modelHealth(false)});
  if(p==='/api/wa4/bootstrap'&&req.method==='GET')return bootstrap(req,res);
  if(p==='/api/wa4/control'&&req.method==='POST'){try{return control(req,res,await readJson(req));}catch(e){return writeJson(res,e.status||400,{ok:false,error:e.message});}}
  const suggestMatch=p.match(/^\/api\/wa4\/conversations\/([0-9a-f-]+)\/suggest$/i);
  if(suggestMatch&&req.method==='POST'){try{await readJson(req);}catch(e){return writeJson(res,e.status||400,{ok:false,error:e.message});}return suggest(req,res,suggestMatch[1]);}
  const bookMatch=p.match(/^\/api\/wa4\/conversations\/([0-9a-f-]+)\/book$/i);
  if(bookMatch&&req.method==='POST'){try{return book(req,res,bookMatch[1],await readJson(req,65536));}catch(e){return writeJson(res,e.status||400,{ok:false,error:e.message});}}
  const rebookMatch=p.match(/^\/api\/wa4\/conversations\/([0-9a-f-]+)\/rebook$/i);
  if(rebookMatch&&req.method==='POST'){try{return rebook(req,res,rebookMatch[1],await readJson(req,65536));}catch(e){return writeJson(res,e.status||400,{ok:false,error:e.message});}}
  const l5Match=p.match(/^\/api\/wa5\/conversations\/([0-9a-f-]+)\/(status|availability|verify|appointments|prepare|confirm)$/i);
  if(l5Match){const method=l5Match[2].toLowerCase();if((method==='status'||method==='appointments')&&req.method==='GET')return l5Call(req,res,l5Match[1],method,null);if(['availability','verify','prepare','confirm'].includes(method)&&req.method==='POST'){try{return l5Call(req,res,l5Match[1],method,await readJson(req,65536));}catch(e){return writeJson(res,e.status||400,{ok:false,error:e.message});}}return writeJson(res,405,{ok:false,error:'WA5_METHOD_NOT_ALLOWED'});}
  return proxy(req,res);
});

proxyServer.on('clientError',(_,s)=>s.end('HTTP/1.1 400 Bad Request\r\n\r\n'));
function shutdown(sig){proxyServer.close(()=>process.exit(0));if(child&&!child.killed)child.kill(sig);setTimeout(()=>process.exit(1),5000).unref();}
process.on('SIGTERM',()=>shutdown('SIGTERM'));process.on('SIGINT',()=>shutdown('SIGINT'));
async function start(){
  const secrets=await loadSecrets(),h=await modelHealth(true),legacy=h.legacy_compat_ready===true&&!!secrets.groq,inherited=String(process.env.NODE_OPTIONS||'').trim(),nodeOptions=(inherited+' --require='+HOOK).trim();
  child=spawn(process.execPath,['server-wa3-v2.js'],{cwd:__dirname,env:Object.assign({},process.env,{PORT:String(INNER_PORT),NODE_OPTIONS:nodeOptions,ASCENDA_GROQ_COMPAT:legacy?'1':'0',GROQ_API_KEY:secrets.groq||'',GEMINI_API_KEY:secrets.gemini||'',OPENAI_API_KEY:process.env.OPENAI_API_KEY||secrets.openai||'',RESEND_API_KEY:process.env.RESEND_API_KEY||secrets.resend||''}),stdio:['ignore','inherit','inherit']});
  child.on('exit',code=>process.exit(code==null?1:code));
  proxyServer.listen(EXTERNAL_PORT,'0.0.0.0',()=>{
    console.log('[WA4] listening',{external:EXTERNAL_PORT,inner:INNER_PORT,legacyCompat:legacy,copilotReady:h.copilot_ready===true,l5:l5.version,l10Bridge:'EVENT_DRIVEN_NO_POLL'});
    setImmediate(async()=>{try{if(await effectiveCanary())await bridge.recoverPending();}catch(e){console.error('[WA-L10-BRIDGE] startup recovery',l4.sanitizeReason(e&&e.message));}});
  });
}
start().catch(e=>{console.error('[WA4] startup failed',e.message);process.exit(1);});
