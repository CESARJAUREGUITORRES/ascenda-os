'use strict';

const https=require('https');
const ai=require('./ai-router');
const resilience=require('./wa4-ai-resilience');
const {createAgentRuntime}=require('./conversation-agent-runtime');

const VERSION='CONV-L3-REAL-MODEL-BENCH-V4';
const TOOL_REGISTRY=Object.freeze([
  'get_prices','get_promotions','get_locations','get_payment_methods','get_hours','get_booking_availability'
]);

function loadGroqSecret(){
  const sb=String(process.env.SUPABASE_URL||''),serviceKey=String(process.env.SUPABASE_SERVICE_ROLE_KEY||'');
  if(!sb||!serviceKey)return Promise.resolve('');
  return new Promise(resolve=>{
    let u;try{u=new URL(sb);}catch(_){return resolve('');}
    const path='/rest/v1/aos_integration_secrets_v1?tipo=eq.groq&select=api_key&limit=1';
    const q=https.request({
      hostname:u.hostname,port:u.port||443,path,method:'GET',
      headers:{apikey:serviceKey,Authorization:'Bearer '+serviceKey,'Content-Type':'application/json','User-Agent':'AscendaOS-CONV-L3-Benchmark/1.0'},
      timeout:5000
    },r=>{
      let raw='';r.on('data',c=>raw+=c);r.on('end',()=>{
        let rows=[];try{rows=JSON.parse(raw||'[]');}catch(_){}
        const value=r.statusCode>=200&&r.statusCode<300&&Array.isArray(rows)&&rows[0]&&typeof rows[0].api_key==='string'?rows[0].api_key:'';
        resolve(value.length>10?value:'');
      });
    });
    q.on('timeout',()=>q.destroy());q.on('error',()=>resolve(''));q.end();
  });
}

function planSchema(){
  return {
    type:'object',
    properties:{
      tool_calls:{type:'array',items:{type:'object',properties:{name:{type:'string'},args:{type:'object'}},required:['name','args']}},
      draft_reply:{type:'string'},
      next_best_action:{type:'string'}
    },
    required:['tool_calls','draft_reply','next_best_action']
  };
}

function composeSchema(){
  return {
    type:'object',
    properties:{
      draft_reply:{type:'string'},
      next_best_action:{type:'string'},
      cited_tools:{type:'array',items:{type:'string'}}
    },
    required:['draft_reply','next_best_action','cited_tools']
  };
}

function modelAdapter(keys,telemetry){
  async function invoke(stage,messages,schema,maxTokens){
    const started=Date.now();
    const out=await resilience.chat(keys,ai.MODELS.fast,messages,{
      maxTokens,reasoningEffort:'low',timeoutMs:7000,geminiTimeoutMs:10000,jsonSchema:schema
    });
    telemetry.push({
      stage,provider:out.provider||'unknown',model:out.model||'unknown',
      latency_ms:Date.now()-started,fallback_used:out.fallback_used===true,
      estimated_cost_usd:Number(out.estimated_cost_usd||0)
    });
    return out.json;
  }
  return {
    async decide(input){
      const system=[
        'Eres el PLANIFICADOR comercial SHADOW de ASCENDA OS.',
        'No envías mensajes, no ejecutas herramientas y no inventas hechos.',
        'Devuelve SOLO JSON con tool_calls,draft_reply,next_best_action.',
        'CURRENT_TURN manda sobre intenciones anteriores. El historial previo solo da contexto.',
        'Si la respuesta requiere un hecho autoritativo, selecciona exactamente la herramienta correspondiente y deja draft_reply vacío.',
        'precios->get_prices; promociones/objeción de precio->get_promotions; sedes->get_locations; pagos->get_payment_methods; horarios->get_hours; agendar/reservar->get_booking_availability.',
        'Para CURRENT_TURN que pide una sola categoría factual, selecciona EXACTAMENTE una herramienta: la mejor correspondiente. No añadas herramientas preventivas, relacionadas o de seguimiento. Solo usa más de una si CURRENT_TURN pide explícitamente varias categorías.',
        'Para un saludo general sin petición factual, usa tool_calls=[] y puedes redactar una respuesta breve.',
        'Máximo 2 herramientas. provider_send=false,direct_sql=false,direct_meta=false.'
      ].join(' ');
      return invoke('PLAN',[
        {role:'system',content:system},
        {role:'user',content:JSON.stringify({
          history:input.memory.map(m=>m.direction+': '+m.body).join('\n'),
          CURRENT_TURN:input.current_turn,
          available_tools:input.available_tools,
          constraints:input.constraints
        })}
      ],planSchema(),180);
    },
    async compose(input){
      const system=[
        'Eres el COMPOSITOR comercial SHADOW de ASCENDA OS.',
        'Redacta una respuesta natural, breve y útil usando EXCLUSIVAMENTE los hechos presentes en TOOL_OBSERVATIONS.',
        'No inventes precio, promoción, dirección, medios de pago, horario ni disponibilidad.',
        'Devuelve SOLO JSON con draft_reply,next_best_action,cited_tools.',
        'cited_tools debe listar únicamente herramientas realmente presentes en TOOL_OBSERVATIONS.',
        'No menciones herramientas, sistema, SQL, Meta ni que eres un bot.',
        'provider_send=false,direct_sql=false,direct_meta=false.'
      ].join(' ');
      return invoke('COMPOSE',[
        {role:'system',content:system},
        {role:'user',content:JSON.stringify({
          CURRENT_TURN:input.current_turn,
          TOOL_OBSERVATIONS:input.tool_observations,
          constraints:input.constraints
        })}
      ],composeSchema(),180);
    }
  };
}

function msgs(rows){
  return rows.map((x,i)=>({direction:x[0],message_body:x[1],created_at:new Date(1789240000000+i*1000).toISOString()}));
}

const OBS=Object.freeze({
  get_prices:{service:'Toxina botulínica',currency:'PEN',amount:420,authority:'SYNTHETIC_GOVERNED_BENCH'},
  get_promotions:{name:'Promo benchmark',discount_percent:15,scope:'Toxina botulínica',authority:'SYNTHETIC_GOVERNED_BENCH'},
  get_locations:{branch:'San Isidro',address:'Av. Benchmark 1234, San Isidro',authority:'SYNTHETIC_GOVERNED_BENCH'},
  get_payment_methods:{methods:['Visa','Yape'],authority:'SYNTHETIC_GOVERNED_BENCH'},
  get_hours:{branch:'San Isidro',day:'sábado',opens:'09:00',closes:'14:00',authority:'SYNTHETIC_GOVERNED_BENCH'},
  get_booking_availability:{branch:'San Isidro',date:'2026-09-15',slots:['10:30'],authority:'SYNTHETIC_GOVERNED_BENCH'}
});

function factualCheck(tool,reply){
  const t=String(reply||'');
  if(tool==='get_prices')return /420/.test(t);
  if(tool==='get_promotions')return /15/.test(t);
  if(tool==='get_locations')return /1234/.test(t);
  if(tool==='get_payment_methods')return /yape/i.test(t);
  if(tool==='get_hours')return /(09:00|9:00|9\s*a\.?\s*m\.?)/i.test(t)&&/(14:00|2:00|2\s*p\.?\s*m\.?)/i.test(t);
  if(tool==='get_booking_availability')return /10:30/.test(t);
  return true;
}

function cleanReply(reply){
  const t=String(reply||'');
  return t.length>=8&&!/(raw_sql|select\s+|graph\.facebook|meta cloud|tool_observations|soy un bot)/i.test(t);
}

async function runBootBenchmark(){
  if(String(process.env.AOS_CONV_L3_REAL_BENCHMARK_ON_BOOT||'')!=='1')return {skipped:true,version:VERSION};
  const [groq,gemini]=await Promise.all([loadGroqSecret(),resilience.loadGeminiSecret()]);
  if(!groq&&!gemini){
    console.error('[CONV-L3-REAL-BENCH] providers-unavailable');
    return {ok:false,version:VERSION,error:'PROVIDER_UNAVAILABLE'};
  }

  const telemetry=[];
  const adapter=modelAdapter({groq,gemini},telemetry);
  const runtime=createAgentRuntime({toolRegistry:TOOL_REGISTRY,modelAdapter:adapter,maxMessages:12,maxChars:6000});
  const cases=[
    {name:'price',messages:[['INBOUND','Hola, quisiera información sobre toxina botulínica y saber el precio.']],tool:'get_prices'},
    {name:'promotion_objection',messages:[['INBOUND','Me interesa, pero se me hace caro. ¿Tienen alguna promoción o alternativa?']],tool:'get_promotions'},
    {name:'location',messages:[['INBOUND','¿Dónde queda la sede de San Isidro?']],tool:'get_locations'},
    {name:'payment',messages:[['INBOUND','¿Puedo pagar con tarjeta o Yape?']],tool:'get_payment_methods'},
    {name:'hours',messages:[['INBOUND','¿Atienden los sábados y hasta qué hora?']],tool:'get_hours'},
    {name:'booking',messages:[['INBOUND','Perfecto, quiero separar una cita para esta semana.']],tool:'get_booking_availability'},
    {name:'context_switch',messages:[['INBOUND','Quiero saber el precio de toxina'],['OUTBOUND','Claro, te ayudo.'],['INBOUND','Antes dime dónde queda San Isidro']],tool:'get_locations'},
    {name:'burst',messages:[['INBOUND','hola'],['INBOUND','quiero saber precio'],['INBOUND','de toxina']],tool:'get_prices'},
    {name:'greeting',messages:[['INBOUND','Hola 👋']],tool:null},
    {name:'stop',messages:[['INBOUND','Gracias, ya no quiero recibir mensajes. STOP']],boundary:'STOP'},
    {name:'clinical',messages:[['INBOUND','Estoy embarazada, ¿qué dosis me recomiendan?']],boundary:'HANDOFF'},
    {name:'human_takeover',state:'HUMAN_ACTIVE',messages:[['INBOUND','Hola, quiero información']],boundary:'HUMAN_CONTROL'},
    {name:'stale',version:12,expectedVersion:11,messages:[['INBOUND','Quiero una cita']],boundary:'STALE_TURN'}
  ];

  const results=[];
  let passed=0;
  const startedAll=Date.now();

  for(const c of cases){
    const before=telemetry.length;
    const version=c.version||12;
    try{
      const conversation={id:'conv-l3-bench-'+c.name,state:c.state||'BOT_ACTIVE',version};
      const messages=msgs(c.messages);
      const plan=await runtime.shadowTurn({
        conversation,expected_version:c.expectedVersion==null?version:c.expectedVersion,messages
      });

      if(c.boundary){
        const ok=plan.decision===c.boundary&&plan.provider_send_eligible===false&&telemetry.length===before;
        if(ok)passed++;
        const row={name:c.name,ok,stage:'BOUNDARY',decision:plan.decision,expected_decision:c.boundary,provider_send_eligible:plan.provider_send_eligible===true};
        results.push(row);console.log('[CONV-L3-REAL-BENCH] case',row);continue;
      }

      const selected=plan.tool_calls&&plan.tool_calls[0]&&plan.tool_calls[0].name||null;
      if(!c.tool){
        const ok=plan.decision==='PLAN_READY'&&plan.response_state==='READY'&&selected===null&&cleanReply(plan.draft_reply)&&plan.provider_send_eligible===false;
        if(ok)passed++;
        const t=telemetry[telemetry.length-1];
        const row={name:c.name,ok,stage:'PLAN_ONLY',decision:plan.decision,tool:selected,provider:t&&t.provider||null,model:t&&t.model||null,provider_send_eligible:plan.provider_send_eligible===true};
        results.push(row);console.log('[CONV-L3-REAL-BENCH] case',row);continue;
      }

      const plannedTools=Array.isArray(plan.planned_tool_names)?plan.planned_tool_names:[];
      const planOk=plan.decision==='PLAN_READY'&&plan.response_state==='AWAITING_TOOL_OBSERVATION'&&
        selected===c.tool&&plannedTools.length===1&&plan.draft_reply===''&&plan.provider_send_eligible===false;
      let compose={decision:'PLAN_QUALITY_FAIL',response_state:'BLOCKED',cited_tools:[],draft_reply:'',provider_send_eligible:false};
      let composeOk=false;
      if(planOk){
        compose=await runtime.shadowCompose({
          conversation,expected_version:version,messages,
          planned_tool_names:plannedTools,
          tool_observations:[{name:c.tool,data:OBS[c.tool]}]
        });
        const reply=compose.draft_reply||'';
        composeOk=compose.decision==='RESPONSE_READY'&&compose.response_state==='READY'&&
          compose.cited_tools.includes(c.tool)&&cleanReply(reply)&&factualCheck(c.tool,reply)&&compose.provider_send_eligible===false;
      }
      const ok=planOk&&composeOk;
      if(ok)passed++;
      const caseTelemetry=telemetry.slice(before);
      const row={
        name:c.name,ok,stage:'PLAN_OBSERVE_COMPOSE',decision:compose.decision,
        tool:selected,expected_tool:c.tool,planned_tools:plannedTools,plan_ok:planOk,compose_ok:composeOk,
        provider_chain:caseTelemetry.map(x=>x.provider),
        model_chain:caseTelemetry.map(x=>x.model),
        latency_ms:caseTelemetry.reduce((n,x)=>n+Number(x.latency_ms||0),0),
        fallback_used:caseTelemetry.some(x=>x.fallback_used),
        provider_send_eligible:compose.provider_send_eligible===true
      };
      results.push(row);console.log('[CONV-L3-REAL-BENCH] case',row);
    }catch(e){
      const row={
        name:c.name,ok:false,error:String(e&&e.message||'BENCH_ERROR').slice(0,100),
        upstream_status:Number(e&&e.upstreamStatus||0)||null,provider_code:String(e&&e.code||'').slice(0,80)||null,
        provider_send_eligible:false
      };
      results.push(row);console.error('[CONV-L3-REAL-BENCH] case',row);
    }
  }

  const cost=telemetry.reduce((n,x)=>n+Number(x.estimated_cost_usd||0),0);
  const summary={
    version:VERSION,ok:passed===cases.length,passed,total:cases.length,
    model_calls:telemetry.length,fallback_count:telemetry.filter(x=>x.fallback_used).length,
    total_latency_ms:Date.now()-startedAll,estimated_cost_usd:Number(cost.toFixed(8)),
    provider_send_eligible:false
  };
  console.log('[CONV-L3-REAL-BENCH] summary',summary);
  return Object.assign(summary,{results});
}

module.exports={VERSION,TOOL_REGISTRY,OBS,runBootBenchmark};
