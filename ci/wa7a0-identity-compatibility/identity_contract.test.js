'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const wa=require('../../app/wa-gateway');

test('phone inbound remains backward compatible',()=>{
  const p={object:'whatsapp_business_account',entry:[{changes:[{field:'messages',value:{metadata:{display_phone_number:'+51 999 111 222',phone_number_id:'pn1'},contacts:[{wa_id:'51999111222',profile:{name:'Paciente Demo'}}],messages:[{id:'wamid.phone',from:'51999111222',timestamp:'1786807000',type:'text',text:{body:'Hola'}}]}}]}]};
  const e=wa.extractWebhook(p);const m=e.messages[0];
  assert.equal(m.from_number,'51999111222');assert.equal(m.from_user_id,null);assert.equal(m.contact_name,'Paciente Demo');
});

test('BSUID-only inbound preserves user identity without fabricating phone',()=>{
  const p={object:'whatsapp_business_account',entry:[{changes:[{field:'messages',value:{metadata:{display_phone_number:'+51 999 111 222',phone_number_id:'pn1'},contacts:[{user_id:'PE.user.abc123',parent_user_id:'PE.parent.001',profile:{name:'Privado',username:'@privado.pe'}}],messages:[{id:'wamid.bsuid',from_user_id:'PE.user.abc123',from_parent_user_id:'PE.parent.001',timestamp:'1786807000',type:'text',text:{body:'Hola privado'}}]}}]}]};
  const e=wa.extractWebhook(p);const m=e.messages[0];
  assert.equal(m.from_number,null);assert.equal(m.from_user_id,'PE.user.abc123');assert.equal(m.from_parent_user_id,'PE.parent.001');assert.equal(m.contact_username,'privado.pe');
  assert.equal(e.events[0].payload.sender_kind,'BSUID');
});

test('phone plus BSUID preserves both independent facts',()=>{
  const p={object:'whatsapp_business_account',entry:[{changes:[{field:'messages',value:{metadata:{display_phone_number:'15551627684',phone_number_id:'pn1'},contacts:[{wa_id:'51999111222',user_id:'PE.user.same',profile:{name:'Dual'}}],messages:[{id:'wamid.dual',from:'51999111222',from_user_id:'PE.user.same',timestamp:'1786807000',type:'text',text:{body:'Dual'}}]}}]}]};
  const m=wa.extractWebhook(p).messages[0];
  assert.equal(m.from_number,'51999111222');assert.equal(m.from_user_id,'PE.user.same');
});

test('status preserves recipient_user_id when phone is absent',()=>{
  const p={object:'whatsapp_business_account',entry:[{changes:[{field:'messages',value:{statuses:[{id:'wamid.out',status:'delivered',timestamp:'1786807100',recipient_user_id:'PE.user.abc123',recipient_parent_user_id:'PE.parent.001'}]}}]}]};
  const e=wa.extractWebhook(p);assert.equal(e.statuses[0].recipient_id,null);assert.equal(e.statuses[0].recipient_user_id,'PE.user.abc123');assert.equal(e.events[0].payload.recipient_kind,'BSUID');
});

test('BSUID outbound serializes provider recipient and never provider to',()=>{
  const payload=wa.buildOutboundPayload({recipient_kind:'BSUID',recipient_address:'PE.user.abc123',type:'text',text:'Hola'});
  assert.equal(payload.recipient,'PE.user.abc123');assert.equal(payload.to,'PE.user.abc123');assert.equal(wa.recipientKind(payload),'BSUID');
  const sent=JSON.parse(JSON.stringify(payload));assert.equal(sent.recipient,'PE.user.abc123');assert.equal(Object.prototype.hasOwnProperty.call(sent,'to'),false);
});

test('legacy server to value can represent BSUID without provider to leak',()=>{
  const payload=wa.buildOutboundPayload({to:'PE.user.legacy',type:'text',text:'Hola'});
  assert.equal(wa.recipientKind(payload),'BSUID');assert.equal(payload.to,'PE.user.legacy');assert.equal(JSON.stringify(payload).includes('"to"'),false);
});

test('phone outbound remains unchanged',()=>{
  const payload=wa.buildOutboundPayload({to:'+51 999 999 999',type:'text',text:'Hola'});
  assert.equal(payload.to,'51999999999');assert.equal(payload.recipient,undefined);assert.equal(wa.recipientKind(payload),'PHONE');
});

test('username is never accepted as explicit routing kind',()=>{
  assert.throws(()=>wa.buildOutboundPayload({recipient_kind:'USERNAME',recipient_address:'@someone',type:'text',text:'Hola'}),/INVALID_RECIPIENT/);
});

test('canary allowlist supports phone and BSUID independently',()=>{
  assert.equal(wa.canaryAllows('+51 911 111 111','true','51911111111,PE.user.safe'),true);
  assert.equal(wa.canaryAllows('PE.user.safe','true','51911111111,PE.user.safe'),true);
  assert.equal(wa.canaryAllows('PE.user.other','true','51911111111,PE.user.safe'),false);
});
