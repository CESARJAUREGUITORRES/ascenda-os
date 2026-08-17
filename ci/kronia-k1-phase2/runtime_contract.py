from pathlib import Path
import json,re,subprocess
root=Path(__file__).resolve().parents[2]; app=root/'app'
k1=(app/'server-k1.js').read_text(); inner=(app/'server.js').read_text(); browser=(app/'public/k1-browser-security.js').read_text()
apphtml=(app/'public/app.html').read_text(); brain=(app/'public/cerebro.html').read_text(); team=(app/'public/admin-team.html').read_text(); login=(app/'public/login.html').read_text(); popup=(root/'chrome-extension/popup.js').read_text(); extauth=(root/'chrome-extension/k1-extension-auth.js').read_text()
source_inner=subprocess.check_output(['git','show','HEAD:app/server.js'],cwd=root,text=True)
assert not re.search(r"const\s+VERIFY_TOKEN\s*=\s*['\"][^'\"]+",source_inner)
assert not re.search(r"process\.env\.RESEND_API_KEY\s*\|\|\s*['\"][^'\"]+",source_inner)
assert "const VERIFY_TOKEN = process.env.META_VERIFY_TOKEN || '__DISABLED__'" in inner
assert "spawn(process.execPath,['server-f5.js']" in k1
assert "spawn(process.execPath,['server-f4.js']" not in k1
assert 'loadResendRuntimeKey' not in k1 and 'aos_integraciones?select=api_key' not in k1
assert 'SUPABASE_SERVICE_ROLE_KEY' in k1 and 'aos_kronia_identity_v3' in k1 and 'aos_app_actor_v3' in k1
assert 'ORIGIN_NOT_ALLOWED' in k1 and 'RATE_LIMIT' in k1 and 'BODY_TOO_LARGE' in k1 and 'PASSWORD_EMAIL_FORBIDDEN' in k1
assert 'aos_si_token' not in browser and 'aos_app_token' in browser
assert '<script src="/k1-browser-security.js"></script>' in apphtml and '<script src="/k1-browser-security.js"></script>' in brain
assert '\nconnectRT();\n' not in brain
assert 'pw.length<10' in team or 'np.length<10' in team
assert 'aos_login_v3' in login and 'aos_verificar_2fa_v3' in login
assert '/api/kronia/login-request' in extauth and '/api/kronia/login-verify' in extauth
assert 'state.password' not in popup and 'kronia_session.password' not in popup
manifest=json.loads((app/'k1-phase2-runtime-manifest.json').read_text())
assert manifest['contract']=='kronia-k1-current-runtime-v3'
assert all(len(v)==64 for v in manifest['files'].values())
print('KRONIA_K1_CURRENT_SOURCE_SECRET_CONTRACT=PASS')
print('KRONIA_K1_CURRENT_RUNTIME_CHAIN=PASS')
print('KRONIA_K1_CURRENT_RUNTIME_CONTRACT=PASS')


# KRONIA_K1_CURRENT_NODE_MATERIALIZED_CONTRACT
from pathlib import Path as _K1Path
_k1root=_K1Path(__file__).resolve().parents[2]
_k1a=(_k1root/'supabase/migrations/20260814170000_kronia_k1_private_credentials_auth_v3.sql').read_text()
_k1b=(_k1root/'supabase/migrations/20260814171000_kronia_k1_app_token_control_plane.sql').read_text()
_k1e=(_k1root/'supabase/migrations/20260814171800_kronia_k1_auth_v3_branded_alignment.sql').read_text()
_k1r=(_k1root/'supabase/rollbacks/20260814_kronia_k1_phase2_safe_recovery.sql').read_text()
_k1browser=(_k1root/'app/public/k1-browser-security.js').read_text()
_k1team=(_k1root/'app/public/admin-team.html').read_text()
_k1manifest=(_k1root/'chrome-extension/manifest.json').read_text()
_k1content=(_k1root/'chrome-extension/content-script.js').read_text()
_k1core=(_k1root/'chrome-extension/kronia-core.js').read_text()
assert 'from public.aos_integration_secrets_v1 s' in _k1a and 'select i.api_key into v_api_key from public.aos_integraciones' not in _k1a
assert 'from public.aos_integration_secrets_v1 s' in _k1e and 'select i.api_key into v_api_key' not in _k1e
assert 'insert into public.aos_integration_secrets_v1' in _k1b and 'update public.aos_integration_secrets_v1' in _k1b
assert "else api_key end" not in _k1b and "else api_secret end" not in _k1b
assert 'aos_team_feed_v3' in _k1b and 'revoke all on table public.aos_team_full from public,anon,authenticated' in _k1b
assert 'SAFE_USER_COLUMNS' in _k1browser and 'SAFE_RRHH_COLUMNS' in _k1browser
assert 'aos_si_token' not in _k1team and 'aos_app_token' in _k1team
assert '"js": ["kronia-core.js", "k1-extension-auth.js", "content-script.js"]' in _k1manifest
assert 'core.loginRequest(u, pw)' in _k1content
assert 'historial: state.historial' not in _k1core and 'data.historial' not in _k1core
assert 'force row level security' in _k1r and 'Sensitive identity reads remain least-privilege during recovery.' in _k1r
print('KRONIA_K1_CURRENT_NODE_MATERIALIZED_CONTRACT=PASS')
