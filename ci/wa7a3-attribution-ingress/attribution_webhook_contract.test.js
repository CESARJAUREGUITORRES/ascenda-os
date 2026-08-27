'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const wa=require('../../app/wa-gateway');

function payload(messages,contact){
  return {object:'whatsapp_business_account',entry:[{changes:[{field:'messages',value:{metadata:{display_phone_number:'+51 999 111 222',phone_number_id:'pn-wa7a3'},contacts:contact?[contact]:[],messages}}]}]};
}
function touchpoints(e){return e.events.filter(x=>x.event_type==='attribution.touchpoint');}

test('preserves explicit Meta referral provenance as a separate touchpoint event',()=>{
  const p=payload([{id:'wamid.ctwa.1',from:'51911111111',timestamp:'1786807000',type:'text',text:{body:'Hola'},referral:{source_url:'https://www.facebook.com/ads/example?utm_source=meta',source_id:'ad-77',source_type:'ad',headline:'HIFU Lima',body:'Agenda hoy',media_type:'image',ctwa_clid:'ctwa-click-001',lead_id:'provider-lead-8',campaign_source:'META_CTWA'}}]);
  const e=wa.extractWebhook(p);const t=touchpoints(e);
  assert.equal(e.messages.length,1);assert.equal(t.length,1);
  assert.equal(t[0].event_key,'attribution:touchpoint:wamid.ctwa.1');
  assert.equal(t[0].provider_message_id,'wamid.ctwa.1');
  assert.equal(t[0].payload.source_id,'ad-77');assert.equal(t[0].payload.source_type,'ad');assert.equal(t[0].payload.ad_id,'ad-77');
  assert.equal(t[0].payload.ctwa_clid,'ctwa-click-001');assert.equal(t[0].payload.provider_lead_id,'provider-lead-8');
  assert.equal(t[0].payload.campaign_source,'META_CTWA');assert.equal(t[0].payload.channel,'WHATSAPP');
  assert.equal(t[0].payload.provider,'META_CLOUD_API');assert.equal(t[0].payload.evidence_version,'WA_7A_3_V1');
  assert.equal('phone' in t[0].payload,false);assert.equal('bsuid' in t[0].payload,false);assert.equal('username' in t[0].payload,false);
});

test('keeps WA-1 legacy normalized referral shape unchanged',()=>{
  const p=payload([{id:'wamid.ctwa.legacy',from:'51911111111',timestamp:'1786807000',type:'text',text:{body:'Hola'},referral:{source_url:'https://www.facebook.com/ads/example',source_id:'ad-77',source_type:'ad',headline:'HIFU',body:'Promo',ctwa_clid:'ctwa-1'}}]);
  const e=wa.extractWebhook(p);
  assert.equal(e.messages[0].ad_id,'ad-77');assert.equal(e.messages[0].campaign_source,'HIFU');
  assert.deepEqual(Object.keys(e.messages[0].raw_referral).sort(),['body','headline','source_id','source_type']);
});

test('no explicit referral means no fabricated attribution even with phone BSUID and username',()=>{
  const contact={wa_id:'51911111111',user_id:'bsuid-abc',profile:{name:'Demo',username:'demo_user'}};
  const p=payload([{id:'wamid.organic.1',from:'51911111111',from_user_id:'bsuid-abc',timestamp:'1786807001',type:'text',text:{body:'Orgánico'}}],contact);
  const e=wa.extractWebhook(p);
  assert.equal(touchpoints(e).length,0);
  assert.ok(e.events.some(x=>x.event_type==='identity.meta_pair'));
});

test('invalid or non-https source URL is stripped while explicit referral evidence remains',()=>{
  const p=payload([{id:'wamid.ctwa.badurl',from:'51911111111',timestamp:'1786807002',type:'text',text:{body:'Hola'},referral:{source_url:'javascript:alert(1)',source_id:'post-9',source_type:'post',headline:'Post'}}]);
  const t=touchpoints(wa.extractWebhook(p))[0];
  assert.equal(t.payload.source_url,null);assert.equal(t.payload.source_id,'post-9');assert.equal(t.payload.ad_id,null);
});

test('replay produces the same deterministic touchpoint key',()=>{
  const msg={id:'wamid.ctwa.replay',from:'51911111111',timestamp:'1786807003',type:'text',text:{body:'Hola'},referral:{source_id:'ad-88',source_type:'ad'}};
  const a=touchpoints(wa.extractWebhook(payload([msg)));
});
