'use strict';

const DELIVERABLE=new Set(['IMMEDIATE','RECOVERY','FLAPPING_SUMMARY','DIGEST']);

function renderTelegramEnvelope(decision){
  if(!decision||!DELIVERABLE.has(decision.action))throw new Error('F9_DECISION_NOT_DELIVERABLE');
  const lines=[];
  if(decision.action==='DIGEST'){
    lines.push('SENTINEL · P2 DIGEST');
    lines.push(`Environment: ${decision.environment}`);
    lines.push(`Domain: ${decision.domain}`);
    lines.push(`Incidents: ${decision.count}`);
    lines.push(`IDs: ${decision.incident_ids.join(', ')}`);
    lines.push(`Window: ${decision.window_start} → ${decision.window_end}`);
  } else {
    const title=decision.action==='RECOVERY'?'SENTINEL · RECOVERY':decision.action==='FLAPPING_SUMMARY'?'SENTINEL · FLAPPING':'SENTINEL · INCIDENT';
    lines.push(title);
    lines.push(`${decision.incident_id} · ${decision.severity} · ${decision.status}`);
    lines.push(`${decision.environment} · ${decision.domain}`);
    lines.push(`${decision.component} / ${decision.capability}`);
    lines.push(`Failure: ${decision.failure_family}`);
    if(decision.release)lines.push(`Release: ${decision.release}`);
    if(decision.commit_sha)lines.push(`Commit: ${decision.commit_sha}`);
    if(decision.deployment_id)lines.push(`Deploy: ${decision.deployment_id}`);
    lines.push(`Signals: ${decision.signal_count} · Reopens: ${decision.reopened_count}`);
  }
  const text=lines.join('\n');
  if(text.length>3500)throw new Error('F9_TELEGRAM_TEMPLATE_TOO_LONG');
  if(/(token|authorization|cookie|password|phone|telefono|dni|email|paciente|patient|nombre|wa_id|recipient)\s*:/i.test(text))throw new Error('F9_TELEGRAM_TEMPLATE_SENSITIVE_LABEL');
  return {channel:'telegram-owner',text};
}

class AlertDispatcher {
  constructor({router,transport}){
    if(!router)throw new Error('F9_ROUTER_REQUIRED');
    if(!transport||typeof transport.send!=='function')throw new Error('F9_TRANSPORT_REQUIRED');
    this.router=router;
    this.transport=transport;
  }

  async dispatch(decision){
    if(!decision||!DELIVERABLE.has(decision.action))return {status:'NOT_DELIVERABLE',delivered:false,action:decision?.action||null};
    if(typeof this.transport.available==='function'&&!this.transport.available()){
      return {status:'UNAVAILABLE',delivered:false,action:decision.action};
    }
    const envelope=renderTelegramEnvelope(decision);
    const ack=await this.transport.send(envelope);
    if(!ack||ack.ok!==true){
      const code=ack?.code||'NO_ACK';
      if(code==='UNAVAILABLE'||code==='MISCONFIGURED')return {status:'UNAVAILABLE',delivered:false,action:decision.action,provider_code:code};
      if(code==='RATE_LIMITED')return {status:'RETRY_LATER',delivered:false,action:decision.action,provider_code:code,retry_after:ack?.retry_after||null};
      return {status:'FAILED',delivered:false,action:decision.action,provider_code:code};
    }
    this.router.recordDelivered(decision,ack.at||new Date().toISOString());
    return {status:'DELIVERED',delivered:true,action:decision.action,provider_message_id:ack.message_id||null};
  }
}

module.exports={AlertDispatcher,renderTelegramEnvelope,DELIVERABLE};
