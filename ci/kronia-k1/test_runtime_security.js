const { spawn } = require('child_process');
const http = require('http');

const PORT = 18181;
const env = Object.assign({}, process.env, {
  PORT: String(PORT),
  SUPABASE_SERVICE_ROLE_KEY: 'ci-dummy-service-role',
  ASCENDA_CORS_ORIGINS: 'https://allowed.example',
  GROQ_API_KEY: '', GEMINI_API_KEY: '', RESEND_API_KEY: '',
  ASCENDA_VERIFY_TOKEN: 'ci-verify-token', TURNSTILE_SECRET_KEY: ''
});

function request(path, opts={}) {
  return new Promise((resolve,reject)=>{
    const body = opts.body === undefined ? null : Buffer.from(opts.body);
    const headers = Object.assign({}, opts.headers||{});
    if (body && headers['Content-Length'] === undefined) headers['Content-Length']=body.length;
    const req=http.request({host:'127.0.0.1',port:PORT,path,method:opts.method||'GET',headers},res=>{
      let data='';res.on('data',c=>data+=c);res.on('end',()=>resolve({status:res.statusCode,headers:res.headers,body:data}));
    });
    req.on('error',reject);if(body)req.write(body);req.end();
  });
}

async function waitServer(){
  for(let i=0;i<60;i++){
    try{const r=await request('/health');if(r.status>=200&&r.status<500)return;}catch(_){}
    await new Promise(r=>setTimeout(r,100));
  }
  throw new Error('server did not start');
}

function assert(cond,msg){if(!cond)throw new Error(msg);}

(async()=>{
  const child=spawn(process.execPath,['app/server.js'],{env,stdio:['ignore','pipe','pipe']});
  let stderr='';child.stderr.on('data',d=>stderr+=d.toString());
  try{
    await waitServer();

    let r=await request('/api/auth/login',{method:'POST',headers:{Origin:'https://evil.example','Content-Type':'application/json'},body:'{}'});
    assert(r.status===403,'disallowed origin expected 403, got '+r.status);

    r=await request('/api/auth/login',{method:'OPTIONS',headers:{Origin:'https://allowed.example','Access-Control-Request-Method':'POST'}});
    assert(r.status===204,'allowed preflight expected 204, got '+r.status);
    assert(r.headers['access-control-allow-origin']==='https://allowed.example','allowed origin was not echoed exactly');

    r=await request('/api/kronia/chat',{method:'POST',headers:{'Content-Type':'application/json','X-Forwarded-For':'203.0.113.2'},body:JSON.stringify({pregunta:'test'})});
    assert(r.status===401,'missing bearer chat expected 401, got '+r.status);

    r=await request('/api/agents/run',{method:'POST',headers:{'Content-Type':'application/json','X-Forwarded-For':'203.0.113.3'},body:'{}'});
    assert(r.status===401,'missing bearer agent control expected 401, got '+r.status);

    r=await request('/api/auth/login',{method:'POST',headers:{'Content-Type':'application/json','Content-Length':'40000','X-Forwarded-For':'203.0.113.4'}});
    assert(r.status===413,'oversized auth request expected 413, got '+r.status);

    let last=null;
    for(let i=0;i<121;i++) last=await request('/api/kronia/__rate_probe',{headers:{'X-Forwarded-For':'203.0.113.9'}});
    assert(last.status===429,'rate probe expected final 429, got '+last.status);

    console.log('KRONIA_K1_RUNTIME_SECURITY_SMOKE=PASS');
  } finally {
    child.kill('SIGTERM');
    await new Promise(r=>setTimeout(r,100));
    if(child.exitCode===null)child.kill('SIGKILL');
  }
})().catch(err=>{console.error(err.stack||err);process.exit(1)});
