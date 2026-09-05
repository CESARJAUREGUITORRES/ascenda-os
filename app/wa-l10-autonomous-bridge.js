'use strict';
const crypto=require('crypto');

function parseJson(v){try{return JSON.parse(String(v||''));}catch(_){return null;}}
function cleanReason(v){return String(v||'WA_L10_UNKNOWN').toUpperCase().replace(/[^A-Z0-9_.:-]/g,'_').slice(0,128);}
function deterministicIdempotency(providerMessageId){
  return 'l10:auto:'+crypto.createHash('sha256').update(String(providerMessageId||'')).digest('hex');
}
function extractInboundProviderIds(raw){
  const payload=parseJson(Buffer.isBuffer(raw)?raw.toString('utf8'):raw);
  const ids=[];const seen=new Set();
  if(!payload||payload.object!=='whatsapp_business_account'||!Array.isArray(payload.entry))return ids;
  for(const entry of payload.entry){
    for(const change of (entry&&Array.isArray(entry.changes)?entry.changes:[])){
      if(change.field!=='messages')continue;
      const value=change.value||{};
      for(const msg of (Array.isArray(value.messages)?value.messages:[])){
        const id=String(msg&&msg.id||'').trim();
        if(id&&!seen.has(id)){seen.add(id);ids.push(id);}
      }
    }
  }
  return ids;
}
function dataOf(out){return out&&Object.prototype.hasOwnProperty.call(out,'data')?out.data:out;}
function bodyOf(out){return out&&out.body&&typeof out.body==='object'?out.body:{};}
function statusOf(out){const n=Number(out&&out.status);return Number.isFinite(n)?n:200;}

function createAutonomousBridge(deps){
  const {serviceRpc,suggestInternal,autoSend,requestHandoff,sendTyping}=deps;
  const log=deps.log||console;
  if(typeof serviceRpc!=='function'||typeof suggestInternal!=='function'||typeof autoSend!=='function'||typeof requestHandoff!=='function')throw new Error('WA_L10_BRIDGE_DEPS_REQUIRED');

  async function record(claim,eventType,reason,extra){
    const x=extra||{};
    try{
      await serviceRpc('aos_wa_l10_bridge_event_v1',{
        p_provider_message_id:claim.provider_message_id,
        p_attempt_id:claim.attempt_id,
        p_event_type:eventType,
        p_reason_code:cleanReason(reason),
        p_authority_decision_id:x.authority_decision_id||null,
        p_outbound_provider_message_id:x.outbound_provider_message_id||null,
        p_latency_ms:x.latency_ms==null?null:Math.max(0,Math.min(Number(x.latency_ms)||0,120000))
      });
    }catch(e){
      log.error&&log.error('[WA-L10-BRIDGE] audit event failed',cleanReason(e&&e.message));
    }
  }

  async function handoff(claim,reason){
    try{await requestHandoff(claim.conversation_id,cleanReason(reason));}
    catch(e){log.error&&log.error('[WA-L10-BRIDGE] handoff failed',cleanReason(e&&e.message));}
  }

  async function enqueueWebhook(raw){
    const ids=extractInboundProviderIds(raw),queued=[];
    for(const providerMessageId of ids){
      const out=dataOf(await serviceRpc('aos_wa_l10_bridge_enqueue_v1',{p_provider_message_id:providerMessageId}))||{};
      if(out.ok===false)throw new Error(out.error||'WA_L10_ENQUEUE_REJECTED');
      if(out.queued===true)queued.push(providerMessageId);
    }
    return {ids,queued};
  }

  async function processProviderMessage(providerMessageId){
    let claim=dataOf(await serviceRpc('aos_wa_l10_bridge_claim_v1',{p_provider_message_id:String(providerMessageId||'')}))||{};
    if(claim.ok===false)throw new Error(claim.error||'WA_L10_CLAIM_REJECTED');
    if(claim.claimed!==true)return {ok:true,processed:false,reason:claim.reason||'WA_L10_NOT_CLAIMED'};
    claim=Object.assign({provider_message_id:String(providerMessageId)},claim);
    const started=Date.now();

    if(typeof sendTyping==='function'){
      try{
        const typingPromise=sendTyping(claim.provider_message_id);
        if(typingPromise&&typeof typingPromise.catch==='function')typingPromise.catch(e=>log.error&&log.error('[WA-L10-BRIDGE] typing indicator failed',cleanReason(e&&e.message)));
      }catch(e){log.error&&log.error('[WA-L10-BRIDGE] typing indicator failed',cleanReason(e&&e.message));}
    }

    try{
      const suggestionResult=await suggestInternal(claim.conversation_id);
      const suggestionBody=bodyOf(suggestionResult),suggestion=suggestionBody.suggestion;
      const nextAction=String((suggestion&&suggestion.next_action)||suggestionBody.next_action||'').toUpperCase();
      const needsHuman=suggestionBody.needs_human===true||(suggestion&&suggestion.needs_human===true)||nextAction.startsWith('HUMAN_');
      if(statusOf(suggestionResult)<200||statusOf(suggestionResult)>=300||!suggestion||!String(suggestion.reply||'').trim()||needsHuman){
        const reason=cleanReason(suggestionBody.blocked_by&&suggestionBody.blocked_by.guard||suggestionBody.error||nextAction||'WA_L10_AI_HANDOFF');
        await handoff(claim,reason);
        await record(claim,'HANDOFF',reason,{latency_ms:Date.now()-started});
        return {ok:true,processed:true,outcome:'HANDOFF',reason};
      }

      await record(claim,'SUGGESTED','WA_L10_GOVERNED_SUGGESTION',{latency_ms:Date.now()-started});
      const identity=((suggestionBody.contexts||{}).identity||{}).identity_state||'NOT_REQUIRED';
      const sendResult=await autoSend({
        conversation_id:claim.conversation_id,
        recipient_kind:claim.recipient_kind,
        recipient_address:claim.recipient_address,
        to:claim.recipient_address,
        type:'text',
        text:String(suggestion.reply).trim(),
        idempotency_key:deterministicIdempotency(providerMessageId),
        safety_action:'ALLOW',
        identity_state:String(identity||'NOT_REQUIRED').toUpperCase(),
        requires_identity:false,
        campaign_key:claim.campaign_key||null
      });
      const sendBody=bodyOf(sendResult),sendStatus=statusOf(sendResult);
      const audit={
        authority_decision_id:sendBody.decision_id||null,
        outbound_provider_message_id:sendBody.message_id||null,
        latency_ms:Date.now()-started
      };
      if(sendStatus>=200&&sendStatus<300&&sendBody.ok===true){
        await record(claim,'SENT','WA_L10_AUTO_SENT',audit);
        return {ok:true,processed:true,outcome:'SENT',message_id:sendBody.message_id||null};
      }
      if(sendBody.decision==='HANDOFF'||sendBody.handoff===true){
        await record(claim,'HANDOFF',sendBody.reason||sendBody.error||'WA_L10_L4_HANDOFF',audit);
        return {ok:true,processed:true,outcome:'HANDOFF',reason:sendBody.reason||sendBody.error||null};
      }
      if(sendStatus>=500){
        await handoff(claim,sendBody.error||'WA_L10_PROVIDER_ERROR');
        await record(claim,'ERROR',sendBody.error||'WA_L10_PROVIDER_ERROR',audit);
        return {ok:false,processed:true,outcome:'ERROR',reason:sendBody.error||null};
      }
      await record(claim,'BLOCKED',sendBody.reason||sendBody.error||'WA_L10_L4_BLOCKED',audit);
      return {ok:true,processed:true,outcome:'BLOCKED',reason:sendBody.reason||sendBody.error||null};
    }catch(e){
      const reason=cleanReason(e&&e.message||'WA_L10_BRIDGE_ERROR');
      await handoff(claim,reason);
      await record(claim,'ERROR',reason,{latency_ms:Date.now()-started});
      log.error&&log.error('[WA-L10-BRIDGE] processing failed',reason);
      return {ok:false,processed:true,outcome:'ERROR',reason};
    }
  }

  async function processProviderIds(ids){
    const out=[];
    for(const id of Array.from(new Set((ids||[]).map(String))).slice(0,10))out.push(await processProviderMessage(id));
    return out;
  }

  async function recoverPending(){
    const rows=dataOf(await serviceRpc('aos_wa_l10_bridge_pending_v1',{p_limit:5}));
    const ids=Array.isArray(rows)?rows.map(r=>String(r&&r.provider_message_id||'')).filter(Boolean):[];
    return processProviderIds(ids);
  }

  return {enqueueWebhook,processProviderMessage,processProviderIds,recoverPending};
}

module.exports={createAutonomousBridge,extractInboundProviderIds,deterministicIdempotency,cleanReason};
