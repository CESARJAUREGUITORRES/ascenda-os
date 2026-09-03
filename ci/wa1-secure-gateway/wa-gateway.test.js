'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('crypto');
const wa=require('../../app/wa-gateway');

function sig(secret,raw){return 'sha256='+crypto.createHmac('sha256',secret).update(raw).digest('hex');}

test('accepts authentic Meta signature',()=>{
  const raw=Buffer.from('{"object":"whatsapp_business_account","entry":[]}');
  assert.equal(wa.verifyMetaSignature(raw,sig('secret-x',raw),'secret-x'),true);
});

test('rejects missing, malformed and forged signatures',()=>{
  const raw=Buffer.from('{"ok":true}');
  assert.equal(wa.verifyMetaSignature(raw,'','secret-x'),false);
  assert.equal(wa.verifyMetaSignature(raw,'sha256=abc','secret-x'),false);
  assert.equal(wa.verifyMetaSignature(raw,sig('attacker',raw),'secret-x'),false);
});

test('signature is bound to exact raw bytes',()=>{
  const raw=Buffer.from('{"a":1}');const changed=Buffer.from('{"a": 1}');
  assert.equal(wa.verifyMetaSignature(changed,sig('secret-x',raw),'secret-x'),false);
});

test('normalizes inbound click-to-whatsapp message without raw payload retention',()=>{
  const p={object:'whatsapp_business_account',entry:[{changes:[{field:'messages',value:{metadata:{display_phone_number:'+51 999 111 222',phone_number_id:'pn1'},contacts:[{wa_id:'51999111222',profile:{name:'Paciente Demo'}}],messages:[{id:'wamid.1',from:'51999111222',timestamp:'1786807000',type:'text',text:{body:'Hola'},referral:{source_id:'ad-77',source_type:'ad',headline:'HIFU'}}]}}]}]};
  const e=wa.extractWebhook(p);
  assert.equal(e.messages.length,1);assert.equal(e.messages[0].from_number,'51999111222');assert.equal(e.messages[0].ad_id,'ad-77');assert.equal(e.messages[0].message_body,'Hola');
  assert.deepEqual(Object.keys(e.messages[0].raw_referral).sort(),['body','headline','source_id','source_type']);
  assert.equal(e.events[0].event_key,'message:wamid.1');
});

test('normalizes status pricing type/category/model/billable without adding it to hot message row',()=>{
  const p={object:'whatsapp_business_account',entry:[{changes:[{field:'messages',value:{statuses:[{id:'wamid.out',status:'delivered',timestamp:'1786807100',recipient_id:'51999999999',pricing:{category:'service',pricing_model:'PMP',type:'free_customer_service',billable:false}}]}}]}]};
  const e=wa.extractWebhook(p);
  assert.equal(e.statuses.length,1);assert.equal(e.statuses[0].status,'delivered');assert.equal(e.statuses[0].pricing_category,'service');assert.equal(e.statuses[0].pricing_model,'PMP');assert.equal(e.statuses[0].pricing_type,'free_customer_service');assert.equal(e.statuses[0].billable,false);
  const statusEvent=e.events.find(x=>x.event_type==='message.status');
  assert.ok(statusEvent);assert.equal(statusEvent.payload.pricing_type,'free_customer_service');assert.equal(statusEvent.payload.billable,false);
});

test('builds governed text/template/media outbound payloads',()=>{
  const text=wa.buildOutboundPayload({to:'+51 999 999 999',type:'text',text:'Hola'});assert.equal(text.to,'51999999999');assert.equal(text.text.body,'Hola');
  const tpl=wa.buildOutboundPayload({to:'51999999999',type:'template',template_name:'recordatorio',language:'es_PE'});assert.equal(tpl.template.name,'recordatorio');
  const img=wa.buildOutboundPayload({to:'51999999999',type:'image',link:'https://example.test/a.jpg',caption:'Demo'});assert.equal(img.image.link,'https://example.test/a.jpg');
});

test('rejects unsupported payloads and non-https media',()=>{
  assert.throws(()=>wa.buildOutboundPayload({to:'51999999999',type:'video',link:'https://example.test/v.mp4'}),/UNSUPPORTED_MESSAGE_TYPE/);
  assert.throws(()=>wa.buildOutboundPayload({to:'51999999999',type:'image',link:'http://example.test/a.jpg'}),/HTTPS_MEDIA_LINK_REQUIRED/);
});

test('requires high entropy shaped idempotency key',()=>{
  assert.equal(wa.validIdempotencyKey('short'),false);assert.equal(wa.validIdempotencyKey('wa:conv:1234567890:01'),true);
});

test('canary blocks recipients outside explicit allowlist',()=>{
  assert.equal(wa.canaryAllows('51911111111','true','51911111111,51922222222'),true);
  assert.equal(wa.canaryAllows('51933333333','true','51911111111,51922222222'),false);
  assert.equal(wa.canaryAllows('51933333333','false',''),true);
});
