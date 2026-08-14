from pathlib import Path
import json,re

root=Path(__file__).resolve().parents[2]
app=root/'app'
proxy=(app/'server-k1.js').read_text(encoding='utf-8')
inner=(app/'server.js').read_text(encoding='utf-8')
mat=(app/'k1_phase2_materialize.py').read_text(encoding='utf-8')
rail=json.loads((app/'railway.json').read_text(encoding='utf-8'))
nix=(app/'nixpacks.toml').read_text(encoding='utf-8')
browser=(app/'public/k1-browser-security.js').read_text(encoding='utf-8')
login=(app/'public/login.html').read_text(encoding='utf-8')
extauth=(root/'chrome-extension/k1-extension-auth.js').read_text(encoding='utf-8')
popup=(root/'chrome-extension/popup.js').read_text(encoding='utf-8')

assert rail['build']['buildCommand']=='python3 k1_phase2_materialize.py'
assert rail['deploy']['startCommand']=='node server-k1.js'
assert 'providers = ["...", "python"]' in nix
assert "spawn(process.execPath,['server-phase2.js']" in proxy
assert 'SUPABASE_SERVICE_ROLE_KEY' in proxy and 'if (!SERVICE_KEY)' in proxy
assert 'aos_app_actor_v3' in proxy and 'aos_kronia_identity_v3' in proxy
assert 'ORIGIN_NOT_ALLOWED' in proxy and 'RATE_LIMIT' in proxy and 'BODY_TOO_LARGE' in proxy
assert "pathname==='/api/kronia/chat'" in proxy and "pathname.startsWith('/api/agents/')" in proxy
assert "d.usuario=id.nombre||id.usuario" in proxy and 'd.rol=id.rol' in proxy

# Materialized inner server must not keep the old anonymous server DB key nor
# the historical static webhook verification secret.
assert "process.env.SUPABASE_SERVICE_ROLE_KEY" in inner
assert "const VERIFY_TOKEN = process.env.META_VERIFY_TOKEN || '__DISABLED__'" in inner
assert "ascendaos_zivital_2026" not in inner
assert re.search(r"const SB_KEY = process\.env\.SUPABASE_SERVICE_ROLE_KEY",inner)

# K1 preserves the Phase 2 login UI exactly as a canonical Auth V3 consumer.
assert 'aos_login_v3' in login and 'aos_verificar_2fa_v3' in login
assert "for p in ['public/app.html','public/cerebro.html']" in mat
assert "write('public/login.html'" not in mat and "p='public/login.html'" not in mat
assert 'aos_app_token' in browser
assert 'aos_kronia_tool_v3' in browser and 'aos_admin_identity_v4' in browser and 'aos_admin_config_v3' in browser
assert "sessionStorage.getItem('aos_kronia_token')" not in browser

# Chrome transport uses Auth V3 via the K1 proxy and never persists a password.
assert '/api/kronia/login-request' in extauth and '/api/kronia/login-verify' in extauth
assert 'challenge_id' in extauth
assert 'loginPassword.value' in popup and 'core.loginRequest(u,pw)' in popup
assert 'state.password' not in popup and 'kronia_session.password' not in popup

manifest=json.loads((app/'k1-phase2-runtime-manifest.json').read_text(encoding='utf-8'))
assert manifest['contract']=='kronia-k1-phase2-runtime-v1'
assert all(len(v)==64 for v in manifest['files'].values())
print('KRONIA_K1_PHASE2_RUNTIME_CONTRACT=PASS')
