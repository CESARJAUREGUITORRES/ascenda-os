'use strict'

const crypto=require('crypto')
const https=require('https')

const DEFAULT_SB_URL='https://ituyqwstonmhnfshnaqz.supabase.co'
const MAX_BODY_BYTES=1024*1024
const UPSTREAM_TIMEOUT_MS=15000
const AUTH_TTL_MS=60000
const STALE_MAX_MS=10*60*1000

const SPECS={
  aos_marketing_dashboard:{keys:['p_mes','p_anio'],ttl:8000},
  aos_marketing_dashboard_anio:{keys:['p_anio'],ttl:15000},
  aos_marketing_period_summary_v2:{keys:['p_fecha_desde','p_fecha_hasta'],ttl:20000},
  aos_marketing_attribution_public_v3:{keys:['p_mes','p_anio'],ttl:30000},
  aos_marketing_attribution_public_v2_anio:{keys:['p_anio'],ttl:60000},
  aos_marketing_intent_public_v2:{keys:['p_mes','p_anio'],ttl:30000},
  aos_marketing_intent_detail_public_v3:{keys:['p_mes','p_anio'],ttl:30000},
  aos_marketing_historico_public_v2:{keys:['p_anio'],ttl:5*60*1000},
  aos_marketing_ltv_public_v2:{keys:['p_anio'],ttl:5*60*1000},
  aos_marketing_value_map_public_v43:{keys:['p_anio','p_mes'],ttl:5*60*1000},
  aos_marketing_lineage_admin_v43:{keys:['p_anio','p_mes'],ttl:30000,token:true}
}

function sha256(value){return crypto.createHash('sha256').update(String(value||'')).digest('hex')}
function serviceRoleKey(){return String(process.env.SUPABASE_SERVICE_ROLE_KEY||process.env.service_role||'').trim()}
function supabaseUrl(){return String(process.env.SUPABASE_URL||DEFAULT_SB_URL).replace(/\/$/,'')}
function stableObject(input,keys){
  const src=input&&typeof input==='object'&&!Array.isArray(input)?input:{}
  const out={}
  keys.forEach(function(k){if(Object.prototype.hasOwnProperty.call(src,k))out[k]=src[k]})
  return out
}
function requestJson(urlString,body,timeoutMs){
  return new Promise(function(resolve,reject){
    const url=new URL(urlString)
    const key=serviceRoleKey()
    if(key.length<20){reject(Object.assign(new Error('SERVICE_ROLE_NOT_CONFIGURED'),{status:503}));return}
    const data=Buffer.from(JSON.stringify(body||{}))
    const headers={
      apikey:key,
      'Content-Type':'application/json',
      'Content-Length':data.length,
      'User-Agent':'AscendaOS-MarketingReadGateway/1.0'
    }
    if(!/^sb_(?:secret|publishable)_/i.test(key))headers.Authorization='Bearer '+key
    const req=https.request({
      hostname:url.hostname,
      port:url.port||443,
      path:url.pathname+url.search,
      method:'POST',
      headers:headers,
      timeout:timeoutMs||UPSTREAM_TIMEOUT_MS
    },function(res){
      let raw='',overflow=false
      res.on('data',function(chunk){
        if(overflow)return
        raw+=chunk
        if(Buffer.byteLength(raw)>MAX_BODY_BYTES)overflow=true
      })
      res.on('end',function(){
        if(overflow){reject(Object.assign(new Error('UPSTREAM_PAYLOAD_TOO_LARGE'),{status:502}));return}
        let parsed=null
        try{parsed=raw?JSON.parse(raw):null}catch(_){parsed=null}
        resolve({status:res.statusCode||502,body:parsed,raw:raw})
      })
    })
    req.on('timeout',function(){req.destroy(Object.assign(new Error('UPSTREAM_TIMEOUT'),{status:504}))})
    req.on('error',reject)
    req.write(data);req.end()
  })
}
function rpc(name,payload){
  return requestJson(supabaseUrl()+'/rest/v1/rpc/'+encodeURIComponent(name),payload||{},UPSTREAM_TIMEOUT_MS)
}
function isSuccess(out){return !!(out&&out.status>=200&&out.status<300&&out.body!==null)}
function retryable(out){
  if(!out)return true
  if(out.status>=500)return true
  const raw=String(out.raw||'')
  return /57014|statement timeout|timeout manager/i.test(raw)
}

function createMarketingReadGateway(config){
  config=config||{}
  const requester=config.rpc||rpc
  const now=config.now||Date.now
  const cache=new Map()
  const inflight=new Map()
  const authCache=new Map()
  const authInflight=new Map()
  let tail=Promise.resolve()

  async function verifyAdmin(token){
    token=String(token||'').trim()
    if(token.length<32)return {ok:false,status:401,error:'ADMIN_SESSION_REQUIRED'}
    const key=sha256(token)
    const hit=authCache.get(key)
    if(hit&&now()-hit.ts<AUTH_TTL_MS)return hit.actor
    if(authInflight.has(key))return authInflight.get(key)

    const pending=(async function(){
      let out
      try{out=await requester('aos_cia_verify_admin_session_v1',{p_token:token})}
      catch(e){return {ok:false,status:e&&e.status||503,error:e&&e.message||'AUTH_UPSTREAM_UNAVAILABLE'}}
      const body=out&&out.body
      if(!out||out.status>=300||!body||body.ok!==true||!body.user_id)return {ok:false,status:401,error:'ADMIN_SESSION_REQUIRED'}
      const actor={ok:true,status:200,user_id:String(body.user_id),usuario:String(body.usuario||'')}
      authCache.set(key,{ts:now(),actor:actor})
      if(authCache.size>64){const first=authCache.keys().next();if(!first.done)authCache.delete(first.value)}
      return actor
    })().finally(function(){authInflight.delete(key)})

    authInflight.set(key,pending)
    return pending
  }

  function cacheKey(name,payload,actor){
    const ordered={}
    Object.keys(payload||{}).sort().forEach(function(k){if(k!=='p_token')ordered[k]=payload[k]})
    return name+'|'+actor.user_id+'|'+JSON.stringify(ordered)
  }

  function runSerialized(fn){
    const queued=tail.catch(function(){}).then(fn)
    tail=queued.then(function(){},function(){})
    return queued
  }

  async function execute(input){
    input=input||{}
    const name=String(input.name||'').trim()
    const spec=SPECS[name]
    if(!spec)return {status:403,body:{ok:false,error:'MARKETING_RPC_NOT_ALLOWED'},cache:'BYPASS'}

    const actor=await verifyAdmin(input.token)
    if(!actor.ok)return {status:actor.status||401,body:{ok:false,error:actor.error||'ADMIN_SESSION_REQUIRED'},cache:'BYPASS'}

    const payload=stableObject(input.payload,spec.keys)
    if(spec.token)payload.p_token=String(input.token||'')
    const key=cacheKey(name,payload,actor)
    const t=now()
    const hit=cache.get(key)
    if(hit&&t-hit.ts<spec.ttl)return {status:200,body:hit.body,cache:'HIT'}
    if(inflight.has(key))return inflight.get(key)

    const work=runSerialized(async function(){
      const fresh=cache.get(key)
      if(fresh&&now()-fresh.ts<spec.ttl)return {status:200,body:fresh.body,cache:'HIT'}
      let out=null,error=null
      try{out=await requester(name,payload)}catch(e){error=e}
      if(isSuccess(out)){
        cache.set(key,{ts:now(),body:out.body})
        if(cache.size>128){const first=cache.keys().next();if(!first.done)cache.delete(first.value)}
        return {status:200,body:out.body,cache:'MISS'}
      }
      const stale=cache.get(key)
      if(stale&&now()-stale.ts<STALE_MAX_MS&&(error||retryable(out))){
        return {status:200,body:stale.body,cache:'STALE'}
      }
      if(error)return {status:error.status||502,body:{ok:false,error:error.message||'MARKETING_UPSTREAM_UNAVAILABLE'},cache:'MISS'}
      return {
        status:out&&out.status||502,
        body:out&&out.body!==null?out.body:{ok:false,error:'MARKETING_UPSTREAM_INVALID_JSON'},
        cache:'MISS'
      }
    }).finally(function(){inflight.delete(key)})

    inflight.set(key,work)
    return work
  }

  return {
    execute:execute,
    allowedNames:function(){return Object.keys(SPECS)},
    cacheSize:function(){return cache.size},
    clear:function(){cache.clear();inflight.clear();authCache.clear();authInflight.clear()}
  }
}

module.exports={createMarketingReadGateway,SPECS}
