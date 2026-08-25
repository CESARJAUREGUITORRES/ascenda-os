'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const wa=require('../../app/wa-gateway');

function envelope(value){return {object:'whatsapp_business_account',entry:[{changes:[{field:'messages',value:Object.assign({metadata:{display_phone_number:'+51 999 111 222',phone_number_id:'pn-wa7a2'}},value)}]}]};}
function eventOf(e,type){return e.events.find(x=>x.event_type===type);}

test('current Meta user_changed_user_id arrives as messages/system and preserves old-new BSUID lineage without phone',()=>{
  const p=envelope({messages:[{id:'wamid.system.uid',timestamp:'1787696000',type:'system',system:{type:'user_changed_user_id',previous_user_id:'PE.OLD1',user_id:'PE.NEW1',previous_parent_user_id:'PE.ENT.OLD1',parent_user_id:'PE.ENT.NEW1',body:'changed'}}]});
  const e=wa.extractWebhook(p);const ev=eventOf(e,'identity.system_change');
  assert.equal(e.messages.length,0);assert.ok(ev);assert.equal(ev.payload.system_type,'user_changed_user_id');assert.equal(ev.payload.previous_user_id,'PE.OLD1');assert.equal(ev.payload.user_id,'PE.NEW1');assert.equal(ev.payload.wa_id,null);
});

test('current Meta user_changed_number preserves new phone when shareable',()=>{
  const p=envelope({messages:[{id:'wamid.system.number',timestamp:'1787696001',type:'system',system:{type:'user_changed_number',previous_user_id:'PE.OLD2',user_id:'PE.NEW2',wa_id:'+51 966 666 666'}}]});
  const ev=eventOf(wa.extractWebhook(p),'identity.system_change');assert.equal(ev.payload.wa_id,'51966666666');assert.equal(ev.payload.user_id,'PE.NEW2');
});

test('signed phone plus BSUID emits independent meta-pair verification evidence',()=>{
  const p=envelope({contacts:[{wa_id:'51911111111',user_id:'PE.PAIR1',parent_user_id:'PE.ENT.PAIR1',profile:{name:'Pair',username:'pair.name'}}],messages:[{id:'wamid.pair',from:'51911111111',from_user_id:'PE.PAIR1',from_parent_user_id:'PE.ENT.PAIR1',timestamp:'1787696002',type:'text',text:{body:'hola'}}]});
  const e=wa.extractWebhook(p);const ev=eventOf(e,'identity.meta_pair');assert.equal(e.messages.length,1);assert.ok(ev);assert.equal(ev.payload.phone,'51911111111');assert.equal(ev.payload.user_id,'PE.PAIR1');assert.equal(ev.payload.parent_user_id,'PE.ENT.PAIR1');
});

test('REQUEST_CONTACT_INFO response emits attested disclosure without storing vcard in normalized message',()=>{
  const p=envelope({contacts:[{user_id:'PE.CONTACT1',profile:{name:'Private'}}],messages:[{id:'wamid.contact.request',from_user_id:'PE.CONTACT1',timestamp:'1787696003',type:'contacts',contacts:[{origin:'contact_request',name:{formatted_name:'Private'},phones:[{phone:'+51 922 222 222',wa_id:'51922222222'}]}]}]});
  const e=wa.extractWebhook(p);const ev=eventOf(e,'identity.contact_disclosure');assert.equal(e.messages[0].message_type,'contacts');assert.equal(e.messages[0].message_body,null);assert.equal(ev.payload.origin,'contact_request');assert.equal(ev.payload.shared_phone,'51922222222');assert.equal(ev.payload.shared_phone_count,1);assert.equal(JSON.stringify(ev).includes('vcard'),false);
});

test('ordinary forwarded contact remains non-attested evidence',()=>{
  const p=envelope({contacts:[{user_id:'PE.CONTACT2',profile:{name:'Private'}}],messages:[{id:'wamid.contact.other',from_user_id:'PE.CONTACT2',timestamp:'1787696004',type:'contacts',contacts:[{origin:'other',phones:[{phone:'+51 933 333 333'}],vcard:'BEGIN:VCARD...'}]}]});
  const ev=eventOf(wa.extractWebhook(p),'identity.contact_disclosure');assert.equal(ev.payload.origin,'other');assert.equal(ev.payload.shared_phone,'51933333333');assert.equal(ev.payload.source,'META_CONTACT_OTHER');assert.equal(JSON.stringify(ev).includes('BEGIN:VCARD'),false);
});

test('delivered/read recipient_user_id creates status binding evidence, sent does not',()=>{
  const delivered=envelope({statuses:[{id:'wamid.out.1',status:'delivered',timestamp:'1787696005',recipient_id:'51944444444',recipient_user_id:'PE.STATUS1',recipient_parent_user_id:'PE.ENT.STATUS1'}]});
  const de=wa.extractWebhook(delivered);const ev=eventOf(de,'identity.status_binding');assert.ok(ev);assert.equal(ev.payload.recipient_user_id,'PE.STATUS1');assert.equal(ev.payload.business_scope,'pn-wa7a2');
  const sent=envelope({statuses:[{id:'wamid.out.2',status:'sent',timestamp:'1787696006',recipient_user_id:'PE.STATUS2'}]});
  assert.equal(eventOf(wa.extractWebhook(sent),'identity.status_binding'),undefined);
});

test('request_contact_info uses native interactive payload for PHONE and BSUID recipients',()=>{
  const a=wa.buildOutboundPayload({to:'+51 955 555 555',type:'request_contact_info',text:'Comparte tu número para continuar.'});
  assert.equal(a.type,'interactive');assert.equal(a.interactive.type,'request_contact_info');assert.equal(a.interactive.action.name,'request_contact_info');assert.equal(a.to,'51955555555');
  const b=wa.buildOutboundPayload({recipient_kind:'BSUID',recipient_address:'PE.REQUEST1',type:'request_contact_info',text:'Comparte tu número para continuar.'});
  assert.equal(b.recipient,'PE.REQUEST1');assert.equal(JSON.stringify(b).includes('"to"'),false);assert.equal(b.interactive.type,'request_contact_info');
});

test('username remains display-only and never appears in identity authority event payloads',()=>{
  const p=envelope({contacts:[{wa_id:'51977777777',user_id:'PE.USERNAME1',profile:{name:'Name',username:'@mutable_name'}}],messages:[{id:'wamid.username',from:'51977777777',from_user_id:'PE.USERNAME1',timestamp:'1787696007',type:'text',text:{body:'hola'}}]});
  const e=wa.extractWebhook(p);assert.equal(e.messages[0].contact_username,'mutable_name');const ev=eventOf(e,'identity.meta_pair');assert.ok(ev);assert.equal(Object.prototype.hasOwnProperty.call(ev.payload,'username'),false);
});
