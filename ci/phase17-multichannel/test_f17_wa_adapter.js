'use strict';
const assert=require('assert');
const {createF17WaAdapter}=require('../../app/f17-wa-adapter');

(async()=>{
  const calls=[];
  async function serviceRpc(name,args){
    calls.push({name,args:JSON.parse(JSON.stringify(args||{}))});
    if(name==='aos_cia_channel_register_canary_recipient_v1')return {ok:true,source:'SYSTEM_CANARY'};
    if(name==='aos_cia_channel_prepare_send_v1')return {ok:true,request_id:'11111111-1111-4111-8111-111111111111',state:'READY',dispatch_allowed:true};
    if(name==='aos_cia_channel_mark_dispatch_v1')return {ok:true,state:args.p_payload.outcome};
    if(name==='aos_cia_channel_ingest_inbound_v1')return {ok:true,inserted:true,identity_status:'UNRESOLVED'};
    if(name==='aos_cia_channel_record_provider_event_v1')return {ok:true,linked:false,inserted:false};
    throw new Error('unexpected rpc '+name);
  }

  const adapter=createF17WaAdapter({serviceRpc,canaryMode:'true'});
  const prepared=await adapter.prepareOutbound({
    actor:'33333333-3333-4333-8333-333333333333',idempotencyKey:'runtime-canary-0001',payload:{to:'51999111222',type:'text',text:{body:'secret body must not enter F17 facts'}}
  });
  assert.equal(prepared.dispatch_allowed,true);
  assert.equal(calls[0].name,'aos_cia_channel_register_canary_recipient_v1');
  assert.equal(calls[0].args.p_payload.allowlist_verified,true);
  assert.equal(calls[1].name,'aos_cia_channel_prepare_send_v1');
  assert.equal(calls[1].args.p_payload.context.canary,true);
  assert.equal(calls[1].args.p_payload.authorization_provenance.strong_2fa,true);
  assert.ok(!JSON.stringify(calls[1]).includes('secret body'));

  await adapter.markAccepted(prepared.request_id,'wamid.accepted');
  await adapter.markFailed(prepared.request_id,'fixture-error');
  assert.equal(calls[2].name,'aos_cia_channel_mark_dispatch_v1');
  assert.equal(calls[2].args.p_payload.outcome,'ACCEPTED');
  assert.equal(calls[3].args.p_payload.outcome,'FAILED');

  await adapter.ingestEnvelope({
    messages:[{provider_message_id:'wamid.in',from_number:'51999888777',message_type:'text',message_body:'DO NOT COPY',raw_referral:{body:'DO NOT COPY REF'},campaign_source:'campaign',ad_id:'ad1',lead_id:'lead1',provider_timestamp:'2026-08-16T00:00:00Z'}],
    events:[{event_key:'message:wamid.in',event_type:'message.received',provider_message_id:'wamid.in',status:'received',payload:{message_type:'text'}}]
  });
  const inboundCall=calls.find(c=>c.name==='aos_cia_channel_ingest_inbound_v1');
  assert.ok(inboundCall);
  const inboundJson=JSON.stringify(inboundCall.args);
  assert.ok(!inboundJson.includes('DO NOT COPY'));
  assert.ok(!Object.prototype.hasOwnProperty.call(inboundCall.args.p_payload,'message_body'));
  assert.ok(!Object.prototype.hasOwnProperty.call(inboundCall.args.p_payload,'raw_referral'));
  assert.ok(calls.some(c=>c.name==='aos_cia_channel_record_provider_event_v1'));

  const nonCanaryCalls=[];
  const nonCanary=createF17WaAdapter({canaryMode:'false',serviceRpc:async(name,args)=>{
    nonCanaryCalls.push({name,args});
    if(name==='aos_cia_channel_prepare_send_v1')return {ok:true,state:'BLOCKED',dispatch_allowed:false};
    throw new Error('unexpected noncanary rpc '+name);
  }});
  const blocked=await nonCanary.prepareOutbound({actor:'33333333-3333-4333-8333-333333333333',idempotencyKey:'runtime-normal-0001',payload:{to:'51999111222',type:'text'}});
  assert.equal(blocked.dispatch_allowed,false);
  assert.equal(nonCanaryCalls.length,1);
  assert.equal(nonCanaryCalls[0].name,'aos_cia_channel_prepare_send_v1');
  assert.equal(nonCanaryCalls[0].args.p_payload.context.canary,false);

  console.log('F17_WA_RUNTIME_ADAPTER_PASS');
})().catch(e=>{console.error(e);process.exit(1);});