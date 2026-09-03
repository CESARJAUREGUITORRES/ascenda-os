'use strict';
const wa=require('../app/wa-gateway');
const l4=require('../app/wa-l4-authority');

function requiredEnv(name,env=process.env){
  const v=String(env[name]||'').trim();
  if(!v)throw new Error(name+'_REQUIRED');
  return v;
}
function parseInput(raw){
  let v;
  try{v=JSON.parse(String(raw||''));}catch(_){throw new Error('WA_L9_INPUT_JSON_INVALID');}
  if(!v||typeof v!=='object'||Array.isArray(v))throw new Error('WA_L9_INPUT_OBJECT_REQUIRED');
  return v;
}
function sanitizeAuthority(v){
  v=v&&typeof v==='object'?v:{};
  return {
    shadow:v.shadow===true,
    decision:String(v.decision||'BLOCK'),
    reason:String(v.reason||'WA_L9_UNKNOWN').slice(0,160),
    would_send:v.would_send===true,
    provider_dispatch:false,
    side_effects_rolled_back:v.side_effects_rolled_back===true,
    authority_mode:v.mode||v.production_mode||null,
    l8_preflight:v.l8_preflight||null,
    production_mode:v.production_mode||null,
    production_kill_switch_engaged:v.production_kill_switch_engaged===true,
    production_auto_reply_enabled:v.production_auto_reply_enabled===true,
    production_ai_send_enabled:v.production_ai_send_enabled===true,
    production_auto_routing_enabled:v.production_auto_routing_enabled===true,
    production_human_send_enabled:v.production_human_send_enabled===true
  };
}
function sanitizeCost(v){
  v=v&&typeof v==='object'?v:{};
  const total=v.total&&typeof v.total==='object'?v.total:{};
  const meta=v.meta&&typeof v.meta==='object'?v.meta:{};
  const ai=v.ai&&typeof v.ai==='object'?v.ai:{};
  return {
    ok:v.ok===true,
    total:{state:total.state||null,amount:total.amount==null?null:Number(total.amount),currency:total.currency||null,reason:total.reason||null},
    meta:{state:meta.state||null,amount:meta.amount==null?null:Number(meta.amount),currency:meta.currency||null,reason:meta.reason||null,outbound_messages:Number(meta.outbound_messages||0),billable_messages:Number(meta.billable_messages||0)},
    ai:{state:ai.state||null,amount:ai.amount==null?null:Number(ai.amount),currency:ai.currency||null,reason:ai.reason||null,runs:Number(ai.runs||0)}
  };
}
function sanitizeJourney(v){
  v=v&&typeof v==='object'?v:{};
  const j=v.journey&&typeof v.journey==='object'?v.journey:{};
  const k=v.kpis&&typeof v.kpis==='object'?v.kpis:{};
  return {
    ok:v.ok===true,
    journey:{bookings:Number(j.bookings||0),rebooks:Number(j.rebooks||0),attendances:Number(j.attendances||0),sales:Number(j.sales||0),revenue_state:j.revenue_state||null,revenue_amount:j.revenue_amount==null?null:Number(j.revenue_amount),revenue_currency:j.revenue_currency||null,attribution_chain_statuses:Array.isArray(j.attribution_chain_statuses)?j.attribution_chain_statuses.slice(0,8):[]},
    kpis:{cost_state:k.cost_state||null,cost_currency:k.cost_currency||null,cost_per_conversation:k.cost_per_conversation==null?null:Number(k.cost_per_conversation),cost_per_booking:k.cost_per_booking==null?null:Number(k.cost_per_booking),cost_per_attendance:k.cost_per_attendance==null?null:Number(k.cost_per_attendance),cost_per_sale:k.cost_per_sale==null?null:Number(k.cost_per_sale),revenue_cost_ratio:k.revenue_cost_ratio==null?null:Number(k.revenue_cost_ratio),revenue_cost_ratio_reason:k.revenue_cost_ratio_reason||null}
  };
}
function buildRedactedEnvelope(input,payload,authorityRequest){
  const rk=wa.recipientKind(payload),ra=wa.recipientAddress(payload);
  return {
    conversation_id:authorityRequest.p_conversation_id,
    recipient_kind:rk,
    recipient_hash:l4.sha256Text(rk+':'+ra),
    payload_hash:l4.payloadHash(payload),
    message_type:payload.type,
    template_name:authorityRequest.p_template_name||null,
    campaign_key_hash:authorityRequest.p_campaign_key?l4.sha256Text(authorityRequest.p_campaign_key):null,
    requires_identity:authorityRequest.p_requires_identity===true,
    identity_state:authorityRequest.p_identity_state,
    safety_action:authorityRequest.p_safety_action,
    raw_content_stored:false,
    provider_dispatch:false
  };
}
function makeRpcClient(env=process.env){
  const base=requiredEnv('SUPABASE_URL',env).replace(/\/$/,'');
  const key=requiredEnv('SUPABASE_SERVICE_ROLE_KEY',env);
  return async function rpc(name,payload){
    const r=await fetch(base+'/rest/v1/rpc/'+encodeURIComponent(name),{
      method:'POST',headers:{apikey:key,Authorization:'Bearer '+key,'Content-Type':'application/json','User-Agent':'AscendaOS-WA-L9-ShadowDemo/1.0'},
      body:JSON.stringify(payload||{})
    });
    const text=await r.text();let data=null;try{data=text?JSON.parse(text):null;}catch(_){}
    if(!r.ok)throw new Error('WA_L9_RPC_'+name+'_HTTP_'+r.status);
    return data;
  };
}
async function runShadowDemo(input,{rpc}={}){
  if(!rpc)throw new Error('WA_L9_RPC_CLIENT_REQUIRED');
  const demoKey=String(input.demo_key||input.idempotency_key||'').trim();
  if(!wa.validIdempotencyKey(demoKey)||!wa.validIdempotencyKey(input.idempotency_key))throw new Error('WA_L9_DEMO_KEY_REQUIRED');
  const payload=wa.buildOutboundPayload(input);
  const authorityRequest=l4.authorityPayload(input,payload);
  const envelope=buildRedactedEnvelope(input,payload,authorityRequest);
  const shadowRaw=await rpc('aos_wa_l9_shadow_authorize_v1',authorityRequest);
  const authority=sanitizeAuthority(shadowRaw);
  const audit=await rpc('aos_wa_l9_demo_record_v1',{
    p_demo_key:demoKey,
    p_conversation_id:authorityRequest.p_conversation_id,
    p_recipient_hash:envelope.recipient_hash,
    p_payload_hash:envelope.payload_hash,
    p_message_type:payload.type,
    p_template_name:authorityRequest.p_template_name,
    p_shadow_result:shadowRaw
  });
  const [costRaw,journeyRaw]=await Promise.all([
    rpc('aos_wa_l7_conversation_cost_v1',{p_conversation_id:authorityRequest.p_conversation_id}),
    rpc('aos_wa_l7_journey_cost_v1',{p_conversation_id:authorityRequest.p_conversation_id})
  ]);
  return {
    ok:true,
    demo_key:demoKey,
    shadow:true,
    provider_dispatch:false,
    reservation_created:false,
    business_ledger_mutation:false,
    envelope,
    authority,
    audit:{ok:audit&&audit.ok===true,replay:audit&&audit.replay===true,decision:audit&&audit.decision||authority.decision,reason:audit&&audit.reason||authority.reason,would_send:audit&&audit.would_send===true,provider_dispatch:false},
    cost:sanitizeCost(costRaw),
    journey:sanitizeJourney(journeyRaw)
  };
}

async function main(){
  try{
    const input=parseInput(requiredEnv('WA_L9_DEMO_INPUT_JSON'));
    const out=await runShadowDemo(input,{rpc:makeRpcClient()});
    const expected=String(process.env.WA_L9_EXPECT_DECISION||'').trim().toUpperCase();
    if(expected&&out.authority.decision!==expected)throw new Error('WA_L9_EXPECTED_'+expected+'_GOT_'+out.authority.decision);
    process.stdout.write(JSON.stringify(out)+'\n');
  }catch(e){
    process.stderr.write(JSON.stringify({ok:false,error:String(e&&e.message||'WA_L9_DEMO_FAILED').slice(0,180)})+'\n');
    process.exitCode=1;
  }
}

if(require.main===module)main();
module.exports={parseInput,sanitizeAuthority,sanitizeCost,sanitizeJourney,buildRedactedEnvelope,makeRpcClient,runShadowDemo};
