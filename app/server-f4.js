// ASCENDA OS — F4 Revenue Operations front proxy.
// Intercepts sensitive KronIA sale-edit confirmations and requires the strong
// Auth V3 app token before delegating to the tokenized F4 database contract.
'use strict';
const http=require('http');
const https=require('https');
const {spawn}=require('child_process');

const EXTERNAL_PORT=parseInt(process.env.PORT||'4173',10);
const INNER_PORT=EXTERNAL_PORT===4189?4190:4189;
const SB_URL=process.env.SUPABASE_URL||'https://ituyqwstonmhnfshnaqz.supabase.co';
const SB_ANON_KEY=process.env.SUPABASE_ANON_KEY||'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYXNlIiwicmVmIjoiaXR1eXF3c3Rvbm1obmZzaG5hcXoiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTc3NDc0NDIxOCwiZXhwIjoyMDkwMzIwMjE4fQ.w_pU4ecrrgekB7WzWrQrQd_7Deu_Cxm5ybUCZry5Mh0';

const child=spawn(process.execPath,['server-phase2.js'],{cwd:__dirname,env:Object.assign({},process.env,{PORT:String(INNER_PORT)}),stdio:['ignore','inherit','inherit']});
child.on('exit',(code,signal)=>{console.error('[F4-PROXY] backend exited',{code,signal});process.exit(code==null?1:code);});

function writeJson(res,status,obj){res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Ascenda-Revenue-Route':'f4'});res.end(JSON.stringify(obj));}
function sbRpc(name,payload){
  return new Promise((resolve,reject)=>{
    let sb;try{sb=new URL(SB_URL);}catch(e){reject(e);return;}
    const data=JSON.stringify(payload||{});
    const req=https.request({hostname:sb.hostname,port:sb.port||443,path:'/rest/v1/rpc/'+name,method:'POST',headers:{apikey:SB_ANON_KEY,Authorization:'Bearer '+SB_ANON_KEY,'Content-Type':'application/json','Content-Length':Buffer.byteLength(data),'User-Agent':'AscendaOS-F4-RevenueProxy/1.0'},timeout:12000},r=>{
      let body='';r.on('data',c=>body+=c);r.on('end',()=>{let parsed={};try{parsed=body?JSON.parse(body):{};}catch(e){parsed={ok:false,error:'UPSTREAM_INVALID_JSON'};}resolve({status:r.statusCode||502,data:parsed});});
    });
    req.on('timeout',()=>req.destroy(new Error('UPSTREAM_TIMEOUT')));req.on('error',reject);req.write(data);req.end();
  });
}
async function handleKroniaSaleEdit(req,res,body){
  const appToken=String(req.headers['x-aos-app-token']||'').trim();
  if(appToken.length<32){writeJson(res,403,{ok:true,respuesta:'🔒 La edición financiera requiere una sesión administrativa 2FA vigente.',provider:'f4-security',error:'F4_STRONG_SESSION_REQUIRED'});return;}
  const action=body&&body.confirmar_accion;const params=action&&action.params||{};const saleId=Number(params.p_venta_id||0);
  if(!saleId||!params.p_campos||typeof params.p_campos!=='object'){writeJson(res,400,{ok:false,error:'INVALID_SALE_EDIT'});return;}
  try{
    const current=await sbRpc('aos_sales_admin_sale_v4',{p_token:appToken,p_sale_id:saleId});
    if(!current.data||current.data.ok!==true||!current.data.row){writeJson(res,403,{ok:true,respuesta:'🔒 No se pudo validar la venta o tu permiso de edición.',provider:'f4-security',resultado:current.data});return;}
    const edited=await sbRpc('aos_editar_venta_v4',{p_token:appToken,p_venta_id:saleId,p_expected_updated_at:current.data.row.updated_at,p_campos:params.p_campos,p_origen:'kronia_f4'});
    const result=edited.data||{};
    if(result.ok===false){writeJson(res,200,{ok:true,respuesta:'⚠️ No pude ejecutar la edición: '+(result.error||'rechazada'),provider:'f4-ejecutor',resultado:result});return;}
    writeJson(res,200,{ok:true,respuesta:'✅ Venta actualizada mediante el contrato seguro F4.',provider:'f4-ejecutor',resultado:result});
  }catch(e){console.error('[F4-PROXY] KronIA sale edit',e.message);writeJson(res,502,{ok:true,respuesta:'⚠️ No fue posible completar la edición segura en este momento.',provider:'f4-ejecutor',error:'F4_UPSTREAM_UNAVAILABLE'});}
}

const server=http.createServer((req,res)=>{
  let pathname='/';try{pathname=new URL(req.url,'http://localhost').pathname;}catch(e){}
  if(pathname==='/api/kronia/chat'&&req.method==='POST'){
    let raw='',overflow=false;req.on('data',c=>{if(overflow)return;raw+=c;if(Buffer.byteLength(raw)>1024*1024)overflow=true;});req.on('end',()=>{
      if(overflow){writeJson(res,413,{ok:false,error:'PAYLOAD_TOO_LARGE'});return;}
      let body;try{body=JSON.parse(raw||'{}');}catch(e){writeJson(res,400,{ok:false,error:'INVALID_JSON'});return;}
      if(body&&body.confirmar_accion&&body.confirmar_accion.rpc==='aos_editar_venta'){handleKroniaSaleEdit(req,res,body);return;}
      proxyBuffered(req,res,raw);
    });return;
  }
  proxyStream(req,res);
});
function proxyBuffered(req,res,raw){
  const headers=Object.assign({},req.headers,{host:'127.0.0.1:'+INNER_PORT,'content-length':Buffer.byteLength(raw)});
  const up=http.request({hostname:'127.0.0.1',port:INNER_PORT,path:req.url,method:req.method,headers},r=>{res.writeHead(r.statusCode||502,r.headers);r.pipe(res);});
  up.on('error',e=>{if(!res.headersSent)writeJson(res,502,{ok:false,error:'UPSTREAM_UNAVAILABLE'});else res.end();console.error('[F4-PROXY] buffered',e.message);});up.write(raw);up.end();
}
function proxyStream(req,res){
  const headers=Object.assign({},req.headers,{host:'127.0.0.1:'+INNER_PORT});
  const up=http.request({hostname:'127.0.0.1',port:INNER_PORT,path:req.url,method:req.method,headers},r=>{res.writeHead(r.statusCode||502,r.headers);r.pipe(res);});
  up.on('error',e=>{if(!res.headersSent)writeJson(res,502,{ok:false,error:'UPSTREAM_UNAVAILABLE'});else res.end();console.error('[F4-PROXY] stream',e.message);});req.pipe(up);
}
function shutdown(sig){console.log('[F4-PROXY] shutdown',sig);server.close(()=>process.exit(0));if(!child.killed)child.kill(sig);setTimeout(()=>process.exit(1),5000).unref();}
process.on('SIGTERM',()=>shutdown('SIGTERM'));process.on('SIGINT',()=>shutdown('SIGINT'));
server.listen(EXTERNAL_PORT,'0.0.0.0',()=>console.log('[F4-PROXY] listening on :'+EXTERNAL_PORT+' -> :'+INNER_PORT));
