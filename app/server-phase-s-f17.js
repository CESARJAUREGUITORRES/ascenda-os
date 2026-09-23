'use strict'
// ASCENDA S15.2 — production bootstrap that preserves Phase S intact while
// inserting the certified F17 boundary before F5.
// REV-PRC1 hotfix: also installs a narrow same-origin Auth V3/2FA bridge for
// governed Product Resolution Center RPCs before the production HTTP server starts.
// CALLCENTER P0: expose a separate allowlisted same-origin boundary that reads
// the HttpOnly Auth V3 session cookie server-side, so mobile/PWA writes do not
// depend on a stale JavaScript token cache.
const childProcess=require('child_process')
const http=require('http')
const https=require('https')
const originalSpawn=childProcess.spawn
const originalCreateServer=http.createServer

const PRC1_ALLOWED=new Set([
  'aos_product_review_admin_v1',
  'aos_product_review_admin_v2',
  'aos_product_review_resolve_v2',
  'aos_product_review_reopen_v1',
  'aos_product_batch_review_v1'
])

const CALLCENTER_ALLOWED=new Set([
  'aos_callcenter_prepare_action_v1',
  'aos_callcenter_commit_action_v1',
  'aos_callcenter_confirm_queue_appointment_v1'
])

function rewriteChildArgs(command,args){
  const a=Array.isArray(args)?args.slice():args
  if(command===process.execPath&&Array.isArray(a)&&a[0]==='server-f5.js'){
    a[0]='server-f17.js'
  }
  return a
}

function installF17Boundary(){
  if(childProcess.spawn&&childProcess.spawn.__aosS152)return
  function aosSpawn(command,args,options){
    const rewritten=rewriteChildArgs(command,args)
    if(Array.isArray(args)&&Array.isArray(rewritten)&&args[0]==='server-f5.js'&&rewritten[0]==='server-f17.js'){
      console.log('[S15.2] Phase S child upgraded: server-f17.js -> server-f5.js chain')
    }
    return originalSpawn.call(childProcess,command,rewritten,options)
  }
  aosSpawn.__aosS152=true
  childProcess.spawn=aosSpawn
}

function writeBridgeJson(res,status,obj,bridge){
  if(res.headersSent)return
  res.writeHead(status,{
    'Content-Type':'application/json; charset=utf-8',
    'Cache-Control':'no-store',
    'X-Content-Type-Options':'nosniff',
    'X-Ascenda-Bridge':bridge||'server-v1'
  })
  res.end(JSON.stringify(obj))
}
function writePrc1Json(res,status,obj){writeBridgeJson(res,status,obj,'prc1-server-v1')}
function writeCallCenterJson(res,status,obj){writeBridgeJson(res,status,obj,'callcenter-cookie-v1')}

function readBridgeJson(req,maxBytes){
  maxBytes=maxBytes||262144
  return new Promise(function(resolve,reject){
    let raw='',overflow=false
    req.on('data',function(c){
      if(overflow)return
      raw+=c
      if(Buffer.byteLength(raw)>maxBytes)overflow=true
    })
    req.on('end',function(){
      if(overflow){const e=new Error('PAYLOAD_TOO_LARGE');e.status=413;reject(e);return}
      try{resolve(JSON.parse(raw||'{}'))}catch(_){const e=new Error('INVALID_JSON');e.status=400;reject(e)}
    })
    req.on('error',reject)
  })
}

function cookieValue(req,name){
  const raw=String(req&&req.headers&&req.headers.cookie||'')
  const parts=raw.split(';')
  for(let i=0;i<parts.length;i++){
    const part=parts[i],eq=part.indexOf('=')
    if(eq<0)continue
    if(part.slice(0,eq).trim()!==name)continue
    let value=part.slice(eq+1).trim()
    try{value=decodeURIComponent(value)}catch(_){}
    return String(value||'').trim()
  }
  return ''
}

function strongBoundaryToken(req){
  const header=String(req&&req.headers&&req.headers['x-aos-app-token']||'').trim()
  if(header.length>=32)return header
  const cookie=cookieValue(req,'aos_app_session')
  return cookie.length>=32?cookie:''
}

function sameOriginRequest(req){
  const origin=String(req&&req.headers&&req.headers.origin||'').trim()
  if(!origin)return true
  try{
    const u=new URL(origin)
    return u.host===String(req.headers.host||'')
  }catch(_){return false}
}

function prc1DbKey(){
  return String(process.env.SUPABASE_ANON_KEY||process.env.SUPABASE_PUBLISHABLE_KEY||'').trim()
}

function prc1Rpc(name,payload){
  return new Promise(function(resolve,reject){
    const key=prc1DbKey()
    if(!key){reject(Object.assign(new Error('SUPABASE_ANON_KEY_NOT_CONFIGURED'),{status:503}));return}
    let sb
    try{sb=new URL(process.env.SUPABASE_URL||'https://ituyqwstonmhnfshnaqz.supabase.co')}catch(e){reject(e);return}
    const data=JSON.stringify(payload||{})
    const headers={
      apikey:key,
      'Content-Type':'application/json',
      'Content-Length':Buffer.byteLength(data),
      'User-Agent':'AscendaOS-F17-SameOrigin-Bridge/1.0'
    }
    // Legacy anon JWTs are valid Bearer tokens. New publishable keys are API keys,
    // not JWTs, so they must not be forced into Authorization.
    if(!/^sb_publishable_/i.test(key))headers.Authorization='Bearer '+key
    const q=https.request({
      hostname:sb.hostname,
      port:sb.port||443,
      path:'/rest/v1/rpc/'+encodeURIComponent(name),
      method:'POST',headers:headers,timeout:12000
    },function(r){
      let body=''
      r.on('data',function(c){body+=c})
      r.on('end',function(){
        let parsed=null
        try{parsed=body?JSON.parse(body):null}catch(_){}
        resolve({status:r.statusCode||502,data:parsed,raw:body})
      })
    })
    q.on('timeout',function(){q.destroy(Object.assign(new Error('DB_TIMEOUT'),{status:504}))})
    q.on('error',reject)
    q.write(data);q.end()
  })
}

async function handleAllowlistedRpc(req,res,allowed,writeJson,scope){
  if(req.method==='OPTIONS'){
    res.writeHead(204,{
      'Access-Control-Allow-Methods':'POST,OPTIONS',
      'Access-Control-Allow-Headers':'Content-Type,X-AOS-App-Token',
      'Cache-Control':'no-store',
      'X-Ascenda-Bridge':scope+'-server-v1'
    })
    res.end();return
  }
  if(req.method!=='POST'){writeJson(res,405,{ok:false,error:'METHOD_NOT_ALLOWED'});return}
  if(!sameOriginRequest(req)){writeJson(res,403,{ok:false,error:'ORIGIN_NOT_ALLOWED'});return}
  const token=strongBoundaryToken(req)
  if(token.length<32){writeJson(res,401,{ok:false,error:'APP_SESSION_REQUIRED'});return}
  try{
    const body=await readBridgeJson(req)
    const name=String(body&&body.name||'').trim()
    if(!allowed.has(name)){writeJson(res,403,{ok:false,error:'RPC_NOT_ALLOWED'});return}
    const payload=body&&body.payload&&typeof body.payload==='object'&&!Array.isArray(body.payload)?Object.assign({},body.payload):{}
    // Never trust a browser supplied p_token. The boundary binds the RPC to the
    // verified strong session transported in the HttpOnly cookie/header.
    payload.p_token=token
    const out=await prc1Rpc(name,payload)
    if(out.data!==null){writeJson(res,out.status,out.data);return}
    writeJson(res,out.status||502,{ok:false,error:'UPSTREAM_INVALID_JSON'})
  }catch(e){
    console.error('['+scope.toUpperCase()+'-BRIDGE]',e&&e.message||e)
    writeJson(res,e&&e.status||502,{ok:false,error:e&&e.message||'BRIDGE_UNAVAILABLE'})
  }
}

function handlePrc1(req,res){return handleAllowlistedRpc(req,res,PRC1_ALLOWED,writePrc1Json,'prc1')}
function handleCallCenter(req,res){return handleAllowlistedRpc(req,res,CALLCENTER_ALLOWED,writeCallCenterJson,'callcenter')}

function installPrc1HttpBoundary(){
  if(http.createServer&&http.createServer.__aosPrc1)return
  function wrap(listener){
    return function(req,res){
      let pathname=''
      try{pathname=new URL(req.url||'/','http://localhost').pathname}catch(_){}
      if(pathname==='/api/prc1/rpc'){handlePrc1(req,res);return}
      if(pathname==='/api/callcenter/rpc'){handleCallCenter(req,res);return}
      return listener.call(this,req,res)
    }
  }
  function aosCreateServer(options,listener){
    if(typeof options==='function')return originalCreateServer.call(http,wrap(options))
    if(typeof listener==='function')return originalCreateServer.call(http,options,wrap(listener))
    return originalCreateServer.call(http,options)
  }
  aosCreateServer.__aosPrc1=true
  http.createServer=aosCreateServer
}

if(require.main===module){
  installPrc1HttpBoundary()
  installF17Boundary()
  require('./server-phase-s.js')
}

module.exports={rewriteChildArgs,installF17Boundary,installPrc1HttpBoundary,handlePrc1,handleCallCenter,strongBoundaryToken}
