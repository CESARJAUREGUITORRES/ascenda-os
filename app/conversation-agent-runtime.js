'use strict';

const AGENT_RUNTIME_VERSION='CONV-L3-SHADOW-V2';
const MAX_TOOL_CALLS=2;
const DEFAULT_MAX_MESSAGES=12;
const DEFAULT_MAX_CHARS=6000;

function text(v){return String(v==null?'':v).trim();}
function upper(v){return text(v).toUpperCase();}

function clipMemory(messages,maxMessages,maxChars){
  const src=Array.isArray(messages)?messages:[];
  const picked=[];
  let used=0;
  for(let i=src.length-1;i>=0&&picked.length<maxMessages;i--){
    const m=src[i]||{};
    const body=text(m.message_body||m.body);
    if(!body)continue;
    const direction=upper(m.direction)==='OUTBOUND'?'OUTBOUND':'INBOUND';
    const take=Math.max(0,Math.min(body.length,maxChars-used));
    if(take<=0)break;
    picked.push({direction,body:body.slice(0,take),created_at:m.created_at||null});
    used+=take;
  }
  return picked.reverse();
}

function semanticTurn(memory){
  const src=Array.isArray(memory)?memory:[];
  let start=0;
  for(let i=src.length-1;i>=0;i--){
    if(src[i]&&src[i].direction==='OUTBOUND'){start=i+1;break;}
  }
  return src.slice(start).filter(m=>m&&m.direction==='INBOUND').map(m=>text(m.body)).filter(Boolean).join('\n');
}

function detectBoundary(memory){
  const inbound=memory.filter(m=>m.direction==='INBOUND').map(m=>m.body).join('\n');
  const u=upper(inbound);
  if(/(^|\b)(STOP|BAJA|NO QUIERO RECIBIR|NO ME ESCRIBAN|NO CONTACTAR)(\b|$)/i.test(inbound)){
    return {kind:'STOP',reason:'customer_stop_or_suppression'};
  }
  if(/\b(DIAGNOSTIC|DIAGNOSTICO|DIAGNÓSTICO|DOSIS|EMBARAZ|ALERG|CONTRAINDIC|RECETA|PRESCRIP|URGENT|EMERGENC)\b/i.test(u)){
    return {kind:'HANDOFF',reason:'clinical_sensitive'};
  }
  return null;
}

function validateToolCalls(requested,registry){
  const allowed=new Set(Array.isArray(registry)?registry.map(x=>text(x&&x.name||x)).filter(Boolean):[]);
  const out=[];
  for(const call of Array.isArray(requested)?requested:[]){
    if(out.length>=MAX_TOOL_CALLS)break;
    const name=text(call&&call.name);
    if(!name||!allowed.has(name))continue;
    out.push({name,args:(call&&call.args&&typeof call.args==='object')?call.args:{}});
  }
  return out;
}

function createAgentRuntime(options){
  options=options||{};
  const modelAdapter=options.modelAdapter;
  const toolRegistry=Array.isArray(options.toolRegistry)?options.toolRegistry:[];
  const maxMessages=Math.max(1,Math.min(30,Number(options.maxMessages||DEFAULT_MAX_MESSAGES)));
  const maxChars=Math.max(500,Math.min(12000,Number(options.maxChars||DEFAULT_MAX_CHARS)));
  if(!modelAdapter||typeof modelAdapter.decide!=='function')throw new Error('CONV_L3_MODEL_ADAPTER_REQUIRED');

  async function shadowTurn(input){
    input=input||{};
    const conversation=input.conversation||{};
    const currentVersion=Number(conversation.version||0);
    const expectedVersion=input.expected_version==null?currentVersion:Number(input.expected_version);
    const memory=clipMemory(input.messages,maxMessages,maxChars);

    if(conversation.state==='HUMAN_ACTIVE'){
      return {version:AGENT_RUNTIME_VERSION,mode:'SHADOW',decision:'HUMAN_CONTROL',reason:'human_takeover_wins',memory,tool_calls:[],provider_send_eligible:false};
    }
    if(expectedVersion!==currentVersion){
      return {version:AGENT_RUNTIME_VERSION,mode:'SHADOW',decision:'STALE_TURN',reason:'conversation_version_changed',memory,tool_calls:[],provider_send_eligible:false};
    }
    const boundary=detectBoundary(memory);
    if(boundary){
      return {version:AGENT_RUNTIME_VERSION,mode:'SHADOW',decision:boundary.kind,reason:boundary.reason,memory,tool_calls:[],provider_send_eligible:false};
    }

    const modelResult=await modelAdapter.decide({
      conversation:{id:conversation.id||null,state:conversation.state||null,version:currentVersion},
      memory,
      current_turn:semanticTurn(memory),
      available_tools:toolRegistry.map(x=>text(x&&x.name||x)).filter(Boolean),
      constraints:{max_tool_calls:MAX_TOOL_CALLS,provider_send:false,direct_sql:false,direct_meta:false}
    });
    const toolCalls=validateToolCalls(modelResult&&modelResult.tool_calls,toolRegistry);
    return {
      version:AGENT_RUNTIME_VERSION,
      mode:'SHADOW',
      decision:'PLAN_READY',
      reason:'shadow_reasoning_complete',
      memory,
      tool_calls:toolCalls,
      draft_reply:text(modelResult&&modelResult.draft_reply).slice(0,3000),
      next_best_action:text(modelResult&&modelResult.next_best_action).slice(0,160)||null,
      provider_send_eligible:false
    };
  }

  return {version:AGENT_RUNTIME_VERSION,shadowTurn};
}

module.exports={AGENT_RUNTIME_VERSION,MAX_TOOL_CALLS,clipMemory,semanticTurn,detectBoundary,validateToolCalls,createAgentRuntime};
