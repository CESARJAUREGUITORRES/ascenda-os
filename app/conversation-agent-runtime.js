'use strict';

const VERSION='CONV-L3-V1';
const DEFAULT_MEMORY_MESSAGES=18;
const MAX_MEMORY_MESSAGES=30;
const DEFAULT_MEMORY_CHARS=12000;
const MAX_MEMORY_CHARS=20000;
const DEFAULT_BURST_WINDOW_MS=900;
const MIN_BURST_WINDOW_MS=250;
const MAX_BURST_WINDOW_MS=2500;
const MAX_TOOL_CALLS=2;
const MAX_REPLY_CHARS=1200;

const TOOL_NAMES=Object.freeze([
  'get_customer_context',
  'get_prices',
  'get_promotions',
  'get_locations_payment_methods',
  'get_availability',
  'prepare_booking',
  'confirm_booking',
  'rebook_booking',
  'cancel_booking',
  'get_media',
  'handoff',
  'create_hot_lead_signal'
]);
const TOOL_NAME_SET=new Set(TOOL_NAMES);
const UUID_RE=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function clean(v,max=2000){
  return String(v==null?'':v).replace(/\u0000/g,'').trim().slice(0,max);
}
function normalize(v){
  return clean(v,6000).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/\s+/g,' ').trim();
}
function redactPII(v){
  let s=clean(v,4000);
  s=s.replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi,'[EMAIL]');
  s=s.replace(/\b(?:\+?\d[\s().-]*){9,15}\b/g,'[TEL]');
  s=s.replace(/\b\d{8}\b/g,'[DOC]');
  return s;
}
function isInbound(m){return String(m&&m.direction||'').toUpperCase().includes('IN');}
function messageText(m){return clean(m&&(m.message_body??m.text),1800);}
function messageTime(m){const n=Date.parse(String(m&&(m.created_at??m.occurredAt)||''));return Number.isFinite(n)?n:null;}
function clamp(n,min,max,fallback){n=Number(n);return Number.isFinite(n)?Math.max(min,Math.min(max,n)):fallback;}
function freezeCopy(v){return Object.freeze(Object.assign({},v));}

function coalesceInboundBurst(messages,windowMs){
  const ms=Array.isArray(messages)?messages:[];
  const w=clamp(windowMs,MIN_BURST_WINDOW_MS,MAX_BURST_WINDOW_MS,DEFAULT_BURST_WINDOW_MS);
  let end=-1;
  for(let i=ms.length-1;i>=0;i--){if(isInbound(ms[i])&&messageText(ms[i])){end=i;break;}}
  if(end<0)return {messages:[],parts:[],text:'',latest_text:'',count:0,burst:false,window_ms:w};
  const picked=[ms[end]];
  let cursor=end;
  while(cursor>0){
    const prev=ms[cursor-1];
    if(!isInbound(prev)||!messageText(prev))break;
    const a=messageTime(prev),b=messageTime(ms[cursor]);
    if(a!=null&&b!=null&&b-a>w)break;
    picked.unshift(prev);cursor--;
  }
  const parts=picked.map(messageText).filter(Boolean);
  return {messages:picked,parts,text:parts.join('\n'),latest_text:parts.at(-1)||'',count:parts.length,burst:parts.length>1,window_ms:w};
}

function buildBoundedMemory(messages,options){
  options=options||{};
  const maxMessages=clamp(options.maxMessages,4,MAX_MEMORY_MESSAGES,DEFAULT_MEMORY_MESSAGES);
  const maxChars=clamp(options.maxChars,1000,MAX_MEMORY_CHARS,DEFAULT_MEMORY_CHARS);
  const all=(Array.isArray(messages)?messages:[]);
  const source=all.slice(-maxMessages);
  const out=[];
  let chars=0;
  for(let i=source.length-1;i>=0;i--){
    const m=source[i]||{};
    const text=redactPII(messageText(m));
    if(!text)continue;
    if(chars+text.length>maxChars)break;
    out.unshift({
      role:isInbound(m)?'user':'assistant',
      text,
      at:clean(m.created_at||m.occurredAt,64)||null
    });
    chars+=text.length;
  }
  const totalNonEmpty=all.filter(x=>messageText(x)).length;
  return {version:VERSION,messages:out,message_count:out.length,char_count:chars,truncated:out.length<totalNonEmpty};
}

function isStop(text){
  const t=normalize(text).replace(/[.!¡¿?]+/g,' ').replace(/\s+/g,' ').trim();
  return /^(stop|parar|baja|salir)$/.test(t)||
    /\b(no me (?:escriban|escribas|contacten|contactes)|dejen de (?:escribirme|contactarme)|no quiero (?:mas )?(?:mensajes|whatsapp|publicidad)|darme de baja|quiero salir|cancelar (?:mensajes|comunicaciones))\b/.test(t);
}
function isPersonalClinical(text){
  const t=normalize(text);
  return /\b(embarazad[ao]|lactancia|alergi[aco]|anticoagul|isotretino|diabetes|cancer|autoinmune|hipertension)\b/.test(t)||
    /\b(me duele (?:mucho|demasiado)|dolor intenso|me sangra|me hinch|reaccion|dificultad para respirar|fiebre)\b/.test(t)||
    /\b(puedo (?:hacerme|ponerme|aplicarme).*(?:si tengo|estando|porque tengo))\b/.test(t)||
    /\b(contraindicacion|contraindicaciones|soy apt[oa]|me conviene clinicamente)\b/.test(t);
}
function humanOwns(policy){
  const p=policy&&typeof policy==='object'?policy:{};
  const owner=String(p.ownerMode||p.ownership||p.conversationState||'').toUpperCase();
  return p.humanActive===true||p.humanTakeover===true||p.handoffRequested===true||owner==='HUMAN'||owner==='HUMAN_ACTIVE'||owner==='HUMAN_REQUESTED';
}
function safeHandoffText(){
  return 'Para ayudarte de forma segura con tu caso particular, voy a derivar esta conversación a una persona del equipo para que lo revise contigo.';
}
function noAction(reason,extra){return Object.assign({outcome:'NO_ACTION',toolTrace:[],confidence:1,handoffReason:reason},extra||{});}
function handoff(reason,text,extra){return Object.assign({outcome:'HANDOFF',response:text?{text:clean(text,MAX_REPLY_CHARS)}:undefined,toolTrace:[],confidence:1,handoffReason:reason},extra||{});}

function sanitizeTrace(call,result,latencyMs){
  return {
    tool:clean(call&&call.name,80),
    ok:result&&result.ok===true,
    status:clean(result&&(result.status||result.error||''),80)||null,
    latencyMs:Math.max(0,Number(latencyMs||0))
  };
}
function validateToolName(name){
  const n=clean(name,80);
  if(!TOOL_NAME_SET.has(n))throw Object.assign(new Error('CONV_L3_TOOL_NOT_ALLOWED'),{code:'CONV_L3_TOOL_NOT_ALLOWED'});
  return n;
}
function withTimeout(promise,ms){
  return new Promise((resolve,reject)=>{
    const t=setTimeout(()=>reject(Object.assign(new Error('CONV_L3_TOOL_TIMEOUT'),{code:'CONV_L3_TOOL_TIMEOUT'})),ms);
    if(t&&typeof t.unref==='function')t.unref();
    Promise.resolve(promise).then(v=>{clearTimeout(t);resolve(v);},e=>{clearTimeout(t);reject(e);});
  });
}
function createToolGateway(options){
  options=options||{};
  const handlers=options.handlers&&typeof options.handlers==='object'?options.handlers:{};
  const defaultTimeoutMs=clamp(options.defaultTimeoutMs,50,1500,300);
  return {
    async execute(call,ctx){
      const name=validateToolName(call&&call.name);
      const handler=handlers[name];
      if(typeof handler!=='function')return {ok:false,error:'TOOL_UNAVAILABLE',tool:name};
      const timeoutMs=clamp(call&&call.timeoutMs,50,1500,defaultTimeoutMs);
      try{
        const value=await withTimeout(handler(call&&call.input||{},ctx||{}),timeoutMs);
        if(value&&value.ok===false)return Object.assign({tool:name},value);
        return {ok:true,tool:name,data:value};
      }catch(err){
        const code=clean(err&&(err.code||err.message),80)||'TOOL_FAILED';
        return {ok:false,tool:name,error:code};
      }
    }
  };
}

function truthRequirement(text){
  const t=normalize(text);
  const required=[];
  if(/(?:s\/?\.?\s*\d|usd\s*\d|\$\s*\d|\b\d+(?:[.,]\d+)?\s*(?:soles?|dolares?|usd)\b)/.test(t))required.push('get_prices');
  if(/\b(?:tenemos|hay|aplica|vigente|incluye)\b.{0,50}\b(?:promo|promocion|oferta|descuento)\b|\b(?:promo|promocion|oferta|descuento)\b.{0,50}\b(?:vigente|aplica|tenemos|hay)\b/.test(t))required.push('get_promotions');
  if(/\b(?:hay|tenemos|queda|quedan)\b.{0,35}\b(?:cupo|cupos|disponibilidad|horario disponible)\b|\b(?:esta|estan) disponible\b/.test(t))required.push('get_availability');
  if(/\b(?:tu|la) cita (?:esta|quedo) (?:confirmada|agendada|reservada)\b|\b(?:cita|reserva) confirmada\b|\bte (?:agende|reserve)\b/.test(t))required.push('confirm_booking');
  return [...new Set(required)];
}
function internalLeak(text){
  const t=normalize(text);
  return /canonical_patient_id|booking_readiness|next_best_action|runtime_policy|adapter_contexts|authority_decision_id|aos_wa_|conv-l3-v1/.test(t);
}

function validateModelResult(v){
  if(!v||typeof v!=='object'||Array.isArray(v))throw Object.assign(new Error('CONV_L3_MODEL_RESULT_INVALID'),{code:'CONV_L3_MODEL_RESULT_INVALID'});
  const outcome=String(v.outcome||'').toUpperCase();
  if(!['RESPOND','HANDOFF','NO_ACTION'].includes(outcome))throw Object.assign(new Error('CONV_L3_MODEL_OUTCOME_INVALID'),{code:'CONV_L3_MODEL_OUTCOME_INVALID'});
  const text=v.response&&v.response.text!=null?clean(v.response.text,MAX_REPLY_CHARS):'';
  if(outcome==='RESPOND'&&!text)throw Object.assign(new Error('CONV_L3_EMPTY_RESPONSE'),{code:'CONV_L3_EMPTY_RESPONSE'});
  const confidence=Number(v.confidence);
  return {
    outcome,
    response:text?{text}:undefined,
    confidence:Number.isFinite(confidence)?Math.max(0,Math.min(1,confidence)):undefined,
    handoffReason:v.handoffReason?clean(v.handoffReason,120):undefined,
    usage:v.usage&&typeof v.usage==='object'?v.usage:undefined,
    decision:v.decision&&typeof v.decision==='object'?v.decision:undefined
  };
}

function createAgentRuntime(options){
  options=options||{};
  const modelAdapter=options.modelAdapter;
  const toolGateway=options.toolGateway;
  const recheck=typeof options.recheck==='function'?options.recheck:null;
  const now=typeof options.now==='function'?options.now:Date.now;
  if(!modelAdapter||typeof modelAdapter.run!=='function')throw new Error('CONV_L3_MODEL_ADAPTER_REQUIRED');
  if(!toolGateway||typeof toolGateway.execute!=='function')throw new Error('CONV_L3_TOOL_GATEWAY_REQUIRED');
  const flights=new Map();

  async function runTurn(input){
    input=input||{};
    const tenantId=clean(input.tenantId,120);
    const conversationId=clean(input.conversationId,64);
    const semanticTurnId=clean(input.semanticTurnId,160);
    if(!tenantId||!UUID_RE.test(conversationId)||!semanticTurnId)throw Object.assign(new Error('CONV_L3_TURN_INPUT_INVALID'),{code:'CONV_L3_TURN_INPUT_INVALID'});
    const policy=input.policy&&typeof input.policy==='object'?input.policy:{};
    if(humanOwns(policy))return noAction('HUMAN_OWNS_CONVERSATION');

    const burst=coalesceInboundBurst(input.inboundMessages,policy.burstWindowMs);
    if(!burst.count)return noAction('NO_INBOUND');
    if(isStop(burst.text))return noAction('STOP_OBSERVED',{policySignals:['STOP_OBSERVED']});
    if(isPersonalClinical(burst.text))return handoff('PERSONALIZED_CLINICAL',safeHandoffText(),{policySignals:['CLINICAL_HANDOFF']});

    const key=tenantId+':'+conversationId;
    if(flights.has(key))return noAction('SINGLE_FLIGHT_BUSY');
    const marker={semanticTurnId,startedAt:now()};flights.set(key,marker);
    const toolTrace=[];
    let toolCalls=0;
    const allowed=(Array.isArray(input.allowedTools)?input.allowedTools:[]).map(x=>typeof x==='string'?x:x&&x.name).filter(Boolean).map(validateToolName);
    const allowedSet=new Set(allowed);
    const memory=input.memory&&typeof input.memory==='object'?input.memory:buildBoundedMemory(input.inboundMessages,{maxMessages:policy.maxMemoryMessages,maxChars:policy.maxMemoryChars});

    const executeTool=async(call)=>{
      if(toolCalls>=MAX_TOOL_CALLS)return {ok:false,error:'TOOL_BUDGET_EXCEEDED'};
      const name=validateToolName(call&&call.name);
      if(!allowedSet.has(name))return {ok:false,error:'TOOL_NOT_ALLOWED_FOR_TURN'};
      toolCalls++;
      const started=now();
      const result=await toolGateway.execute(Object.assign({},call,{name}),{tenantId,conversationId,semanticTurnId});
      toolTrace.push(sanitizeTrace({name},result,now()-started));
      return result;
    };

    try{
      const raw=await modelAdapter.run({
        version:VERSION,
        tenantId,conversationId,semanticTurnId,
        semanticTurn:freezeCopy({text:redactPII(burst.text),latest_text:redactPII(burst.latest_text),parts:burst.parts.map(redactPII),count:burst.count,burst:burst.burst,window_ms:burst.window_ms}),
        memory,
        allowedTools:allowed.slice(),
        policy:Object.assign({},policy,{providerDispatch:false,directSql:false,maxToolCalls:MAX_TOOL_CALLS,oneOutboundDefault:true})
      },executeTool);
      const result=validateModelResult(raw);

      if(result.outcome==='RESPOND'&&toolTrace.some(t=>t.ok===false)&&raw&&raw.requiresToolTruth===true){
        return handoff('GOVERNED_TOOL_UNAVAILABLE',null,{toolTrace,confidence:0,policySignals:['NO_FABRICATION']});
      }
      if(result.outcome==='RESPOND'&&result.response&&internalLeak(result.response.text)){
        return handoff('INTERNAL_POLICY_LEAK',null,{toolTrace,confidence:0,policySignals:['FAIL_CLOSED']});
      }
      if(result.outcome==='RESPOND'&&result.response){
        const required=truthRequirement(result.response.text);
        const okTools=new Set(toolTrace.filter(t=>t.ok).map(t=>t.tool));
        const missing=required.filter(name=>name==='confirm_booking'
          ? !['confirm_booking','rebook_booking'].some(x=>okTools.has(x))
          : !okTools.has(name));
        if(missing.length)return handoff('MISSING_GOVERNED_EVIDENCE',null,{toolTrace,confidence:0,policySignals:['NO_FABRICATION'],requiredTools:required,missingTools:missing});
      }
      if(recheck){
        let state;
        try{state=await recheck({tenantId,conversationId,semanticTurnId,startedAt:marker.startedAt});}
        catch(_){return noAction('RECHECK_UNAVAILABLE',{toolTrace,policySignals:['FAIL_CLOSED']});}
        if(state&&humanOwns(state))return noAction('HUMAN_TAKEOVER_RACE',{toolTrace,policySignals:['HUMAN_WINS']});
        if(state&&(state.newerInbound===true||state.stale===true))return noAction('STALE_TURN',{toolTrace,policySignals:['STALE_SUPPRESSED']});
      }
      result.toolTrace=toolTrace;
      result.semanticTurn={count:burst.count,burst:burst.burst,window_ms:burst.window_ms};
      result.providerDispatch=false;
      return result;
    }finally{
      if(flights.get(key)===marker)flights.delete(key);
    }
  }

  function snapshot(){return {version:VERSION,inFlight:flights.size,providerDispatch:false,maxToolCalls:MAX_TOOL_CALLS};}
  return {version:VERSION,runTurn,snapshot};
}

module.exports={
  VERSION,TOOL_NAMES,MAX_TOOL_CALLS,MAX_REPLY_CHARS,
  normalize,redactPII,coalesceInboundBurst,buildBoundedMemory,
  isStop,isPersonalClinical,humanOwns,createToolGateway,createAgentRuntime,
  validateToolName,validateModelResult,truthRequirement,internalLeak
};
