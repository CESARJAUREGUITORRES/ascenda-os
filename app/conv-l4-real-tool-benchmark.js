'use strict'

const https=require('https')
const {createToolGateway}=require('./conversation-tool-gateway')
const {createBusinessToolHandlers,searchKnowledge}=require('./conversation-business-tools')

const VERSION='CONV-L4-REAL-TOOL-BENCH-V1'

function parse(raw){try{return raw?JSON.parse(raw):null}catch(_){return null}}

function createSupabaseAdapters(){
  const base=String(process.env.SUPABASE_URL||'').replace(/\/$/,'')
  const key=String(process.env.SUPABASE_SERVICE_ROLE_KEY||'')
  if(!base||!key)throw new Error('SUPABASE_SERVICE_ROLE_NOT_CONFIGURED')
  const u=new URL(base)

  function request(method,path,body){
    return new Promise((resolve,reject)=>{
      const payload=body==null?'':JSON.stringify(body)
      const headers={
        apikey:key,
        Authorization:'Bearer '+key,
        Accept:'application/json',
        'Content-Type':'application/json',
        'User-Agent':'AscendaOS-CONV-L4-Benchmark/1.0'
      }
      if(payload)headers['Content-Length']=Buffer.byteLength(payload)
      const req=https.request({
        hostname:u.hostname,port:u.port||443,path,method,headers,timeout:4000
      },res=>{
        let raw=''
        res.on('data',c=>raw+=c)
        res.on('end',()=>{
          if((res.statusCode||500)<200||(res.statusCode||500)>=300){
            const e=new Error('SUPABASE_REQUEST_FAILED_'+String(res.statusCode||0))
            e.upstreamStatus=res.statusCode
            return reject(e)
          }
          resolve(parse(raw))
        })
      })
      req.on('timeout',()=>req.destroy(new Error('SUPABASE_REQUEST_TIMEOUT')))
      req.on('error',reject)
      if(payload)req.write(payload)
      req.end()
    })
  }

  return {
    rest:path=>request('GET',path),
    rpc:(name,payload)=>request('POST','/rest/v1/rpc/'+encodeURIComponent(name),payload||{})
  }
}

function tomorrowLima(){
  const d=new Date(Date.now()+24*60*60*1000)
  try{return new Intl.DateTimeFormat('en-CA',{timeZone:'America/Lima',year:'numeric',month:'2-digit',day:'2-digit'}).format(d)}
  catch(_){return d.toISOString().slice(0,10)}
}

async function runBootBenchmark(){
  if(String(process.env.AOS_CONV_L4_REAL_TOOL_BENCHMARK_ON_BOOT||'')!=='1')return {skipped:true,version:VERSION}
  const adapters=createSupabaseAdapters()
  const handlers=createBusinessToolHandlers(adapters)
  const gateway=createToolGateway({handlers})
  const started=Date.now()

  const sampleRows=await adapters.rest('/rest/v1/aos_wa4_price_authority_v1?select=entity_id,entity_type,entity_name,quote_price,moneda&entity_type=eq.SERVICIO&ready_for_quote=eq.true&order=entity_name&limit=1')
  const sample=Array.isArray(sampleRows)&&sampleRows[0]?sampleRows[0]:null
  if(!sample)throw new Error('NO_QUOTABLE_SERVICE_SAMPLE')
  const query=String(sample.entity_name||'').split(/\s+/).slice(0,2).join(' ')

  const cases=[]
  cases.push(await gateway.execute('get_prices',{query}))
  cases.push(await gateway.execute('get_promotions',{query}))
  cases.push(await gateway.execute('get_locations_payment_methods',{}))
  cases.push(await gateway.execute('get_customer_context',{phone:'000000000'}))
  cases.push(await gateway.execute('get_availability',{
    treatment_id:String(sample.entity_id),
    date:tomorrowLima(),
    site:'SAN ISIDRO'
  }))
  cases.push(await gateway.execute('get_media',{query}))

  const knowledgeStarted=Date.now()
  let knowledge
  try{
    knowledge=await searchKnowledge(adapters.rpc,query)
    knowledge={ok:true,tool:'bounded_knowledge',latency_ms:Date.now()-knowledgeStarted,data:knowledge}
  }catch(e){
    knowledge={ok:false,tool:'bounded_knowledge',latency_ms:Date.now()-knowledgeStarted,error:String(e&&e.message||'KNOWLEDGE_FAILED').slice(0,120)}
  }
  cases.push(knowledge)

  const payment=cases.find(x=>x.tool==='get_locations_payment_methods')
  const serialized=JSON.stringify(payment&&payment.data||{})
  const noSensitivePaymentFields=!/(numero_cuenta|cci|titular|SECRET|account_number)/i.test(serialized)
  const noWrites=cases.every(x=>!['confirm_booking','handoff','create_hot_lead_signal'].includes(x.tool))
  const latencies=cases.map(x=>Number(x.latency_ms||0)).filter(Number.isFinite)
  const maxToolLatency=latencies.length?Math.max(...latencies):0
  const hardFailures=cases.filter(x=>x.ok===false&&x.tool!=='bounded_knowledge')
  const summary={
    version:VERSION,
    ok:hardFailures.length===0&&noSensitivePaymentFields&&noWrites,
    total_cases:cases.length,
    hard_failures:hardFailures.length,
    no_sensitive_payment_fields:noSensitivePaymentFields,
    no_write_tools_executed:noWrites,
    max_tool_latency_ms:maxToolLatency,
    total_latency_ms:Date.now()-started,
    sample_service:String(sample.entity_name||''),
    sample_currency:String(sample.moneda||''),
    provider_send_eligible:false
  }
  console.log('[CONV-L4-REAL-TOOL-BENCH] cases',cases.map(x=>({tool:x.tool,ok:x.ok,latency_ms:x.latency_ms,error:x.error||null})))
  console.log('[CONV-L4-REAL-TOOL-BENCH] summary',summary)
  return Object.assign(summary,{cases})
}

module.exports={VERSION,runBootBenchmark}
