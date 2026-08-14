from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parent
base_path = ROOT / 'k1_runtime_base.py'
src = base_path.read_text(encoding='utf-8')

# The vendored base is byte-identical to the K1 CI materializer. Adapt it to
# Railway's /app root and execute only production runtime transformations.
old = "    out, n = re.subn(pattern, repl, text, count=1, flags=flags)"
new = "    if r'\\1' in repl or r'\\g<' in repl:\n        out, n = re.subn(pattern, repl, text, count=1, flags=flags)\n    else:\n        out, n = re.subn(pattern, lambda _m: repl, text, count=1, flags=flags)"
if old not in src:
    raise SystemExit('K1 runtime base contract changed: sub_once anchor missing')
src = src.replace(old, new, 1)

# Drop DB migration materialization: canonical K1 SQL is applied separately.
sql_start = src.index('# SQL: qualify pgcrypto')
server_start = src.index('# Server: environment-only secrets')
src = src[:sql_start] + src[server_start:]

# Drop Chrome packaging from Railway runtime; Chrome files are versioned directly.
chrome_marker = '# Chrome extension: copy hardened core'
if chrome_marker in src:
    src = src[:src.index(chrome_marker)] + "print('KRONIA_K1_RUNTIME_PATCH=PASS')\n"

# Railway executes inside app/. Adapt repository-relative paths to service root.
src = src.replace("ROOT = Path('.')", "ROOT = Path(__file__).resolve().parent")
src = src.replace("'app/server.js'", "'server.js'")
src = src.replace('"app/server.js"', '"server.js"')
src = src.replace("'app/public/", "'public/")
src = src.replace('"app/public/', '"public/')

# Preserve Studio: the historical base regex was too broad and was caught by
# the syntax gate. Replace only getKey(), leaving provider fallback functions.
marker = '# Studio\'s nested provider key resolver becomes environment-backed.'
if marker in src:
    start = src.index(marker)
    stmt_start = src.index('s = re.sub', start)
    stmt_end = src.index('# Generic legacy secret reads must not survive K1.', stmt_start)
    narrow = r'''s = re.sub(
    r"/\* Leer keys de Supabase integraciones \*/\s*function getKey\(tipo, cb\) \{.*?\n        \}\s*(?=function tryGemini)",
    "/* Provider keys live in the server environment */\\n        function getKey(tipo, cb){ var map={gemini:process.env.GEMINI_API_KEY||'',api:process.env.OPENAI_API_KEY||'',openai:process.env.OPENAI_API_KEY||'',groq:process.env.GROQ_API_KEY||''}; cb(map[tipo]||'') }\\n        ",
    s, count=1, flags=re.S)
'''
    src = src[:stmt_start] + narrow + src[stmt_end:]

# Execute the same core transformation inside app/.
exec(compile(src, str(base_path), 'exec'), {'__name__': '__main__', '__file__': str(base_path)})

# Release deltas added after the base certificate was introduced.
server_path = ROOT / 'server.js'
server = server_path.read_text(encoding='utf-8')
server = server.replace("var groqKey = rows && rows[0] ? rows[0].api_key : null", "var groqKey = process.env.GROQ_API_KEY || ''")
server = server.replace("{ok:true,text:j.text}", "{ok:true,text:j.text,texto:j.text}")

# Session issue/verify/revoke primitives are service-role only in the canonical
# K1 closure. Legacy Node verify/logout routes must therefore use the same
# server-side service RPC boundary as the new auth/chat routes.
if "sbRpc('aos_kronia_verify_token'" in server:
    server = server.replace("sbRpc('aos_kronia_verify_token'", "sbServiceRpc('aos_kronia_verify_token'")
elif "sbServiceRpc('aos_kronia_verify_token'" not in server:
    raise SystemExit('K1 verify-token service boundary missing')
if "sbRpc('aos_kronia_revocar_token'" in server:
    server = server.replace("sbRpc('aos_kronia_revocar_token'", "sbServiceRpc('aos_kronia_revocar_token'")
elif "sbServiceRpc('aos_kronia_revocar_token'" not in server:
    raise SystemExit('K1 revoke-token service boundary missing')

# K1.6 — origin policy, rate limiting and request-size limits for privileged
# surfaces. Same-origin is automatic. Cross-origin clients (including the
# production Chrome extension) must be explicitly listed in ASCENDA_CORS_ORIGINS.
security_helpers = r'''
var K1_RATE_BUCKETS = new Map()
function k1ClientIp(req) {
  var xff = String((req.headers && req.headers['x-forwarded-for']) || '').split(',')[0].trim()
  return xff || (req.socket && req.socket.remoteAddress) || 'unknown'
}
function k1OriginAllowed(req) {
  var origin = String((req.headers && req.headers.origin) || '').trim()
  if (!origin) return true
  var proto = String((req.headers && req.headers['x-forwarded-proto']) || 'https').split(',')[0].trim()
  var host = String((req.headers && (req.headers['x-forwarded-host'] || req.headers.host)) || '').split(',')[0].trim()
  if (host && origin === proto + '://' + host) return true
  var allowed = String(process.env.ASCENDA_CORS_ORIGINS || '').split(',').map(function(x){return x.trim()}).filter(Boolean)
  return allowed.indexOf(origin) !== -1
}
function k1RateAllowed(req, scope, limit, windowMs) {
  var now = Date.now(), key = scope + '|' + k1ClientIp(req), b = K1_RATE_BUCKETS.get(key)
  if (!b || now - b.started >= windowMs) { b = {started:now,count:0}; K1_RATE_BUCKETS.set(key,b) }
  b.count += 1
  if (K1_RATE_BUCKETS.size > 5000) {
    K1_RATE_BUCKETS.forEach(function(v,k){ if(now-v.started > 3600000) K1_RATE_BUCKETS.delete(k) })
  }
  return b.count <= limit
}
function k1InstallBodyLimit(req, res, maxBytes) {
  if (!maxBytes || req._k1BodyLimitInstalled) return true
  var declared = parseInt(String((req.headers && req.headers['content-length']) || '0'),10) || 0
  if (declared > maxBytes) {
    res.writeHead(413, {'Content-Type':'application/json'}); res.end(JSON.stringify({ok:false,error:'Solicitud demasiado grande'})); return false
  }
  req._k1BodyLimitInstalled = true
  var seen = 0, originalOn = req.on.bind(req)
  req.on = function(event, listener) {
    if (event === 'data') {
      return originalOn('data', function(chunk) {
        if (req._k1BodyExceeded) return
        seen += Buffer.isBuffer(chunk) ? chunk.length : Buffer.byteLength(String(chunk))
        if (seen > maxBytes) {
          req._k1BodyExceeded = true
          if (!res.writableEnded) { res.writeHead(413, {'Content-Type':'application/json'}); res.end(JSON.stringify({ok:false,error:'Solicitud demasiado grande'})) }
          req.destroy(); return
        }
        listener(chunk)
      })
    }
    return originalOn(event, listener)
  }
  return true
}
'''
create_anchor = 'http.createServer(async function(req, res) {'
if 'function k1OriginAllowed(req)' not in server:
    if create_anchor not in server:
        raise SystemExit('K1 server create anchor missing')
    server = server.replace(create_anchor, security_helpers + '\n' + create_anchor, 1)

early_anchor = "http.createServer(async function(req, res) {\n  var p = req.url.split('?')[0]\n"
early_guard = r'''http.createServer(async function(req, res) {
  var p = req.url.split('?')[0]
  var k1Protected = p.startsWith('/api/kronia/') || p.startsWith('/api/auth/') || p.startsWith('/api/agents/')
  if (k1Protected) {
    var k1Origin = String((req.headers && req.headers.origin) || '').trim()
    if (!k1OriginAllowed(req)) { res.writeHead(403, {'Content-Type':'application/json'}); res.end(JSON.stringify({ok:false,error:'Origen no permitido'})); return }
    if (k1Origin) { res.setHeader('Access-Control-Allow-Origin',k1Origin); res.setHeader('Vary','Origin') }
    var k1SetHeader = res.setHeader.bind(res)
    res.setHeader = function(name,value) {
      if (String(name).toLowerCase()==='access-control-allow-origin' && value==='*' && k1Origin) return k1SetHeader(name,k1Origin)
      return k1SetHeader(name,value)
    }
    if (req.method === 'OPTIONS') {
      res.writeHead(204, {'Access-Control-Allow-Methods':'POST,GET,OPTIONS','Access-Control-Allow-Headers':'Content-Type, Authorization','Access-Control-Max-Age':'600'}); res.end(); return
    }
    var k1Rate = p === '/api/auth/resend-2fa' ? ['auth-resend',6,600000]
      : p === '/api/auth/verify-2fa' || p === '/api/kronia/login-verify' ? ['auth-verify',20,300000]
      : p === '/api/auth/login' || p === '/api/kronia/login-request' ? ['auth-login',30,300000]
      : p === '/api/kronia/whisper' ? ['whisper',30,300000]
      : p.startsWith('/api/agents/') ? ['agents',120,60000]
      : ['kronia',120,60000]
    if (!k1RateAllowed(req,k1Rate[0],k1Rate[1],k1Rate[2])) { res.writeHead(429, {'Content-Type':'application/json','Retry-After':'60'}); res.end(JSON.stringify({ok:false,error:'Demasiadas solicitudes'})); return }
    var k1Max = p === '/api/kronia/whisper' ? 27262976 : p.startsWith('/api/agents/') ? 1048576 : p === '/api/kronia/chat' ? 524288 : 32768
    if (!k1InstallBodyLimit(req,res,k1Max)) return
  }
'''
if early_guard not in server:
    if early_anchor not in server:
        raise SystemExit('K1 early middleware anchor missing')
    server = server.replace(early_anchor, early_guard, 1)

server_path.write_text(server, encoding='utf-8')

config_path = ROOT / 'public/admin-config.html'
config = config_path.read_text(encoding='utf-8')
config = config.replace(
    "sbRpc('aos_kronia_tool',{p_token:t,p_tool:'aos_admin_desactivar_integracion',p_params:{p_id:id}})",
    "sbRpc('aos_kronia_admin_desactivar_integracion',{p_token:t,p_id:id})"
)
config_path.write_text(config, encoding='utf-8')

app_path = ROOT / 'public/app.html'
app = app_path.read_text(encoding='utf-8')
legacy_payload = "var payload={pregunta:q,usuario:usuario,rol:rol,sede:sede,session_id:KR.sessionId,historial:KR.historial.slice(-8),lead_actual:krGetLead(),id_asesor:idAsesor};"
secure_payload = "var kTok=sessionStorage.getItem('aos_kronia_token')||'';if(!kTok){KR.enviando=false;if(typing)typing.style.display='none';krAddMsg('ai','Sesión segura requerida. Vuelve a ingresar.');return;}var payload={pregunta:q,session_id:KR.sessionId,historial:KR.historial.slice(-8),lead_actual:krGetLead()};"
if legacy_payload in app:
    app = app.replace(legacy_payload, secure_payload, 1)
elif secure_payload not in app:
    raise SystemExit('K1 main-chat payload contract missing')

legacy_fetch = "fetch('/api/kronia/chat',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)})"
secure_fetch = "fetch('/api/kronia/chat',{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+kTok},body:JSON.stringify(payload)})"
if legacy_fetch in app:
    app = app.replace(legacy_fetch, secure_fetch, 1)
elif secure_fetch not in app:
    raise SystemExit('K1 main-chat bearer contract missing')

legacy_whisper = "headers:{'Content-Type':'audio/webm','X-AOS-User':(AOS.ctx&&AOS.ctx.nombre)||'','X-AOS-Id':(AOS.ctx&&AOS.ctx.idAsesor)||''}"
secure_whisper = "headers:{'Content-Type':'audio/webm','Authorization':'Bearer '+(sessionStorage.getItem('aos_kronia_token')||'')}"
if legacy_whisper in app:
    app = app.replace(legacy_whisper, secure_whisper, 1)
elif secure_whisper not in app:
    raise SystemExit('K1 main-Whisper bearer contract missing')
app_path.write_text(app, encoding='utf-8')

# Build evidence: Railway and CI can compare the same deterministic file hashes.
targets = [
    'server.js',
    'public/app.html',
    'public/kronia-core.js',
    'public/login.html',
    'public/admin-sales.html',
    'public/admin-config.html',
]
manifest = {
    'contract': 'kronia-k1-runtime-v1',
    'files': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in targets},
}
(ROOT / 'k1-runtime-manifest.json').write_text(json.dumps(manifest, sort_keys=True, indent=2) + '\n', encoding='utf-8')
print('KRONIA_K1_RAILWAY_RUNTIME=PASS')
for path, digest in manifest['files'].items():
    print(path + ' ' + digest)
