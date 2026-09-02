'use strict';
const crypto=require('crypto');

function safeEqual(a,b){
  const aa=Buffer.from(String(a||''));
  const bb=Buffer.from(String(b||''));
  if(!aa.length||aa.length!==bb.length)return false;
  return crypto.timingSafeEqual(aa,bb);
}
function internalTokenValid(headerValue,secret){
  const expected=String(secret||'').trim();
  const actual=String(headerValue||'').trim();
  return expected.length>=32&&safeEqual(actual,expected);
}
function uuidValue(v){
  const s=String(v||'').trim();
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(s)?s:null;
}
function sha256Text(v){return crypto.createHash('sha256').update(String(v==null?'':v)).digest('hex');}
function payloadHash(payload){return sha256Text(JSON.stringify(payload||{}));}
function authorityPayload(body,payload){
  const b=body||{};
  const conversationId=uuidValue(b.conversation_id);
  if(!conversationId)throw Object.assign(new Error('WA_L4_CONVERSATION_ID_REQUIRED'),{status:400});
  const recipientKind=String(payload&&payload._recipient_kind||b.recipient_kind||'').trim().toUpperCase();
  const recipientAddress=String((payload&&(payload.recipient||payload.to))||b.recipient_address||'').trim();
  if(!['PHONE','BSUID'].includes(recipientKind)||!recipientAddress)throw Object.assign(new Error('WA_L4_RECIPIENT_REQUIRED'),{status:400});
  return {
    p_conversation_id:conversationId,
    p_recipient_kind:recipientKind,
    p_recipient_address:recipientAddress,
    p_message_type:String(b.type||'text').trim().toLowerCase(),
    p_template_name:b.type&&String(b.type).toLowerCase()==='template'?String(b.template_name||'').trim():null,
    p_idempotency_key:String(b.idempotency_key||''),
    p_content_hash:payloadHash(payload),
    p_safety_action:String(b.safety_action||'ALLOW').trim().toUpperCase(),
    p_identity_state:String(b.identity_state||'NOT_REQUIRED').trim().toUpperCase(),
    p_requires_identity:b.requires_identity===true,
    p_campaign_key:b.campaign_key==null?null:String(b.campaign_key).trim()||null
  };
}
function decisionHttpStatus(decision){
  if(!decision||decision.decision==='BLOCK')return 403;
  if(decision.decision==='HANDOFF')return 409;
  return 200;
}
function sanitizeReason(v){return String(v||'WA_L4_UNKNOWN').replace(/[^A-Z0-9_.:-]/gi,'_').slice(0,128);}

module.exports={safeEqual,internalTokenValid,uuidValue,sha256Text,payloadHash,authorityPayload,decisionHttpStatus,sanitizeReason};
