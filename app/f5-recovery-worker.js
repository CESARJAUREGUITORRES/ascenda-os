'use strict';
// One-shot F5 recovery worker for the temporary service-role-only XLSX bridge.
// It never mutates aos_pacientes. It only feeds the already-certified F5 staging RPC.
const https=require('https');
const f5=require('./f5-historical-upload');

const SB_URL=process.env.SUPABASE_URL||'https://ituyqwstonmhnfshnaqz.supabase.co';
const SB_SERVICE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY||'';
const TRANSPORT='aos_f5_private_file_transport_tmp';

function parseJson(raw){try{return raw?JSON.parse(raw):null;}catch(_){return null;}}
function sbRequest(method,endpoint,body,prefer){return new Promise((resolve,reject)=>{
  if(!SB_SERVICE_KEY)return reject(new Error('F5_SERVICE_ROLE_NOT_CONFIGURED'));
  const u=new URL(SB_URL),data=body==null?'':JSON.stringify(body);
  const headers={apikey:SB_SERVICE_KEY,Authorization:'Bearer '+SB_SERVICE_KEY,'Content-Type':'application/json','User-Agent':'AscendaOS-F5-Recovery/1.0'};
  if(data)headers['Content-Length']=Buffer.byteLength(data);if(prefer)headers.Prefer=prefer;
  const q=https.request({hostname:u.hostname,port:u.port||443,path:endpoint,method,headers,timeout:30000},r=>{let raw='';r.on('data',c=>raw+=c);r.on('end',()=>{const out={status:r.statusCode||502,data:parseJson(raw),raw};if(out.status>=200&&out.status<300)resolve(out);else reject(Object.assign(new Error('F5_RECOVERY_DB_REJECTED'),{status:out.status,data:out.data}));});});
  q.on('timeout',()=>q.destroy(new Error('F5_RECOVERY_DB_TIMEOUT')));q.on('error',reject);if(data)q.write(data);q.end();
});}
const get=e=>sbRequest('GET',e,null);
const rpc=(n,p)=>sbRequest('POST','/rest/v1/rpc/'+n,p);
const patch=(e,b)=>sbRequest('PATCH',e,b,'return=minimal');

function safeFilename(s){s=String(s||'').trim();if(!/^(SAN ISIDRO|PUEBLO LIBRE) 20(24|25|26)\.xlsx$/i.test(s))return'';return s.toUpperCase().replace('.XLSX','.xlsx');}
async function manifestBySha(sha){const o=await get('/rest/v1/aos_f5_source_batches_v1?source_sha256=eq.'+encodeURIComponent(sha)+'&select=id,source_sha256,source_filename,source_rows,source_columns&limit=2');const a=Array.isArray(o.data)?o.data:[];return a.length===1?a[0]:null;}
async function mark(filename,body){return patch('/rest/v1/'+TRANSPORT+'?source_filename=eq.'+encodeURIComponent(filename),body);}

async function processFile(row){
  const filename=safeFilename(row.source_filename);if(!filename)throw new Error('RECOVERY_FILENAME_INVALID');
  if(!/^[0-9a-f]{64}$/.test(String(row.source_sha256||'')))throw new Error('RECOVERY_SHA_INVALID');
  await mark(filename,{status:'PROCESSING',error_code:null});
  const buffer=Buffer.from(String(row.content_base64||''),'base64');
  if(!buffer.length)throw new Error('RECOVERY_EMPTY_PAYLOAD');
  const normalized=await f5.parseAndNormalize(buffer);
  if(normalized.sourceSha!==row.source_sha256)throw new Error('RECOVERY_SHA_MISMATCH');
  const manifest=await manifestBySha(normalized.sourceSha);if(!manifest)throw new Error('RECOVERY_MANIFEST_MISSING');
  if(String(manifest.source_filename).toUpperCase()!==filename.toUpperCase())throw new Error('RECOVERY_FILENAME_MANIFEST_MISMATCH');
  if(Number(manifest.source_columns)!==normalized.columns||Number(manifest.source_rows)!==normalized.rows.length)throw new Error('RECOVERY_MANIFEST_COUNT_MISMATCH');
  let inserted=0,existing=0,last=null;
  for(let i=0;i<normalized.rows.length;i+=500){
    const out=await rpc('aos_f5_ingest_source_rows_v1',{p_source_sha256:normalized.sourceSha,p_rows:normalized.rows.slice(i,i+500)});
    const d=out.data||{};if(d.ok!==true)throw new Error('RECOVERY_PRIVATE_INGEST_REJECTED');inserted+=Number(d.inserted||0);existing+=Number(d.existing||0);last=d;
  }
  if(!last||last.complete!==true)throw new Error('RECOVERY_BATCH_INCOMPLETE');
  await mark(filename,{status:'COMPLETE',content_base64:'',error_code:null,processed_at:new Date().toISOString()});
  console.log('[F5-RECOVERY] complete',{filename,rows:normalized.rows.length,inserted,existing});
  return {filename,rows:normalized.rows.length,inserted,existing};
}

async function run(){
  if(!SB_SERVICE_KEY){console.log('[F5-RECOVERY] skipped: no service key');return {skipped:true};}
  let out;try{out=await get('/rest/v1/'+TRANSPORT+'?status=in.(READY,PROCESSING)&select=source_filename,source_sha256,content_base64&order=source_filename.asc');}
  catch(e){if(e.status===404||e.status===400){console.log('[F5-RECOVERY] bridge absent; no-op');return {skipped:true};}throw e;}
  const rows=Array.isArray(out.data)?out.data:[];if(!rows.length){console.log('[F5-RECOVERY] no pending payloads');return {processed:0};}
  let processed=0;
  for(const row of rows){try{await processFile(row);processed++;}catch(e){console.error('[F5-RECOVERY] file failed',row.source_filename,e.message);try{await mark(row.source_filename,{status:'ERROR',error_code:String(e.message||'RECOVERY_FAILED').slice(0,120)});}catch(_){ }throw e;}}
  return {processed};
}
module.exports={run,safeFilename};
