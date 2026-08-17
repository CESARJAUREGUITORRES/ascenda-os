'use strict';

function boolMode(v){return String(v==null?'true':v).toLowerCase()==='true';}
function uuidLike(v){return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(v||''));}

function createF17WaAdapter(opts){
  const serviceRpc=opts&&opts.serviceRpc;
  const canaryMode=opts&&opts.canaryMode;
  if(typeof serviceRpc!=='function')throw new Error('F17_SERVICE_RPC_REQUIRED');

  async function rpc(name,payload){
    const out=await serviceRpc(name,{p_payload:payload||{}});
    if(!out||out.ok!==true)throw Object.assign(new Error('F17_RPC_REJECTED'),{status:502});
    return out;
  }

  async function prepareOutbound(input){
    const d=input||{};const payload=d.payload||{};const actor=String(d.actor||'');
    const canary=boolMode(canaryMode);
    if(canary){
      await rpc('aos_cia_channel_register_canary_recipient_v1',{
        channel:'WHATSAPP',recipient_contact:payload.to,allowlist_verified:true,
        requested_by_user_id:uuidLike(actor)?actor:null,ttl_minutes:30
      });
    }
    return rpc('aos_cia_channel_prepare_send_v1',{
      channel:'WHATSAPP',recipient_contact:payload.to,purpose:'ADMIN_WHATSAPP_SEND',
      message_class:String(payload.type||'text').toUpperCase(),idempotency_key:String(d.idempotencyKey||''),
      requested_by_user_id:uuidLike(actor)?actor:null,
      authorization_provenance:{source:'admin-chats',strong_2fa:true,canary_allowlist:canary},
      context:{canary,transport:'WA1_META_GATEWAY'}
    });
  }

  function markAccepted(requestId,providerMessageId){
    return rpc('aos_cia_channel_mark_dispatch_v1',{
      request_id:requestId,outcome:'ACCEPTED',provider:'META_WHATSAPP',provider_message_id:String(providerMessageId||'')
    });
  }
  function markFailed(requestId,errorCode){
    return rpc('aos_cia_channel_mark_dispatch_v1',{
      request_id:requestId,outcome:'FAILED',provider:'META_WHATSAPP',error_code:String(errorCode||'WA_SEND_FAILED').slice(0,128)
    });
  }

  async function ingestEnvelope(envelope){
    const e=envelope||{messages:[],events:[]};const results={inbound:0,events_linked:0,events_unlinked:0};
    for(const m of e.messages||[]){
      const r=await rpc('aos_cia_channel_ingest_inbound_v1',{
        channel:'WHATSAPP',provider_message_id:m.provider_message_id,sender_contact:m.from_number,
        conversation_ref:m.conversation_id||null,message_type:m.message_type,provider_timestamp:m.provider_timestamp||m.received_at||null,
        attribution_ref:{campaign_source:m.campaign_source||null,ad_id:m.ad_id||null,lead_id:m.lead_id||null}
      });
      if(r.inserted)results.inbound++;
    }
    for(const ev of e.events||[]){
      const r=await rpc('aos_cia_channel_record_provider_event_v1',{
        channel:'WHATSAPP',provider_message_id:ev.provider_message_id,event_key:ev.event_key,
        event_type:ev.event_type,status:ev.status,payload:ev.payload||{}
      });
      if(r.linked)results.events_linked++;else results.events_unlinked++;
    }
    return results;
  }

  return {prepareOutbound,markAccepted,markFailed,ingestEnvelope};
}

module.exports={createF17WaAdapter};