'use strict';

const assert=require('node:assert/strict');
const {TelegramTransport}=require('../../sentinel/alerts/telegram-transport.cjs');
const {MemoryAlertState}=require('../../sentinel/alerts/memory-alert-state.cjs');
const {AlertRouter}=require('../../sentinel/alerts/alert-router.cjs');
const {AlertDispatcher}=require('../../sentinel/alerts/alert-dispatcher.cjs');

const syntheticToken='123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghi';
const syntheticChat='-1001234567890';
const sha='f90542bfa21b7be5e3a306f0d9241c52368fbe19';
let now='2026-08-16T19:30:00-05:00';
const state=new MemoryAlertState();
const router=new AlertRouter({state,clock:()=>now});
const decision=router.route({
  incident_id:'SEN-2026-9101',severity:'P1',status:'OPEN',environment:'production',domain:'SENTINEL',component:'alert-router',capability:'telegram-adapter',failure_family:'synthetic-canary',updated_at:now,signal_count:1,reopened_count:0,
  correlation:{release:`ascenda-os@${sha}`,commit_sha:sha,deployment_id:'f9-telegram-fixture'}
});

(async()=>{
  const disabled=new TelegramTransport({enabled:false,configProvider:async()=>({bot_token:syntheticToken,chat_id:syntheticChat}),fetchImpl:async()=>{throw new Error('MUST_NOT_CALL');}});
  let dispatcher=new AlertDispatcher({router,transport:disabled});
  let result=await dispatcher.dispatch(decision);
  assert.equal(result.status,'UNAVAILABLE');
  assert.equal(result.delivered,false);

  const calls=[];
  const successFetch=async(url,options)=>{
    calls.push({url,options});
    return {ok:true,status:200,json:async()=>({ok:true,result:{message_id:7788}})};
  };
  const liveShape=new TelegramTransport({enabled:true,configProvider:async()=>({bot_token:syntheticToken,chat_id:syntheticChat}),fetchImpl:successFetch,timeoutMs:1000});
  dispatcher=new AlertDispatcher({router,transport:liveShape});
  result=await dispatcher.dispatch(decision);
  assert.equal(result.status,'DELIVERED');
  assert.equal(result.provider_message_id,'7788');
  assert.equal(calls.length,1);
  assert.match(calls[0].url,/^https:\/\/api\.telegram\.org\/bot[^/]+\/sendMessage$/);
  assert.ok(calls[0].url.includes(syntheticToken));
  assert.equal(calls[0].options.method,'POST');
  assert.equal(calls[0].options.headers['content-type'],'application/json');
  const body=JSON.parse(calls[0].options.body);
  assert.equal(body.chat_id,syntheticChat);
  assert.match(body.text,/SEN-2026-9101/);
  assert.deepEqual(body.link_preview_options,{is_disabled:true});
  assert.equal(Object.prototype.hasOwnProperty.call(body,'parse_mode'),false);

  const missing=new TelegramTransport({enabled:true,configProvider:async()=>({}),fetchImpl:successFetch});
  dispatcher=new AlertDispatcher({router:new AlertRouter({state:new MemoryAlertState(),clock:()=>now}),transport:missing});
  const missingDecision=dispatcher.router.route({...decision,incident_id:'SEN-2026-9102'});
  result=await dispatcher.dispatch(missingDecision);
  assert.equal(result.status,'UNAVAILABLE');
  assert.equal(result.provider_code,'MISCONFIGURED');

  const rateFetch=async()=>({ok:false,status:429,json:async()=>({ok:false,error_code:429,parameters:{retry_after:17}})});
  const rate=new TelegramTransport({enabled:true,configProvider:async()=>({bot_token:syntheticToken,chat_id:syntheticChat}),fetchImpl:rateFetch});
  const rateRouter=new AlertRouter({state:new MemoryAlertState(),clock:()=>now});
  dispatcher=new AlertDispatcher({router:rateRouter,transport:rate});
  const rateDecision=rateRouter.route({...decision,incident_id:'SEN-2026-9103'});
  result=await dispatcher.dispatch(rateDecision);
  assert.equal(result.status,'RETRY_LATER');
  assert.equal(result.retry_after,17);
  assert.equal(result.delivered,false);

  const rejectedFetch=async()=>({ok:false,status:403,json:async()=>({ok:false,error_code:403,description:'synthetic'})});
  const rejected=new TelegramTransport({enabled:true,configProvider:async()=>({bot_token:syntheticToken,chat_id:syntheticChat}),fetchImpl:rejectedFetch});
  const rejectRouter=new AlertRouter({state:new MemoryAlertState(),clock:()=>now});
  dispatcher=new AlertDispatcher({router:rejectRouter,transport:rejected});
  result=await dispatcher.dispatch(rejectRouter.route({...decision,incident_id:'SEN-2026-9104'}));
  assert.equal(result.status,'FAILED');
  assert.equal(result.provider_code,'TELEGRAM_REJECTED');
  assert.equal(JSON.stringify(result).includes(syntheticToken),false);

  console.log(JSON.stringify({
    ok:true,
    certificate:'SENTINEL_F9_TELEGRAM_ADAPTER_CONTRACT_PASS',
    real_network_calls:0,
    live_secrets_used:false,
    server_side_config_provider:true,
    send_message_post_shape:true,
    link_preview_disabled:true,
    ack_required:true,
    rate_limit_retry_after:true,
    unconfigured_is_unavailable:true,
    secrets_not_returned:true
  }));
})().catch(e=>{console.error(e.stack||e);process.exit(1);});
