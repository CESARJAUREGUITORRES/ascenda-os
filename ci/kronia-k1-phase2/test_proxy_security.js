'use strict';
const {spawn}=require('child_process');
const http=require('http');
const path=require('path');
const root=path.resolve(__dirname,'../..');
const app=path.join(root,'app');
const PORT=4290;
function req(method,p,headers,body){return new Promise((resolve,reject)=>{const data=body?Buffer.from(body):null;const h=Object.assign({},headers||{});if(data&&!h['Content-Length'])h['Content-Length']=data.length;const r=http.request({hostname:'127.0.0.1',port:PORT,path:p,method,headers:h},res=>{let d='';res.on('data',c=>d+=c);res.on('end',()=>resolve({status:res.statusCode,body:d,headers:res.headers}))});r.on('error',reject);if(data)r.write(data);r.end()})}
function sleep(ms){return new Promise(r=>setTimeout(r,ms))}
(async()=>{
 const child=spawn(process.execPath,['server-k1.js'],{cwd:app,env:Object.assign({},process.env,{PORT:String(PORT),SUPABASE_SERVICE_ROLE_KEY:'ci-not-a-real-service-role-key',META_VERIFY_TOKEN:'ci-disabled',K1_SKIP_RUNTIME_SECRET_LOOKUP:'1',RESEND_API_KEY:'ci-not-a-real-resend-key'}),stdio:['ignore','pipe','pipe']});
 let logs='';child.stdout.on('data',d=>logs+=d);child.stderr.on('data',d=>logs+=d);
 try{
  let ready=false;for(let i=0;i<40;i++){try{const r=await req('GET','/login');if(r.status===200){ready=true;break}}catch(e){}await sleep(250)}
  if(!ready)throw new Error('proxy not ready: '+logs.slice(-1000));
  let r=await req('POST','/api/kronia/chat',{'Content-Type':'application/json'},'{}');if(r.status!==401)throw new Error('missing bearer expected 401 got '+r.status);
  r=await req('OPTIONS','/api/kronia/chat',{Origin:'http://127.0.0.1:'+PORT,'Access-Control-Request-Method':'POST'});if(r.status!==204)throw new Error('preflight expected 204 got '+r.status);
  r=await req('POST','/api/kronia/chat',{Origin:'https://evil.example','Content-Type':'application/json'},'{}');if(r.status!==403)throw new Error('bad origin expected 403 got '+r.status);
  r=await req('POST','/api/kronia/whisper',{'Content-Type':'audio/webm','Content-Length':String(21*1024*1024)});if(r.status!==413)throw new Error('oversize expected 413 got '+r.status);

  // Server-credential-backed administrative APIs must not remain public relays.
  r=await req('POST','/api/send-email',{'Content-Type':'application/json'},JSON.stringify({to:'nobody@example.invalid',subject:'x',html:'x'}));if(r.status!==401)throw new Error('send-email missing bearer expected 401 got '+r.status);
  r=await req('GET','/api/studio/connections');if(r.status!==401)throw new Error('studio missing bearer expected 401 got '+r.status);
  r=await req('OPTIONS','/api/send-email',{Origin:'http://127.0.0.1:'+PORT,'Access-Control-Request-Method':'POST'});if(r.status!==204)throw new Error('send-email preflight expected 204 got '+r.status);
  r=await req('POST','/api/send-email',{Origin:'https://evil.example','Content-Type':'application/json'},'{}');if(r.status!==403)throw new Error('send-email bad origin expected 403 got '+r.status);

  let last=0;for(let i=0;i<61;i++){r=await req('POST','/api/kronia/chat',{'Content-Type':'application/json'},'{}');last=r.status;}if(last!==429)throw new Error('rate limit expected 429 got '+last);
  console.log('KRONIA_K1_PHASE2_PROXY_SMOKE=PASS');
 } finally {child.kill('SIGTERM');await sleep(300);if(!child.killed)child.kill('SIGKILL');}
})().catch(e=>{console.error(e.stack||e);process.exit(1)});
