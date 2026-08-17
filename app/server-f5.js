'use strict';
// F5 outer boundary: owner/admin 2FA XLSX intake into private patient-identity staging.
// Everything outside /api/f5/* is proxied unchanged to the certified WA4 -> WA3 -> WA2 -> F4 chain.
const http=require('http');
const https=require('https');
const {spawn}=require('child_process');
const f5=require('./f5-historical-upload');
const f5Recovery=require('./f5-recovery-worker');

const EXTERNAL_PORT=parseInt(process.env.PORT||'4173',10);
const INNER_PORT=EXTERNAL_PORT===4208?4209:4208;
const SB_URL=process.env.SUPABASE_URL||'https://ituyqwstonmhnfshnaqz.supabase.co';
const SB_ANON_KEY=process.env.SUPABASE_ANON_KEY||'';
const SB_SERVICE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY||'';
let child=null;

function writeJson(res,status,obj){res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','X-Ascenda-F5-Upload':'v1'});res.end(JSON.stringify(obj));}
function strongToken(req){const t=String(req.headers['x-aos-app-token']||'').trim();return t.length>=32?t:'';}
function readRaw(req,max=f5.MAX_FILE_BYTES){return new Promise((resolve,reject)=>{const chunks=[];let total=0,over=false;req.on('data',c=>{if(over)return;total+=c.length;if(total>max){over=true;return;}chunks.push(c);});req.on('end',()=>over?reject(Object.assign(new Error('FILE_TOO_LARGE'),{status:413})):resolve(Buffer.concat(chunks)));req.on('error',reject);});}
function parseJson(raw){try{return raw?JSON.parse(raw):null;}catch(_){return null;}}
function sbRequest(method,endpoint,body,service,prefer){return new Promise((resolve,reject)=>{const key=service?SB_SERVICE_KEY:SB_ANON_KEY;if(!key)return reject(Object.assign(new Error(service?'SUPABASE_SERVICE_ROLE_NOT_CONFIGURED':'SUPABASE_ANON_KEY_NOT_CONFIGURED'),{status:503}));let u;try{u=new URL(SB_URL);}catch(e){return reject(e);}const data=body==null?'':JSON.stringify(body),headers={apikey:key,Authorization:'Bearer '+key,'Content-Type':'application/json','User-Agent':'AscendaOS-F5-Upload/1.0'};if(data)headers['Content-Length']=Buffer.byteLength(data);if(prefer)headers.Prefer=prefer;const q=https.request({hostname:u.hostname,port:u.port||443,path:endpoint,method,headers,timeout:30000},r=>{let raw='';r.on('data',c=>raw+=c);r.on('end',()=>{const out={status:r.statusCode||502,data:parseJson(raw),raw};if(out.status>=200&&out.status<300)resolve(out);else reject(Object.assign(new Error('F5_DB_REJECTED'),{status:502,upstreamStatus:out.status,data:out.data}));});});q.on('timeout',()=>q.destroy(Object.assign(new Error('F5_DB_TIMEOUT'),{status:504})));q.on('error',reject);if(data)q.write(data);q.end();});}
const anonRpc=(n,p)=>sbRequest('POST','/rest/v1/rpc/'+n,p,false);
const serviceRpc=(n,p)=>sbRequest('POST','/rest/v1/rpc/'+n,p,true);
const serviceGet=e=>sbRequest('GET',e,null,true);

async function authorize(req){const token=strongToken(req);if(!token)return null;try{const out=await anonRpc('aos_app_actor_v3',{p_token:token,p_required_panel:'admin-import-ventas',p_require_2fa:true});const id=typeof out.data==='string'?out.data:'';return /^[0-9a-f-]{36}$/i.test(id)?{id,token}:null;}catch(_){return null;}}
function safeFilename(req){const s=String(req.headers['x-aos-source-filename']||'').trim();if(!/^(SAN ISIDRO|PUEBLO LIBRE) 20(24|25|26)\.xlsx$/i.test(s))return'';return s.toUpperCase().replace('.XLSX','.xlsx');}
async function manifestBySha(sha){const o=await serviceGet('/rest/v1/aos_f5_source_batches_v1?source_sha256=eq.'+encodeURIComponent(sha)+'&select=id,source_sha256,source_filename,source_sede,source_year,source_rows,source_columns,status,metadata&limit=2');const a=Array.isArray(o.data)?o.data:[];return a.length===1?a[0]:null;}
async function handleUpload(req,res){
 const actor=await authorize(req);if(!actor)return writeJson(res,403,{ok:false,error:'F5_ADMIN_2FA_REQUIRED'});
 if(!SB_SERVICE_KEY)return writeJson(res,503,{ok:false,error:'F5_SERVICE_ROLE_NOT_CONFIGURED'});
 const filename=safeFilename(req);if(!filename)return writeJson(res,400,{ok:false,error:'SOURCE_FILENAME_INVALID'});
 try{
   const buffer=await readRaw(req);
   const normalized=await f5.parseAndNormalize(buffer);
   const manifest=await manifestBySha(normalized.sourceSha);
   if(!manifest)return writeJson(res,409,{ok:false,error:'SOURCE_SHA_NOT_IN_MANIFEST',sha256:normalized.sourceSha});
   if(String(manifest.source_filename).toUpperCase()!==filename.toUpperCase())return writeJson(res,409,{ok:false,error:'SOURCE_FILENAME_SHA_MISMATCH'});
   if(Number(manifest.source_columns)!==normalized.columns||Number(manifest.source_rows)!==normalized.rows.length)return writeJson(res,409,{ok:false,error:'SOURCE_MANIFEST_COUNT_MISMATCH',expected_rows:Number(manifest.source_rows),parsed_rows:normalized.rows.length});
   let inserted=0,existing=0,last=null;
   for(let i=0;i<normalized.rows.length;i+=500){const chunk=normalized.rows.slice(i,i+500);const out=await serviceRpc('aos_f5_ingest_source_rows_v1',{p_source_sha256:normalized.sourceSha,p_rows:chunk});const d=out.data||{};if(d.ok!==true)throw Object.assign(new Error('F5_PRIVATE_INGEST_REJECTED'),{status:502});inserted+=Number(d.inserted||0);existing+=Number(d.existing||0);last=d;}
   writeJson(res,200,{ok:true,filename:manifest.source_filename,sha256:normalized.sourceSha,expected_rows:Number(manifest.source_rows),parsed_rows:normalized.rows.length,inserted,existing,complete:last&&last.complete===true});
 }catch(e){console.error('[F5-UPLOAD]',e.message,{filename});writeJson(res,e.status||500,{ok:false,error:String(e.message||'F5_UPLOAD_FAILED').slice(0,120),row:e.row||null});}
}
async function handleStatus(req,res){const actor=await authorize(req);if(!actor)return writeJson(res,403,{ok:false,error:'F5_ADMIN_2FA_REQUIRED'});try{const o=await serviceGet('/rest/v1/aos_f5_source_batches_v1?select=source_filename,source_sede,source_year,source_rows,status,metadata&order=source_year.asc,source_sede.asc');const rows=Array.isArray(o.data)?o.data:[];writeJson(res,200,{ok:true,batches:rows.map(x=>({filename:x.source_filename,sede:x.source_sede,year:x.source_year,expected_rows:Number(x.source_rows),staged_rows:Number((x.metadata||{}).staged_rows||0),complete:(x.metadata||{}).staging_complete===true,status:x.status}))});}catch(_){writeJson(res,503,{ok:false,error:'F5_STATUS_UNAVAILABLE'});}}
function proxy(req,res){const q=http.request({hostname:'127.0.0.1',port:INNER_PORT,path:req.url,method:req.method,headers:Object.assign({},req.headers,{host:'127.0.0.1:'+INNER_PORT})},r=>{res.writeHead(r.statusCode||502,r.headers);r.pipe(res);});q.on('error',()=>{if(!res.headersSent)res.writeHead(502,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'F5_UPSTREAM_UNAVAILABLE'}));});req.pipe(q);}
const server=http.createServer(async(req,res)=>{let u;try{u=new URL(req.url,'http://localhost');}catch(_){return writeJson(res,400,{ok:false,error:'INVALID_URL'});}if(u.pathname==='/api/f5/historical-upload'&&req.method==='POST')return handleUpload(req,res);if(u.pathname==='/api/f5/historical-status'&&req.method==='GET')return handleStatus(req,res);return proxy(req,res);});
server.on('clientError',(_,s)=>s.end('HTTP/1.1 400 Bad Request\r\n\r\n'));
function shutdown(sig){server.close(()=>process.exit(0));if(child&&!child.killed)child.kill(sig);setTimeout(()=>process.exit(1),5000).unref();}process.on('SIGTERM',()=>shutdown('SIGTERM'));process.on('SIGINT',()=>shutdown('SIGINT'));
child=spawn(process.execPath,['server-wa4.js'],{cwd:__dirname,env:Object.assign({},process.env,{PORT:String(INNER_PORT)}),stdio:['ignore','inherit','inherit']});child.on('exit',code=>process.exit(code==null?1:code));server.listen(EXTERNAL_PORT,'0.0.0.0',()=>{console.log('[F5-UPLOAD] listening',{external:EXTERNAL_PORT,inner:INNER_PORT,maxFileBytes:f5.MAX_FILE_BYTES});setTimeout(()=>f5Recovery.run().catch(e=>console.error('[F5-RECOVERY] fatal',e.message)),12000).unref();});
