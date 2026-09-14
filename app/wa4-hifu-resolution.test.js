'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {isGenericHifuContext,preferHifuFrozenRows}=require('./wa4-copilot');
const runtime=require('./wa4-conversation-runtime-v2');

function row(title,category){
  return {knowledge_id:'service:'+title,domain:'CATALOG',title,facts:{nombre:title,categoria:category}};
}

test('generic HIFU resolves only to Zi Frozen catalog family when available',()=>{
  const rows=[
    row('HIFU 7D BRAZOS','CORPORAL'),
    row('HIFU CORP ABDOMEN ALTO','CORPORAL'),
    row('ZI FROZEN BEAUTY','HIFU'),
    row('ZI FROZEN CISNE','HIFU'),
    row('ZI FROZEN FULL FACE','HIFU'),
    {knowledge_id:'clinic:hifu',domain:'CLINIC_KNOWLEDGE',title:'HIFU general',facts:{}}
  ];
  const ctx={state:{treatment:'HIFU'}};
  assert.equal(isGenericHifuContext('hola quiero mas informacion sobre el Hifu',ctx),true);
  const out=preferHifuFrozenRows(rows,'hola quiero mas informacion sobre el Hifu',ctx);
  assert.deepEqual(out.filter(x=>x.domain==='CATALOG').map(x=>x.title),[
    'ZI FROZEN BEAUTY','ZI FROZEN CISNE','ZI FROZEN FULL FACE'
  ]);
  assert.ok(!out.some(x=>x.title==='HIFU 7D BRAZOS'));
});

test('body-specific HIFU keeps corporal catalog eligible',()=>{
  const rows=[row('HIFU 7D BRAZOS','CORPORAL'),row('ZI FROZEN BEAUTY','HIFU')];
  const ctx={state:{treatment:'HIFU'}};
  assert.equal(isGenericHifuContext('quiero HIFU para brazos',ctx),false);
  assert.deepEqual(preferHifuFrozenRows(rows,'quiero HIFU para brazos',ctx),rows);
});

test('follow-up benefits and availability retain HIFU treatment context',()=>{
  const messages=[
    {direction:'INBOUND',message_body:'hola quiero mas informacion sobre el Hifu',created_at:'2026-09-14T21:57:44Z'},
    {direction:'OUTBOUND',message_body:'Te cuento sobre HIFU.',created_at:'2026-09-14T21:57:57Z'},
    {direction:'INBOUND',message_body:'cuales son los beneficios ?',created_at:'2026-09-14T21:58:18Z'},
    {direction:'INBOUND',message_body:'disponibilidad ?',created_at:'2026-09-14T21:59:37Z'}
  ];
  const out=runtime.buildRuntimeContext({messages,conversation:{campaign_source:null}});
  assert.equal(out.state.treatment,'HIFU');
  assert.ok(out.intents.includes('SCHEDULE'));
  assert.equal(out.booking_readiness,'HIGH');
});
