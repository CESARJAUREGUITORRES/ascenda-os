'use strict'

// TEMPORARY WA-4C diagnostic. Exposes only booleans/status codes; never secret values.
const http=require('http')
const https=require('https')
const originalCreateServer=http.createServer

function safeJson(res,status,obj){
  res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'})
  res.end(JSON.stringify(obj))
}

function probe(){
  return new Promise((resolve)=>{
    const rawUrl=String(process.env.SUPABASE_URL||'https://ituyqwstonmhnfshnaqz.supabase.co').trim()
    const key=String(process.env.SUPABASE_SERVICE_ROLE_KEY||process.env.service_role||'').trim()
    let u
    try{u=new URL(rawUrl)}catch(_){return resolve({ok:false,code:'SUPABASE_URL_INVALID',service_key_present:!!key,expected_project:false})}
    const expectedProject=u.hostname==='ituyqwstonmhnfshnaqz.supabase.co'
    if(!key)return resolve({ok:false,code:'SERVICE_KEY_MISSING',service_key_present:false,expected_project:expectedProject})
    const headers={apikey:key,'User-Agent':'AscendaOS-WA4C-Probe/1.0'}
    if(!/^sb_(?:secret|publishable)_/i.test(key))headers.Authorization='Bearer '+key
    const q=https.request({hostname:u.hostname,port:u.port||443,path:'/rest/v1/aos_integration_secrets_v1?tipo=eq.groq&select=api_key,nombre&limit=1',method:'GET',headers,timeout:12000},r=>{
      let raw=''
      r.on('data',c=>raw+=c)
      r.on('end',()=>{
        let rows=null
        try{rows=raw?JSON.parse(raw):null}catch(_){}
        const first=Array.isArray(rows)?rows[0]:null
        resolve({
          ok:(r.statusCode||500)>=200&&(r.statusCode||500)<300,
          code:(r.statusCode||500)>=200&&(r.statusCode||500)<300?'REST_OK':'REST_REJECTED',
          upstream_http:r.statusCode||502,
          service_key_present:true,
          expected_project:expectedProject,
          row_count:Array.isArray(rows)?rows.length:null,
          groq_key_present:!!(first&&typeof first.api_key==='string'&&first.api_key.length>10)
        })
      })
    })
    q.on('timeout',()=>{q.destroy();resolve({ok:false,code:'REST_TIMEOUT',service_key_present:true,expected_project:expectedProject})})
    q.on('error',e=>resolve({ok:false,code:'REST_NETWORK_ERROR',service_key_present:true,expected_project:expectedProject,error_class:String(e&&e.code||'NETWORK').slice(0,40)}))
    q.end()
  })
}

function wrap(listener){
  return function(req,res){
    let pathname=''
    try{pathname=new URL(req.url||'/','http://localhost').pathname}catch(_){}
    if(pathname==='/api/wa4c/vault-probe'&&req.method==='GET'){
      probe().then(out=>safeJson(res,200,out)).catch(()=>safeJson(res,200,{ok:false,code:'PROBE_FAILED'}))
      return
    }
    return listener.call(this,req,res)
  }
}

function patchedCreateServer(options,listener){
  if(typeof options==='function')return originalCreateServer.call(http,wrap(options))
  if(typeof listener==='function')return originalCreateServer.call(http,options,wrap(listener))
  return originalCreateServer.call(http,options)
}
patchedCreateServer.__wa4cVaultProbe=true
http.createServer=patchedCreateServer
