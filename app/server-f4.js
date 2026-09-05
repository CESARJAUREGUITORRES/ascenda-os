// ASCENDA OS — F4 Revenue Operations + WA-1 secure front proxy.
'use strict';
const http=require('http');
const https=require('https');
const {spawn}=require('child_process');
const wa=require('./wa-gateway');
const l4=require('./wa-l4-authority');
const {createEmailGateway}=require('./email-gateway');
const EMAIL_GATEWAY=createEmailGateway();

const EXTERNAL_PORT=parseInt(process.env.PORT||'4173',10);
const INNER_PORT=EXTERNAL_PORT===4189?4190:4189;
const SB_URL=process.env.SUPABASE_URL||'https://ituyqwstonmhnfshnaqz.supabase.co';
const SB_ANON_KEY=process.env.SUPABASE_ANON_KEY||'';
const SB_SERVICE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY||'';
const WA_VERIFY_TOKEN=process.env.WHATSAPP_VERIFY_TOKEN||'';
const WA_APP_SECRET=process.env.WHATSAPP_APP_SECRET||'';
const WA_ACCESS_TOKEN=process.env.WHATSAPP_ACCESS_TOKEN||'';
const WA_PHONE_NUMBER_ID=process.env.WHATSAPP_PHONE_NUMBER_ID||'';
const WA_GRAPH_VERSION=process.env.WHATSAPP_GRAPH_VERSION||'';
const WA_CANARY_MODE=process.env.WA_CANARY_MODE||'true';
const WA_CANARY_ALLOW_TO=process.env.WA_CANARY_ALLOW_TO||'';
const WA_L4_INTERNAL_TOKEN=process.env.WA_L4_INTERNAL_TOKEN||'';

// Least privilege: WA/service-role/provider/L4 authority secrets belong only to this front proxy.
// The legacy/product child does not need them and must never inherit them.
const childEnv=Object.assign({},process.env,{PORT:String(INNER_PORT)});
delete childEnv.SUPABASE_SERVICE_ROLE_KEY;
delete childEnv.WHATSAPP_VERIFY_TOKEN;
delete childEnv.WHATSAPP_APP_SECRET;
delete childEnv.WHATSAPP_ACCESS_TOKEN;
delete childEnv.WHATSAPP_PHONE_NUMBER_ID;
delete childEnv.WHATSAPP_GRAPH_VERSION;
delete childEnv.WA_CANARY_MODE;
delete childEnv.WA_CANARY_ALLOW_TO;
delete childEnv.WA_L4_INTERNAL_TOKEN;
const child=spawn(process.execPath,['server-phase2.js'],{cwd:__dirname,env:childEnv,stdio:['ignore','inherit','inherit']});
child.on('exit',(code,signal)=>{console.error('[F4-PROXY] backend exited',{code,signal});process.exit(code==null?1:code);});

function writeJson(res,status,obj,extra){res.writeHead(status,Object.assign({'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Ascenda-Revenue-Route':'f4','X-Ascenda-WA-Gateway':'v1'},extra||{}));res.end(JSON.stringify(obj));}
function readJson(req,maxBytes=1024*1024){return new Promise((resolve,reject)=>{let raw='',overflow=false;req.on('data',c=>{if(overflow)return;raw+=c;if(Buffer.byteLength(raw)>maxBytes)overflow=true;});req.on('end',()=>{if(overflow){reject(Object.assign(new Error('PAYLOAD_TOO_LARGE'),{status:413}));return;}try{resolve({raw,body:JSON.parse(raw||'{}')});}catch(e){reject(Object.assign(new Error('INVALID_JSON'),{status:400}));}});req.on('error',reject);});}
function readRaw(req,maxBytes=1024*1024){return new Promise((resolve,reject)=>{const chunks=[];let total=0,overflow=false;req.on('data',c=>{if(overflow)return;total+=c.length;if(total>maxBytes){overflow=true;return;}chunks.push(c);});req.on('end',()=>overflow?reject(Object.assign(new Error('PAYLOAD_TOO_LARGE'),{status:413})):resolve(Buffer.concat(chunks)));req.on('error',reject);});}
function sbRpc(name,payload){
  return new Promise((resolve,reject)=>{
    if(!SB_ANON_KEY){reject(new Error('SUPABASE_ANON_KEY_NOT_CONFIGURED'));return;}
    let sb;try{sb=new URL(SB_URL);}catch(e){reject(e);return;}
    const data=JSON.stringify(payload||{});
    const req=https.request({hostname:sb.hostname,port:sb.port||443,path:'/rest/v1/rpc/'+name,method:'POST',headers:{apikey:SB_ANON_KEY,Authorization:'Bearer '+SB_ANON_KEY,'Content-Type':'application/json','Content-Length':Buffer.byteLength(data),'User-Agent':'AscendaOS-F4-RevenueProxy/1.0'},timeout:12000},r=>{
      let body='';r.on('data',c=>body+=c);r.on('end',()=>{let parsed={};try{parsed=body?JSON.parse(body):{};}catch(e){parsed={ok:false,error:'UPSTREAM_INVALID_JSON'};}resolve({status:r.statusCode||502,data:parsed});});
    });
    req.on('timeout',()=>req.destroy(new Error('UPSTREAM_TIMEOUT')));req.on('error',reject);req.write(data);req.end();
  });
}
function sbService(method,endpoint,body,prefer){
  return new Promise((resolve,reject)=>{
    if(!SB_SERVICE_KEY){reject(Object.assign(new Error('WA_SERVICE_ROLE_NOT_CONFIGURED'),{status:503}));return;}
    let sb;try{sb=new URL(SB_URL);}catch(e){reject(e);return;}
    const data=body==null?'':JSON.stringify(body);const headers={apikey:SB_SERVICE_KEY,Authorization:'Bearer '+SB_SERVICE_KEY,'Content-Type':'application/json','User-Agent':'AscendaOS-WA-Gateway/1.0'};
    if(data)headers['Content-Length']=Buffer.byteLength(data);if(prefer)headers.Prefer=prefer;
    const q=https.request({hostname:sb.hostname,port:sb.port||443,path:endpoint,method,headers,timeout:12000},r=>{let out='';r.on('data',c=>out+=c);r.on('end',()=>{let parsed=null;try{parsed=out?JSON.parse(out):null;}catch(e){}const result={status:r.statusCode||502,data:parsed,raw:out};if(result.status>=200&&result.status<300)resolve(result);else reject(Object.assign(new Error('WA_DB_WRITE_FAILED'),{status:502,upstreamStatus:result.status}));});});
    q.on('timeout',()=>q.destroy(new Error('WA_DB_TIMEOUT')));q.on('error',reject);if(data)q.write(data);q.end();
  });
}
function sbServiceRpc(name,payload){return sbService('POST','/rest/v1/rpc/'+name,payload||{});}
function strongToken(req){const t=String(req.headers['x-aos-app-token']||'').trim();return t.length>=32?t:'';}
async function authorizeWaSender(req){const token=strongToken(req);if(!token)return null;const out=await sbRpc('aos_app_actor_v3',{p_token:token,p_required_panel:'admin-chats',p_require_2fa:true});if(out.status<200||out.status>=300)return null;const actor=out.data;return typeof actor==='string'&&/^[0-9a-f-]{36}$/i.test(actor)?actor:null;}
function authorizeWaAutoRuntime(req){return l4.internalTokenValid(req.headers['x-aos-wa-auto-token'],WA_L4_INTERNAL_TOKEN);}

async function handleKroniaSaleEdit(req,res,body){
  const appToken=strongToken(req);
  if(!appToken){writeJson(res,403,{ok:true,respuesta:'🔒 La edición financiera requiere una sesión administrativa 2FA vigente.',provider:'f4-security',error:'F4_STRONG_SESSION_REQUIRED'});return;}
  const action=body&&body.confirmar_accion;const params=action&&action.params||{};const saleId=Number(params.p_venta_id||0);
  if(!saleId||!params.p_campos||typeof params.p_campos!=='object'){writeJson(res,400,{ok:false,error:'INVALID_SALE_EDIT'});return;}
  try{
    const current=await sbRpc('aos_sales_admin_sale_v4',{p_token:appToken,p_sale_id:saleId});
    if(!current.data||current.data.ok!==true||!current.data.row){writeJson(res,403,{ok:true,respuesta:'🔒 No se pudo validar la venta o tu permiso de edición.',provider:'f4-security',resultado:current.data});return;}
    const edited=await sbRpc('aos_editar_venta_v4',{p_token:appToken,p_venta_id:saleId,p_expected_updated_at:current.data.row.updated_at,p_campos:params.p_campos,p_origen:'kronia_f4'});
    const result=edited.data||{};
    if(result.ok===false){writeJson(res,200,{ok:true,respuesta:'⚠️ No pude ejecutar la edición: '+(result.error||'rechazada'),provider:'f4-ejecutor',resultado:result});return;}
    writeJson(res,200,{ok:true,respuesta:'✅ Venta actualizada mediante el contrato seguro F4.',provider:'f4-ejecutor',resultado:result});
  }catch(e){console.error('[F4-PROXY] KronIA sale edit',e.message);writeJson(res,502,{ok:true,respuesta:'⚠️ No fue posible completar la edición segura en este momento.',provider:'f4-ejecutor',error:'F4_UPSTREAM_UNAVAILABLE'});}
}
async function handleCandidates(req,res,body){
  const appToken=strongToken(req);if(!appToken){writeJson(res,403,{ok:false,error:'F4_STRONG_SESSION_REQUIRED'});return;}
  const caseId=String((body&&body.case_id)||'').trim();if(!caseId){writeJson(res,400,{ok:false,error:'CASE_ID_REQUIRED'});return;}
  try{const out=await sbRpc('aos_cartera_candidates_v2',{p_token:appToken,p_case_id:caseId});writeJson(res,out.status>=200&&out.status<300?200:out.status,out.data||{ok:false,error:'UPSTREAM_EMPTY'});}catch(e){console.error('[F4-PROXY] candidates',e.message);writeJson(res,502,{ok:false,error:'F4_UPSTREAM_UNAVAILABLE'});}
}

async function handleRevenueRead(req,res,body,kind){
  const appToken=strongToken(req);
  if(!appToken){writeJson(res,403,{ok:false,error:'F4_STRONG_SESSION_REQUIRED'});return;}
  let rpcName='',payload={};
  if(kind==='cartera'){rpcName='aos_cartera_gateway';payload={p_token:appToken,p_estado:String((body&&body.estado)||''),p_sede:String((body&&body.sede)||''),p_limit:Number((body&&body.limit)||100),p_offset:Number((body&&body.offset)||0)};}
  else if(kind==='sales-intelligence'){rpcName='aos_sales_intelligence_gateway';payload={p_token:appToken,p_anio:Number((body&&body.anio)||0),p_sede:String((body&&body.sede)||''),p_asesor:String((body&&body.asesor)||'')};}
  else{writeJson(res,400,{ok:false,error:'INVALID_REVENUE_READ'});return;}
  try{const out=await sbRpc(rpcName,payload);if(out.status<200||out.status>=300){writeJson(res,502,{ok:false,error:'F4_REVENUE_UPSTREAM_REJECTED',upstream_status:out.status});return;}writeJson(res,200,out.data||{ok:false,error:'UPSTREAM_EMPTY'});}
  catch(e){console.error('[F4-PROXY] revenue read',kind,e.message);writeJson(res,502,{ok:false,error:'F4_REVENUE_UPSTREAM_UNAVAILABLE'});}
}

function waConfigReadyInbound(){return !!(WA_VERIFY_TOKEN&&WA_APP_SECRET&&SB_SERVICE_KEY);}
function waConfigReadyOutbound(){return !!(waConfigReadyInbound()&&WA_ACCESS_TOKEN&&WA_PHONE_NUMBER_ID&&/^v\d+\.\d+$/.test(WA_GRAPH_VERSION));}
function handleWaVerify(req,res){
  if(!WA_VERIFY_TOKEN){writeJson(res,503,{ok:false,error:'WA_VERIFY_TOKEN_NOT_CONFIGURED'});return;}
  const u=new URL(req.url,'http://localhost');const mode=u.searchParams.get('hub.mode');const token=u.searchParams.get('hub.verify_token');const challenge=u.searchParams.get('hub.challenge')||'';
  if(mode==='subscribe'&&wa.safeEqualText(token,WA_VERIFY_TOKEN)){res.writeHead(200,{'Content-Type':'text/plain; charset=utf-8','Cache-Control':'no-store','X-Ascenda-WA-Gateway':'v1'});res.end(challenge);return;}
  res.writeHead(403,{'Cache-Control':'no-store','X-Ascenda-WA-Gateway':'v1'});res.end('Forbidden');
}
async function persistWaEnvelope(envelope){
  for(const m of envelope.messages){await sbService('POST','/rest/v1/aos_wa_messages_v1?on_conflict=provider_message_id',m,'resolution=merge-duplicates,return=minimal');}
  for(const st of envelope.statuses){
    const patch={status:st.status,pricing_category:st.pricing_category,pricing_model:st.pricing_model,billable:st.billable,error_code:st.error_code,error_title:st.error_title,updated_at:new Date().toISOString()};
    if(st.status==='sent')patch.sent_at=st.provider_timestamp;if(st.status==='delivered')patch.delivered_at=st.provider_timestamp;if(st.status==='read')patch.read_at=st.provider_timestamp;if(st.status==='failed')patch.failed_at=st.provider_timestamp;
    await sbService('PATCH','/rest/v1/aos_wa_messages_v1?provider_message_id=eq.'+encodeURIComponent(st.provider_message_id),patch,'return=minimal');
  }
  for(const ev of envelope.events){await sbService('POST','/rest/v1/aos_wa_events_v1?on_conflict=event_key',ev,'resolution=ignore-duplicates,return=minimal');}
}
async function handleWaWebhook(req,res){
  if(!waConfigReadyInbound()){writeJson(res,503,{ok:false,error:'WA_GATEWAY_NOT_CONFIGURED'});return;}
  try{
    const raw=await readRaw(req,1024*1024);const signature=req.headers['x-hub-signature-256'];
    if(!wa.verifyMetaSignature(raw,signature,WA_APP_SECRET)){writeJson(res,401,{ok:false,error:'INVALID_META_SIGNATURE'});return;}
    let payload;try{payload=JSON.parse(raw.toString('utf8'));}catch(e){writeJson(res,400,{ok:false,error:'INVALID_JSON'});return;}
    const envelope=wa.extractWebhook(payload);await persistWaEnvelope(envelope);
    res.writeHead(200,{'Content-Type':'text/plain; charset=utf-8','Cache-Control':'no-store','X-Ascenda-WA-Gateway':'v1'});res.end('EVENT_RECEIVED');
  }catch(e){console.error('[WA-GATEWAY] webhook',e.message);writeJson(res,e.status||503,{ok:false,error:e.message==='PAYLOAD_TOO_LARGE'?'PAYLOAD_TOO_LARGE':'WA_WEBHOOK_UNAVAILABLE'});}
}
function graphSend(payload){
  return new Promise((resolve,reject)=>{
    if(!waConfigReadyOutbound()){reject(Object.assign(new Error('WA_OUTBOUND_NOT_CONFIGURED'),{status:503,definite:true}));return;}
    const data=JSON.stringify(payload);const q=https.request({hostname:'graph.facebook.com',path:'/'+WA_GRAPH_VERSION+'/'+encodeURIComponent(WA_PHONE_NUMBER_ID)+'/messages',method:'POST',headers:{Authorization:'Bearer '+WA_ACCESS_TOKEN,'Content-Type':'application/json','Content-Length':Buffer.byteLength(data),'User-Agent':'AscendaOS-WA-Gateway/1.0'},timeout:15000},r=>{let out='';r.on('data',c=>out+=c);r.on('end',()=>{let parsed={};try{parsed=out?JSON.parse(out):{};}catch(e){}if(r.statusCode>=200&&r.statusCode<300)resolve(parsed);else reject(Object.assign(new Error('META_SEND_REJECTED'),{status:502,metaStatus:r.statusCode,definite:true}));});});
    q.on('timeout',()=>q.destroy(Object.assign(new Error('META_SEND_TIMEOUT'),{status:504,ambiguous:true})));
    q.on('error',err=>reject(Object.assign(err,{status:err.status||502,ambiguous:err.definite!==true})));
    q.write(data);q.end();
  });
}
async function reserveOutbound(idempotencyKey,actor,payload,meta){
  const m=meta||{};const recipientKind=wa.recipientKind(payload);const recipientAddress=wa.recipientAddress(payload);
  const created=await sbService('POST','/rest/v1/aos_wa_outbound_requests_v1?on_conflict=idempotency_key',{
    idempotency_key:String(idempotencyKey),actor_id:actor,to_number:recipientKind==='PHONE'?recipientAddress:null,
    recipient_kind:recipientKind,recipient_address:recipientAddress,message_type:payload.type,state:'PENDING',
    send_origin:m.send_origin||'HUMAN',conversation_id:m.conversation_id||null,authority_decision_id:m.authority_decision_id||null,updated_at:new Date().toISOString()
  },'resolution=ignore-duplicates,return=representation');
  if(Array.isArray(created.data)&&created.data.length===1)return {owner:true,row:created.data[0]};
  const existing=await sbService('GET','/rest/v1/aos_wa_outbound_requests_v1?idempotency_key=eq.'+encodeURIComponent(idempotencyKey)+'&select=idempotency_key,state,provider_message_id,error_code,send_origin,conversation_id,authority_decision_id&limit=1',null);
  return {owner:false,row:Array.isArray(existing.data)?existing.data[0]||null:null};
}
async function handleWaSend(req,res,body){
  if(!waConfigReadyOutbound()){writeJson(res,503,{ok:false,error:'WA_OUTBOUND_NOT_CONFIGURED'});return;}
  const actor=await authorizeWaSender(req);if(!actor){writeJson(res,403,{ok:false,error:'WA_ADMIN_2FA_REQUIRED'});return;}
  if(!wa.validIdempotencyKey(body&&body.idempotency_key)){writeJson(res,400,{ok:false,error:'IDEMPOTENCY_KEY_REQUIRED'});return;}
  let payload;try{payload=wa.buildOutboundPayload(body);}catch(e){writeJson(res,e.status||400,{ok:false,error:e.message});return;}
  if(!wa.canaryAllows(payload.to,WA_CANARY_MODE,WA_CANARY_ALLOW_TO)){writeJson(res,403,{ok:false,error:'WA_CANARY_RECIPIENT_BLOCKED'});return;}
  let reservation;
  try{
    reservation=await reserveOutbound(body.idempotency_key,actor,payload,{send_origin:'HUMAN'});
    if(!reservation.owner){
      const row=reservation.row||{};
      writeJson(res,row.state==='FAILED'?409:200,{ok:row.state!=='FAILED',idempotent:true,message_id:row.provider_message_id||null,status:row.state||'PENDING',error:row.state==='FAILED'?(row.error_code||'PREVIOUS_SEND_FAILED'):undefined});return;
    }
    const meta=await graphSend(payload);const messageId=meta&&meta.messages&&meta.messages[0]&&meta.messages[0].id;
    if(!messageId)throw Object.assign(new Error('META_MESSAGE_ID_MISSING'),{status:502,ambiguous:true});
    await sbService('PATCH','/rest/v1/aos_wa_outbound_requests_v1?idempotency_key=eq.'+encodeURIComponent(body.idempotency_key),{state:'ACCEPTED',provider_message_id:String(messageId),error_code:null,updated_at:new Date().toISOString()},'return=minimal');
    await sbService('POST','/rest/v1/aos_wa_messages_v1?on_conflict=provider_message_id',{
      provider_message_id:String(messageId),idempotency_key:String(body.idempotency_key),direction:'OUTBOUND',from_number:null,to_number:wa.recipientKind(payload)==='PHONE'?wa.recipientAddress(payload):null,to_user_id:wa.recipientKind(payload)==='BSUID'?wa.recipientAddress(payload):null,phone_number_id:WA_PHONE_NUMBER_ID,contact_name:null,message_type:payload.type,message_body:payload.type==='text'?payload.text.body:null,media_id:null,status:'accepted',actor_id:actor,send_origin:'HUMAN',received_at:new Date().toISOString(),updated_at:new Date().toISOString()
    },'resolution=merge-duplicates,return=minimal');
    await sbService('POST','/rest/v1/aos_wa_events_v1?on_conflict=event_key',{event_key:'outbound:'+String(messageId),event_type:'message.accepted',provider_message_id:String(messageId),status:'accepted',payload:{actor_id:actor,message_type:payload.type,send_origin:'HUMAN'}},'resolution=ignore-duplicates,return=minimal');
    writeJson(res,200,{ok:true,idempotent:false,message_id:String(messageId),status:'ACCEPTED',canary:String(WA_CANARY_MODE).toLowerCase()==='true'});
  }catch(e){
    if(reservation&&reservation.owner&&e.definite===true){try{await sbService('PATCH','/rest/v1/aos_wa_outbound_requests_v1?idempotency_key=eq.'+encodeURIComponent(body.idempotency_key),{state:'FAILED',error_code:String(e.message||'WA_SEND_FAILED').slice(0,128),updated_at:new Date().toISOString()},'return=minimal');}catch(_e){}}
    const ambiguous=!!(reservation&&reservation.owner&&e.definite!==true);
    console.error('[WA-GATEWAY] outbound',e.message,ambiguous?'ambiguous_pending':'definite_failure');
    writeJson(res,e.status||502,{ok:false,error:e.message||'WA_SEND_FAILED',status:ambiguous?'PENDING':'FAILED',retry_safe:false});
  }
}
async function requestL4Handoff(conversationId,reason){
  try{return await sbServiceRpc('aos_wa3_handoff_request_v1',{p_conversation_id:conversationId,p_box_id:null,p_actor_id:null,p_reason:l4.sanitizeReason(reason)});}catch(e){console.error('[WA-L4] handoff',e.message);return null;}
}
async function recordL4ProviderError(conversationId,decisionId,errorCode,ambiguous){
  try{await sbService('POST','/rest/v1/aos_wa_events_v1?on_conflict=event_key',{
    event_key:'auto-provider-error:'+String(decisionId),event_type:'auto.provider_error',provider_message_id:null,status:'handoff',
    payload:{conversation_id:conversationId,authority_decision_id:decisionId,error_code:l4.sanitizeReason(errorCode),ambiguous:!!ambiguous,raw_content_stored:false}
  },'resolution=ignore-duplicates,return=minimal');}catch(e){console.error('[WA-L4] provider audit',e.message);}
}
async function handleWaAutoSend(req,res,body){
  if(!WA_L4_INTERNAL_TOKEN||WA_L4_INTERNAL_TOKEN.length<32){writeJson(res,503,{ok:false,error:'WA_L4_INTERNAL_AUTH_NOT_CONFIGURED'});return;}
  if(!authorizeWaAutoRuntime(req)){writeJson(res,403,{ok:false,error:'WA_L4_INTERNAL_AUTH_REQUIRED'});return;}
  if(!wa.validIdempotencyKey(body&&body.idempotency_key)){writeJson(res,400,{ok:false,error:'IDEMPOTENCY_KEY_REQUIRED'});return;}
  let payload,authorityRequest;
  try{payload=wa.buildOutboundPayload(body);authorityRequest=l4.authorityPayload(body,payload);}catch(e){writeJson(res,e.status||400,{ok:false,error:e.message||'WA_L4_INVALID_REQUEST'});return;}
  let authority;
  try{
    const authOut=await sbServiceRpc('aos_wa_l4_authorize_autonomous_send_v1',authorityRequest);
    authority=authOut.data||{};
  }catch(e){console.error('[WA-L4] authority unavailable',e.message);writeJson(res,503,{ok:false,error:'WA_L4_AUTHORITY_UNAVAILABLE'});return;}
  if(authority.decision!=='ALLOW'){
    if(authority.decision==='HANDOFF')await requestL4Handoff(authorityRequest.p_conversation_id,authority.reason||'WA_L4_HANDOFF');
    writeJson(res,l4.decisionHttpStatus(authority),{ok:false,decision:authority.decision||'BLOCK',reason:authority.reason||'WA_L4_BLOCKED',decision_id:authority.decision_id||null,replay:!!authority.replay,handoff:authority.decision==='HANDOFF'});return;
  }
  if(!waConfigReadyOutbound()){await requestL4Handoff(authorityRequest.p_conversation_id,'WA_OUTBOUND_NOT_CONFIGURED');writeJson(res,503,{ok:false,error:'WA_OUTBOUND_NOT_CONFIGURED',decision_id:authority.decision_id,handoff:true});return;}
  const actor=String(authority.autonomous_actor_id||'00000000-0000-4000-8000-000000000004');
  let reservation;
  try{
    reservation=await reserveOutbound(body.idempotency_key,actor,payload,{send_origin:'AUTO',conversation_id:authorityRequest.p_conversation_id,authority_decision_id:authority.decision_id});
    if(!reservation.owner){
      const row=reservation.row||{};
      writeJson(res,row.state==='FAILED'?409:200,{ok:row.state!=='FAILED',idempotent:true,decision_id:authority.decision_id,message_id:row.provider_message_id||null,status:row.state||'PENDING',send_origin:'AUTO',error:row.state==='FAILED'?(row.error_code||'PREVIOUS_SEND_FAILED'):undefined});return;
    }
    const meta=await graphSend(payload);const messageId=meta&&meta.messages&&meta.messages[0]&&meta.messages[0].id;
    if(!messageId)throw Object.assign(new Error('META_MESSAGE_ID_MISSING'),{status:502,ambiguous:true});
    await sbService('PATCH','/rest/v1/aos_wa_outbound_requests_v1?idempotency_key=eq.'+encodeURIComponent(body.idempotency_key),{state:'ACCEPTED',provider_message_id:String(messageId),error_code:null,updated_at:new Date().toISOString()},'return=minimal');
    const rk=wa.recipientKind(payload),ra=wa.recipientAddress(payload);
    await sbService('POST','/rest/v1/aos_wa_messages_v1?on_conflict=provider_message_id',{
      provider_message_id:String(messageId),idempotency_key:String(body.idempotency_key),direction:'OUTBOUND',from_number:null,to_number:rk==='PHONE'?ra:null,to_user_id:rk==='BSUID'?ra:null,phone_number_id:WA_PHONE_NUMBER_ID,contact_name:null,message_type:payload.type,message_body:payload.type==='text'?payload.text.body:null,media_id:null,status:'accepted',actor_id:actor,conversation_id:authorityRequest.p_conversation_id,send_origin:'AUTO',authority_decision_id:authority.decision_id,received_at:new Date().toISOString(),updated_at:new Date().toISOString()
    },'resolution=merge-duplicates,return=minimal');
    await sbService('POST','/rest/v1/aos_wa_events_v1?on_conflict=event_key',{event_key:'auto-outbound:'+String(messageId),event_type:'auto.message.accepted',provider_message_id:String(messageId),status:'accepted',payload:{conversation_id:authorityRequest.p_conversation_id,authority_decision_id:authority.decision_id,message_type:payload.type,send_origin:'AUTO',raw_content_stored:false}},'resolution=ignore-duplicates,return=minimal');
    writeJson(res,200,{ok:true,idempotent:false,decision_id:authority.decision_id,message_id:String(messageId),status:'ACCEPTED',send_origin:'AUTO',mode:authority.mode});
  }catch(e){
    if(reservation&&reservation.owner&&e.definite===true){try{await sbService('PATCH','/rest/v1/aos_wa_outbound_requests_v1?idempotency_key=eq.'+encodeURIComponent(body.idempotency_key),{state:'FAILED',error_code:l4.sanitizeReason(e.message||'WA_SEND_FAILED'),updated_at:new Date().toISOString()},'return=minimal');}catch(_e){}}
    const ambiguous=!!(reservation&&reservation.owner&&e.definite!==true);
    await recordL4ProviderError(authorityRequest.p_conversation_id,authority.decision_id,e.message||'WA_SEND_FAILED',ambiguous);
    await requestL4Handoff(authorityRequest.p_conversation_id,e.message||'WA_SEND_FAILED');
    console.error('[WA-L4] provider outbound',e.message,ambiguous?'ambiguous_pending':'definite_failure');
    writeJson(res,e.status||502,{ok:false,error:e.message||'WA_SEND_FAILED',decision_id:authority.decision_id,status:ambiguous?'PENDING':'FAILED',retry_safe:false,handoff:true});
  }
}
async function handleWaAutoTyping(req,res,body){
  if(!WA_L4_INTERNAL_TOKEN||WA_L4_INTERNAL_TOKEN.length<32){writeJson(res,503,{ok:false,error:'WA_L4_INTERNAL_AUTH_NOT_CONFIGURED'});return;}
  if(!authorizeWaAutoRuntime(req)){writeJson(res,403,{ok:false,error:'WA_L4_INTERNAL_AUTH_REQUIRED'});return;}
  const messageId=String(body&&body.provider_message_id||'').trim();
  if(!/^wamid\.[A-Za-z0-9._~:/+=-]{8,500}$/.test(messageId)){writeJson(res,400,{ok:false,error:'WA_TYPING_PROVIDER_MESSAGE_ID_REQUIRED'});return;}
  if(!waConfigReadyOutbound()){writeJson(res,503,{ok:false,error:'WA_OUTBOUND_NOT_CONFIGURED'});return;}
  try{
    await graphSend({messaging_product:'whatsapp',status:'read',message_id:messageId,typing_indicator:{type:'text'}});
    writeJson(res,200,{ok:true,typing:true,provider:'META'});
  }catch(e){
    console.error('[WA-L10] typing indicator',l4.sanitizeReason(e&&e.message));
    writeJson(res,e.status||502,{ok:false,error:'WA_TYPING_PROVIDER_UNAVAILABLE'});
  }
}

async function handleWaStatus(req,res){
  try{
    const actor=await authorizeWaSender(req);if(!actor){writeJson(res,403,{ok:false,error:'WA_ADMIN_2FA_REQUIRED'});return;}
    let l4Status={available:false};
    try{const r=await sbServiceRpc('aos_wa_l4_status_v1',{});l4Status=Object.assign({available:true},r.data||{});}catch(e){l4Status={available:false,error:'WA_L4_STATUS_UNAVAILABLE'};}
    writeJson(res,200,{ok:true,gateway:'v1+l4',inbound_configured:waConfigReadyInbound(),outbound_configured:waConfigReadyOutbound(),legacy_human_canary:String(WA_CANARY_MODE).toLowerCase()==='true',legacy_human_allowlist_count:String(WA_CANARY_ALLOW_TO).split(',').filter(Boolean).length,l4_internal_auth_configured:WA_L4_INTERNAL_TOKEN.length>=32,l4:l4Status});
  }catch(e){writeJson(res,503,{ok:false,error:'WA_STATUS_UNAVAILABLE'});}
}

const server=http.createServer(async(req,res)=>{
  let pathname='/';try{pathname=new URL(req.url,'http://localhost').pathname;}catch(e){}
  if(pathname==='/api/email-gateway'||pathname==='/api/send-email'){EMAIL_GATEWAY.handleAdmin(req,res);return;}
  if(pathname==='/api/resend-webhook'){EMAIL_GATEWAY.handleWebhook(req,res);return;}
  if((pathname==='/webhook'||pathname==='/webhook/')&&req.method==='GET'){handleWaVerify(req,res);return;}
  if((pathname==='/webhook'||pathname==='/webhook/')&&req.method==='POST'){await handleWaWebhook(req,res);return;}
  if(pathname==='/api/wa/send'&&req.method==='POST'){try{const parsed=await readJson(req,256*1024);await handleWaSend(req,res,parsed.body);}catch(e){writeJson(res,e.status||400,{ok:false,error:e.message||'INVALID_REQUEST'});}return;}
  if(pathname==='/api/wa/auto-send'&&req.method==='POST'){try{const parsed=await readJson(req,256*1024);await handleWaAutoSend(req,res,parsed.body);}catch(e){writeJson(res,e.status||400,{ok:false,error:e.message||'INVALID_REQUEST'});}return;}
  if(pathname==='/api/wa/auto-typing'&&req.method==='POST'){try{const parsed=await readJson(req,16*1024);await handleWaAutoTyping(req,res,parsed.body);}catch(e){writeJson(res,e.status||400,{ok:false,error:e.message||'INVALID_REQUEST'});}return;}
  if(pathname==='/api/wa/status'&&req.method==='GET'){await handleWaStatus(req,res);return;}
  if(pathname==='/api/wa/send'&&req.method==='OPTIONS'){res.writeHead(204,{'Access-Control-Allow-Methods':'POST,OPTIONS','Access-Control-Allow-Headers':'Content-Type,X-AOS-App-Token','Cache-Control':'no-store'});res.end();return;}
  if(pathname==='/api/wa/auto-send'){writeJson(res,405,{ok:false,error:'WA_L4_INTERNAL_POST_ONLY'});return;}
  if(pathname==='/api/wa/auto-typing'){writeJson(res,405,{ok:false,error:'WA_L4_INTERNAL_POST_ONLY'});return;}
  if(pathname==='/api/f4/cartera-read'&&req.method==='POST'){try{const parsed=await readJson(req,64*1024);await handleRevenueRead(req,res,parsed.body,'cartera');}catch(e){writeJson(res,e.status||400,{ok:false,error:e.message||'INVALID_REQUEST'});}return;}
  if(pathname==='/api/f4/sales-intelligence-read'&&req.method==='POST'){try{const parsed=await readJson(req,64*1024);await handleRevenueRead(req,res,parsed.body,'sales-intelligence');}catch(e){writeJson(res,e.status||400,{ok:false,error:e.message||'INVALID_REQUEST'});}return;}
  if(pathname==='/api/f4/cartera-candidates'&&req.method==='POST'){
    try{const parsed=await readJson(req,128*1024);await handleCandidates(req,res,parsed.body);}catch(e){writeJson(res,e.status||400,{ok:false,error:e.message||'INVALID_REQUEST'});}return;
  }
  if(pathname==='/api/kronia/chat'&&req.method==='POST'){
    try{const parsed=await readJson(req);if(parsed.body&&parsed.body.confirmar_accion&&parsed.body.confirmar_accion.rpc==='aos_editar_venta'){await handleKroniaSaleEdit(req,res,parsed.body);return;}proxyBuffered(req,res,parsed.raw);}catch(e){writeJson(res,e.status||400,{ok:false,error:e.message||'INVALID_REQUEST'});}return;
  }
  proxyStream(req,res);
});
function proxyBuffered(req,res,raw){const headers=Object.assign({},req.headers,{host:'127.0.0.1:'+INNER_PORT,'content-length':Buffer.byteLength(raw)});const up=http.request({hostname:'127.0.0.1',port:INNER_PORT,path:req.url,method:req.method,headers},r=>{res.writeHead(r.statusCode||502,r.headers);r.pipe(res);});up.on('error',e=>{if(!res.headersSent)writeJson(res,502,{ok:false,error:'UPSTREAM_UNAVAILABLE'});else res.end();console.error('[F4-PROXY] buffered',e.message);});up.write(raw);up.end();}
function proxyStream(req,res){const headers=Object.assign({},req.headers,{host:'127.0.0.1:'+INNER_PORT});const up=http.request({hostname:'127.0.0.1',port:INNER_PORT,path:req.url,method:req.method,headers},r=>{res.writeHead(r.statusCode||502,r.headers);r.pipe(res);});up.on('error',e=>{if(!res.headersSent)writeJson(res,502,{ok:false,error:'UPSTREAM_UNAVAILABLE'});else res.end();console.error('[F4-PROXY] stream',e.message);});req.pipe(up);}
function shutdown(sig){console.log('[F4-PROXY] shutdown',sig);server.close(()=>process.exit(0));if(!child.killed)child.kill(sig);setTimeout(()=>process.exit(1),5000).unref();}
process.on('SIGTERM',()=>shutdown('SIGTERM'));process.on('SIGINT',()=>shutdown('SIGINT'));
server.listen(EXTERNAL_PORT,'0.0.0.0',()=>console.log('[F4-PROXY] listening on :'+EXTERNAL_PORT+' -> :'+INNER_PORT+' | WA gateway v1 + L4 authority AUTO_OFF-by-default'));
