'use strict';
const https=require('https');
const ai=require('./ai-router');

const GEMINI_MODEL='gemini-3.8-flash';
const GEMINI_COST={input:0.75,output:3.75};
const DEFAULT_SCHEMA=Object.freeze({type:'object'});
let geminiSecretCache={value:'',expiresAt:0};

function providerError(name,message,status,upstreamStatus,code){
  const e=new Error(name);e.status=status||502;e.upstreamStatus=upstreamStatus||null;e.code=code||null;e.messageSafe=String(message||'').slice(0,180)||null;return e;
}

function loadGeminiSecret(){
  const now=Date.now();if(now<geminiSecretCache.expiresAt)return Promise.resolve(geminiSecretCache.value);
  const sb=String(process.env.SUPABASE_URL||''),serviceKey=String(process.env.SUPABASE_SERVICE_ROLE_KEY||'');
  if(!sb||!serviceKey){geminiSecretCache={value:'',expiresAt:now+30000};return Promise.resolve('');}
  return new Promise(resolve=>{
    let u;try{u=new URL(sb);}catch(_){geminiSecretCache={value:'',expiresAt:now+30000};return resolve('');}
    const path='/rest/v1/aos_integration_secrets_v1?tipo=eq.gemini&select=api_key&limit=1';
    const q=https.request({hostname:u.hostname,port:u.port||443,path,method:'GET',headers:{apikey:serviceKey,Authorization:'Bearer '+serviceKey,'Content-Type':'application/json','User-Agent':'AscendaOS-WA4-ProviderRouter/1.0'},timeout:5000},r=>{
      let raw='';r.on('data',c=>raw+=c);r.on('end',()=>{
        let rows=[];try{rows=JSON.parse(raw||'[]');}catch(_){}
        const value=r.statusCode>=200&&r.statusCode<300&&Array.isArray(rows)&&rows[0]&&typeof rows[0].api_key==='string'?rows[0].api_key:'';
        geminiSecretCache={value:value.length>10?value:'',expiresAt:Date.now()+(value.length>10?300000:30000)};resolve(geminiSecretCache.value);
      });
    });
    q.on('timeout',()=>q.destroy());q.on('error',()=>{geminiSecretCache={value:'',expiresAt:Date.now()+30000};resolve('');});q.end();
  });
}

function geminiRequest(apiKey,body,timeoutMs){
  return new Promise((resolve,reject)=>{
    if(!apiKey)return reject(providerError('GEMINI_KEY_REQUIRED','Gemini key missing',503,null,'GEMINI_KEY_REQUIRED'));
    const data=JSON.stringify(body||{});
    const q=https.request({hostname:'generativelanguage.googleapis.com',path:'/v1beta/interactions',method:'POST',headers:{'x-goog-api-key':apiKey,'Content-Type':'application/json','Content-Length':Buffer.byteLength(data),'User-Agent':'AscendaOS-WA4/1.0'},timeout:Number(timeoutMs||10000)},r=>{
      let raw='';r.on('data',c=>raw+=c);r.on('end',()=>{
        let parsed;try{parsed=raw?JSON.parse(raw):{};}catch(_){return reject(providerError('GEMINI_INVALID_JSON','Invalid provider JSON',502,r.statusCode,'GEMINI_INVALID_JSON'));}
        if(r.statusCode>=200&&r.statusCode<300)return resolve(parsed);
        const msg=parsed&&parsed.error&&parsed.error.message,code=parsed&&parsed.error&&parsed.error.status;
        reject(providerError('GEMINI_REJECTED',msg,502,r.statusCode,code));
      });
    });
    q.on('timeout',()=>q.destroy(providerError('GEMINI_TIMEOUT','Gemini timeout',504,null,'GEMINI_TIMEOUT')));
    q.on('error',reject);q.write(data);q.end();
  });
}

function messageInput(messages){
  const source=Array.isArray(messages)?messages:[],system=[],input=[];
  for(const m of source){
    if(!m||typeof m.content!=='string'||!m.content.trim())continue;
    if(String(m.role||'').toLowerCase()==='system')system.push(m.content.trim());
    else input.push(String(m.role||'user').toUpperCase()+':\n'+m.content.trim());
  }
  return {system_instruction:system.join('\n\n').slice(0,16000),input:input.join('\n\n').slice(0,240000)};
}

function textFromInteraction(out){
  const steps=Array.isArray(out&&out.steps)?out.steps:[];
  for(let i=steps.length-1;i>=0;i--){
    const s=steps[i];if(!s||s.type!=='model_output'||!Array.isArray(s.content))continue;
    const texts=s.content.filter(x=>x&&x.type==='text'&&typeof x.text==='string').map(x=>x.text.trim()).filter(Boolean);
    if(texts.length)return texts.join('\n');
  }
  return '';
}

function usageFromInteraction(out){
  const u=out&&out.usage||{};
  return {prompt_tokens:Number(u.total_input_tokens||0),completion_tokens:Number(u.total_output_tokens||0),total_tokens:Number(u.total_tokens||0)};
}
function geminiCost(usage){
  const u=usage||{};return Number((((Number(u.prompt_tokens||0)*GEMINI_COST.input)+(Number(u.completion_tokens||0)*GEMINI_COST.output))/1000000).toFixed(8));
}

async function geminiChat(apiKey,messages,options){
  const opts=options||{},parts=messageInput(messages),started=Date.now();
  if(!parts.input)return Promise.reject(providerError('GEMINI_INPUT_REQUIRED','No user input',400,null,'GEMINI_INPUT_REQUIRED'));
  const max=Math.max(64,Math.min(Number(opts.maxTokens||700),3000));
  const out=await geminiRequest(apiKey,{
    model:opts.geminiModel||GEMINI_MODEL,
    input:parts.input,
    system_instruction:parts.system_instruction||undefined,
    store:false,
    generation_config:{max_output_tokens:max,thinking_level:'low',thinking_summaries:'none'},
    response_format:{type:'text',mime_type:'application/json',schema:opts.jsonSchema||DEFAULT_SCHEMA}
  },opts.geminiTimeoutMs||10000);
  if(out&&out.status&&out.status!=='completed')throw providerError('GEMINI_INCOMPLETE','Interaction status '+String(out.status),502,null,'GEMINI_INCOMPLETE');
  const content=textFromInteraction(out);if(!content)throw providerError('GEMINI_EMPTY_RESPONSE','Empty Gemini response',502,null,'GEMINI_EMPTY_RESPONSE');
  let json;try{json=JSON.parse(content);}catch(_){throw providerError('GEMINI_NON_JSON_RESPONSE','Non-JSON Gemini response',502,null,'GEMINI_NON_JSON_RESPONSE');}
  const usage=usageFromInteraction(out);
  return {provider:'gemini',model:String(out&&out.model||opts.geminiModel||GEMINI_MODEL),json,usage,latencyMs:Date.now()-started,estimated_cost_usd:geminiCost(usage),fallback_used:true};
}

function retryableGroq(e){
  const name=String(e&&e.message||''),up=Number(e&&e.upstreamStatus||0),code=String(e&&e.code||'').toUpperCase();
  if(name==='GROQ_KEY_REQUIRED'||name==='GROQ_TIMEOUT'||name==='GROQ_EMPTY_RESPONSE'||name==='GROQ_NON_JSON_RESPONSE'||name==='GROQ_INVALID_JSON')return true;
  if(up===401||up===403||up===408||up===429||up>=500)return true;
  if(['ECONNRESET','ECONNREFUSED','EAI_AGAIN','ENOTFOUND','ETIMEDOUT'].includes(code))return true;
  return false;
}

async function chat(keys,model,messages,options){
  const k=keys||{},opts=options||{},started=Date.now();
  try{
    const out=await ai.chat(k.groq||'',model,messages,opts);
    return Object.assign({provider:'groq',fallback_used:false,estimated_cost_usd:ai.estimateCost(out.model,out.usage)},out);
  }catch(e){
    if(!retryableGroq(e))throw e;
    const geminiKey=k.gemini||await loadGeminiSecret();if(!geminiKey)throw e;
    const fallback=await geminiChat(geminiKey,messages,opts);
    fallback.primary_error=String(e&&e.message||'GROQ_FAILED').slice(0,80);
    fallback.total_latency_ms=Date.now()-started;
    return fallback;
  }
}

function clearSecretCache(){geminiSecretCache={value:'',expiresAt:0};}
module.exports={GEMINI_MODEL,GEMINI_COST,retryableGroq,messageInput,textFromInteraction,usageFromInteraction,geminiChat,chat,loadGeminiSecret,clearSecretCache};
