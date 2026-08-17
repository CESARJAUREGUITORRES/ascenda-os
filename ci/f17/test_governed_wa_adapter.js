'use strict'
const assert=require('assert');
const {createF17WhatsAppAdapter}=require('../../app/f17-whatsapp-adapter');

async function main(){
 const calls=[];
 const rpc=async(name,payload)=>{calls.push({name,payload});
  if(name==='aos_cia_channel_prepare_send_v1'){
   const key=payload.p_payload.idempotency_key;
   if(key.endsWith(':policy-deny'))return {ok:true,state:'BLOCKED',dispatch_allowed:false,request_id:'00000000-0000-4000-8000-000000000001'};
   return {ok:true,state:'READY',dispatch_allowed:true,request_id:'00000000-0000-4000-8000-000000000002'};
  }
  if(name==='aos_cia_channel_canary_control_v1')return {ok:true,owned:payload.p_enable===true};
  if(name==='aos_cia_channel_set_release_gate_v1')return {ok:true};
  if(name==='aos_cia_channel_mark_dispatch_v1')return {ok:true,state:payload.p_payload.state};
  if(name==='aos_cia_channel_record_provider_event_v1')return {ok:true,matched:true,inserted:true,context:{canary:true}};
  if(name==='aos_cia_channel_record_inbound_v1')return {ok:true,inserted:true};
  throw new Error('unexpected rpc '+name);
 };
 const a=createF17WhatsAppAdapter({serviceRpc:rpc});
 const p=await a.prepare({to:'51999999999',actor:'00000000-0000-4000-8000-000000000003',idempotencyKey:'f17-canary-1234567890',messageClass:'text',canary:true});
 assert.equal(p.state,'READY');
 assert.equal(calls.filter(x=>x.name==='aos_cia_channel_prepare_send_v1').length,2);
 assert.equal(calls.filter(x=>x.name==='aos_cia_channel_canary_control_v1'&&x.payload.p_enable===true).length,1);
 assert.equal(calls.filter(x=>x.name==='aos_cia_channel_canary_control_v1'&&x.payload.p_enable===false).length,1);
 assert.equal(calls.filter(x=>x.name==='aos_cia_channel_set_release_gate_v1').length,1);
 await a.markAccepted(p.request_id,'wamid.test');
 const ev=await a.recordEvent({provider_message_id:'wamid.test',event_key:'status:wamid.test:sent:1',event_type:'message.status',status:'sent',payload:{recipient_id:'redacted'}});
 assert.equal(ev.matched,true);
 await a.recordInbound({provider_message_id:'wamid.inbound',from_number:'51999999999',message_type:'text',provider_timestamp:new Date().toISOString(),raw_referral:null});
 console.log('F17 governed WA adapter unit contract PASS');
}
main().catch(e=>{console.error(e);process.exit(1);});
