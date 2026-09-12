'use strict';

const test=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('crypto');
const {createMetaCloudAdapter,normalizeProviderError,providerCategory}=require('./meta-cloud-adapter');

function sig(secret,raw){return 'sha256='+crypto.createHmac('sha256',secret).update(raw).digest('hex');}

function requesterFixture(map,calls){
  return async function(method,path,body){
    calls.push({method,path,body});
    const key=method+' '+path.split('?')[0];
    const hit=map[key]||map[path]||map[key.replace(/^GET /,'')];
    if(hit instanceof Error)throw hit;
    if(typeof hit==='function')return hit(method,path,body);
    if(hit)return JSON.parse(JSON.stringify(hit));
    throw Object.assign(new Error('UNEXPECTED_REQUEST '+method+' '+path),{status:500});
  };
}

test('verifies webhook signature and normalizes one inbound through WA gateway contract',()=>{
  const calls=[];
  const a=createMetaCloudAdapter({appSecret:'secret-x',accessToken:'tok',phoneNumberId:'pn1',graphVersion:'v99.0',requester:requesterFixture({},calls)});
  const payload={object:'whatsapp_business_account',entry:[{changes:[{field:'messages',value:{metadata:{phone_number_id:'pn1'},messages:[{id:'wamid.12345678',from:'51999999999',timestamp:'1786807000',type:'text',text:{body:'Hola'}}]}}]}]};
  const raw=Buffer.from(JSON.stringify(payload));
  assert.equal(a.verifyWebhook(raw,sig('secret-x',raw)),true);
  const env=a.normalizeWebhook(payload);
  assert.equal(env.messages.length,1);
  assert.equal(env.messages[0].provider_message_id,'wamid.12345678');
  assert.equal(calls.length,0);
});

test('health checks token permissions and phone asset without exposing token',async()=>{
  const calls=[];
  const a=createMetaCloudAdapter({
    accessToken:'secret-token-never-return',
    phoneNumberId:'pn1',
    graphVersion:'v99.0',
    appSecret:'app-secret',
    requester:requesterFixture({
      'GET me':{status:200,data:{id:'u1'},latencyMs:4},
      'GET me/permissions':{status:200,data:{data:[
        {permission:'whatsapp_business_management',status:'granted'},
        {permission:'whatsapp_business_messaging',status:'granted'}
      ]},latencyMs:5},
      'GET pn1':{status:200,data:{id:'pn1',verified_name:'Zi Vital',display_phone_number:'+51 demo',quality_rating:'GREEN',whatsapp_business_account:{id:'waba1'}},latencyMs:5}
    },calls)
  });
  const h=await a.health();
  assert.equal(h.ok,true);
  assert.equal(h.credentialState,'READY');
  assert.equal(h.permissionsState,'READY');
  assert.equal(h.assetState,'READY');
  assert.equal(h.businessAccountAvailable,true);
  assert.doesNotMatch(JSON.stringify(h),/secret-token-never-return/);
});


test('health fails closed when WABA asset access cannot be resolved',async()=>{
  const calls=[];
  const denied=Object.assign(new Error('META_100'),{status:400,errorCode:'META_100',providerHttpStatus:400,diagnosis:'PERMISSION_OR_ASSET_ACCESS'});
  const a=createMetaCloudAdapter({
    accessToken:'tok',phoneNumberId:'pn1',graphVersion:'v99.0',
    requester:async(method,path,body)=>{
      calls.push({method,path,body});
      if(path==='me?fields=id')return {status:200,data:{id:'u1'}};
      if(path==='me/permissions')return {status:200,data:{data:[{permission:'whatsapp_business_management',status:'granted'},{permission:'whatsapp_business_messaging',status:'granted'}]}};
      if(path.startsWith('pn1?fields=id%2Cdisplay_phone_number'))return {status:200,data:{id:'pn1',verified_name:'Zi Vital'}};
      if(path.startsWith('pn1?fields=whatsapp_business_account'))throw denied;
      throw new Error('unexpected '+path);
    }
  });
  const h=await a.health();
  assert.equal(h.ok,false);
  assert.equal(h.credentialState,'READY');
  assert.equal(h.assetState,'READY');
  assert.equal(h.permissionsState,'READY');
  assert.equal(h.businessAccountAvailable,false);
  assert.equal(h.diagnosis,'WABA_ASSET_ACCESS_MISSING');
});

test('sendPayload returns normalized dispatch receipt',async()=>{
  const calls=[];
  const a=createMetaCloudAdapter({
    accessToken:'tok',phoneNumberId:'pn1',graphVersion:'v99.0',
    requester:requesterFixture({
      'POST pn1/messages':{status:200,data:{messages:[{id:'wamid.out.12345678'}]},latencyMs:19}
    },calls)
  });
  const r=await a.sendText({to:'51999999999',text:'Hola'});
  assert.equal(r.accepted,true);
  assert.equal(r.providerMessageId,'wamid.out.12345678');
  assert.equal(r.latencyMs,19);
  assert.equal(calls[0].body.type,'text');
});

test('media supports image audio video and document',async()=>{
  const calls=[];
  const a=createMetaCloudAdapter({
    accessToken:'tok',phoneNumberId:'pn1',graphVersion:'v99.0',
    requester:async(method,path,body)=>{calls.push({method,path,body});return {status:200,data:{messages:[{id:'wamid.media.12345678'}]},latencyMs:1};}
  });
  for(const type of ['image','audio','video','document']){
    const r=await a.sendMedia({to:'51999999999',type,link:'https://example.test/a.bin',caption:type==='audio'?undefined:'demo'});
    assert.equal(r.accepted,true);
  }
  assert.deepEqual(calls.map(x=>x.body.type),['image','audio','video','document']);
});

test('template listing resolves WABA from phone asset and normalizes read model',async()=>{
  const calls=[];
  const a=createMetaCloudAdapter({
    accessToken:'tok',phoneNumberId:'pn1',graphVersion:'v99.0',
    requester:requesterFixture({
      'GET pn1':{status:200,data:{id:'pn1',whatsapp_business_account:{id:'waba1'}}},
      'GET waba1/message_templates':{status:200,data:{data:[{id:'t1',name:'recordatorio',status:'APPROVED',category:'UTILITY',language:'es_PE',components:[]}]}}
    },calls)
  });
  const r=await a.listTemplates();
  assert.equal(r.ok,true);
  assert.equal(r.count,1);
  assert.equal(r.templates[0].status,'APPROVED');
});

test('typing uses status/read provider payload and no message id requirement',async()=>{
  const calls=[];
  const a=createMetaCloudAdapter({
    accessToken:'tok',phoneNumberId:'pn1',graphVersion:'v99.0',
    requester:async(method,path,body)=>{calls.push({method,path,body});return {status:200,data:{success:true},latencyMs:3};}
  });
  const r=await a.typing('wamid.abcdefgh12345678');
  assert.equal(r.accepted,true);
  assert.equal(r.providerMessageId,null);
  assert.equal(calls[0].body.status,'read');
  assert.equal(calls[0].body.typing_indicator.type,'text');
});

test('normalizes provider error categories and definite/transient semantics',()=>{
  let e=normalizeProviderError(401,{error:{code:190,error_subcode:463}},'X');
  assert.equal(e.category,'AUTH');
  assert.equal(e.errorCode,'META_190_463');
  assert.equal(e.definite,true);
  e=normalizeProviderError(500,{error:{code:2}},'X');
  assert.equal(e.category,'TRANSIENT');
  assert.equal(e.definite,false);
  assert.equal(providerCategory('132001',400),'TEMPLATE');
  assert.equal(providerCategory('130429',429),'RATE');
  assert.equal(providerCategory('131005',403),'PERMISSION');
});

test('rejects invalid direct payload types at provider boundary',async()=>{
  const a=createMetaCloudAdapter({accessToken:'tok',phoneNumberId:'pn1',graphVersion:'v99.0',requester:async()=>{throw new Error('should not call');}});
  await assert.rejects(()=>a.sendPayload({messaging_product:'whatsapp',type:'location'}),/META_MESSAGE_TYPE_NOT_ALLOWED/);
});
