// ASCENDA OS — KronIA K1 security outer boundary (CURRENT chain aware).
// Authority source: aos_app_sessions_v3 / aos_app_actor_v3.
// CURRENT runtime preserved: K1 -> F5 -> WA4 -> WA3 -> WA2 -> F4 -> Phase2/core.
'use strict';

const http = require('http');
const https = require('https');
const crypto = require('crypto');
const { spawn } = require('child_process');

const EXTERNAL_PORT = parseInt(process.env.PORT || '4173',10);
const CURRENT_PORT = parseInt(process.env.K1_INNER_PORT || '4210',10);
const SB_URL = process.env.SUPABASE_URL || 'https://ituyqwstonmhnfshnaqz.supabase.co';
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const EXTRA_ORIGINS = new Set(String(process.env.K1_ALLOWED_ORIGINS||'').split(',').map(s=>s.trim()).filter(Boolean));
if (!SERVICE_KEY) {
  console.error('[K1] SUPABASE_SERVICE_ROLE_KEY is required; refusing insecure startup');
  process.exit(1);
}

let child=null;
const buckets=new Map();
function ipOf(req){return String((req.headers['x-forwarded-for']||'').split(',')[0]||req.socket.remoteAddress||'unknown').trim();}
function rateKey(req,group){return group+':'+ipOf(req);}
function allowedRate(req,group,limit){
  const now=Date.now(),key=rateKey(req,group),old=buckets.get(key);
  if(!old||now-old.start>=60000){buckets.set(key,{start:now,count:1});return true;}
  old.count++; return old.count<=limit;
}
setInterval(()=>{const cut=Date.now()-120000;for(const [k,v] of buckets){if(v.start<cut)buckets.delete(k);}},60000).unref();

function ipOrigin(req){return String(req.headers.origin||'');}
function originAllowed(req){
  const o=ipOrigin(req);
  if(!o)return true;
  if(EXTRA_ORIGINS.has(o))return true;
  if(/^chrome-extension:\/\/[a-z]+$/i.test(o))return true;
  try{const u=new URL(o);return u.host===req.headers.host;}catch(_){return false;}
}
function cors(req,res){
  const o=ipOrigin(req);
  if(o&&originAllowed(req)){res.setHeader('Access-Control-Allow-Origin',o);res.setHeader('Vary','Origin');}
  res.setHeader('Access-Control-Allow-Methods','GET,POST,PATCH,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers','Authorization,Content-Type,X-AOS-App-Token');
  res.setHeader('Cache-Control','no-store');
}
function json(res,status,obj){res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'});res.end(JSON.stringify(obj));}
function bearer(req){const h=String(req.headers.authorization||'');return /^Bearer\s+/i.test(h)?h.replace(/^Bearer\s+/i,'').trim():'';}
function appToken(req){const x=String(req.headers['x-aos-app-token']||'').trim();return x.length>=32?x:bearer(req);}

function sbRequest(method,endpoint,body){
  const u=new URL(SB_URL+endpoint),payload=body===undefined?null:JSON.stringify(body);
  return new Promise(resolve=>{
    let settled=false;
    const done=(value)=>{if(settled)return;settled=true;resolve(value);};
    const headers={'apikey':SERVICE_KEY,'Authorization':'Bearer '+SERVICE_KEY,'Content-Type':'application/json'};
    if(payload!==null)headers['Content-Length']=Buffer.byteLength(payload);
    const r=https.request({hostname:u.hostname,path:u.pathname+u.search,method,headers},rr=>{let d='';rr.on('data',c=>d+=c);rr.on('end',()=>{let parsed=null;try{parsed=JSON.parse(d)}catch(_){parsed=d}done({status:rr.statusCode||500,data:parsed});});});
    r.setTimeout(8000,()=>{r.destroy();done({status:504,data:null});});
    r.on('error',()=>done({status:503,data:null}));if(payload!==null)r.write(payload);r.end();
  });
}

function startInner(runtimeEnv){
  child=spawn(process.execPath,['server-phase-s.js'],{cwd:__dirname,env:runtimeEnv,stdio:['ignore','inherit','inherit']});
  child.on('exit',(code,signal)=>{console.error('[K1] CURRENT chain exited',{code,signal});process.exit(code==null?1:code);});
}

async function identity(req,requireAdmin){
  const token=appToken(req);if(token.length<32)return {ok:false,status:401,error:'APP_SESSION_REQUIRED'};
  let r=await sbRequest('POST','/rest/v1/rpc/aos_kronia_identity_v3',{p_token:token,p_require_admin:!!requireAdmin,p_required_panel:null});
  if(r.status<300&&r.data&&r.data.ok)return Object.assign({status:200,token},r.data);
  if(r.status!==404&&r.status!==400&&r.data&&r.data.error!=='UNAUTHORIZED')return {ok:false,status:401,error:(r.data&&r.data.error)||'UNAUTHORIZED'};
  const a=await sbRequest('POST','/rest/v1/rpc/aos_app_actor_v3',{p_token:token,p_required_panel:null,p_require_2fa:!!requireAdmin});
  const uid=typeof a.data==='string'?a.data:(a.data||'');
  if(!uid||String(uid)==='null')return {ok:false,status:401,error:'UNAUTHORIZED'};
  const u=await sbRequest('GET','/rest/v1/aos_usuarios?select=id,codigo_asesor,nombre,rol,nivel_jerarquia,sede,email,two_factor,paneles_acceso&activo=eq.true&id=eq.'+encodeURIComponent(uid));
  const row=Array.isArray(u.data)&&u.data[0];if(!row)return {ok:false,status:401,error:'IDENTITY_NOT_ACTIVE'};
  if(requireAdmin&&!(String(row.rol||'').toLowerCase()==='admin'&&[1,2].includes(Number(row.nivel_jerarquia))&&row.two_factor===true))return {ok:false,status:403,error:'ADMIN_2FA_REQUIRED'};
  return {ok:true,status:200,token,user_id:row.id,id_asesor:row.codigo_asesor,usuario:row.nombre,nombre:row.nombre,rol:(String(row.rol||'').toLowerCase()==='admin'&&[1,2].includes(Number(row.nivel_jerarquia)))?'ADMIN':'ASESOR',nivel:row.nivel_jerarquia,sede:row.sede,email:row.email,paneles_acceso:row.paneles_acceso||[]};
}

function collect(req,max){return new Promise((resolve,reject)=>{let size=0,ch=[];req.on('data',c=>{size+=c.length;if(size>max){reject(Object.assign(new Error('BODY_TOO_LARGE'),{status:413}));req.destroy();return;}ch.push(c);});req.on('end',()=>resolve(Buffer.concat(ch)));req.on('error',reject);});}
function proxy(req,res,body){
  const headers=Object.assign({},req.headers,{host:'127.0.0.1:'+CURRENT_PORT});delete headers['content-length'];
  if(body)headers['content-length']=Buffer.byteLength(body);
  const up=http.request({hostname:'127.0.0.1',port:CURRENT_PORT,path:req.url,method:req.method,headers},ur=>{res.writeHead(ur.statusCode||502,ur.headers);ur.pipe(res);});
  up.on('error',()=>{if(!res.headersSent)json(res,502,{ok:false,error:'UPSTREAM_UNAVAILABLE'});else res.end();});
  if(body){up.end(body);}else req.pipe(up);
}

async function handleAuthCompat(req,res,pathname){
  if(!allowedRate(req,'auth',12)){json(res,429,{ok:false,error:'RATE_LIMIT'});return;}
  let raw;try{raw=await collect(req,32768);}catch(e){json(res,e.status||400,{ok:false,error:e.message});return;}
  let d={};try{d=JSON.parse(raw.toString('utf8')||'{}');}catch(_){json(res,400,{ok:false,error:'INVALID_JSON'});return;}
  if(pathname==='/api/kronia/login-request'){
    const r=await sbRequest('POST','/rest/v1/rpc/aos_login_v3',{p_usuario:String(d.usuario||''),p_password:String(d.password||'')});
    const out=r.data||{};if(out.app_token){out.token=out.app_token;}json(res,out.ok?200:401,out);return;
  }
  if(pathname==='/api/kronia/login-verify'){
    const r=await sbRequest('POST','/rest/v1/rpc/aos_verificar_2fa_v3',{p_challenge_id:d.challenge_id,p_codigo:String(d.codigo||'')});
    const out=r.data||{};if(out.app_token){out.token=out.app_token;}json(res,out.ok?200:401,out);return;
  }
}

const server=http.createServer(async(req,res)=>{
  let pathname='/';try{pathname=new URL(req.url,'http://localhost').pathname}catch(_){}
  const adminCredentialApi=pathname==='/api/send-email'||pathname.startsWith('/api/studio/');
  const protectedRoute=pathname.startsWith('/api/kronia/')||pathname.startsWith('/api/agents/')||adminCredentialApi;
  if(protectedRoute){cors(req,res);if(!originAllowed(req)){json(res,403,{ok:false,error:'ORIGIN_NOT_ALLOWED'});return;}if(req.method==='OPTIONS'){res.writeHead(204);res.end();return;}}

  if(pathname==='/api/kronia/login-request'||pathname==='/api/kronia/login-verify'){
    if(req.method!=='POST'){json(res,405,{ok:false,error:'METHOD_NOT_ALLOWED'});return;}
    await handleAuthCompat(req,res,pathname);return;
  }
  if(pathname==='/api/kronia/verify'){
    const id=await identity(req,false);json(res,id.ok?200:id.status,{ok:id.ok,usuario:id.usuario,id_asesor:id.id_asesor,rol:id.rol,sede:id.sede,error:id.error});return;
  }
  if(pathname==='/api/kronia/logout'&&req.method==='POST'){
    const id=await identity(req,false);if(!id.ok){json(res,id.status,{ok:false,error:id.error});return;}
    const hash=crypto.createHash('sha256').update(id.token).digest('hex');
    await sbRequest('PATCH','/rest/v1/aos_app_sessions_v3?token_hash=eq.'+hash,{revoked:true,last_used_at:new Date().toISOString()});
    await sbRequest('PATCH','/rest/v1/aos_cia_admin_sessions?token_hash=eq.'+hash,{revoked:true,last_used_at:new Date().toISOString()});
    json(res,200,{ok:true});return;
  }
  if(pathname==='/api/kronia/chat'&&req.method==='POST'){
    if(!allowedRate(req,'chat',60)){json(res,429,{ok:false,error:'RATE_LIMIT'});return;}
    const id=await identity(req,false);if(!id.ok){json(res,id.status,{ok:false,error:id.error});return;}
    let raw;try{raw=await collect(req,262144);}catch(e){json(res,e.status||400,{ok:false,error:e.message});return;}
    let d={};try{d=JSON.parse(raw.toString('utf8')||'{}');}catch(_){json(res,400,{ok:false,error:'INVALID_JSON'});return;}
    d.usuario=id.nombre||id.usuario;d.id_asesor=id.id_asesor;d.rol=id.rol;d.sede=id.sede;
    const next=Buffer.from(JSON.stringify(d));req.headers.authorization='Bearer '+id.token;req.headers['x-aos-app-token']=id.token;proxy(req,res,next);return;
  }
  if(pathname==='/api/kronia/whisper'&&req.method==='POST'){
    if(!allowedRate(req,'voice',20)){json(res,429,{ok:false,error:'RATE_LIMIT'});return;}
    const len=Number(req.headers['content-length']||0);if(len>20*1024*1024){json(res,413,{ok:false,error:'BODY_TOO_LARGE'});return;}
    const id=await identity(req,false);if(!id.ok){json(res,id.status,{ok:false,error:id.error});return;}req.headers['x-aos-app-token']=id.token;proxy(req,res);return;
  }
  if(pathname.startsWith('/api/agents/')){
    if(!allowedRate(req,'agents',120)){json(res,429,{ok:false,error:'RATE_LIMIT'});return;}
    const id=await identity(req,true);if(!id.ok){json(res,id.status,{ok:false,error:id.error});return;}req.headers['x-aos-app-token']=id.token;proxy(req,res);return;
  }
  if(pathname==='/api/send-email'&&req.method==='POST'){
    if(!allowedRate(req,'email',30)){json(res,429,{ok:false,error:'RATE_LIMIT'});return;}
    const id=await identity(req,true);if(!id.ok){json(res,id.status,{ok:false,error:id.error});return;}
    let raw;try{raw=await collect(req,524288);}catch(e){json(res,e.status||400,{ok:false,error:e.message});return;}
    let d={};try{d=JSON.parse(raw.toString('utf8')||'{}');}catch(_){json(res,400,{ok:false,error:'INVALID_JSON'});return;}
    const html=String(d.html||'');
    if(/(?:contrase(?:ñ|n)a|password)\s*:\s*(?:<[^>]+>\s*)*[^<\s]/i.test(html)){json(res,422,{ok:false,error:'PASSWORD_EMAIL_FORBIDDEN'});return;}
    req.headers['x-aos-app-token']=id.token;proxy(req,res,Buffer.from(JSON.stringify(d)));return;
  }
  if(pathname.startsWith('/api/studio/')){
    if(!allowedRate(req,'studio',120)){json(res,429,{ok:false,error:'RATE_LIMIT'});return;}
    const id=await identity(req,true);if(!id.ok){json(res,id.status,{ok:false,error:id.error});return;}
    const len=Number(req.headers['content-length']||0);if(len>5*1024*1024){json(res,413,{ok:false,error:'BODY_TOO_LARGE'});return;}
    req.headers['x-aos-app-token']=id.token;proxy(req,res);return;
  }
  if(pathname.startsWith('/api/kronia/')){
    const id=await identity(req,false);if(!id.ok){json(res,id.status,{ok:false,error:id.error});return;}req.headers['x-aos-app-token']=id.token;proxy(req,res);return;
  }
  proxy(req,res);
});

server.on('clientError',(err,socket)=>socket.end('HTTP/1.1 400 Bad Request\r\n\r\n'));
function shutdown(sig){server.close(()=>process.exit(0));if(child&&!child.killed)child.kill(sig);setTimeout(()=>process.exit(1),5000).unref();}
process.on('SIGTERM',()=>shutdown('SIGTERM'));process.on('SIGINT',()=>shutdown('SIGINT'));

function bootstrap(){
  const runtimeEnv=Object.assign({},process.env,{PORT:String(CURRENT_PORT)});
  startInner(runtimeEnv);
  server.listen(EXTERNAL_PORT,'0.0.0.0',()=>console.log('[K1] security outer boundary listening',EXTERNAL_PORT,'-> current',CURRENT_PORT));
}
bootstrap();