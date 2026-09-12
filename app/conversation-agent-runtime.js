'use strict';

const AGENT_RUNTIME_VERSION='CONV-L3-SHADOW-V3';
const MAX_TOOL_CALLS=2;
const DEFAULT_MAX_MESSAGES=12;
const DEFAULT_MAX_CHARS=6000;
const MAX_OBSERVATION_CHARS=12000;

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
  return src.slice(start)
    .filter(m=>m&&m.direction==='INBOUND')
    .map(m=>text(m.body))
    .filter(Boolean)
    .join('\n');
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

function registryNames(registry){
  return Array.isArray(registry)?registry.map(x=>text(x&&x.name||x)).filter(Boolean):[];
}

function validateToolCalls(requested,registry){
  const allowed=new Set(registryNames(registry));
  const out=[];
  for(const call of Array.isArray(requested)?requested:[]){
    if(out.length>=MAX_TOOL_CALLS)break;
    const name=text(call&&call.name);
    if(!name||!allowed.has(name)||out.some(x=>x.name===name))continue;
    out.push({name,args:(call&&call.args&&typeof call.args==='object'&&!Array.isArray(call.args))?call.args:{}});
  }
  return out;
}

function safeObservationData(value){
  if(!value||typeof value!=='object'||Array.isArray(value))return {};
  try{
    const raw=JSON.stringify(value);
    if(!raw||raw.length>MAX_OBSERVATION_CHARS)return {};
    return JSON.parse(raw);
  }catch(_){return {};}
}

function validateToolObservations(observations,registry,plannedNames){
  const allowed=new Set(registryNames(registry));
  const planned=new Set((Array.isArray(plannedNames)?plannedNames:[]).map(text).filter(Boolean));
  const out=[];
  for(const observation of Array.isArray(observations)?observations:[]){
    if(out.length>=MAX_TOOL_CALLS)break;
    const name=text(observation&&observation.name);
    if(!name||!allowed.has(name)||!planned.has(name)||out.some(x=>x.name===name))continue;
    out.push({name,data:safeObservationData(observation&&observation.data)});
  }
  return out;
}

function preflight(conversation,expectedVersion,memory){
  const currentVersion=Number(conversation&&conversation.version||0);
  if(conversation&&conversation.state==='HUMAN_ACTIVE'){
    return {decision:'HUMAN_CONTROL',reason:'human_takeover_wins',currentVersion};
  }
  if(Number(expectedVersion)!==currentVersion){
    return {decision:'STALE_TURN',reason:'conversation_version_changed',currentVersion};
  }
  const boundary=detectBoundary(memory);
  if(boundary)return {decision:boundary.kind,reason:boundary.reason,currentVersion};
  return {decision:null,reason:null,currentVersion};
}

function boundaryResult(pre,memory){
  return {
    version:AGENT_RUNTIME_VERSION,
    mode:'SHADOW',
    decision:pre.decision,
    response_state:'BLOCKED',
    reason:pre.reason,
    memory,
    tool_calls:[],
    draft_reply:'',
    provider_send_eligible:false
  };
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
    const pre=preflight(conversation,expectedVersion,memory);
    if(pre.decision)return boundaryResult(pre,memory);

    const modelResult=await modelAdapter.decide({
      conversation:{id:conversation.id||null,state:conversation.state||null,version:currentVersion},
      memory,
      current_turn:semanticTurn(memory),
      available_tools:registryNames(toolRegistry),
      constraints:{max_tool_calls:MAX_TOOL_CALLS,provider_send:false,direct_sql:false,direct_meta:false}
    });
    const toolCalls=validateToolCalls(modelResult&&modelResult.tool_calls,toolRegistry);
    const awaiting=toolCalls.length>0;
    return {
      version:AGENT_RUNTIME_VERSION,
      mode:'SHADOW',
      decision:'PLAN_READY',
      response_state:awaiting?'AWAITING_TOOL_OBSERVATION':'READY',
      reason:awaiting?'tool_observation_required':'shadow_reasoning_complete',
      memory,
      tool_calls:toolCalls,
      planned_tool_names:toolCalls.map(x=>x.name),
      draft_reply:awaiting?'':text(modelResult&&modelResult.draft_reply).slice(0,3000),
      next_best_action:text(modelResult&&modelResult.next_best_action).slice(0,160)||null,
      provider_send_eligible:false
    };
  }

  async function shadowCompose(input){
    input=input||{};
    const conversation=input.conversation||{};
    const currentVersion=Number(conversation.version||0);
    const expectedVersion=input.expected_version==null?currentVersion:Number(input.expected_version);
    const memory=clipMemory(input.messages,maxMessages,maxChars);
    const pre=preflight(conversation,expectedVersion,memory);
    if(pre.decision)return boundaryResult(pre,memory);

    const planned=Array.from(new Set((Array.isArray(input.planned_tool_names)?input.planned_tool_names:[]).map(text).filter(Boolean))).slice(0,MAX_TOOL_CALLS);
    const allowed=new Set(registryNames(toolRegistry));
    const validPlanned=planned.filter(name=>allowed.has(name));
    if(!validPlanned.length){
      return {
        version:AGENT_RUNTIME_VERSION,mode:'SHADOW',decision:'OBSERVATION_REQUIRED',
        response_state:'BLOCKED',reason:'planned_tool_required',memory,tool_calls:[],
        tool_observations:[],draft_reply:'',provider_send_eligible:false
      };
    }

    const observations=validateToolObservations(input.tool_observations,toolRegistry,validPlanned);
    const observed=new Set(observations.map(x=>x.name));
    const missing=validPlanned.filter(name=>!observed.has(name));
    if(missing.length){
      return {
        version:AGENT_RUNTIME_VERSION,mode:'SHADOW',decision:'OBSERVATION_REQUIRED',
        response_state:'AWAITING_TOOL_OBSERVATION',reason:'missing_tool_observation',
        memory,tool_calls:[],planned_tool_names:validPlanned,missing_tool_names:missing,
        tool_observations:observations,draft_reply:'',provider_send_eligible:false
      };
    }
    if(typeof modelAdapter.compose!=='function')throw new Error('CONV_L3_COMPOSE_ADAPTER_REQUIRED');

    const composed=await modelAdapter.compose({
      conversation:{id:conversation.id||null,state:conversation.state||null,version:currentVersion},
      memory,
      current_turn:semanticTurn(memory),
      tool_observations:observations,
      constraints:{provider_send:false,direct_sql:false,direct_meta:false,observed_tools_only:true}
    });
    const draft=text(composed&&composed.draft_reply).slice(0,3000);
    if(!draft){
      return {
        version:AGENT_RUNTIME_VERSION,mode:'SHADOW',decision:'COMPOSE_INVALID',
        response_state:'BLOCKED',reason:'empty_composed_reply',memory,tool_calls:[],
        tool_observations:observations,draft_reply:'',provider_send_eligible:false
      };
    }
    const cited=Array.from(new Set((Array.isArray(composed&&composed.cited_tools)?composed.cited_tools:[])
      .map(text).filter(name=>observed.has(name))));
    return {
      version:AGENT_RUNTIME_VERSION,
      mode:'SHADOW',
      decision:'RESPONSE_READY',
      response_state:'READY',
      reason:'tool_observation_composed',
      memory,
      tool_calls:[],
      planned_tool_names:validPlanned,
      tool_observations:observations,
      cited_tools:cited,
      draft_reply:draft,
      next_best_action:text(composed&&composed.next_best_action).slice(0,160)||null,
      provider_send_eligible:false
    };
  }

  return {version:AGENT_RUNTIME_VERSION,shadowTurn,shadowCompose};
}

module.exports={
  AGENT_RUNTIME_VERSION,MAX_TOOL_CALLS,clipMemory,semanticTurn,detectBoundary,
  validateToolCalls,validateToolObservations,createAgentRuntime
};
