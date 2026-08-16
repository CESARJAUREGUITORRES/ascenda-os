'use strict';
// ASCENDA Conversations — PHASE S stabilization boundary.
// Purpose: keep the certified F5->WA4->WA3->WA2->F4 chain intact while
// making WA-3 bootstrap resilient, observable and fail-closed for writes.
const http=require('http');
const https=require('https');
const {spawn}=require('child_process');

const EXTERNAL_PORT=parseInt(process.env.PORT||'4173',10);
const INNER_PORT=EXTERNAL_PORT===4225?4226:4225;
const SB_URL=process.env.SUPABASE_URL||'https://ituyqwstonmhnfshnaqz.supabase.co';
const SB_ANON_KEY=process.env.SUPABASE_ANON_KEY||'';
const SB_SERVICE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY||'';
const WA_CANARY_MODE=process.env.WA_CANARY_MODE||'true';
const WA_CANARY_ALLOW_TO=process.env.WA_CANARY_ALLOW_TO||'';
const UUID_RE=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

let childAlive=true;
const child=spawn(process.execPath,['server-f5.js'],{
  cwd:__dirname,
  env:Object.assign({},process.env,{PORT:String(INNER_PORT)}),
  stdio:['ignore','inherit','inherit']
});
child.on('exit',(code,signal)=>{
  childAlive=false;
  console.error('[PHASE-S] server-f5 exited',{code,signal});
  process.exit(code==null?1:code);
});

function writeJson(res,status,obj){
  res.writeHead(status,{
    'Content-Type':'application/json; charset=utf-8',
    'Cache-Control':'no-store',
    'X-Content-Type-Options':'nosniff',
    'X-Ascenda-Phase-S':'wa3-stabilization-v1'
  });
  res.end(JSON.stringify(obj));
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
      'User-Agent':'AscendaOS-Phase-S/1.0'
    };
    if(data)headers['Content-Length']=Buffer.byteLength(data);
    const q=https.request({
      hostname:sb.hostname,
      port:sb.port||443,
      path:endpoint,
      method,
      headers,
      timeout:8000
    },r=>{
      let raw='';
      r.on('data',c=>raw+=c);
      r.on('end',()=>{
        const out={status:r.statusCode||502,data:parseData(raw),raw};
        if(out.status>=200&&out.status<300)return resolve(out);
        reject(Object.assign(new Error('PHASE_S_DB_UNAVAILABLE'),{status:502,upstreamStatus:out.status,data:out.data}));
      });
    });
    q.on('timeout',()=>q.destroy(Object.assign(new Error('PHASE_S_DB_TIMEOUT'),{status:504})));
    q.on('error',reject);
    if(data)q.write(data);
    q.end();
  });
}
const sbRpc=(name,payload)=>sbRequest('POST','/rest/v1/rpc/'+name,payload,false);
const serviceGet=endpoint=>sbRequest('GET',endpoint,null,true);

async function actor(req){
  const token=strongToken(req);
  if(!token)return null;
  try{
    const out=await sbRpc('aos_wa3_actor_v1',{p_token:token});
    const a=out.data;
    return a&&a.ok===true&&UUID_RE.test(String(a.actor_id||''))?a:null;
  }catch(_){return null;}
}

async function readComponent(name,endpoint){
  const started=Date.now();
  try{
    const out=await serviceGet(endpoint);
    return {name,ok:true,data:out.data,latency_ms:Date.now()-started};
  }catch(e){
    console.warn('[PHASE-S] bootstrap component degraded',name,e.message);
    return {name,ok:false,data:null,latency_ms:Date.now()-started,error:String(e.message||'UNAVAILABLE').slice(0,80)};
  }
}

async function buildBootstrap(req){
  const a=await actor(req);
  if(!a)return {status:403,body:{ok:false,error:'WA3_2FA_PANEL_REQUIRED'}};

  const parts=await Promise.all([
    readComponent('control','/rest/v1/aos_wa_routing_control_v1?select=auto_routing_enabled,human_send_enabled,ai_send_enabled,updated_at&id=eq.1'),
    readComponent('boxes','/rest/v1/aos_wa_boxes_v1?select=id,code,name,status,routing_strategy,is_default,priority,updated_at&order=is_default.desc,priority.desc,name.asc'),
    readComponent('members','/rest/v1/aos_wa_box_members_v1?select=box_id,user_id,active,max_active,priority,last_assigned_at&order=priority.desc,last_assigned_at.asc.nullsfirst'),
    readComponent('users','/rest/v1/aos_usuarios?select=id,nombre,rol,cargo,sede,activo,nivel_jerarquia,paneles_acceso&activo=eq.true&order=nombre.asc')
  ]);
  const map={};parts.forEach(p=>{map[p.name]=p;});

  let control=(map.control.ok&&Array.isArray(map.control.data)?map.control.data[0]:null)||{
    auto_routing_enabled:false,
    human_send_enabled:false,
    ai_send_enabled:false,
    degraded:true
  };
  let boxes=map.boxes.ok&&Array.isArray(map.boxes.data)?map.boxes.data:[];
  let members=map.members.ok&&Array.isArray(map.members.data)?map.members.data:[];
  let users=map.users.ok&&Array.isArray(map.users.data)?map.users.data:[];

  if(a.is_admin!==true){
    members=members.filter(m=>m.user_id===a.actor_id&&m.active===true);
    const allowedBoxes=new Set(members.map(m=>m.box_id));
    boxes=boxes.filter(b=>allowedBoxes.has(b.id));
    users=users.filter(u=>u.id===a.actor_id);
  }
  const me=users.find(u=>u.id===a.actor_id)||{id:a.actor_id};
  if(a.is_admin!==true){
    users=users.map(u=>({
      id:u.id,nombre:u.nombre,rol:u.rol,cargo:u.cargo,sede:u.sede,
      activo:u.activo,nivel_jerarquia:u.nivel_jerarquia
    }));
  }

  const degraded=parts.filter(p=>!p.ok).map(p=>p.name);
  return {status:200,body:{
    ok:true,
    version:'WA3-V1+PHASE-S',
    actor:{id:a.actor_id,is_admin:a.is_admin===true,name:me.nombre||null},
    control,
    boxes,
    members,
    users,
    canary:{
      enabled:String(WA_CANARY_MODE).toLowerCase()==='true',
      allowlist_count:String(WA_CANARY_ALLOW_TO).split(',').map(x=>x.trim()).filter(Boolean).length
    },
    stability:{
      mode:degraded.length?'DEGRADED':'NATIVE',
      recovery_required:false,
      degraded_components:degraded,
      components:parts.map(p=>({name:p.name,ok:p.ok,latency_ms:p.latency_ms,error:p.ok?null:p.error}))
    }
  }};
}

async function handleBootstrap(req,res){
  const out=await buildBootstrap(req);
  writeJson(res,out.status,out.body);
}
async function handlePhaseStatus(req,res){
  const a=await actor(req);
  if(!a)return writeJson(res,403,{ok:false,error:'PHASE_S_2FA_REQUIRED'});
  const snapshot=await buildBootstrap(req);
  if(snapshot.status!==200)return writeJson(res,snapshot.status,snapshot.body);
  writeJson(res,200,{
    ok:true,
    phase:'S',
    runtime:'server-phase-s.js',
    child_alive:childAlive,
    bootstrap_mode:snapshot.body.stability.mode,
    degraded_components:snapshot.body.stability.degraded_components,
    human_send_enabled:!!(snapshot.body.control&&snapshot.body.control.human_send_enabled),
    auto_routing_enabled:!!(snapshot.body.control&&snapshot.body.control.auto_routing_enabled),
    ai_send_enabled:!!(snapshot.body.control&&snapshot.body.control.ai_send_enabled),
    canary:snapshot.body.canary
  });
}

function proxy(req,res){
  const headers=Object.assign({},req.headers,{host:'127.0.0.1:'+INNER_PORT});
  const q=http.request({hostname:'127.0.0.1',port:INNER_PORT,path:req.url,method:req.method,headers},r=>{
    res.writeHead(r.statusCode||502,r.headers);
    r.pipe(res);
  });
  q.on('error',e=>{
    console.error('[PHASE-S] upstream',e.message);
    if(!res.headersSent)writeJson(res,502,{ok:false,error:'PHASE_S_UPSTREAM_UNAVAILABLE'});else res.end();
  });
  req.pipe(q);
}

const server=http.createServer(async(req,res)=>{
  let u;try{u=new URL(req.url,'http://localhost');}catch(_){return writeJson(res,400,{ok:false,error:'INVALID_URL'});}
  const p=u.pathname;
  if(req.method==='GET'&&p==='/health')return writeJson(res,childAlive?200:503,{ok:childAlive,service:'ascenda-phase-s',child_alive:childAlive});
  if(req.method==='GET'&&p==='/api/wa3/bootstrap')return handleBootstrap(req,res);
  if(req.method==='GET'&&p==='/api/phase-s/status')return handlePhaseStatus(req,res);
  return proxy(req,res);
});

server.listen(EXTERNAL_PORT,'0.0.0.0',()=>console.log('[PHASE-S] stabilization boundary listening',{external:EXTERNAL_PORT,inner:INNER_PORT}));
function shutdown(sig){
  console.log('[PHASE-S] shutdown',sig);
  try{child.kill(sig);}catch(_){}
  server.close(()=>process.exit(0));
  setTimeout(()=>process.exit(1),5000).unref();
}
process.on('SIGTERM',()=>shutdown('SIGTERM'));
process.on('SIGINT',()=>shutdown('SIGINT'));
