'use strict'

const VERSION='CONV-L4-TOOL-GATEWAY-V1'
const TOOL_NAMES=Object.freeze([
  'get_customer_context',
  'get_prices',
  'get_promotions',
  'get_locations_payment_methods',
  'get_availability',
  'prepare_booking',
  'confirm_booking',
  'get_media',
  'handoff',
  'create_hot_lead_signal'
])

function text(v){return String(v==null?'':v).trim()}
function safeObject(v){
  if(!v||typeof v!=='object'||Array.isArray(v))return {}
  try{
    const raw=JSON.stringify(v)
    return raw.length<=16000?JSON.parse(raw):{}
  }catch(_){return {}}
}

function createToolGateway(options){
  options=options||{}
  const handlers=options.handlers||{}
  const allowed=new Set(TOOL_NAMES)
  async function execute(name,input,ctx){
    name=text(name)
    if(!allowed.has(name))return {ok:false,tool:name,error:'TOOL_NOT_ALLOWED',latency_ms:0}
    const handler=handlers[name]
    if(typeof handler!=='function')return {ok:false,tool:name,error:'TOOL_HANDLER_UNAVAILABLE',latency_ms:0}
    const started=Date.now()
    try{
      const data=await handler(safeObject(input),safeObject(ctx))
      return {ok:true,tool:name,latency_ms:Date.now()-started,data:safeObject(data)}
    }catch(e){
      return {ok:false,tool:name,latency_ms:Date.now()-started,error:text(e&&e.code||e&&e.message||'TOOL_FAILED').slice(0,120)}
    }
  }
  return {version:VERSION,toolNames:()=>TOOL_NAMES.slice(),execute}
}

module.exports={VERSION,TOOL_NAMES,createToolGateway}
