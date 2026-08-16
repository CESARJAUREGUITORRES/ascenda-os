'use strict';
const fs=require('fs');
const path=require('path');
const file=path.join(process.cwd(),'app','server-f4.js');
let s=fs.readFileSync(file,'utf8');
function once(oldText,newText,label){
  const count=s.split(oldText).length-1;
  if(count!==1)throw new Error(label+': expected 1 match, found '+count);
  s=s.replace(oldText,newText);
}

once(
  "const wa=require('./wa-gateway');\nconst {createEmailGateway}=require('./email-gateway');",
  "const wa=require('./wa-gateway');\nconst {createF17WaAdapter}=require('./f17-wa-adapter');\nconst {createEmailGateway}=require('./email-gateway');",
  'import F17 WA adapter'
);

once(
  "const data=body==null?'':JSON.stringify(body);const headers={apikey:SB_SERVICE_KEY,Authorization:'Bearer '+SB_SERVICE_KEY,'Content-Type':'application/json','User-Agent':'AscendaOS-WA-Gateway/1.0'};",
  "const data=body==null?'':JSON.stringify(body);const headers={apikey:SB_SERVICE_KEY,'Content-Type':'application/json','User-Agent':'AscendaOS-WA-Gateway/1.0'};if(!/^sb_secret_/i.test(SB_SERVICE_KEY))headers.Authorization='Bearer '+SB_SERVICE_KEY;",
  'service key header compatibility'
);

once(
  "function strongToken(req){const t=String(req.headers['x-aos-app-token']||'').trim();return t.length>=32?t:'';}",
  "async function sbServiceRpc(name,payload){const out=await sbService('POST','/rest/v1/rpc/'+encodeURIComponent(name),payload||{});return out.data;}\nconst F17_WA=createF17WaAdapter({serviceRpc:sbServiceRpc,canaryMode:WA_CANARY_MODE});\nfunction strongToken(req){const t=String(req.headers['x-aos-app-token']||'').trim();return t.length>=32?t:'';}",
  'instantiate F17 WA adapter'
);

const persistNeedle="  for(const ev of envelope.events){await sbService('POST','/rest/v1/aos_wa_events_v1?on_conflict=event_key',ev,'resolution=ignore-duplicates,return=minimal');}\n}";
once(
  persistNeedle,
  "  for(const ev of envelope.events){await sbService('POST','/rest/v1/aos_wa_events_v1?on_conflict=event_key',ev,'resolution=ignore-duplicates,return=minimal');}\n  await F17_WA.ingestEnvelope(envelope);\n}",
  'wire inbound/provider events'
);

once(
  "  if(!wa.canaryAllows(payload.to,WA_CANARY_MODE,WA_CANARY_ALLOW_TO)){writeJson(res,403,{ok:false,error:'WA_CANARY_RECIPIENT_BLOCKED'});return;}\n  let reservation;",
  "  if(!wa.canaryAllows(payload.to,WA_CANARY_MODE,WA_CANARY_ALLOW_TO)){writeJson(res,403,{ok:false,error:'WA_CANARY_RECIPIENT_BLOCKED'});return;}\n  let f17Request=null;\n  try{\n    f17Request=await F17_WA.prepareOutbound({actor,idempotencyKey:body.idempotency_key,payload});\n    if(!f17Request||f17Request.dispatch_allowed!==true){writeJson(res,403,{ok:false,error:'F17_CHANNEL_POLICY_BLOCKED',state:f17Request&&f17Request.state||'BLOCKED'});return;}\n  }catch(e){console.error('[WA-GATEWAY] F17 prepare',e.message);writeJson(res,e.status||503,{ok:false,error:'F17_CHANNEL_POLICY_UNAVAILABLE'});return;}\n  let reservation;",
  'enforce F17 prepare before legacy reservation'
);

once(
  "    if(!reservation.owner){\n      const row=reservation.row||{};\n      writeJson(res,row.state==='FAILED'?409:200,{ok:row.state!=='FAILED',idempotent:true,message_id:row.provider_message_id||null,status:row.state||'PENDING',error:row.state==='FAILED'?(row.error_code||'PREVIOUS_SEND_FAILED'):undefined});return;\n    }",
  "    if(!reservation.owner){\n      const row=reservation.row||{};\n      if(row.provider_message_id&&f17Request&&f17Request.request_id)await F17_WA.markAccepted(f17Request.request_id,row.provider_message_id);\n      writeJson(res,row.state==='FAILED'?409:200,{ok:row.state!=='FAILED',idempotent:true,message_id:row.provider_message_id||null,status:row.state||'PENDING',error:row.state==='FAILED'?(row.error_code||'PREVIOUS_SEND_FAILED'):undefined});return;\n    }",
  'reconcile idempotent legacy acceptance'
);

once(
  "    await sbService('POST','/rest/v1/aos_wa_events_v1?on_conflict=event_key',{event_key:'outbound:'+String(messageId),event_type:'message.accepted',provider_message_id:String(messageId),status:'accepted',payload:{actor_id:actor,message_type:payload.type}},'resolution=ignore-duplicates,return=minimal');\n    writeJson(res,200,{ok:true,idempotent:false,message_id:String(messageId),status:'ACCEPTED',canary:String(WA_CANARY_MODE).toLowerCase()==='true'});",
  "    await sbService('POST','/rest/v1/aos_wa_events_v1?on_conflict=event_key',{event_key:'outbound:'+String(messageId),event_type:'message.accepted',provider_message_id:String(messageId),status:'accepted',payload:{actor_id:actor,message_type:payload.type}},'resolution=ignore-duplicates,return=minimal');\n    await F17_WA.markAccepted(f17Request.request_id,String(messageId));\n    writeJson(res,200,{ok:true,idempotent:false,message_id:String(messageId),status:'ACCEPTED',canary:String(WA_CANARY_MODE).toLowerCase()==='true',governed:true});",
  'mark governed provider acceptance'
);

once(
  "    if(reservation&&reservation.owner&&e.definite===true){try{await sbService('PATCH','/rest/v1/aos_wa_outbound_requests_v1?idempotency_key=eq.'+encodeURIComponent(body.idempotency_key),{state:'FAILED',error_code:String(e.message||'WA_SEND_FAILED').slice(0,128),updated_at:new Date().toISOString()},'return=minimal');}catch(_e){}}",
  "    if(reservation&&reservation.owner&&e.definite===true){try{await sbService('PATCH','/rest/v1/aos_wa_outbound_requests_v1?idempotency_key=eq.'+encodeURIComponent(body.idempotency_key),{state:'FAILED',error_code:String(e.message||'WA_SEND_FAILED').slice(0,128),updated_at:new Date().toISOString()},'return=minimal');if(f17Request&&f17Request.request_id)await F17_WA.markFailed(f17Request.request_id,e.message||'WA_SEND_FAILED');}catch(_e){}}",
  'mark governed definite failure'
);

fs.writeFileSync(file,s);
console.log('F17_WA_RUNTIME_PATCH_APPLIED');