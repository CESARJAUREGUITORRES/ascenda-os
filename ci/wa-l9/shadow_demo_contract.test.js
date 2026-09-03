'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const demo=require('../../scripts/wa-l9-shadow-demo');

const SCRIPT=fs.readFileSync(path.join(__dirname,'../../scripts/wa-l9-shadow-demo.js'),'utf8');
const PHONE='51970000001';
const BODY='Hola, quiero reservar HIFU mañana por la tarde';
const CID='99999999-9999-4999-8999-999999999901';

test('shadow CLI has no Meta/provider dispatch capability',()=>{
  assert.doesNotMatch(SCRIPT,/graph\.facebook\.com/);
  assert.doesNotMatch(SCRIPT,/WHATSAPP_ACCESS_TOKEN/);
  assert.doesNotMatch(SCRIPT,/graphSend\s*\(/);
  assert.doesNotMatch(SCRIPT,/reserveOutbound\s*\(/);
  assert.match(SCRIPT,/aos_wa_l9_shadow_authorize_v1/);
  assert.match(SCRIPT,/aos_wa_l9_demo_record_v1/);
});

test('redacted envelope never emits raw recipient or message body',()=>{
  const wa=require('../../app/wa-gateway');
  const l4=require('../../app/wa-l4-authority');
  const input={conversation_id:CID,to:PHONE,type:'text',text:BODY,idempotency_key:'l9:unit:shadow:00000001',demo_key:'l9:unit:shadow:00000001',safety_action:'ALLOW',identity_state:'VERIFIED',requires_identity:false,campaign_key:'campaign-secret-name'};
  const payload=wa.buildOutboundPayload(input);
  const authority=l4.authorityPayload(input,payload);
  const envelope=demo.buildRedactedEnvelope(input,payload,authority);
  const raw=JSON.stringify(envelope);
  assert.equal(envelope.provider_dispatch,false);
  assert.equal(envelope.raw_content_stored,false);
  assert.equal(envelope.recipient_hash.length,64);
  assert.equal(envelope.payload_hash.length,64);
  assert(!raw.includes(PHONE));
  assert(!raw.includes(BODY));
  assert(!raw.includes('campaign-secret-name'));
});

test('end-to-end shadow orchestration returns would-send evidence without raw content',async()=>{
  const calls=[];
  const rpc=async(name,payload)=>{
    calls.push({name,payload});
    if(name==='aos_wa_l9_shadow_authorize_v1')return {ok:true,decision:'ALLOW',reason:'WA_L4_ALLOWED',mode:'CANARY',l8_preflight:'PASS',shadow:true,would_send:true,provider_dispatch:false,side_effects_rolled_back:true,production_mode:'CANARY',production_kill_switch_engaged:false,production_auto_reply_enabled:true,production_ai_send_enabled:true,production_auto_routing_enabled:false,production_human_send_enabled:true};
    if(name==='aos_wa_l9_demo_record_v1')return {ok:true,replay:false,decision:'ALLOW',reason:'WA_L4_ALLOWED',would_send:true,provider_dispatch:false};
    if(name==='aos_wa_l7_conversation_cost_v1')return {ok:true,total:{state:'KNOWN',amount:0,currency:null,reason:'COST_RECONCILED'},meta:{state:'KNOWN',amount:0,reason:'META_COST_RECONCILED',outbound_messages:0,billable_messages:0},ai:{state:'KNOWN',amount:0,reason:'NO_AI_RUNS',runs:0}};
    if(name==='aos_wa_l7_journey_cost_v1')return {ok:true,journey:{bookings:1,rebooks:0,attendances:0,sales:0,revenue_state:'KNOWN',revenue_amount:0,revenue_currency:null,attribution_chain_statuses:['ATTRIBUTED']},kpis:{cost_state:'KNOWN',cost_per_conversation:0,revenue_cost_ratio:null,revenue_cost_ratio_reason:'ZERO_COST_DENOMINATOR'}};
    throw new Error('unexpected '+name);
  };
  const input={conversation_id:CID,to:PHONE,type:'text',text:BODY,idempotency_key:'l9:unit:orchestrate:0001',demo_key:'l9:unit:orchestrate:0001',safety_action:'ALLOW',identity_state:'VERIFIED',requires_identity:false,campaign_key:'campaign-secret-name'};
  const out=await demo.runShadowDemo(input,{rpc});
  assert.equal(out.ok,true);
  assert.equal(out.shadow,true);
  assert.equal(out.provider_dispatch,false);
  assert.equal(out.reservation_created,false);
  assert.equal(out.business_ledger_mutation,false);
  assert.equal(out.authority.decision,'ALLOW');
  assert.equal(out.authority.would_send,true);
  assert.equal(out.authority.side_effects_rolled_back,true);
  assert.equal(out.audit.provider_dispatch,false);
  assert.deepEqual(calls.map(x=>x.name),['aos_wa_l9_shadow_authorize_v1','aos_wa_l9_demo_record_v1','aos_wa_l7_conversation_cost_v1','aos_wa_l7_journey_cost_v1']);
  const rendered=JSON.stringify(out);
  assert(!rendered.includes(PHONE));
  assert(!rendered.includes(BODY));
  assert(!rendered.includes('campaign-secret-name'));
});
