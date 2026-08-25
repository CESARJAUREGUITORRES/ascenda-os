'use strict';
const crypto=require('crypto');

function safeEqualText(a,b){
  const aa=Buffer.from(String(a||''));const bb=Buffer.from(String(b||''));
  if(aa.length!==bb.length)return false;
  return crypto.timingSafeEqual(aa,bb);
}

function verifyMetaSignature(rawBody,signatureHeader,appSecret){
  if(!appSecret||!signatureHeader)return false;
  const header=String(signatureHeader).trim();
  if(!/^sha256=[a-f0-9]{64}$/i.test(header))return false;
  const digest='sha256='+crypto.createHmac('sha256',appSecret).update(Buffer.isBuffer(rawBody)?rawBody:Buffer.from(String(rawBody||''))).digest('hex');
  return safeEqualText(header.toLowerCase(),digest.toLowerCase());
}

function trimText(v,max){return String(v==null?'':v).slice(0,max||4000);}
function normalizePhone(v){return String(v||'').replace(/\D/g,'').slice(0,20);}
function phoneValue(v){
  const raw=String(v==null?'':v).trim();
  if(!raw||/[A-Za-z]/.test(raw))return null;
  const digits=normalizePhone(raw);
  return digits.length>=8&&digits.length<=20?digits:null;
}
function userIdValue(v){
  const s=String(v==null?'':v).trim();
  if(!s||s.length>256||/[\u0000-\u001f\u007f]/.test(s))return null;
  return s;
}
function usernameValue(v){
  const s=String(v==null?'':v).trim().replace(/^@/,'');
  return s?trimText(s,256):null;
}
function isoFromUnix(v){const n=Number(v);return Number.isFinite(n)&&n>0?new Date(n*1000).toISOString():new Date().toISOString();}

function recipientFromInput(d){
  const explicitKind=String(d&&d.recipient_kind||'').trim().toUpperCase();
  const explicitAddress=userIdValue(d&&d.recipient_address);
  const explicitRecipient=userIdValue(d&&d.recipient);
  if(explicitKind==='PHONE'){
    const phone=phoneValue(explicitAddress||d.to);
    if(!phone)throw Object.assign(new Error('INVALID_RECIPIENT'),{status:400});
    return {kind:'PHONE',address:phone};
  }
  if(explicitKind==='BSUID'){
    const bsuid=userIdValue(explicitAddress||explicitRecipient||d.to);
    if(!bsuid)throw Object.assign(new Error('INVALID_RECIPIENT'),{status:400});
    return {kind:'BSUID',address:bsuid};
  }
  const phone=phoneValue(d&&d.to);
  if(phone)return {kind:'PHONE',address:phone};
  const bsuid=userIdValue(explicitRecipient||(d&&d.to));
  if(bsuid)return {kind:'BSUID',address:bsuid};
  throw Object.assign(new Error('INVALID_RECIPIENT'),{status:400});
}
function recipientAddress(payload){return userIdValue(payload&&(payload.to||payload.recipient));}
function recipientKind(payload){return payload&&payload.recipient?'BSUID':'PHONE';}

function messageBody(msg){
  if(msg.text&&msg.text.body)return trimText(msg.text.body,8000);
  if(msg.button&&msg.button.text)return trimText(msg.button.text,2000);
  if(msg.interactive){
    const i=msg.interactive;
    if(i.button_reply)return trimText(i.button_reply.title||i.button_reply.id,2000);
    if(i.list_reply)return trimText(i.list_reply.title||i.list_reply.id,2000);
  }
  if(msg.image&&msg.image.caption)return trimText(msg.image.caption,4000);
  if(msg.document&&msg.document.caption)return trimText(msg.document.caption,4000);
  return '';
}
function mediaId(msg){const t=msg.type;const obj=t&&msg[t];return obj&&obj.id?trimText(obj.id,256):null;}
function contactForMessage(contacts,msg){
  const msgPhone=phoneValue(msg&&msg.from);
  const msgUser=userIdValue(msg&&msg.from_user_id)||(!msgPhone?userIdValue(msg&&msg.from):null);
  return (contacts||[]).find(c=>{
    const cp=phoneValue(c&&c.wa_id);const cu=userIdValue(c&&c.user_id);
    return (msgUser&&cu===msgUser)||(msgPhone&&cp===msgPhone);
  })||{};
}
function contactPhones(card){
  const seen=new Set();
  (card&&Array.isArray(card.phones)?card.phones:[]).forEach(p=>{
    const v=phoneValue((p&&p.wa_id)||(p&&p.phone));if(v)seen.add(v);
  });
  return Array.from(seen);
}
function identityKey(parts){return trimText(parts.filter(Boolean).join(':'),900);}

function extractWebhook(payload){
  const messages=[];const statuses=[];const events=[];
  if(!payload||payload.object!=='whatsapp_business_account'||!Array.isArray(payload.entry))return {messages,statuses,events};
  payload.entry.forEach(entry=>{
    (entry.changes||[]).forEach(change=>{
      // Meta corrected the 2026 contract: there is no subscribable `user_id_update` field.
      // BSUID rotation is consumed below as a system message on the existing `messages` subscription.
      if(change.field!=='messages')return;
      const value=change.value||{};const meta=value.metadata||{};const contacts=value.contacts||[];
      const businessScope=trimText(meta.phone_number_id,128)||'default';
      (value.messages||[]).forEach(msg=>{
        const observedAt=isoFromUnix(msg.timestamp);
        if(String(msg.type||'').toLowerCase()==='system'){
          const system=msg.system||{};const systemType=String(system.type||'').toLowerCase();
          if(['user_changed_number','user_changed_user_id'].includes(systemType)){
            const previousUser=userIdValue(system.previous_user_id);
            const currentUser=userIdValue(system.user_id);
            const previousParent=userIdValue(system.previous_parent_user_id);
            const currentParent=userIdValue(system.parent_user_id);
            const changedPhone=phoneValue(system.wa_id);
            events.push({
              event_key:identityKey(['identity','system',trimText(msg.id,256)||businessScope,systemType,previousUser,currentUser,String(msg.timestamp||'')]),
              event_type:'identity.system_change',provider_message_id:trimText(msg.id,256)||null,status:'observed',
              payload:{business_scope:businessScope,system_type:systemType,previous_user_id:previousUser,user_id:currentUser,previous_parent_user_id:previousParent,parent_user_id:currentParent,wa_id:changedPhone,observed_at:observedAt,source:'META_MESSAGES_SYSTEM'}
            });
          }
          return; // System identity events are state transitions, not customer chat messages.
        }

        const contact=contactForMessage(contacts,msg);const profile=contact.profile||{};
        const fromPhone=phoneValue(msg.from)||phoneValue(contact.wa_id);
        const fromUser=userIdValue(msg.from_user_id)||userIdValue(contact.user_id)||(!fromPhone?userIdValue(msg.from):null);
        const parentUser=userIdValue(msg.from_parent_user_id)||userIdValue(contact.parent_user_id);
        const referral=msg.referral||{};
        const row={
          provider_message_id:trimText(msg.id,256),direction:'INBOUND',
          from_number:fromPhone,to_number:phoneValue(meta.display_phone_number),
          from_user_id:fromUser,from_parent_user_id:parentUser,to_user_id:null,to_parent_user_id:null,
          phone_number_id:trimText(meta.phone_number_id,128)||null,
          contact_name:trimText(profile.name,256)||null,contact_username:usernameValue(profile.username),
          message_type:trimText(msg.type||'unknown',64),message_body:messageBody(msg)||null,media_id:mediaId(msg),status:'received',
          campaign_source:trimText(referral.headline||referral.source_type||'',512)||null,ad_id:trimText(referral.source_id||'',256)||null,
          raw_referral:Object.keys(referral).length?{
            source_id:trimText(referral.source_id,256)||null,source_type:trimText(referral.source_type,64)||null,
            headline:trimText(referral.headline,512)||null,body:trimText(referral.body,1000)||null
          }:null,provider_timestamp:observedAt,received_at:new Date().toISOString()
        };
        if(!row.provider_message_id)return;
        messages.push(row);
        events.push({event_key:'message:'+row.provider_message_id,event_type:'message.received',provider_message_id:row.provider_message_id,status:'received',payload:{message_type:row.message_type,phone_number_id:row.phone_number_id,has_referral:!!row.raw_referral,sender_kind:row.from_number?'PHONE':(row.from_user_id?'BSUID':'UNKNOWN'),has_user_id:!!row.from_user_id}});

        // A signed Meta message carrying both identifiers is direct channel-pair evidence.
        if(fromPhone&&fromUser){
          events.push({event_key:'identity:pair:'+row.provider_message_id,event_type:'identity.meta_pair',provider_message_id:row.provider_message_id,status:'observed',payload:{business_scope:businessScope,phone:fromPhone,user_id:fromUser,parent_user_id:parentUser,observed_at:observedAt,source:'META_SIGNED_MESSAGE_PAIR'}});
        }

        // REQUEST_CONTACT_INFO response versus an arbitrary forwarded contact card.
        if(String(msg.type||'').toLowerCase()==='contacts'&&Array.isArray(msg.contacts)){
          msg.contacts.forEach((card,index)=>{
            const phones=contactPhones(card);const origin=String(card&&card.origin||'other').toLowerCase();
            events.push({
              event_key:'identity:contact:'+row.provider_message_id+':'+index,
              event_type:'identity.contact_disclosure',provider_message_id:row.provider_message_id,status:'observed',
              payload:{business_scope:businessScope,origin,sender_phone:fromPhone,sender_user_id:fromUser,sender_parent_user_id:parentUser,shared_phone:phones.length===1?phones[0]:null,shared_phone_count:phones.length,observed_at:observedAt,source:origin==='contact_request'?'META_CONTACT_REQUEST':'META_CONTACT_OTHER'}
            });
          });
        }
      });
      (value.statuses||[]).forEach(st=>{
        const id=trimText(st.id,256);if(!id)return;
        const pricing=st.pricing||{};const state=trimText(st.status||'unknown',64);
        const recipientPhone=phoneValue(st.recipient_id);
        const recipientUser=userIdValue(st.recipient_user_id)||(!recipientPhone?userIdValue(st.recipient_id):null);
        const recipientParent=userIdValue(st.recipient_parent_user_id);
        const observedAt=isoFromUnix(st.timestamp);
        const row={provider_message_id:id,status:state,recipient_id:recipientPhone,recipient_user_id:recipientUser,recipient_parent_user_id:recipientParent,provider_timestamp:observedAt,
          pricing_category:trimText(pricing.category||'',64)||null,pricing_model:trimText(pricing.pricing_model||'',64)||null,
          billable:typeof pricing.billable==='boolean'?pricing.billable:null,error_code:null,error_title:null};
        if(Array.isArray(st.errors)&&st.errors[0]){row.error_code=trimText(st.errors[0].code,64)||null;row.error_title=trimText(st.errors[0].title||st.errors[0].message,512)||null;}
        statuses.push(row);
        events.push({event_key:'status:'+id+':'+state+':'+String(st.timestamp||''),event_type:'message.status',provider_message_id:id,status:state,payload:{recipient_id:row.recipient_id,recipient_user_id:row.recipient_user_id,recipient_parent_user_id:row.recipient_parent_user_id,recipient_kind:row.recipient_id?'PHONE':(row.recipient_user_id?'BSUID':'UNKNOWN'),pricing_category:row.pricing_category,pricing_model:row.pricing_model,billable:row.billable,error_code:row.error_code}});
        if(recipientUser&&['delivered','read'].includes(String(state).toLowerCase())){
          events.push({event_key:'identity:status:'+id+':'+state+':'+recipientUser,event_type:'identity.status_binding',provider_message_id:id,status:state,payload:{business_scope:businessScope,provider_status:state,recipient_user_id:recipientUser,recipient_parent_user_id:recipientParent,observed_at:observedAt,source:'META_STATUS_RECIPIENT_USER_ID'}});
        }
      });
    });
  });
  return {messages,statuses,events};
}

function buildOutboundPayload(input){
  const d=input||{};const recipient=recipientFromInput(d);const type=String(d.type||'text').toLowerCase();
  const out={messaging_product:'whatsapp',recipient_type:'individual'};
  if(recipient.kind==='PHONE')out.to=recipient.address;
  else{
    out.recipient=recipient.address;
    // Compatibility alias for existing ASCENDA server code. Non-enumerable means it is never sent to Meta.
    Object.defineProperty(out,'to',{value:recipient.address,enumerable:false,writable:false});
  }
  Object.defineProperty(out,'_recipient_kind',{value:recipient.kind,enumerable:false,writable:false});
  out.type=type;
  if(type==='text'){
    const body=trimText(d.text,4096);if(!body)throw Object.assign(new Error('TEXT_REQUIRED'),{status:400});out.text={preview_url:false,body};
  }else if(type==='template'){
    const name=trimText(d.template_name,512);const language=trimText(d.language||'es',32);if(!name)throw Object.assign(new Error('TEMPLATE_NAME_REQUIRED'),{status:400});
    out.template={name,language:{code:language}};if(Array.isArray(d.components))out.template.components=d.components;
  }else if(type==='request_contact_info'){
    const body=trimText(d.text||d.body,1024);if(!body)throw Object.assign(new Error('CONTACT_REQUEST_TEXT_REQUIRED'),{status:400});
    out.type='interactive';out.interactive={type:'request_contact_info',body:{text:body},action:{name:'request_contact_info'}};
    Object.defineProperty(out,'_ascenda_message_type',{value:'request_contact_info',enumerable:false,writable:false});
  }else if(['image','document','audio'].includes(type)){
    const link=trimText(d.link,2048);if(!/^https:\/\//i.test(link))throw Object.assign(new Error('HTTPS_MEDIA_LINK_REQUIRED'),{status:400});
    out[type]={link};if(type!=='audio'&&d.caption)out[type].caption=trimText(d.caption,1024);if(type==='document'&&d.filename)out.document.filename=trimText(d.filename,255);
  }else throw Object.assign(new Error('UNSUPPORTED_MESSAGE_TYPE'),{status:400});
  return out;
}

function validIdempotencyKey(v){return /^[A-Za-z0-9._:-]{16,120}$/.test(String(v||''));}
function normalizeCanaryAddress(v){const p=phoneValue(v);return p?('PHONE:'+p):('BSUID:'+String(v||'').trim());}
function canaryAllows(to,mode,allowCsv){
  if(String(mode||'true').toLowerCase()!=='true')return true;
  const candidate=normalizeCanaryAddress(to);if(candidate==='BSUID:')return false;
  const allowed=new Set(String(allowCsv||'').split(',').map(x=>x.trim()).filter(Boolean).map(normalizeCanaryAddress));
  return allowed.has(candidate);
}

module.exports={verifyMetaSignature,extractWebhook,buildOutboundPayload,normalizePhone,phoneValue,userIdValue,recipientAddress,recipientKind,validIdempotencyKey,canaryAllows,safeEqualText};
