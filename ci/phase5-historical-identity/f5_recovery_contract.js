const fs=require('fs');
const w=fs.readFileSync('app/f5-recovery-worker.js','utf8');
const s=fs.readFileSync('app/server-f5.js','utf8');
function a(x,m){if(!x)throw new Error(m)}
a(w.includes("const TRANSPORT='aos_f5_private_file_transport_tmp'"),'temporary bridge table missing');
a(w.includes("rpc('aos_f5_ingest_source_rows_v1'"),'worker must use certified private ingest RPC');
a(w.includes('normalized.sourceSha!==row.source_sha256'),'exact SHA gate missing');
a(w.includes('RECOVERY_MANIFEST_COUNT_MISMATCH'),'manifest count gate missing');
a(w.includes("status:'COMPLETE',content_base64:''"),'payload must be erased after successful ingest');
a(w.includes("status:'ERROR'"),'worker must fail closed');
for(const forbidden of ['insert into public.aos_pacientes','update public.aos_pacientes','delete from public.aos_pacientes','/rest/v1/aos_pacientes'])a(!w.toLowerCase().includes(forbidden.toLowerCase()),'canonical patient mutation forbidden: '+forbidden);
a(s.includes("require('./f5-recovery-worker')"),'server must bind recovery worker explicitly');
a(s.includes('setTimeout(()=>f5Recovery.run()'),'recovery must execute asynchronously after server bind');
console.log('F5 recovery worker safety contract: PASS');
