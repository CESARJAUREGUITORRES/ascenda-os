'use strict';
const https=require('https');
const ai=require('./ai-router');
const resilience=require('./wa4-ai-resilience');
const answerCards=require('./wa4-answer-cards');

const VERSION='WA4-FASTPATH-R1-BENCH';
const ROUNDS=8;
let groqSecretCache={value:'',expiresAt:0};

function percentile(values,p){
  const xs=(Array.isArray(values)?values:[]).map(Number).filter(Number.isFinite).sort((a,b)=>a-b);
  if(!xs.length)return null;
  const rank=Math.max(1,Math.ceil((Number(p)||0)*xs.length));
  return xs[Math.min(xs.length-1,rank-1)];
}

function loadGroqSecret(){
  const now=Date.now();if(now<groqSecretCache.expiresAt)return Promise.resolve(groqSecretCache.value);
  const sb=String(process.env.SUPABASE_URL||''),serviceKey=String(process.env.SUPABASE_SERVICE_ROLE_KEY||'');
  if(!sb||!serviceKey){groqSecretCache={value:'',expiresAt:now+30000};return Promise.resolve('');}
  return new Promise(resolve=>{
    let u;try{u=new URL(sb);}catch(_){groqSecretCache={value:'',expiresAt:now+30000};return resolve('');}
    const path='/rest/v1/aos_integration_secrets_v1?tipo=eq.groq&select=api_key&limit=1';
    const q=https.request({hostname:u.hostname,port:u.port||443,path,method:'GET',headers:{apikey:serviceKey,Authorization:'Bearer '+serviceKey,'Content-Type':'application/json','User-Agent':'AscendaOS-WA4-Benchmark/1.0'},timeout:5000},r=>{
      let raw='';r.on('data',c=>raw+=c);r.on('end',()=>{
        let rows=[];try{rows=JSON.parse(raw||'[]');}catch(_){}
        const value=r.statusCode>=200&&r.statusCode<300&&Array.isArray(rows)&&rows[0]&&typeof rows[0].api_key==='string'?rows[0].api_key:'';
        groqSecretCache={value:value.length>10?value:'',expiresAt:Date.now()+(value.length>10?300000:30000)};resolve(groqSecretCache.value);
      });
    });
    q.on('timeout',()=>q.destroy());q.on('error',()=>{groqSecretCache={value:'',expiresAt:Date.now()+30000};resolve('');});q.end();
  });
}

function syntheticKnowledge(){
  return {
    version:'WA4-BENCH-SYNTHETIC-V1',audience:'PUBLIC_CLIENT',authority:'GOVERNED_SOURCE_ONLY',generic_llm_authority:false,price_authority:'BENCH_ONLY',price_stage:true,
    items:[{
      knowledge_id:'bench-svc-1',domain:'CATALOG',title:'Tratamiento demo',authority_tier:1,freshness_state:'CURRENT',
      evidence_ref:{version:'bench-v1',source_code:'BENCH_SYNTHETIC'},
      facts:{nombre:'Tratamiento demo',categoria:'Benchmark',precio_oferta:199,moneda:'PEN',descripcion_comercial:'Servicio sintético usado exclusivamente para medir latencia del pipeline de IA.',beneficios:['Respuesta breve y gobernada'],faqs:[{q:'¿Cuál es el precio?',a:'S/ 199.'}]}
    }]
  };
}

function schemas(){
  return {
    sales:{type:'object',properties:{reply:{type:'string'},intent:{type:'string'},next_action:{type:'string'},confidence:{type:'number'},cited_knowledge_ids:{type:'array',items:{type:'string'}},needs_human:{type:'boolean'},reason:{type:'string'}},required:['reply','intent','next_action','confidence','cited_knowledge_ids','needs_human','reason']},
    safety:{type:'object',properties:{allow:{type:'boolean'},category:{type:'string'},rationale:{type:'string'}},required:['allow','category','rationale']}
  };
}

async function oneRound(keys,round){
  const cards=answerCards.build(syntheticKnowledge(),{maxItems:4}),schema=schemas();
  const mainMessages=[
    {role:'system',content:'Eres un benchmark sintético de ASCENDA. Usa solo GOVERNED_KNOWLEDGE. Devuelve JSON. No diagnostiques ni inventes. Cita bench-svc-1.'},
    {role:'user',content:JSON.stringify({client_message:'¿Cuánto cuesta el tratamiento demo?',GOVERNED_KNOWLEDGE:cards,required_reply:'El precio aprobado es S/ 199.',round})}
  ];
  const started=Date.now();
  const mainStarted=Date.now();
  const main=await resilience.chat(keys,ai.MODELS.fast,mainMessages,{maxTokens:180,reasoningEffort:'low',timeoutMs:6000,geminiTimeoutMs:7000,jsonSchema:schema.sales});
  const mainMs=Date.now()-mainStarted;
  const citations=Array.isArray(main&&main.json&&main.json.cited_knowledge_ids)?main.json.cited_knowledge_ids.map(String):[];
  if(!main||!main.json||!String(main.json.reply||'').trim()||!citations.includes('bench-svc-1'))throw new Error('BENCH_MAIN_INVALID');
  const safetyStarted=Date.now();
  const safety=await resilience.chat(keys,ai.MODELS.safety,[
    {role:'system',content:'Evalúa solo seguridad factual. Devuelve JSON {allow,category,rationale}.'},
    {role:'user',content:JSON.stringify({client_message:'¿Cuánto cuesta el tratamiento demo?',proposed_reply:String(main.json.reply||''),approved_public_knowledge:cards})}
  ],{maxTokens:80,reasoningEffort:'low',timeoutMs:4000,geminiTimeoutMs:6000,jsonSchema:schema.safety});
  const safetyMs=Date.now()-safetyStarted,totalMs=Date.now()-started;
  if(!safety||!safety.json||safety.json.allow!==true)throw new Error('BENCH_SAFETY_BLOCKED');
  return {round,main_ms:mainMs,safety_ms:safetyMs,total_ms:totalMs,main_provider:main.provider||'unknown',safety_provider:safety.provider||'unknown',fallback_used:main.fallback_used===true||safety.fallback_used===true};
}

async function runBootBenchmark(options){
  const opts=options||{};
  if(!opts.force&&String(process.env.AOS_WA4_FASTPATH_BENCHMARK_ON_BOOT||'')!=='1')return {skipped:true,version:VERSION};
  const [groq,gemini]=await Promise.all([loadGroqSecret(),resilience.loadGeminiSecret()]);
  if(!groq&&!gemini){console.error('[WA4-FASTPATH-BENCH] providers-unavailable');return {ok:false,error:'BENCH_PROVIDER_UNAVAILABLE',version:VERSION};}
  const rounds=Math.max(1,Math.min(Number(opts.rounds||ROUNDS),12)),results=[],failures=[];
  for(let i=1;i<=rounds;i++){
    try{
      const r=await oneRound({groq,gemini},i);results.push(r);
      console.log('[WA4-FASTPATH-BENCH] round',{round:i,ok:true,main_ms:r.main_ms,safety_ms:r.safety_ms,total_ms:r.total_ms,main_provider:r.main_provider,safety_provider:r.safety_provider,fallback_used:r.fallback_used});
    }catch(e){
      failures.push({round:i,error:String(e&&e.message||'BENCH_ERROR').slice(0,80)});
      console.error('[WA4-FASTPATH-BENCH] round',{round:i,ok:false,error:String(e&&e.message||'BENCH_ERROR').slice(0,80)});
    }
  }
  const main=results.map(x=>x.main_ms),safety=results.map(x=>x.safety_ms),total=results.map(x=>x.total_ms);
  const summary={version:VERSION,ok:results.length===rounds,samples:rounds,valid:results.length,failed:failures.length,fallback_count:results.filter(x=>x.fallback_used).length,main_p50_ms:percentile(main,.50),main_p95_ms:percentile(main,.95),safety_p50_ms:percentile(safety,.50),safety_p95_ms:percentile(safety,.95),total_p50_ms:percentile(total,.50),total_p95_ms:percentile(total,.95)};
  console.log('[WA4-FASTPATH-BENCH] summary',summary);
  return Object.assign(summary,{results,failures});
}

if(String(process.env.AOS_WA4_FASTPATH_BENCHMARK_ON_BOOT||'')==='1')setImmediate(()=>runBootBenchmark().catch(e=>console.error('[WA4-FASTPATH-BENCH] unexpected',{error:String(e&&e.message||'BENCH_ERROR').slice(0,80)})));

module.exports={VERSION,ROUNDS,percentile,syntheticKnowledge,oneRound,runBootBenchmark};
