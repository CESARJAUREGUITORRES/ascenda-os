from pathlib import Path
import re

ROOT = Path('.')

class PatchError(RuntimeError):
    pass

def read(path):
    return (ROOT / path).read_text(encoding='utf-8')

def write(path, text):
    (ROOT / path).write_text(text, encoding='utf-8')

def sub_once(text, pattern, repl, label, flags=0):
    out, n = re.subn(pattern, repl, text, count=1, flags=flags)
    if n != 1:
        raise PatchError(f'{label}: expected 1 replacement, got {n}')
    return out

def ensure(text, needle, label):
    if needle not in text:
        raise PatchError(f'{label}: missing expected marker {needle!r}')

# -----------------------------------------------------------------------------
# SQL: qualify pgcrypto with empty search_path, close raw auth RPCs, preserve
# safe integration metadata, and make extension compatibility claim server-only.
# -----------------------------------------------------------------------------
path = 'supabase/migrations/20260814051500_kronia_k1_identity_session_hardening.sql'
sql = read(path)
sql = re.sub(r'(?<!extensions\.)\bdigest\(', 'extensions.digest(', sql)
sql = re.sub(r'(?<!extensions\.)\bgen_random_bytes\(', 'extensions.gen_random_bytes(', sql)
if 'aos_login_v2(text,text)' not in sql:
    marker = "-- Legacy token administration is never browser-callable."
    auth_revoke = """-- Login/2FA primitives are server-only; their legacy return payload contains\n-- material that must never cross the browser trust boundary.\nrevoke execute on function public.aos_login_v2(text,text) from public,anon,authenticated;\nrevoke execute on function public.aos_verificar_2fa(text,text) from public,anon,authenticated;\n\n"""
    sql = sql.replace(marker, auth_revoke + marker, 1)
# url_api is metadata/documentation endpoint, not a credential.
sql = sql.replace('url_docs,url_signup,multi_cuenta,logo_url)', 'url_api,url_docs,url_signup,multi_cuenta,logo_url)')
write(path, sql)

path = 'supabase/migrations/20260814051600_kronia_k1_extension_claim.sql'
sql2 = read(path)
sql2 = re.sub(r'(?<!extensions\.)\bdigest\(', 'extensions.digest(', sql2)
sql2 = re.sub(r'(?<!extensions\.)\bgen_random_bytes\(', 'extensions.gen_random_bytes(', sql2)
sql2 = sql2.replace(
    "grant execute on function public.aos_kronia_claim_verified_2fa(text,text,text,text,text) to anon,authenticated;",
    "grant execute on function public.aos_kronia_claim_verified_2fa(text,text,text,text,text) to service_role;"
)
write(path, sql2)

# -----------------------------------------------------------------------------
# Server: environment-only secrets, service-only auth primitives, bearer-only
# KronIA/voice, authoritative tool gateway for mutation, and admin-gated agents.
# -----------------------------------------------------------------------------
path = 'app/server.js'
s = read(path)

s = re.sub(r"const VERIFY_TOKEN\s*=\s*[^\n]+", "const VERIFY_TOKEN = process.env.ASCENDA_VERIFY_TOKEN || ''", s, count=1)
# Add server-only Supabase key beside the existing public anon key.
if 'SUPABASE_SERVICE_ROLE_KEY' not in s:
    s = sub_once(s, r"(const SB_KEY\s*=\s*[^\n]+\n)", r"\1const SB_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || ''\n", 'service role env')

# Remove all hardcoded provider fallbacks. Never copy legacy values into the patch.
s = re.sub(r"process\.env\.RESEND_API_KEY\s*\|\|\s*['\"][^'\"]+['\"]", "process.env.RESEND_API_KEY || ''", s)
s = re.sub(r"process\.env\.GROQ_API_KEY\s*\|\|\s*['\"][^'\"]+['\"]", "process.env.GROQ_API_KEY || ''", s)
s = re.sub(r"process\.env\.GEMINI_API_KEY\s*\|\|\s*['\"][^'\"]+['\"]", "process.env.GEMINI_API_KEY || ''", s)
# Known Turnstile secret assignment/fallback forms.
s = re.sub(r"var TURNSTILE_SECRET\s*=\s*[^\n]+", "var TURNSTILE_SECRET = process.env.TURNSTILE_SECRET_KEY || ''", s)
s = re.sub(r"const TURNSTILE_SECRET\s*=\s*[^\n]+", "const TURNSTILE_SECRET = process.env.TURNSTILE_SECRET_KEY || ''", s)

# Server-side service RPC and auth helpers, inserted once before legacy validator.
if 'function sbServiceRpc(' not in s:
    helper = r'''
function sbServiceRpc(fnName, params) {
  if (!SB_SERVICE_KEY) return Promise.resolve({ ok:false, error:'Server auth not configured' })
  var url = new URL(SB_URL + '/rest/v1/rpc/' + fnName)
  var data = JSON.stringify(params || {})
  return new Promise(function(resolve) {
    var rq = https.request({
      hostname:url.hostname, path:url.pathname, method:'POST',
      headers:{'apikey':SB_SERVICE_KEY,'Authorization':'Bearer '+SB_SERVICE_KEY,'Content-Type':'application/json','Content-Length':Buffer.byteLength(data)}
    }, function(r){ var d=''; r.on('data',function(c){d+=c}); r.on('end',function(){ try{resolve(JSON.parse(d))}catch(e){resolve({ok:false,error:'Invalid server auth response'})} }) })
    rq.on('error', function(){ resolve({ok:false,error:'Server auth transport error'}) }); rq.write(data); rq.end()
  })
}
function bearerToken(req) { return String((req.headers && req.headers.authorization) || '').replace(/^Bearer\s+/i,'').trim() }
function verifyKroniaBearer(req) {
  var tok = bearerToken(req)
  if (!tok) return Promise.resolve({ok:false,status:401,error:'Sesión KronIA requerida'})
  return sbServiceRpc('aos_kronia_verify_token',{p_token:tok}).then(function(v){
    if (!v || !v.ok) return {ok:false,status:401,error:(v&&v.error)||'Sesión inválida'}
    v.token = tok; return v
  })
}
function requireKroniaAdmin(req) {
  return verifyKroniaBearer(req).then(function(v){
    if (!v.ok) return v
    if (String(v.rol||'').toUpperCase() !== 'ADMIN') return {ok:false,status:403,error:'Administrador requerido'}
    return v
  })
}
function kroniaTool(token, tool, params) {
  return sbServiceRpc('aos_kronia_tool',{p_token:token,p_tool:tool,p_params:params||{}})
}
function send2FAEmail(email, code, nombre) {
  var key = process.env.RESEND_API_KEY || ''
  if (!key || !email || !code) return Promise.resolve(false)
  var payload = JSON.stringify({
    from:'Ascenda OS <noreply@zivital.pe>', to:[email], subject:'Código de verificación Ascenda OS',
    html:'<div style="font-family:Arial,sans-serif"><h2>Ascenda OS</h2><p>Hola '+String(nombre||'')+'. Tu código de verificación es:</p><div style="font-size:28px;font-weight:700;letter-spacing:6px">'+String(code)+'</div><p>Este código expira en pocos minutos.</p></div>'
  })
  return new Promise(function(resolve){
    var rq=https.request({hostname:'api.resend.com',path:'/emails',method:'POST',headers:{'Authorization':'Bearer '+key,'Content-Type':'application/json','Content-Length':Buffer.byteLength(payload)}},function(r){var d='';r.on('data',function(c){d+=c});r.on('end',function(){resolve(r.statusCode>=200&&r.statusCode<300)})})
    rq.on('error',function(){resolve(false)});rq.write(payload);rq.end()
  })
}
function sanitizeLoginResult(x) {
  var out = Object.assign({}, x || {})
  delete out.code; delete out.codigo; delete out.email_real; delete out.password; delete out.password_hash
  return out
}
function startKroniaLogin(login, password, origin, deviceInfo, ip) {
  if (!login || !password) return Promise.resolve({ok:false,error:'Usuario y contraseña requeridos'})
  return sbServiceRpc('aos_login_v2',{p_usuario:String(login).toLowerCase(),p_password:password}).then(function(r){
    if (!r || !r.ok) return sanitizeLoginResult(r)
    if (r.require_2fa) {
      return send2FAEmail(r.email_real,r.code,r.nombre).then(function(sent){
        var clean=sanitizeLoginResult(r); clean.delivery_ok=!!sent; return clean
      })
    }
    return sbServiceRpc('aos_kronia_claim_session',{p_login_usuario:login,p_password:password,p_2fa_codigo:null,p_device_info:deviceInfo||'',p_ip_origen:ip||'',p_origen:origin||'web'}).then(function(k){
      var clean=sanitizeLoginResult(r); if(k&&k.ok){clean.kronia_token=k.token;clean.kronia_expira_at=k.expira_at;clean.rol=k.rol;clean.sede=k.sede;clean.id_asesor=k.id_asesor} return clean
    })
  })
}
function verifyKroniaLogin(login, password, code, origin, deviceInfo, ip) {
  if (!login || !password || !code) return Promise.resolve({ok:false,error:'Credenciales y código requeridos'})
  return sbServiceRpc('aos_verificar_2fa',{p_usuario:login,p_codigo:code}).then(function(v){
    if(!v||!v.ok) return sanitizeLoginResult(v)
    return sbServiceRpc('aos_kronia_claim_session',{p_login_usuario:login,p_password:password,p_2fa_codigo:code,p_device_info:deviceInfo||'',p_ip_origen:ip||'',p_origen:origin||'web'}).then(function(k){
      var clean=sanitizeLoginResult(v); if(k&&k.ok){clean.kronia_token=k.token;clean.token=k.token;clean.kronia_expira_at=k.expira_at;clean.rol=k.rol;clean.sede=k.sede;clean.id_asesor=k.id_asesor;clean.usuario=k.usuario} else {return k} return clean
    })
  })
}
'''
    s = sub_once(s, r"\nfunction validarSesionKronia\(", '\n' + helper + '\nfunction validarSesionKronia(', 'insert auth helpers')

# Whisper provider secret must be environment-only.
if "function procesarWhisper(chunks, res)" in s:
    s = sub_once(s,
        r"function procesarWhisper\(chunks, res\) \{.*?\n\}\n(?=\nfunction procesarKroniaChat)",
        r'''function procesarWhisper(chunks, res) {
  var GROQ = process.env.GROQ_API_KEY || ''
  if(!GROQ){res.writeHead(503,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'Voice provider not configured'}));return}
  var audio=Buffer.concat(chunks), boundary='----KroniaBoundary'+Date.now()
  var head='--'+boundary+'\r\nContent-Disposition: form-data; name="file"; filename="audio.webm"\r\nContent-Type: audio/webm\r\n\r\n'
  var tail='\r\n--'+boundary+'\r\nContent-Disposition: form-data; name="model"\r\n\r\nwhisper-large-v3-turbo\r\n--'+boundary+'--\r\n'
  var payload=Buffer.concat([Buffer.from(head),audio,Buffer.from(tail)])
  var rq=https.request({hostname:'api.groq.com',path:'/openai/v1/audio/transcriptions',method:'POST',headers:{'Authorization':'Bearer '+GROQ,'Content-Type':'multipart/form-data; boundary='+boundary,'Content-Length':payload.length}},function(r){var d='';r.on('data',function(c){d+=c});r.on('end',function(){try{var j=JSON.parse(d);res.writeHead(r.statusCode||200,{'Content-Type':'application/json'});res.end(JSON.stringify(j.text?{ok:true,text:j.text}:{ok:false,error:j.error&&j.error.message||'Transcription failed'}))}catch(e){res.writeHead(502,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'Invalid transcription response'}))}})})
  rq.on('error',function(){res.writeHead(502,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'Voice provider unavailable'}))});rq.write(payload);rq.end()
}''', 'whisper env-only', flags=re.S)

# Mutation execution must go through token-bound gateway. Keep context reads inside
# trusted server for K1; K2 will type every read tool.
s = s.replace('function procesarKroniaChat(d, pregunta, usuario, rol, sede, sessionId, res)', 'function procesarKroniaChat(d, pregunta, usuario, rol, sede, sessionId, authToken, res)')
s = s.replace('sbRpc(confirmarAccion.rpc, params).then(function(result) {', "params._session_id=sessionId; kroniaTool(authToken, confirmarAccion.rpc, params).then(function(result) {")
# Remove obsolete client-shaped audit write if present; gateway is authoritative.
s = re.sub(r"\n\s*sbPost\('/rest/v1/aos_kronia_acciones'.*?\.catch\(function\(\)\{\}\)\s*", '\n', s, flags=re.S)

# Provider key loader for agent runtime becomes env-only.
s = re.sub(r"var GROQ_KEY = ''\s*\nvar GEMINI_KEY = ''", "var GROQ_KEY = process.env.GROQ_API_KEY || ''\nvar GEMINI_KEY = process.env.GEMINI_API_KEY || ''", s, count=1)
s = re.sub(r"// Load AI keys from Supabase on startup\s*\nfunction loadAIKeys\(\) \{.*?\n\}", "// Provider credentials are injected by the server environment.\nfunction loadAIKeys(){ console.log('[AGENTS] Provider config — Groq:',GROQ_KEY?'YES':'NO','| Gemini:',GEMINI_KEY?'YES':'NO') }", s, count=1, flags=re.S)
# Studio's nested provider key resolver becomes environment-backed.
s = re.sub(r"/\* Leer keys de Supabase integraciones \*/\s*function getKey\(tipo, cb\) \{.*?\n\s*getKey\('gemini'", "/* Provider keys live in the server environment */\n        function getKey(tipo, cb){ var map={gemini:process.env.GEMINI_API_KEY||'',openai:process.env.OPENAI_API_KEY||'',groq:process.env.GROQ_API_KEY||''}; cb(map[tipo]||'') }\n        getKey('gemini'", s, count=1, flags=re.S)
# Generic legacy secret reads must not survive K1.
s = s.replace("/rest/v1/aos_integraciones?tipo=eq.groq&estado=eq.conectado&select=api_key&limit=1", "/rest/v1/aos_integraciones?tipo=eq.groq&estado=eq.conectado&select=nombre&limit=1")

# Main handler becomes async and gates every /api/agents/* route before dispatch.
s = s.replace('http.createServer(function(req, res) {', 'http.createServer(async function(req, res) {', 1)
if "p.startsWith('/api/agents/')" not in s.split("http.createServer(async function(req, res) {",1)[1][:1200]:
    s = sub_once(s, r"(http\.createServer\(async function\(req, res\) \{\s*\n\s*var p = req\.url\.split\('\?'\)\[0\]\s*\n)", r"\1  if (p.startsWith('/api/agents/') && req.method !== 'OPTIONS') {\n    var agentIdentity = await requireKroniaAdmin(req)\n    if (!agentIdentity.ok) { res.writeHead(agentIdentity.status||401,{'Content-Type':'application/json','Access-Control-Allow-Origin':'*'}); res.end(JSON.stringify({ok:false,error:agentIdentity.error})); return }\n  }\n", 'agent admin middleware')

# Replace extension auth routes with server-authoritative auth plus web aliases.
s = sub_once(s,
    r"\s*// ═══ KRONIA EXT — STEP 1: REQUEST CODE.*?(?=\s*// ═══ KRONIA EXT — VERIFY TOKEN)",
    r'''
  // ═══ K1 AUTH — SERVER-AUTHORITATIVE LOGIN / 2FA ═══
  if ((p === '/api/auth/login' || p === '/api/kronia/login-request') && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin','*'); var body=''; req.on('data',function(c){body+=c}); req.on('end',function(){
      try{var d=JSON.parse(body||'{}');var login=(d.usuario||d.p_usuario||'').trim();var password=d.password||d.p_password||'';startKroniaLogin(login,password,p.indexOf('/kronia/')>=0?'chrome_extension':'web',d.device_info||'',req.socket&&req.socket.remoteAddress||'').then(function(out){res.writeHead(out&&out.ok?200:401,{'Content-Type':'application/json'});res.end(JSON.stringify(out||{ok:false,error:'Login failed'}))})}catch(e){res.writeHead(400,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'JSON inválido'}))}
    }); return
  }
  if ((p === '/api/auth/verify-2fa' || p === '/api/kronia/login-verify') && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin','*'); var body=''; req.on('data',function(c){body+=c}); req.on('end',function(){
      try{var d=JSON.parse(body||'{}');var login=(d.login_usuario||d.usuario||d.p_usuario||'').trim();var password=d.password||d.p_password||'';var code=d.codigo||d.p_codigo||'';verifyKroniaLogin(login,password,code,p.indexOf('/kronia/')>=0?'chrome_extension':'web',d.device_info||'',req.socket&&req.socket.remoteAddress||'').then(function(out){res.writeHead(out&&out.ok?200:401,{'Content-Type':'application/json'});res.end(JSON.stringify(out||{ok:false,error:'2FA failed'}))})}catch(e){res.writeHead(400,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'JSON inválido'}))}
    }); return
  }
  if (p === '/api/auth/resend-2fa' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin','*'); var body=''; req.on('data',function(c){body+=c}); req.on('end',function(){
      try{var d=JSON.parse(body||'{}');var login=(d.login_usuario||d.usuario||d.p_usuario||'').trim();var password=d.password||d.p_password||'';if(!login||!password){res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:true,server_managed:true}));return}startKroniaLogin(login,password,'web',d.device_info||'',req.socket&&req.socket.remoteAddress||'').then(function(out){res.writeHead(out&&out.ok?200:401,{'Content-Type':'application/json'});res.end(JSON.stringify(out||{ok:false,error:'Resend failed'}))})}catch(e){res.writeHead(400,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'JSON inválido'}))}
    }); return
  }
''', 'replace legacy auth routes', flags=re.S)

# Bearer-only chat route.
s = sub_once(s,
    r"\s*// ═══ KRONIA CHAT — AI ASESOR CON CONTROL DE ROLES ═══.*?(?=\s*// ═══ KRONIA WHISPER)",
    r'''
  // ═══ KRONIA CHAT — K1 BEARER-ONLY ═══
  if (p === '/api/kronia/chat' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin','*'); var body=''; req.on('data',function(c){body+=c}); req.on('end',async function(){
      try{var d=JSON.parse(body||'{}');var pregunta=(d.pregunta||'').trim();if(!pregunta){res.writeHead(400,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'Pregunta requerida'}));return}var v=await verifyKroniaBearer(req);if(!v.ok){res.writeHead(v.status||401,{'Content-Type':'application/json'});res.end(JSON.stringify(v));return}procesarKroniaChat(d,pregunta,v.usuario,v.rol,v.sede,d.session_id||('ses_'+Date.now()),v.token,res)}catch(e){res.writeHead(400,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'Invalid JSON'}))}
    }); return
  }
''', 'replace chat auth', flags=re.S)

# Bearer-only Whisper route; no X-AOS identity fallback.
s = sub_once(s,
    r"\s*// ═══ KRONIA WHISPER — VOICE TO TEXT ═══.*?(?=\s*// ═══ STUDIO API)",
    r'''
  // ═══ KRONIA WHISPER — K1 BEARER-ONLY ═══
  if (p === '/api/kronia/whisper' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin','*'); var v=await verifyKroniaBearer(req);if(!v.ok){res.writeHead(v.status||401,{'Content-Type':'application/json'});res.end(JSON.stringify(v));return}var chunks=[];req.on('data',function(c){chunks.push(c)});req.on('end',function(){procesarWhisper(chunks,res)});return
  }
''', 'replace whisper auth', flags=re.S)

write(path, s)

# -----------------------------------------------------------------------------
# Shared KronIA core: extension login now requires password but never persists it.
# -----------------------------------------------------------------------------
path='app/public/kronia-core.js'; c=read(path)
if 'pendingLoginPassword' not in c:
    c=c.replace("onError: config.onError || function () {}", "onError: config.onError || function () {},\n      pendingLoginPassword: null")
    c=c.replace('function loginRequest(usuario) {', 'function loginRequest(usuario, password) {\n      state.pendingLoginPassword = password || \'\'')
    c=c.replace('body: JSON.stringify({ usuario: usuario })', 'body: JSON.stringify({ usuario: usuario, password: password || \'\' })')
    c=c.replace('codigo: codigo,\n          device_info:', "codigo: codigo,\n          password: state.pendingLoginPassword || '',\n          device_info:")
    c=c.replace("state.token = d.token;", "state.token = d.token; state.pendingLoginPassword = null;",1)
write(path,c)

# -----------------------------------------------------------------------------
# Web login: server endpoints; never display/forward server-generated 2FA material.
# -----------------------------------------------------------------------------
path='app/public/login.html'; l=read(path)
l=l.replace("/rest/v1/rpc/aos_login_v2", "/api/auth/login")
l=l.replace("/rest/v1/rpc/aos_verificar_2fa", "/api/auth/verify-2fa")
l=l.replace("/api/send-2fa", "/api/auth/resend-2fa")
l=l.replace('res.code','res.server_managed_code').replace('res.email_real','res.email_masked')
l=l.replace('p_codigo: code', "p_codigo: code, password: _SI_LOGIN_PASSWORD, login_usuario: _SI_LOGIN_USER")
if "aos_kronia_token" not in l:
    l=l.replace('function completeLogin(res) {', "function completeLogin(res) {\n      if(res && (res.kronia_token||res.token)) sessionStorage.setItem('aos_kronia_token',res.kronia_token||res.token);")
write(path,l)

# Native sales editor: same token-bound gateway as KronIA.
path='app/public/admin-sales.html'; a=read(path)
a=a.replace("fetch(SB+'/rest/v1/rpc/aos_editar_venta',{", "var kTok=sessionStorage.getItem('aos_kronia_token'); if(!kTok){document.getElementById('ev-status').innerHTML='<span style=\"color:#DC2626;\">Sesión segura requerida. Vuelve a ingresar.</span>';return;}\n  fetch(SB+'/rest/v1/rpc/aos_kronia_tool',{")
a=a.replace("body:JSON.stringify({p_venta_id:EV.ventaId, p_campos:campos, p_editado_por:usuario, p_rol:rol, p_origen:'panel_ventas'})", "body:JSON.stringify({p_token:kTok,p_tool:'aos_editar_venta',p_params:{p_venta_id:EV.ventaId,p_campos:campos,_session_id:'sales-'+Date.now()}})")
write(path,a)

# Integration config: metadata-only reads; disconnect through ADMIN gateway.
path='app/public/admin-config.html'; g=read(path)
safe='id,tipo,nombre,cuenta,estado,principal,created_at,updated_at,categoria,icono,descripcion,pasos_guia,uso_para,orden,url_api,url_docs,url_signup,multi_cuenta,logo_url'
g=g.replace("/rest/v1/aos_integraciones?select=*&order=categoria,orden", "/rest/v1/aos_integraciones?select="+safe+"&order=categoria,orden")
g=re.sub(r"function desactivarInteg\(id\)\{[^\n]*sbPatch\('/rest/v1/aos_integraciones\?id=eq\.'\+id,\{estado:'pendiente',api_key:'',api_secret:'',cuenta:''\}\)\.then\(function\(\)\{showToast\('Desactivado',''\);loadIntegraciones\(\);\}\);\}", "function desactivarInteg(id){if(!confirm('¿Desactivar este conector?'))return;var t=sessionStorage.getItem('aos_kronia_token');if(!t){showToast('Sesión segura requerida','err');return;}sbRpc('aos_kronia_tool',{p_token:t,p_tool:'aos_admin_desactivar_integracion',p_params:{p_id:id}}).then(function(r){if(r&&r.ok){showToast('Desactivado','');loadIntegraciones();}else showToast((r&&r.error)||'No autorizado','err');});}", g)
write(path,g)

# Chrome extension: copy hardened core and require password only in memory.
ext_core=read('app/public/kronia-core.js')
write('chrome-extension/kronia-core.js', ext_core)
path='chrome-extension/popup.js'; p=read(path)
p=p.replace('CORE.loginRequest(u)', "CORE.loginRequest(u, document.getElementById('loginPass') ? document.getElementById('loginPass').value : '')")
write(path,p)
path='chrome-extension/popup.html'; ph=read(path)
if 'id="loginPass"' not in ph:
    ph=ph.replace('id="loginUser"', 'id="loginUser"',1)
    # Insert password immediately after the username input element.
    ph=re.sub(r'(<input[^>]+id="loginUser"[^>]*>)', r'\1\n<input id="loginPass" type="password" placeholder="Contraseña" autocomplete="current-password">', ph, count=1)
write(path,ph)

print('KRONIA_K1_RUNTIME_PATCH=PASS')
