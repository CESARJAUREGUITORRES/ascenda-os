'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {createAutonomousBridge,extractInboundProviderIds,deterministicIdempotency}=require('./wa-l10-autonomous-bridge');

function webhook(ids){
  return Buffer.from(JSON.stringify({object:'whatsapp_business_account',entry:[{changes:[{field:'messages',value:{messages:ids.map(id=>({id,type:'text'})),statuses:[{id:'status-only'}]}}]}]}));
}
function claim(id){return {ok:true,claimed:true,provider_message_id:id,attempt_id:'11111111-1111-4111-8111-111111111111',conversation_id:'22222222-2222-4222-8222-222222222222',recipient_kind:'PHONE',recipient_address:'51911111111',run_key:'WA-L10-TEST-RUN-0001',campaign_key:null};}
function safeSuggestion(){return {status:200,body:{ok:true,needs_human:false,contexts:{identity:{identity_state:'NOT_REQUIRED'}},suggestion:{reply:'Hola, ¿en qué te ayudo?',next_action:'REPLY',needs_human:false}}};}


test('extracts only inbound provider message ids and de-duplicates them',()=>{
  const ids=extractInboundProviderIds(webhook(['wamid.1','wamid.1','wamid.2']));
  assert.deepEqual(ids,['wamid.1','wamid.2']);
  assert.deepEqual(extractInboundProviderIds(Buffer.from('{bad')),[]);
});

test('deterministic idempotency is stable and L4-valid shaped',()=>{
  const a=deterministicIdempotency('wamid.same'),b=deterministicIdempotency('wamid.same');
  assert.equal(a,b);assert.match(a,/^l10:auto:[a-f0-9]{64}$/);assert.ok(a.length>=16&&a.length<=120);
});

test('non-canary enqueue does not invoke AI or outbound',async()=>{
  let suggests=0,sends=0;
  const bridge=createAutonomousBridge({
    serviceRpc:async(name)=>name==='aos_wa_l10_bridge_enqueue_v1'?{data:{ok:true,queued:false,reason:'WA_L10_CANARY_NOT_EFFECTIVE'}}:{data:{ok:true}},
    suggestInternal:async()=>{suggests++;return safeSuggestion();},
    autoSend:async()=>{sends++;return {status:200,body:{ok:true}};},
    requestHandoff:async()=>{}
  });
  const q=await bridge.enqueueWebhook(webhook(['wamid.off']));
  assert.deepEqual(q.queued,[]);assert.equal(suggests,0);assert.equal(sends,0);
});

test('eligible inbound produces one governed suggestion and one auto-send',async()=>{
  let sends=0,handoffs=0;const events=[];
  const bridge=createAutonomousBridge({
    serviceRpc:async(name,p)=>{
      if(name==='aos_wa_l10_bridge_claim_v1')return {data:claim(p.p_provider_message_id)};
      if(name==='aos_wa_l10_bridge_event_v1'){events.push(p);return {data:{ok:true}};}
      return {data:{ok:true}};
    },
    suggestInternal:async()=>safeSuggestion(),
    autoSend:async(body)=>{sends++;assert.equal(body.conversation_id,'22222222-2222-4222-8222-222222222222');assert.equal(body.recipient_kind,'PHONE');assert.match(body.idempotency_key,/^l10:auto:/);return {status:200,body:{ok:true,decision_id:'33333333-3333-4333-8333-333333333333',message_id:'wamid.out.1'}};},
    requestHandoff:async()=>{handoffs++;}
  });
  const r=await bridge.processProviderMessage('wamid.in.1');
  assert.equal(r.outcome,'SENT');assert.equal(sends,1);assert.equal(handoffs,0);
  assert.deepEqual(events.map(x=>x.p_event_type),['SUGGESTED','SENT']);
});

test('human-required suggestion hands off and never sends',async()=>{
  let sends=0,handoffs=0;const events=[];
  const bridge=createAutonomousBridge({
    serviceRpc:async(name,p)=>{
      if(name==='aos_wa_l10_bridge_claim_v1')return {data:claim(p.p_provider_message_id)};
      if(name==='aos_wa_l10_bridge_event_v1'){events.push(p.p_event_type);return {data:{ok:true}};}
      return {data:{ok:true}};
    },
    suggestInternal:async()=>({status:200,body:{ok:true,needs_human:true,next_action:'HUMAN_CLINICAL',suggestion:null}}),
    autoSend:async()=>{sends++;return {status:200,body:{ok:true}};},
    requestHandoff:async()=>{handoffs++;}
  });
  const r=await bridge.processProviderMessage('wamid.clinical');
  assert.equal(r.outcome,'HANDOFF');assert.equal(sends,0);assert.equal(handoffs,1);assert.deepEqual(events,['HANDOFF']);
});

test('L4 BLOCK is terminal for this event and is not retried or handed off',async()=>{
  let sends=0,handoffs=0;const events=[];
  const bridge=createAutonomousBridge({
    serviceRpc:async(name,p)=>{
      if(name==='aos_wa_l10_bridge_claim_v1')return {data:claim(p.p_provider_message_id)};
      if(name==='aos_wa_l10_bridge_event_v1'){events.push(p.p_event_type);return {data:{ok:true}};}
      return {data:{ok:true}};
    },
    suggestInternal:async()=>safeSuggestion(),
    autoSend:async()=>{sends++;return {status:403,body:{ok:false,decision:'BLOCK',reason:'WA_L4_COOLDOWN'}};},
    requestHandoff:async()=>{handoffs++;}
  });
  const r=await bridge.processProviderMessage('wamid.cooldown');
  assert.equal(r.outcome,'BLOCKED');assert.equal(sends,1);assert.equal(handoffs,0);assert.deepEqual(events,['SUGGESTED','BLOCKED']);
});

test('provider/runtime error fails closed into human handoff with no retry loop',async()=>{
  let sends=0,handoffs=0;const events=[];
  const bridge=createAutonomousBridge({
    serviceRpc:async(name,p)=>{
      if(name==='aos_wa_l10_bridge_claim_v1')return {data:claim(p.p_provider_message_id)};
      if(name==='aos_wa_l10_bridge_event_v1'){events.push(p.p_event_type);return {data:{ok:true}};}
      return {data:{ok:true}};
    },
    suggestInternal:async()=>safeSuggestion(),
    autoSend:async()=>{sends++;throw new Error('META_SEND_TIMEOUT');},
    requestHandoff:async()=>{handoffs++;}
  });
  const r=await bridge.processProviderMessage('wamid.error');
  assert.equal(r.outcome,'ERROR');assert.equal(sends,1);assert.equal(handoffs,1);assert.deepEqual(events,['SUGGESTED','ERROR']);
});

test('eligible inbound requests real typing before governed suggestion and canonical send',async()=>{
  const order=[];
  const bridge=createAutonomousBridge({
    serviceRpc:async(name,p)=>{if(name==='aos_wa_l10_bridge_claim_v1')return {data:claim(p.p_provider_message_id)};return {data:{ok:true}};},
    sendTyping:(id)=>{order.push('typing:'+id);return Promise.resolve({ok:true});},
    suggestInternal:async()=>{order.push('suggest');return safeSuggestion();},
    autoSend:async()=>{order.push('send');return {status:200,body:{ok:true,decision_id:'33333333-3333-4333-8333-333333333333',message_id:'wamid.out.typing'}};},
    requestHandoff:async()=>{}
  });
  const r=await bridge.processProviderMessage('wamid.typing');
  assert.equal(r.outcome,'SENT');assert.deepEqual(order,['typing:wamid.typing','suggest','send']);
});

test('typing indicator failure is best-effort and never blocks governed reply',async()=>{
  let sends=0,handoffs=0;
  const bridge=createAutonomousBridge({
    serviceRpc:async(name,p)=>{if(name==='aos_wa_l10_bridge_claim_v1')return {data:claim(p.p_provider_message_id)};return {data:{ok:true}};},
    sendTyping:()=>{throw new Error('META_TYPING_UNAVAILABLE');},
    suggestInternal:async()=>safeSuggestion(),
    autoSend:async()=>{sends++;return {status:200,body:{ok:true,decision_id:'33333333-3333-4333-8333-333333333333',message_id:'wamid.out.typing2'}};},
    requestHandoff:async()=>{handoffs++;},
    log:{error:()=>{}}
  });
  const r=await bridge.processProviderMessage('wamid.typing.fail');
  assert.equal(r.outcome,'SENT');assert.equal(sends,1);assert.equal(handoffs,0);
});
