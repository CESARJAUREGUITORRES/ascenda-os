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

function normalizePhone(v){return String(v||'').replace(/\D/g,'').slice(0,20);}
function isoFromUnix(v){const n=Number(v);return Number.isFinite(n)&&n>0?new Date(n*1000).toISOString():new Date().toISOString();}
function trimText(v,max){return String(v==null?'':v).slice(0,max||4000);}

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
function mediaId(msg){
  const t=msg.type;const obj=t&&msg[t];return obj&&obj.id?trimText(obj.id,256):null;
}

function extractWebhook(payload){
  const messages=[];const statuses=[];const events=[];
  if(!payload||payload.object!=='whatsapp_business_account'||!Array.isArray(payload.entry))return {messages,statuses,events};
  payload.entry.forEach(entry=>{
    (entry.changes||[]).forEach(change=>{
      if(change.field!=='messages')return;
      const value=change.value||{};const meta=value.metadata||{};const contacts=value.contacts||[];
      (value.messages||[]).forEach(msg=>{
        const from=normalizePhone(msg.from);const contact=contacts.find(c=>normalizePhone(c.wa_id)===from)||{};
        const referral=msg.referral||{};
        const row={
          provider_message_id:trimText(msg.id,256),direction:'INBOUND',from_number:from,to_number:normalizePhone(meta.display_phone_number),
          phone_number_id:trimText(meta.phone_number_id,128)||null,contact_name:trimText(contact.profile&&contact.profile.name,256)||null,
          message_type:trimText(msg.type||'unknown',64),message_body:messageBody(msg)||null,media_id:mediaId(msg),status:'received',
          campaign_source:trimText(referral.headline||referral.source_type||'',512)||null,ad_id:trimText(referral.source_id||'',256)||null,
          raw_referral:Object.keys(referral).length?{
            source_id:trimText(referral.source_id,256)||null,source_type:trimText(referral.source_type,64)||null,
            headline:trimText(referral.headline,512)||null,body:trimText(referral.body,1000)||null
          }:null,provider_timestamp:isoFromUnix(msg.timestamp),received_at:new Date().toISOString()
        };
        if(!row.provider_message_id)return;
        messages.push(row);
        events.push({event_key:'message:'+row.provider_message_id,event_type:'message.received',provider_message_id:row.provider_message_id,status:'received',payload:{message_type:row.message_type,phone_number_id:row.phone_number_id,has_referral:!!row.raw_referral}});
      });
      (value.statuses||[]).forEach(st=>{
        const id=trimText(st.id,256);if(!id)return;
        const pricing=st.pricing||{};const state=trimText(st.status||'unknown',64);
        const row={provider_message_id:id,status:state,recipient_id:normalizePhone(st.recipient_id),provider_timestamp:isoFromUnix(st.timestamp),
          pricing_category:trimText(pricing.category||'',64)||null,pricing_model:trimText(pricing.pricing_model||'',64)||null,
          billable:typeof pricing.billable==='boolean'?pricing.billable:null,error_code:null,error_title:null};
        if(Array.isArray(st.errors)&&st.errors[0]){row.error_code=trimText(st.errors[0].code,64)||null;row.error_title=trimText(st.errors[0].title||st.errors[0].message,512)||null;}
        statuses.push(row);
        events.push({event_key:'status:'+id+':'+state+':'+String(st.timestamp||''),event_type:'message.status',provider_message_id:id,status:state,payload:{recipient_id:row.recipient_id,pricing_category:row.pricing_category,pricing_model:row.pricing_model,billable:row.billable,error_code:row.error_code}});
      });
    });
  });
  return {messages,statuses,events};
}

function buildOutboundPayload(input){
  const d=input||{};const to=normalizePhone(d.to);if(to.length<8||to.length>15)throw Object.assign(new Error('INVALID_RECIPIENT'),{status:400});
  const type=String(d.type||'text').toLowerCase();const out={messaging_product:'whatsapp',recipient_type:'individual',to,type};
  if(type==='text'){
    const body=trimText(d.text,4096);if(!body)throw Object.assign(new Error('TEXT_REQUIRED'),{status:400});out.text={preview_url:false,body};
  }else if(type==='template'){
    const name=trimText(d.template_name,512);const language=trimText(d.language||'es',32);if(!name)throw Object.assign(new Error('TEMPLATE_NAME_REQUIRED'),{status:400});
    out.template={name,language:{code:language}};if(Array.isArray(d.components))out.template.components=d.components;
  }else if(['image','document','audio'].includes(type)){
    const link=trimText(d.link,2048);if(!/^https:\/\//i.test(link))throw Object.assign(new Error('HTTPS_MEDIA_LINK_REQUIRED'),{status:400});
    out[type]={link};if(type!=='audio'&&d.caption)out[type].caption=trimText(d.caption,1024);if(type==='document'&&d.filename)out.document.filename=trimText(d.filename,255);
  }else throw Object.assign(new Error('UNSUPPORTED_MESSAGE_TYPE'),{status:400});
  return out;
}

function validIdempotencyKey(v){return /^[A-Za-z0-9._:-]{16,120}$/.test(String(v||''));}
function canaryAllows(to,mode,allowCsv){
  if(String(mode||'true').toLowerCase()!=='true')return true;
  const allowed=new Set(String(allowCsv||'').split(',').map(normalizePhone).filter(Boolean));
  return allowed.has(normalizePhone(to));
}

module.exports={verifyMetaSignature,extractWebhook,buildOutboundPayload,normalizePhone,validIdempotencyKey,canaryAllows,safeEqualText};
