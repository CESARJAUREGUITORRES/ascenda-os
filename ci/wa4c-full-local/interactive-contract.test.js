'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const interactive=require('../../app/wa-interactive');
const wa=require('../../app/wa-gateway');

test('builds WhatsApp reply buttons within governed limits',()=>{
  const p=interactive.build({to:'51911111111',type:'interactive_buttons',text:'¿Qué deseas revisar?',buttons:[{id:'price',title:'Ver precio'},{id:'included',title:'Qué incluye'},{id:'advisor',title:'Hablar asesor'}]});
  assert.equal(p.type,'interactive');assert.equal(p.interactive.type,'button');assert.equal(p.interactive.action.buttons.length,3);assert.equal(interactive.messageType(p),'interactive_buttons');assert.equal(interactive.messageBody(p),'¿Qué deseas revisar?');
});

test('rejects invalid or ambiguous reply button payloads',()=>{
  assert.throws(()=>interactive.build({to:'51911111111',type:'interactive_buttons',text:'x',buttons:[]}),/INTERACTIVE_BUTTON_COUNT/);
  assert.throws(()=>interactive.build({to:'51911111111',type:'interactive_buttons',text:'x',buttons:[{id:'a',title:'Uno'},{id:'a',title:'Dos'}]}),/INTERACTIVE_DUPLICATE_ID/);
  assert.throws(()=>interactive.build({to:'51911111111',type:'interactive_buttons',text:'x',buttons:[{id:'a',title:'123456789012345678901'}]}),/INTERACTIVE_BUTTON_TITLE_TOO_LONG/);
});

test('builds WhatsApp list and enforces ten-row ceiling',()=>{
  const p=interactive.build({to:'51911111111',type:'interactive_list',text:'Elige una opción',button_text:'Ver opciones',sections:[{title:'Opciones',rows:[{id:'price',title:'Ver precio'},{id:'payment',title:'Medios de pago'},{id:'advisor',title:'Hablar asesor'}]}]});
  assert.equal(p.interactive.type,'list');assert.equal(p.interactive.action.sections[0].rows.length,3);assert.equal(interactive.messageType(p),'interactive_list');
  const rows=Array.from({length:11},(_,i)=>({id:'r'+i,title:'Opción '+i}));
  assert.throws(()=>interactive.build({to:'51911111111',type:'interactive_list',text:'x',button_text:'Opciones',sections:[{rows}]}),/INTERACTIVE_LIST_ROW_LIMIT/);
});

test('existing inbound parser normalizes button and list replies',()=>{
  const base=(message)=>({object:'whatsapp_business_account',entry:[{changes:[{field:'messages',value:{metadata:{display_phone_number:'51999999999',phone_number_id:'local-phone-id'},contacts:[{wa_id:'51911111111',profile:{name:'Beta'}}],messages:[message]}}]}]});
  let e=wa.extractWebhook(base({id:'wamid.button',from:'51911111111',timestamp:'1788010000',type:'interactive',interactive:{type:'button_reply',button_reply:{id:'price',title:'Ver precio'}}}));
  assert.equal(e.messages[0].message_body,'Ver precio');
  e=wa.extractWebhook(base({id:'wamid.list',from:'51911111111',timestamp:'1788010001',type:'interactive',interactive:{type:'list_reply',list_reply:{id:'payment',title:'Medios de pago'}}}));
  assert.equal(e.messages[0].message_body,'Medios de pago');
});
