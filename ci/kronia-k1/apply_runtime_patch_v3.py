from pathlib import Path

src_path = Path('ci/kronia-k1/apply_runtime_patch.py')
src = src_path.read_text(encoding='utf-8')

# Keep regex replacement strings literal unless the source explicitly uses a
# backreference. This is the same safe engine fix introduced in v2.
old = "    out, n = re.subn(pattern, repl, text, count=1, flags=flags)"
new = "    if r'\\1' in repl or r'\\g<' in repl:\n        out, n = re.subn(pattern, repl, text, count=1, flags=flags)\n    else:\n        out, n = re.subn(pattern, lambda _m: repl, text, count=1, flags=flags)"
if old not in src:
    raise SystemExit('K1 v3: patch engine anchor not found')
src = src.replace(old, new, 1)

# The first implementation matched from getKey() all the way to the later
# getKey('gemini') invocation, consuming tryGemini/tryOpenAI. Replace only the
# getKey function itself and leave Studio behavior structurally intact.
marker = "# Studio's nested provider key resolver becomes environment-backed."
start = src.index(marker)
stmt_start = src.index("s = re.sub", start)
stmt_end = src.index("# Generic legacy secret reads must not survive K1.", stmt_start)
replacement = r'''s = re.sub(
    r"/\* Leer keys de Supabase integraciones \*/\s*function getKey\(tipo, cb\) \{.*?\n        \}\s*(?=function tryGemini)",
    "/* Provider keys live in the server environment */\\n        function getKey(tipo, cb){ var map={gemini:process.env.GEMINI_API_KEY||'',api:process.env.OPENAI_API_KEY||'',openai:process.env.OPENAI_API_KEY||'',groq:process.env.GROQ_API_KEY||''}; cb(map[tipo]||'') }\\n        ",
    s, count=1, flags=re.S)
'''
src = src[:stmt_start] + replacement + src[stmt_end:]

# The generate-copy route still used the result of a metadata query as if it
# contained api_key. Preserve the route while sourcing the credential from env.
needle = "s = s.replace(\"/rest/v1/aos_integraciones?tipo=eq.groq&estado=eq.conectado&select=api_key&limit=1\", \"/rest/v1/aos_integraciones?tipo=eq.groq&estado=eq.conectado&select=nombre&limit=1\")"
pos = src.index(needle) + len(needle)
src = src[:pos] + "\ns = s.replace(\"var groqKey = rows && rows[0] ? rows[0].api_key : null\", \"var groqKey = process.env.GROQ_API_KEY || ''\")" + src[pos:]

code = compile(src, str(src_path), 'exec')
exec(code, {'__name__': '__main__', '__file__': str(src_path)})

# K1 uses a narrow token-bound ADMIN RPC for integration deactivation. This
# prevents the configuration UI from overloading the general KronIA tool router.
cfg_path = Path('app/public/admin-config.html')
cfg = cfg_path.read_text(encoding='utf-8')
cfg = cfg.replace(
    "sbRpc('aos_kronia_tool',{p_token:t,p_tool:'aos_admin_desactivar_integracion',p_params:{p_id:id}})",
    "sbRpc('aos_kronia_admin_desactivar_integracion',{p_token:t,p_id:id})"
)
cfg_path.write_text(cfg, encoding='utf-8')

# The main app embeds its own KronIA client instead of using KroniaCore. Migrate
# both text and Whisper paths to the same opaque Bearer credential.
app_path = Path('app/public/app.html')
app = app_path.read_text(encoding='utf-8')
legacy_payload = "var payload={pregunta:q,usuario:usuario,rol:rol,sede:sede,session_id:KR.sessionId,historial:KR.historial.slice(-8),lead_actual:krGetLead(),id_asesor:idAsesor};"
secure_payload = "var kTok=sessionStorage.getItem('aos_kronia_token')||'';if(!kTok){KR.enviando=false;if(typing)typing.style.display='none';krAddMsg('ai','Sesión segura requerida. Vuelve a ingresar.');return;}var payload={pregunta:q,session_id:KR.sessionId,historial:KR.historial.slice(-8),lead_actual:krGetLead()};"
if legacy_payload not in app:
    raise SystemExit('K1 v3: main chat legacy payload anchor not found')
app = app.replace(legacy_payload, secure_payload, 1)
legacy_fetch = "fetch('/api/kronia/chat',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)})"
secure_fetch = "fetch('/api/kronia/chat',{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+kTok},body:JSON.stringify(payload)})"
if legacy_fetch not in app:
    raise SystemExit('K1 v3: main chat fetch anchor not found')
app = app.replace(legacy_fetch, secure_fetch, 1)
legacy_whisper = "headers:{'Content-Type':'audio/webm','X-AOS-User':(AOS.ctx&&AOS.ctx.nombre)||'','X-AOS-Id':(AOS.ctx&&AOS.ctx.idAsesor)||''}"
secure_whisper = "headers:{'Content-Type':'audio/webm','Authorization':'Bearer '+(sessionStorage.getItem('aos_kronia_token')||'')}"
if legacy_whisper not in app:
    raise SystemExit('K1 v3: main Whisper legacy headers anchor not found')
app = app.replace(legacy_whisper, secure_whisper, 1)
app_path.write_text(app, encoding='utf-8')

# Preserve the historical Whisper response contract (`texto`) while also
# supporting the shared core's normalized `text` field.
server_path = Path('app/server.js')
server = server_path.read_text(encoding='utf-8')
server = server.replace("{ok:true,text:j.text}", "{ok:true,text:j.text,texto:j.text}")
server_path.write_text(server, encoding='utf-8')
