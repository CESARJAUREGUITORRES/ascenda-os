from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parent


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


def write(rel, text):
    (ROOT / rel).write_text(text, encoding='utf-8')


def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    if new in text:
        return text
    raise SystemExit(f'K1 internal boundary: {label} anchor missing')


# -----------------------------------------------------------------------------
# Node server: service-role REST helpers, internal writers/readers and narrow
# authenticated feeds for current UI consumers.
# -----------------------------------------------------------------------------
server = read('server.js')

service_helpers = r'''
function sbServiceGet(endpoint) {
  if (!SB_SERVICE_KEY) return Promise.reject(new Error('Server auth not configured'))
  var url = new URL(SB_URL + endpoint)
  return new Promise(function(resolve,reject) {
    var rq=https.request({hostname:url.hostname,path:url.pathname+url.search,method:'GET',headers:{'apikey':SB_SERVICE_KEY,'Authorization':'Bearer '+SB_SERVICE_KEY,'Accept':'application/json'}},function(r){
      var d='';r.on('data',function(c){d+=c});r.on('end',function(){
        if(r.statusCode<200||r.statusCode>=300){reject(new Error('Supabase service GET '+r.statusCode));return}
        try{resolve(d?JSON.parse(d):null)}catch(e){reject(new Error('Invalid service GET response'))}
      })
    });rq.on('error',reject);rq.end()
  })
}
function sbServicePost(endpoint, body, method) {
  if (!SB_SERVICE_KEY) return Promise.reject(new Error('Server auth not configured'))
  var url=new URL(SB_URL+endpoint), verb=method||'POST', data=JSON.stringify(body||{})
  return new Promise(function(resolve,reject){
    var rq=https.request({hostname:url.hostname,path:url.pathname+url.search,method:verb,headers:{'apikey':SB_SERVICE_KEY,'Authorization':'Bearer '+SB_SERVICE_KEY,'Content-Type':'application/json','Content-Length':Buffer.byteLength(data),'Prefer':'return=minimal'}},function(r){
      var d='';r.on('data',function(c){d+=c});r.on('end',function(){if(r.statusCode<200||r.statusCode>=300){reject(new Error('Supabase service write '+r.statusCode));return}resolve(r.statusCode)})
    });rq.on('error',reject);rq.write(data);rq.end()
  })
}
'''
if 'function sbServiceGet(endpoint)' not in server:
    anchor = 'function bearerToken(req) {'
    if anchor not in server:
        raise SystemExit('K1 internal boundary: bearerToken anchor missing')
    server = server.replace(anchor, service_helpers + '\n' + anchor, 1)

# Internal server-originated audit/telemetry writes must not depend on anon ACL.
for table in ('aos_kronia_conversaciones','aos_agente_logs','aos_agente_acciones','aos_log_auditoria'):
    server = server.replace("sbPost('/rest/v1/" + table, "sbServicePost('/rest/v1/" + table)
# Internal reads that K1 makes browser-private.
server = server.replace("sbFetch('/rest/v1/aos_security_log?", "sbServiceGet('/rest/v1/aos_security_log?")
server = server.replace("sbFetch('/rest/v1/aos_agente_logs?", "sbServiceGet('/rest/v1/aos_agente_logs?")

routes = r'''
  // ═══ K1 INTERNAL FEEDS — tokenized, sanitized, service-backed ═══
  if (p === '/api/agents/logs' && req.method === 'GET') {
    // /api/agents/* is already guarded by requireKroniaAdmin in K1 middleware.
    try {
      var lu = new URL(req.url,'http://localhost')
      var lim = Math.min(Math.max(parseInt(lu.searchParams.get('limit')||'40',10)||40,1),5000)
      var agentId = String(lu.searchParams.get('agent_id')||'')
      var since = String(lu.searchParams.get('since')||'')
      var success = String(lu.searchParams.get('success')||'')
      if (agentId && !/^[A-Za-z0-9_.-]{1,80}$/.test(agentId)) { res.writeHead(400,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'agent_id inválido'}));return }
      if (since && isNaN(Date.parse(since))) { res.writeHead(400,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'since inválido'}));return }
      var q=['select=id,agente_id,tarea_id,accion,input_resumen,output_resumen,resultado,motor_usado,modelo_usado,tokens_input,tokens_output,costo_usd,duracion_ms,exitoso,error,created_at','order=created_at.desc','limit='+lim]
      if(agentId) q.push('agente_id=eq.'+encodeURIComponent(agentId))
      if(since) q.push('created_at=gte.'+encodeURIComponent(new Date(since).toISOString()))
      if(success==='true'||success==='false') q.push('exitoso=eq.'+success)
      sbServiceGet('/rest/v1/aos_agente_logs?'+q.join('&')).then(function(rows){res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:true,logs:Array.isArray(rows)?rows:[]}))}).catch(function(){res.writeHead(502,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'Agent log backend unavailable'}))})
    } catch(e) { res.writeHead(400,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'Consulta inválida'})) }
    return
  }

  if (p === '/api/kronia/audit-feed' && req.method === 'GET') {
    var feedIdentity = await verifyKroniaBearer(req)
    if (!feedIdentity.ok) { res.writeHead(feedIdentity.status||401,{'Content-Type':'application/json'});res.end(JSON.stringify(feedIdentity));return }
    try {
      var fu = new URL(req.url,'http://localhost')
      var afterId = Math.max(parseInt(fu.searchParams.get('after_id')||'0',10)||0,0)
      var flim = Math.min(Math.max(parseInt(fu.searchParams.get('limit')||'20',10)||20,1),100)
      var fq=['select=id,tabla,accion,ts,timestamp_reg','limit='+flim]
      if(afterId>0){fq.push('id=gt.'+afterId);fq.push('order=id.asc')}else{fq.push('order=id.desc')}
      sbServiceGet('/rest/v1/aos_log_auditoria?'+fq.join('&')).then(function(rows){res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:true,events:Array.isArray(rows)?rows:[]}))}).catch(function(){res.writeHead(502,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'Audit feed unavailable'}))})
    } catch(e) { res.writeHead(400,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'Consulta inválida'})) }
    return
  }

  if (p === '/api/kronia/admin/security-dashboard' && req.method === 'GET') {
    var secIdentity = await requireKroniaAdmin(req)
    if (!secIdentity.ok) { res.writeHead(secIdentity.status||401,{'Content-Type':'application/json'});res.end(JSON.stringify(secIdentity));return }
    Promise.all([
      sbServiceRpc('aos_security_dashboard',{}),
      sbServiceGet('/rest/v1/aos_log_auditoria?select=id,ts,timestamp_reg,usuario,asesor,accion,tabla,registro_id,detalle,referencia&order=ts.desc.nullsfirst,timestamp_reg.desc.nullsfirst&limit=50')
    ]).then(function(parts){
      var d=parts[0]||{}, audit=Array.isArray(parts[1])?parts[1]:[]
      if(Array.isArray(d)) d=d[0]||{}
      var out=Object.assign({},d,{audit:audit})
      res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify(out))
    }).catch(function(){res.writeHead(502,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'Security dashboard unavailable'}))})
    return
  }
'''
if "p === '/api/agents/logs'" not in server:
    anchor = '  // ===== AGENTS THINK-LOOP API ====='
    if anchor not in server:
        raise SystemExit('K1 internal boundary: agents API anchor missing')
    server = server.replace(anchor, routes + '\n' + anchor, 1)

write('server.js', server)

# -----------------------------------------------------------------------------
# Agent Office: all privileged agent endpoints + log feed use ADMIN Bearer.
# -----------------------------------------------------------------------------
agents = read('public/agents.html')
if 'function k1AgentHeaders(extra)' not in agents:
    anchor = '// ————— Palette (Ascenda) —————'
    helper = r'''
function k1AgentToken(){
  try{return sessionStorage.getItem('aos_kronia_token')||(window.parent&&window.parent!==window?window.parent.sessionStorage.getItem('aos_kronia_token'):'')||''}catch(e){return ''}
}
function k1AgentHeaders(extra){
  var h=Object.assign({},extra||{}),t=k1AgentToken();if(t)h.Authorization='Bearer '+t;return h
}
function secureAgentLogs(opts){
  opts=opts||{};var q=[]
  if(opts.limit)q.push('limit='+encodeURIComponent(opts.limit))
  if(opts.agent_id)q.push('agent_id='+encodeURIComponent(opts.agent_id))
  if(opts.since)q.push('since='+encodeURIComponent(opts.since))
  if(typeof opts.success==='boolean')q.push('success='+opts.success)
  return fetch(RAILWAY_URL+'/api/agents/logs?'+q.join('&'),{headers:k1AgentHeaders()}).then(function(r){if(!r.ok)throw new Error('agent logs '+r.status);return r.json()}).then(function(j){return j&&Array.isArray(j.logs)?j.logs:[]})
}
'''
    if anchor not in agents:
        raise SystemExit('K1 internal boundary: agent helper anchor missing')
    agents = agents.replace(anchor, helper + '\n' + anchor, 1)

# Authenticate rwPost and direct agent API calls.
agents = agents.replace("headers: { 'Content-Type': 'application/json' },", "headers: k1AgentHeaders({ 'Content-Type': 'application/json' }),")
agents = agents.replace("fetch(window.RAILWAY_URL + '/api/agents/costs')", "fetch(window.RAILWAY_URL + '/api/agents/costs',{headers:k1AgentHeaders()})")

# Replace direct agent-log table reads with the protected feed.
agents = agents.replace("window.sbGet('/rest/v1/aos_agente_logs?order=created_at.desc&limit=40&select=agente_id,accion,input_resumen,output_resumen,exitoso,error')", "secureAgentLogs({limit:40})")
agents = agents.replace("window.sbGet('/rest/v1/aos_agente_logs?order=created_at.desc&limit=20&select=agente_id,accion,input_resumen,exitoso,error,duracion_ms,created_at')", "secureAgentLogs({limit:20})")
agents = agents.replace("window.sbGet('/rest/v1/aos_agente_logs?agente_id=eq.' + agent.id + '&order=created_at.desc&limit=20')", "secureAgentLogs({agent_id:agent.id,limit:20})")
agents = agents.replace("window.sbGet('/rest/v1/aos_agente_logs?created_at=gte.' + limaDate + 'T05:00:00Z&exitoso=eq.true&select=id')", "secureAgentLogs({since:limaDate+'T05:00:00Z',success:true,limit:5000})")

write('public/agents.html', agents)

# -----------------------------------------------------------------------------
# Main app agent notification bootstrap: no direct agent-log table read.
# -----------------------------------------------------------------------------
app = read('public/app.html')
pattern = re.compile(r"fetch\('https://ituyqwstonmhnfshnaqz\.supabase\.co/rest/v1/aos_agente_logs\?order=created_at\.desc&limit=8&select=agente_id,accion,input_resumen,exitoso,error,created_at',\s*\{\s*headers:\s*\{[^}]+\}\s*\}\)\.then\(function\(r\) \{ return r\.json\(\); \}\)", re.S)
replacement = "fetch('/api/agents/logs?limit=8',{headers:{'Authorization':'Bearer '+(sessionStorage.getItem('aos_kronia_token')||'')}}).then(function(r){return r.json()}).then(function(j){return j&&Array.isArray(j.logs)?j.logs:[]})"
if pattern.search(app):
    app = pattern.sub(replacement, app, count=1)
elif "/api/agents/logs?limit=8" not in app:
    raise SystemExit('K1 internal boundary: app agent-feed anchor missing')
write('public/app.html', app)

# -----------------------------------------------------------------------------
# Security Config: dashboard + audit data are served by ADMIN bearer endpoint.
# -----------------------------------------------------------------------------
config = read('public/admin-config.html')
sec_pattern = re.compile(r"function loadSecurityDashboard\(\)\{.*?\n\}\nfunction renderSecKPIs", re.S)
sec_replacement = r'''function loadSecurityDashboard(){
  loadConfig();
  var tok=sessionStorage.getItem('aos_kronia_token')||'';
  if(!tok){showToast('Sesión segura requerida','err');return;}
  fetch('/api/kronia/admin/security-dashboard',{headers:{'Authorization':'Bearer '+tok}}).then(function(r){return r.json()}).then(function(d){
    if(!d||!d.ok)return;
    _secData=d;
    renderSecKPIs(d);
    renderSecLayers(d.capas);
    renderSecAlerts(d);
    renderSecEvents(d.events||[]);
    renderSecAccesos(d.accesos||[]);
    renderSecAudit(d.audit||[]);
  });
}
function renderSecKPIs'''
if sec_pattern.search(config):
    config = sec_pattern.sub(sec_replacement, config, count=1)
elif "/api/kronia/admin/security-dashboard" not in config:
    raise SystemExit('K1 internal boundary: security dashboard anchor missing')
write('public/admin-config.html', config)

# -----------------------------------------------------------------------------
# Brain: replace direct audit REST/Realtime exposure with bearer audit feed.
# Polling remains at 8s so proactivity is preserved without public DB access.
# -----------------------------------------------------------------------------
brain = read('public/cerebro.html')
check_pattern = re.compile(r"function checkSB\(\)\{.*?\n\}\nsetInterval\(checkSB, 30000\);", re.S)
check_repl = r'''function k1BrainToken(){try{return sessionStorage.getItem('aos_kronia_token')||(window.parent&&window.parent!==window?window.parent.sessionStorage.getItem('aos_kronia_token'):'')||''}catch(e){return ''}}
function checkSB(){
  var tok=k1BrainToken();if(!tok){setSBStatus(false,'Sesión requerida');return;}
  fetch('/api/kronia/audit-feed?limit=1',{headers:{'Authorization':'Bearer '+tok},cache:'no-store'}).then(r=>{
    if(r.ok){sbBackoff=0;setSBStatus(true);}else{setSBStatus(false,'Backend '+r.status);}
  }).catch(()=>setSBStatus(false,'Sin conexión'));
}
setInterval(checkSB, 30000);'''
if check_pattern.search(brain):
    brain = check_pattern.sub(check_repl, brain, count=1)
elif "function k1BrainToken()" not in brain:
    raise SystemExit('K1 internal boundary: Brain connectivity anchor missing')

rt_pattern = re.compile(r"let ws=null, wsR=0;.*?connectRT\(\);", re.S)
rt_repl = "// K1: direct Realtime subscription to audit table removed; secure 8s polling below preserves proactivity."
if rt_pattern.search(brain):
    brain = rt_pattern.sub(rt_repl, brain, count=1)
elif "direct Realtime subscription to audit table removed" not in brain:
    raise SystemExit('K1 internal boundary: Brain realtime anchor missing')

poll_pattern = re.compile(r"let lastId=0;\nasync function poll\(\)\{.*?setInterval\(poll, 8000\);", re.S)
poll_repl = r'''let lastId=0;
async function poll(){
  try{
    var tok=k1BrainToken();if(!tok)return;
    const r=await fetch('/api/kronia/audit-feed?after_id='+lastId+'&limit=10',{headers:{'Authorization':'Bearer '+tok}});
    const j=await r.json(),rows=j&&Array.isArray(j.events)?j.events:[];
    if(rows.length){rows.forEach(row=>{if(row.tabla&&row.tabla!=='sistema')activateTable(row.tabla,row.accion);lastId=Math.max(lastId,row.id);});}
  }catch(_){}
}
(function initAuditFeed(){
  var tok=k1BrainToken();if(!tok)return;
  fetch('/api/kronia/audit-feed?limit=1',{headers:{'Authorization':'Bearer '+tok}}).then(r=>r.json()).then(j=>{var d=j&&j.events;if(d&&d[0])lastId=d[0].id;});
})();
setInterval(poll, 8000);'''
if poll_pattern.search(brain):
    brain = poll_pattern.sub(poll_repl, brain, count=1)
elif "/api/kronia/audit-feed?after_id=" not in brain:
    raise SystemExit('K1 internal boundary: Brain poll anchor missing')

write('public/cerebro.html', brain)

# Final artifact manifest must describe the actual files Railway will serve.
targets = [
    'server.js','public/app.html','public/kronia-core.js','public/login.html',
    'public/admin-sales.html','public/admin-config.html','public/agents.html','public/cerebro.html'
]
manifest={'contract':'kronia-k1-runtime-v2','files':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in targets}}
(ROOT/'k1-runtime-manifest.json').write_text(json.dumps(manifest,sort_keys=True,indent=2)+'\n',encoding='utf-8')
print('KRONIA_K1_INTERNAL_BOUNDARY=PASS')
for path,digest in manifest['files'].items():print(path+' '+digest)
