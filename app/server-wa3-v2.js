'use strict';
// WA-3 V2 additive multiagent boundary.
// Handles only readiness/queue/claim/team summary. Existing server-wa3.js remains ownership, routing and human-send authority.
const http=require('http');
const https=require('https');
const crypto=require('crypto');
const {spawn}=require('child_process');

const EXTERNAL_PORT=parseInt(process.env.PORT||'4173',10);
const INNER_PORT=EXTERNAL_PORT===4200?4201:4200;
const SB_URL=process.env.SUPABASE_URL||'https://ituyqwstonmhnfshnaqz.supabase.co';
const SB_ANON_KEY=process.env.SUPABASE_ANON_KEY||'';
const SB_SERVICE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY||'';
const UUID_RE=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const child=spawn(process.execPath,['server-wa3.js'],{
  cwd:__dirname,
  env:Object.assign({},process.env,{PORT:String(INNER_PORT)}),
  stdio:['ignore','inherit','inherit']
});
child.on('exit',(code,signal)=>{
  console.error('[WA3V2] server-wa3 exited',{code,signal});
  process.exit(code==null?1:code);
});

function writeJson(res,status,obj){
  res.writeHead(status,{
    'Content-Type':'application/json; charset=utf-8',
    'Cache-Control':'no-store',
    'X-Content-Type-Options':'nosniff',
    'X-Ascenda-WA3-Multiagent':'v2'
  });
  res.end(JSON.stringify(obj));
}
function readJson(req,maxBytes=64*1024){
  return new Promise((resolve,reject)=>{
    let raw='',overflow=false;
    req.on('data',c=>{if(overflow)return;raw+=c;if(Buffer.byteLength(raw)>maxBytes)overflow=true;});
    req.on('end',()=>{
      if(overflow)return reject(Object.assign(new Error('PAYLOAD_TOO_LARGE'),{status:413}));
      try{resolve(JSON.parse(raw||'{}'));}catch(_){reject(Object.assign(new Error('INVALID_JSON'),{status:400}));}
    });
    req.on('error',reject);
  });
}
function parseData(raw){try{return raw?JSON.parse(raw):null;}catch(_){return null;}}
function strongToken(req){const t=String(req.headers['x-aos-app-token']||'').trim();return t.length>=32?t:'';}
function sbRequest(method,endpoint,body,useService){
  return new Promise((resolve,reject)=>{
    const key=useService?SB_SERVICE_KEY:SB_ANON_KEY;
    if(!key)return reject(Object.assign(new Error(useService?'SUPABASE_SERVICE_ROLE_NOT_CONFIGURED':'SUPABASE_ANON_KEY_NOT_CONFIGURED'),{status:503}));
    let sb;try{sb=new URL(SB_URL);}catch(e){return reject(e);}
    const data=body==null?'':JSON.stringify(body);
    const headers={
      apikey:key,
      Authorization:'Bearer '+key,
      'Content-Type':'application/json',
      'User-Agent':'AscendaOS-WA3V2/1.0'
    };
    if(data)headers['Content-Length']=Buffer.byteLength(data);
    const q=https.request({hostname:sb.hostname,port:sb.port||443,path:endpoint,method,headers,timeout:12000},r=>{
      let raw='';r.on('data',c=>raw+=c);r.on('end',()=>{
        const out={status:r.statusCode||502,data:parseData(raw),raw};
        if(out.status>=200&&out.status<300)resolve(out);
        else reject(Object.assign(new Error('WA3V2_DB_UNAVAILABLE'),{status:502,upstreamStatus:out.status,data:out.data}));
      });
    });
    q.on('timeout',()=>q.destroy(new Error('WA3V2_DB_TIMEOUT')));
    q.on('error',reject);
    if(data)q.write(data);
    q.end();
  });
}
const sbRpc=(name,payload)=>sbRequest('POST','/rest/v1/rpc/'+name,payload,false);
const serviceRpc=(name,payload)=>sbRequest('POST','/rest/v1/rpc/'+name,payload,true);
const serviceGet=(endpoint)=>sbRequest('GET',endpoint,null,true);

async function actor(req){
  const token=strongToken(req);if(!token)return null;
  try{
    const out=await sbRpc('aos_wa3_actor_v1',{p_token:token});
    const a=out.data;
    return a&&a.ok===true&&UUID_RE.test(String(a.actor_id||''))?a:null;
  }catch(_){return null;}
}
async function requireActor(req,res,adminOnly){
  const a=await actor(req);
  if(!a){writeJson(res,403,{ok:false,error:'WA3_2FA_PANEL_REQUIRED'});return null;}
  if(adminOnly&&a.is_admin!==true){writeJson(res,403,{ok:false,error:'WA3_ADMIN_REQUIRED'});return null;}
  return a;
}
async function queueSummary(a){
  const out=await serviceRpc('aos_wa3_queue_summary_v1',{p_actor_id:a.actor_id});
  return out.data||{ok:false,error:'WA3_QUEUE_SUMMARY_EMPTY'};
}
async function getQueue(req,res){
  const a=await requireActor(req,res,false);if(!a)return;
  try{
    const d=await queueSummary(a);
    writeJson(res,d.ok===false?409:200,d);
  }catch(e){writeJson(res,503,{ok:false,error:'WA3_QUEUE_SUMMARY_UNAVAILABLE'});}
}
async function teamSummary(req,res){
  const a=await requireActor(req,res,true);if(!a)return;
  try{
    const [members,users,assignments]=await Promise.all([
      serviceGet('/rest/v1/aos_wa_box_members_v1?active=eq.true&select=box_id,user_id,max_active,priority,last_assigned_at'),
      serviceGet('/rest/v1/aos_usuarios?activo=eq.true&select=id,nombre,rol,cargo,sede,nivel_jerarquia,paneles_acceso'),
      serviceGet('/rest/v1/aos_wa_assignments_v1?state=eq.ACTIVE&select=owner_user_id,box_id')
    ]);
    const memberRows=Array.isArray(members.data)?members.data:[];
    const userRows=Array.isArray(users.data)?users.data:[];
    const assignmentRows=Array.isArray(assignments.data)?assignments.data:[];
    const ids=new Set(memberRows.map(x=>String(x.user_id||'')));
    const candidateUsers=userRows.filter(u=>ids.has(String(u.id)));
    const agents=await Promise.all(candidateUsers.map(async u=>{
      const effectiveOut=await serviceRpc('aos_wa3_effective_presence_v2',{p_actor_id:u.id});
      const p=effectiveOut.data||{};
      if(p.ok===false)throw new Error('WA3_EFFECTIVE_PRESENCE_UNAVAILABLE');
      const boxes=memberRows.filter(m=>m.user_id===u.id).map(m=>({box_id:m.box_id,max_active:m.max_active,priority:m.priority}));
      const activeLoad=assignmentRows.filter(x=>x.owner_user_id===u.id).length;
      return {
        id:u.id,
        name:u.nombre||null,
        role:u.rol||null,
        cargo:u.cargo||null,
        sede:u.sede||null,
        effective_status:p.status||'OFFLINE',
        labor_state:p.labor_state||null,
        last_seen_at:p.last_seen_at||null,
        available_since:p.available_since||null,
        presence_source:p.presence_source||null,
        active_load:activeLoad,
        boxes:boxes
      };
    }));
    agents.sort((x,y)=>String(x.name||'').localeCompare(String(y.name||''),'es'));
    writeJson(res,200,{
      ok:true,
      agents:agents,
      generated_at:new Date().toISOString(),
      snapshot_source:'aos_wa3_effective_presence_v2',
      privacy:'NO_CUSTOMER_DATA'
    });
  }catch(e){writeJson(res,503,{ok:false,error:'WA3_TEAM_SUMMARY_UNAVAILABLE'});}
}
async function presence(req,res){
  const a=await requireActor(req,res,false);if(!a)return;
  let body;try{body=await readJson(req);}catch(e){return writeJson(res,e.status||400,{ok:false,error:e.message});}
  const status=String(body&&body.status||'AVAILABLE').trim().toUpperCase();
  try{
    const touched=await serviceRpc('aos_wa3_agent_presence_touch_v1',{p_actor_id:a.actor_id,p_status:status});
    const p=touched.data||{};
    if(p.ok===false)return writeJson(res,409,p);
    const queue=await queueSummary(a);
    writeJson(res,200,{ok:true,presence:p,queue:queue});
  }catch(e){writeJson(res,503,{ok:false,error:'WA3_PRESENCE_UNAVAILABLE'});}
}
async function claimNext(req,res){
  const a=await requireActor(req,res,false);if(!a)return;
  let body;try{body=await readJson(req);}catch(e){return writeJson(res,e.status||400,{ok:false,error:e.message});}
  const boxId=String(body&&body.box_id||'');
  if(!UUID_RE.test(boxId))return writeJson(res,400,{ok:false,error:'INVALID_BOX_ID'});
  try{
    const out=await serviceRpc('aos_wa3_claim_next_v2',{p_box_id:boxId,p_actor_id:a.actor_id});
    const d=out.data||{};
    writeJson(res,d.ok===false?409:200,d);
  }catch(e){writeJson(res,503,{ok:false,error:'WA3_CLAIM_UNAVAILABLE'});}
}

// Per-session limiter. The WA3V2 boundary sits behind multiple internal wrappers,
// so socket.remoteAddress is normally loopback and MUST NOT be the primary key.
// Reads and writes use independent buckets so UI polling can never block a human action.
const buckets=new Map();
function rateIdentity(req){
  const token=strongToken(req);
  if(token)return 'session:'+crypto.createHash('sha256').update(token).digest('hex').slice(0,32);
  return 'unauth:'+String(req.socket.remoteAddress||'unknown');
}
function rateAllowed(req){
  const now=Date.now();
  const read=req.method==='GET'||req.method==='HEAD';
  const scope=read?'read':'write';
  const limit=read?600:120;
  const key=rateIdentity(req)+'|'+scope;
  let b=buckets.get(key);
  if(!b||now-b.start>60000){b={start:now,n:0};buckets.set(key,b);}
  b.n++;
  if(buckets.size>2000){for(const [k,v] of buckets)if(now-v.start>120000)buckets.delete(k);}
  return b.n<=limit;
}
function proxy(req,res){
  const headers=Object.assign({},req.headers,{host:'127.0.0.1:'+INNER_PORT});
  const q=http.request({hostname:'127.0.0.1',port:INNER_PORT,path:req.url,method:req.method,headers},r=>{
    res.writeHead(r.statusCode||502,r.headers);r.pipe(res);
  });
  q.on('error',e=>{
    console.error('[WA3V2] proxy',e.message);
    if(!res.headersSent)writeJson(res,502,{ok:false,error:'WA3V2_INNER_UNAVAILABLE'});else res.end();
  });
  req.pipe(q);
}

const server=http.createServer(async(req,res)=>{
  let u;try{u=new URL(req.url,'http://localhost');}catch(_){return writeJson(res,400,{ok:false,error:'INVALID_URL'});}
  const p=u.pathname;
  if(p.startsWith('/api/wa3/')&&!rateAllowed(req))return writeJson(res,429,{ok:false,error:'WA3_RATE_LIMIT'});
  if(req.method==='GET'&&p==='/api/wa3/queue-summary')return getQueue(req,res);
  if(req.method==='GET'&&p==='/api/wa3/team-summary')return teamSummary(req,res);
  if(req.method==='POST'&&p==='/api/wa3/presence')return presence(req,res);
  if(req.method==='POST'&&p==='/api/wa3/claim-next')return claimNext(req,res);
  return proxy(req,res);
});
server.on('clientError',(_,socket)=>socket.end('HTTP/1.1 400 Bad Request\r\n\r\n'));
server.listen(EXTERNAL_PORT,'0.0.0.0',()=>console.log('[WA3V2] multiagent boundary listening',{external:EXTERNAL_PORT,inner:INNER_PORT}));
function shutdown(sig){
  console.log('[WA3V2] shutdown',sig);
  try{child.kill(sig);}catch(_){}
  server.close(()=>process.exit(0));
  setTimeout(()=>process.exit(1),5000).unref();
}
process.on('SIGTERM',()=>shutdown('SIGTERM'));
process.on('SIGINT',()=>shutdown('SIGINT'));
