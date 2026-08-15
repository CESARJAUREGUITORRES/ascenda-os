from pathlib import Path
import json,re,subprocess

root=Path(__file__).resolve().parents[2]
app=root/'app'
proxy=(app/'server-k1.js').read_text(encoding='utf-8')
inner=(app/'server.js').read_text(encoding='utf-8')
mat=(app/'k1_phase2_materialize.py').read_text(encoding='utf-8')
rail=json.loads((app/'railway.json').read_text(encoding='utf-8'))
nix=(app/'nixpacks.toml').read_text(encoding='utf-8')
browser=(app/'public/k1-browser-security.js').read_text(encoding='utf-8')
apphtml=(app/'public/app.html').read_text(encoding='utf-8')
brain=(app/'public/cerebro.html').read_text(encoding='utf-8')
team=(app/'public/admin-team.html').read_text(encoding='utf-8')
login=(app/'public/login.html').read_text(encoding='utf-8')
extauth=(root/'chrome-extension/k1-extension-auth.js').read_text(encoding='utf-8')
popup=(root/'chrome-extension/popup.js').read_text(encoding='utf-8')

# Read committed source independently of materializer working-tree changes.
source_inner=subprocess.check_output(['git','show','HEAD:app/server.js'],cwd=root,text=True,encoding='utf-8')
resend_fallback=re.compile(r"process\.env\.RESEND_API_KEY\s*\|\|\s*['\"][^'\"]+",re.I)
verify_literal=re.compile(r"const\s+VERIFY_TOKEN\s*=\s*['\"][^'\"]+",re.I)
assert not resend_fallback.search(source_inner)
assert not verify_literal.search(source_inner)

assert rail['build']['buildCommand']=='python3 k1_phase2_materialize.py'
assert rail['deploy']['startCommand']=='node server-k1.js'
assert 'providers = ["...", "python"]' in nix
assert "spawn(process.execPath,['server-phase2.js']" in proxy
assert 'SUPABASE_SERVICE_ROLE_KEY' in proxy and 'if (!SERVICE_KEY)' in proxy
assert 'aos_app_actor_v3' in proxy and 'aos_kronia_identity_v3' in proxy
assert 'ORIGIN_NOT_ALLOWED' in proxy and 'RATE_LIMIT' in proxy and 'BODY_TOO_LARGE' in proxy
assert "pathname==='/api/kronia/chat'" in proxy and "pathname.startsWith('/api/agents/')" in proxy
assert "pathname==='/api/send-email'" in proxy and "pathname.startsWith('/api/studio/')" in proxy
assert 'PASSWORD_EMAIL_FORBIDDEN' in proxy
assert "const id=await identity(req,true)" in proxy
assert "d.usuario=id.nombre||id.usuario" in proxy and 'd.rol=id.rol' in proxy

# Resend runtime secret must come from the server-only integrations store and be
# handed to the Phase2 child only in process memory. CI can explicitly skip this
# production lookup with a synthetic env key.
assert 'loadResendRuntimeKey' in proxy
assert "/rest/v1/aos_integraciones?select=api_key&tipo=eq.resend&estado=eq.conectado&principal=eq.true&limit=1" in proxy
assert "K1_SKIP_RUNTIME_SECRET_LOOKUP==='1'" in proxy
assert 'runtimeEnv.RESEND_API_KEY=resendKey' in proxy
assert "console.log('[K1] Resend" not in proxy

# Materialized inner server must use server authority and contain no provider
# secret fallback regardless of whether HEAD was already sanitized.
assert "process.env.SUPABASE_SERVICE_ROLE_KEY" in inner
assert "const VERIFY_TOKEN = process.env.META_VERIFY_TOKEN || '__DISABLED__'" in inner
assert re.search(r"const SB_KEY = process\.env\.SUPABASE_SERVICE_ROLE_KEY",inner)
assert not resend_fallback.search(inner)
assert not verify_literal.search(inner.replace("const VERIFY_TOKEN = process.env.META_VERIFY_TOKEN || '__DISABLED__'",''))

# K1 preserves Phase 2 login and reuses the shell's publishable anon key.
assert 'aos_login_v3' in login and 'aos_verificar_2fa_v3' in login
assert "write('public/login.html'" not in mat and "p='public/login.html'" not in mat
assert "var _SB='https://ituyqwstonmhnfshnaqz.supabase.co',_SK=" in apphtml
assert 'window._SK' in browser
assert 'aos_app_token' in browser
assert 'aos_kronia_tool_v3' in browser and 'aos_admin_identity_v4' in browser and 'aos_admin_config_v3' in browser
assert "sessionStorage.getItem('aos_kronia_token')" not in browser
assert "u.pathname==='/api/send-email'" in browser and "u.pathname.indexOf('/api/studio/')===0" in browser
assert 'scrubCredentialEmail' in browser and 'Entregada por el administrador mediante canal seguro' in browser
assert "params={servicios:p.servicios||[],cmp:p.cmp||''}" in browser

# Brain cannot retain a direct audit WebSocket after audit becomes server-only.
assert 'window._SK=SK;' in brain
assert '<script src="/k1-browser-security.js"></script>' in brain
assert '/* K1: direct audit Realtime disabled; sanitized polling remains. */' in brain
assert '\nconnectRT();\n' not in brain
assert 'setInterval(poll, 8000)' in brain
assert 'auditRows' in browser and "gt.indexOf('gt.')===0" in browser

# Team UI matches K1 backend password policy.
assert 'pw.length<10' in team or 'np.length<10' in team
assert 'Mínimo 6 caracteres' not in team and 'mínimo 6 caracteres' not in team and 'Contraseña mínimo 6 caracteres' not in team

# Chrome transport uses Auth V3 and never persists a password.
assert '/api/kronia/login-request' in extauth and '/api/kronia/login-verify' in extauth
assert 'challenge_id' in extauth
assert 'loginPassword.value' in popup and 'core.loginRequest(u,pw)' in popup
assert 'state.password' not in popup and 'kronia_session.password' not in popup

manifest=json.loads((app/'k1-phase2-runtime-manifest.json').read_text(encoding='utf-8'))
assert manifest['contract']=='kronia-k1-phase2-runtime-v1'
assert 'public/admin-team.html' in manifest['files']
assert all(len(v)==64 for v in manifest['files'].values())
print('KRONIA_K1_PHASE2_SOURCE_SECRET_CONTRACT=PASS')
print('KRONIA_K1_PHASE2_RUNTIME_SECRET_HANDOFF=PASS')
print('KRONIA_K1_PHASE2_RUNTIME_CONTRACT=PASS')
