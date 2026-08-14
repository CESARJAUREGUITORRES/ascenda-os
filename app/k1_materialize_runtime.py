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
