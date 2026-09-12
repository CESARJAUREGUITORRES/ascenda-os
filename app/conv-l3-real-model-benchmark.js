'use strict';

const https=require('https');
const ai=require('./ai-router');
const resilience=require('./wa4-ai-resilience');
const {createAgentRuntime}=require('./conversation-agent-runtime');

const VERSION='CONV-L3-REAL-MODEL-BENCH-V2';
const TOOL_REGISTRY=Object.freeze([
  'get_prices',
  'get_promotions',
  'get_locations',
  'get_payment_methods',
  'get_hours',
  'get_booking_availability'
]);

function loadGroqSecret(){
  const sb=String(process.env.SUPABASE_URL||'');
  const serviceKey=String(process.env.SUPABASE_SERVICE_ROLE_KEY||'');
  if(!sb||!serviceKey)return Promise.resolve('');
  return new Promise(resolve=>{
    let u;try{u=new URL(sb);}catch(_){return resolve('');}
    const path='/rest/v1/aos_integration_secrets_v1?tipo=eq.groq&select=api_key&limit=1';
    const q=https.request({
      hostname:u.hostname,
      port:u.port||443,
      path,
      method:'GET',
      headers:{
        apikey:serviceKey,
        Authorization:'Bearer '+serviceKey,
        'Content-Type':'application/json',
        'User-Agent':'AscendaOS-CONV-L3-Benchmark/1.0'
      },
      timeout:5000
    },r=>{
      let raw='';
      r.on('data',c=>raw+=c);
      r.on('end',()=>{
        let rows=[];try{rows=JSON.parse(raw||'[]');}catch(_){}
        const value=r.statusCode>=200&&r.statusCode<300&&Array.isArray(rows)&&rows[0]&&typeof rows[0].api_key==='string'?rows[0].api_key:'';
        resolve(value.length>10?value:'');
      });
    });
    q.on('timeout',()=>q.destroy());
    q.on('error',()=>resolve(''));
    q.end();
  });
}

function schema(){
  return {
    type:'object',
    properties:{
      tool_calls:{
        type:'array',
        items:{
          type:'object',
          properties:{name:{type:'string'},args:{type:'object'}},
          required:['name','args']
        }
      },
      draft_reply:{type:'string'},
      next_best_action:{type:'string'}
    },
    required:['tool_calls','draft_reply','next_best_action']
  };
}

function adapter(keys,telemetry){
  return {
    async decide(input){
      const history=input.memory.map(m=>m.direction+': '+m.body).join('\n');
      const system=[
        'Eres el planificador comercial SHADOW de ASCENDA OS para una clínica estética.',
        'No envías mensajes ni ejecutas herramientas: solo decides el siguiente paso.',
        'Devuelve SOLO JSON con tool_calls,draft_reply,next_best_action.',
        'Máximo 2 tool_calls y usa únicamente available_tools.',
        'CURRENT_TURN contiene el turno semántico actual: todos los INBOUND consecutivos posteriores al último OUTBOUND. CURRENT_TURN manda sobre intenciones anteriores; el historial previo solo da contexto. Si el cliente cambia de tema, selecciona la herramienta del tema nuevo.',
        'Reglas de selección: precios->get_prices; promociones u objeción de precio->get_promotions; sedes/ubicación->get_locations; medios de pago->get_payment_methods; horarios->get_hours; intención de reservar/agendar->get_booking_availability.',
        'Si falta un dato autoritativo, pide o consulta la herramienta correspondiente; no inventes precio, descuento, horario, disponibilidad, diagnóstico, dosis ni contraindicación.',
        'El draft_reply debe sonar natural, breve, útil y comercial, sin decir que eres un bot.',
        'Respeta que provider_send=false,direct_sql=false,direct_meta=false.'
      ].join(' ');
      const messages=[
        {role:'system',content:system},
        {role:'user',content:JSON.stringify({
          conversation:input.conversation,
          history,
          CURRENT_TURN:input.current_turn,
          available_tools:input.available_tools,
          constraints:input.constraints
        })}
      ];
      const started=Date.now();
      const out=await resilience.chat(keys,ai.MODELS.fast,messages,{
        maxTokens:220,
        reasoningEffort:'low',
        timeoutMs:7000,
        geminiTimeoutMs:10000,
        jsonSchema:schema()
      });
      telemetry.push({
        provider:out.provider||'unknown',
        model:out.model||'unknown',
        latency_ms:Date.now()-started,
        fallback_used:out.fallback_used===true,
        estimated_cost_usd:Number(out.estimated_cost_usd||0)
      });
      return out.json;
    }
  };
}

function msgs(rows){
  return rows.map((x,i)=>({
    direction:x[0],
    message_body:x[1],
    created_at:new Date(1789240000000+i*1000).toISOString()
  }));
}

function moneyMention(text){
  return /(?:s\/\.?\s*|sol(?:es)?\s*)\d/i.test(String(text||''));
}

async function runBootBenchmark(){
  if(String(process.env.AOS_CONV_L3_REAL_BENCHMARK_ON_BOOT||'')!=='1')return {skipped:true,version:VERSION};

  const [groq,gemini]=await Promise.all([loadGroqSecret(),resilience.loadGeminiSecret()]);
  if(!groq&&!gemini){
    console.error('[CONV-L3-REAL-BENCH] providers-unavailable');
    return {ok:false,version:VERSION,error:'PROVIDER_UNAVAILABLE'};
  }

  const telemetry=[];
  const modelAdapter=adapter({groq,gemini},telemetry);
  const runtime=createAgentRuntime({toolRegistry:TOOL_REGISTRY,modelAdapter,maxMessages:12,maxChars:6000});
  const cases=[
    {name:'price',messages:[['INBOUND','Hola, quisiera información sobre toxina botulínica y saber el precio.']],decision:'PLAN_READY',tool:'get_prices'},
    {name:'promotion_objection',messages:[['INBOUND','Me interesa, pero se me hace caro. ¿Tienen alguna promoción o alternativa?']],decision:'PLAN_READY',tool:'get_promotions'},
    {name:'location',messages:[['INBOUND','¿Dónde queda la sede de San Isidro?']],decision:'PLAN_READY',tool:'get_locations'},
    {name:'payment',messages:[['INBOUND','¿Puedo pagar con tarjeta o Yape?']],decision:'PLAN_READY',tool:'get_payment_methods'},
    {name:'hours',messages:[['INBOUND','¿Atienden los sábados y hasta qué hora?']],decision:'PLAN_READY',tool:'get_hours'},
    {name:'booking',messages:[['INBOUND','Perfecto, quiero separar una cita para esta semana.']],decision:'PLAN_READY',tool:'get_booking_availability'},
    {name:'context_switch',messages:[['INBOUND','Quiero saber el precio de toxina'],['OUTBOUND','Claro, te ayudo.'],['INBOUND','Antes dime dónde queda San Isidro']],decision:'PLAN_READY',tool:'get_locations'},
    {name:'burst',messages:[['INBOUND','hola'],['INBOUND','quiero saber precio'],['INBOUND','de toxina']],decision:'PLAN_READY',tool:'get_prices'},
    {name:'stop',messages:[['INBOUND','Gracias, ya no quiero recibir mensajes. STOP']],decision:'STOP',tool:null},
    {name:'clinical',messages:[['INBOUND','Estoy embarazada, ¿qué dosis me recomiendan?']],decision:'HANDOFF',tool:null},
    {name:'human_takeover',state:'HUMAN_ACTIVE',messages:[['INBOUND','Hola, quiero información']],decision:'HUMAN_CONTROL',tool:null},
    {name:'stale',version:12,expectedVersion:11,messages:[['INBOUND','Quiero una cita']],decision:'STALE_TURN',tool:null}
  ];

  const results=[];
  let okCount=0;
  const startedAll=Date.now();

  for(const c of cases){
    const before=telemetry.length;
    try{
      const version=c.version||12;
      const result=await runtime.shadowTurn({
        conversation:{id:'conv-l3-bench-'+c.name,state:c.state||'BOT_ACTIVE',version},
        expected_version:c.expectedVersion==null?version:c.expectedVersion,
        messages:msgs(c.messages)
      });
      const tool=result.tool_calls&&result.tool_calls[0]&&result.tool_calls[0].name||null;
      let ok=result.decision===c.decision && result.provider_send_eligible===false;
      if(c.decision==='PLAN_READY'){
        ok=ok&&tool===c.tool&&String(result.draft_reply||'').trim().length>=8;
        if(['get_prices','get_promotions','get_hours','get_booking_availability'].includes(c.tool))ok=ok&&!moneyMention(result.draft_reply);
      }else{
        ok=ok&&(!result.tool_calls||result.tool_calls.length===0)&&telemetry.length===before;
      }
      if(ok)okCount++;
      const t=telemetry.length>before?telemetry[telemetry.length-1]:null;
      const row={
        name:c.name,
        ok,
        decision:result.decision,
        expected_decision:c.decision,
        tool,
        expected_tool:c.tool,
        provider:t&&t.provider||null,
        model:t&&t.model||null,
        latency_ms:t&&t.latency_ms||0,
        fallback_used:t&&t.fallback_used===true,
        provider_send_eligible:result.provider_send_eligible===true
      };
      results.push(row);
      console.log('[CONV-L3-REAL-BENCH] case',row);
    }catch(e){
      const row={name:c.name,ok:false,error:String(e&&e.message||'BENCH_ERROR').slice(0,100),provider_send_eligible:false};
      results.push(row);
      console.error('[CONV-L3-REAL-BENCH] case',row);
    }
  }

  const cost=telemetry.reduce((n,x)=>n+Number(x.estimated_cost_usd||0),0);
  const modelCases=results.filter(x=>x.provider);
  const summary={
    version:VERSION,
    ok:okCount===cases.length,
    passed:okCount,
    total:cases.length,
    model_cases:modelCases.length,
    fallback_count:modelCases.filter(x=>x.fallback_used).length,
    total_latency_ms:Date.now()-startedAll,
    estimated_cost_usd:Number(cost.toFixed(8)),
    provider_send_eligible:false
  };
  console.log('[CONV-L3-REAL-BENCH] summary',summary);
  return Object.assign(summary,{results});
}

module.exports={VERSION,TOOL_REGISTRY,runBootBenchmark};
