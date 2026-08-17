from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[2]; app=root/'app'
k1=(app/'server-k1.js').read_text(); phase_s=(app/'server-phase-s.js').read_text(); inner=(app/'server.js').read_text(); browser=(app/'public/k1-browser-security.js').read_text()
apphtml=(app/'public/app.html').read_text(); brain=(app/'public/cerebro.html').read_text(); team=(app/'public/admin-team.html').read_text(); login=(app/'public/login.html').read_text()
popup=(root/'chrome-extension/popup.js').read_text(); extauth=(root/'chrome-extension/k1-extension-auth.js').read_text(); manifest=(root/'chrome-extension/manifest.json').read_text(); content=(root/'chrome-extension/content-script.js').read_text(); core=(root/'chrome-extension/kronia-core.js').read_text()
a=(root/'supabase/migrations/20260814170000_kronia_k1_private_credentials_auth_v3.sql').read_text(); b=(root/'supabase/migrations/20260814171000_kronia_k1_app_token_control_plane.sql').read_text(); e=(root/'supabase/migrations/20260814171800_kronia_k1_auth_v3_branded_alignment.sql').read_text(); recovery=(root/'supabase/rollbacks/20260814_kronia_k1_phase2_safe_recovery.sql').read_text()
rail=json.loads((app/'railway.json').read_text())
assert not re.search(r"const\s+VERIFY_TOKEN\s*=\s*['\"][^'\"]+",inner)
assert not re.search(r"process\.env\.RESEND_API_KEY\s*\|\|\s*['\"][^'\"]+",inner)
assert "const VERIFY_TOKEN = process.env.META_VERIFY_TOKEN || '__DISABLED__'" in inner
assert "spawn(process.execPath,['server-phase-s.js']" in k1 and "spawn(process.execPath,['server-f5.js']" not in k1
assert "spawn(process.execPath,['server-f5.js']" in phase_s
assert rail['deploy']['startCommand']=="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-k1.js"
assert 'server-k1.js -> server-phase-s.js -> server-f5.js' in rail['build']['buildCommand']
assert 'loadResendRuntimeKey' not in k1 and 'aos_integraciones?select=api_key' not in k1
assert 'SUPABASE_SERVICE_ROLE_KEY' in k1 and 'aos_kronia_identity_v3' in k1 and 'aos_app_actor_v3' in k1
assert 'ORIGIN_NOT_ALLOWED' in k1 and 'RATE_LIMIT' in k1 and 'BODY_TOO_LARGE' in k1 and 'PASSWORD_EMAIL_FORBIDDEN' in k1
assert 'aos_si_token' not in browser and 'aos_app_token' in browser
assert '<script src="/k1-browser-security.js"></script>' in apphtml and '<script src="/k1-browser-security.js"></script>' in brain
assert '\nconnectRT();\n' not in brain
assert 'aos_si_token' not in team and 'aos_app_token' in team
assert 'pw.length<10' in team or 'np.length<10' in team
assert 'aos_login_v3' in login and 'aos_verificar_2fa_v3' in login
assert '/api/kronia/login-request' in extauth and '/api/kronia/login-verify' in extauth
assert 'state.password' not in popup and 'kronia_session.password' not in popup
assert 'from public.aos_integration_secrets_v1 s' in a and 'select i.api_key into v_api_key from public.aos_integraciones' not in a
assert 'K1 CURRENT private provider vault bootstrap.' in a
assert 'from public.aos_integration_secrets_v1 s' in e and 'select i.api_key into v_api_key' not in e
assert 'insert into public.aos_integration_secrets_v1' in b and 'update public.aos_integration_secrets_v1' in b
assert "else api_key end" not in b and "else api_secret end" not in b
assert 'aos_team_feed_v3' in b and 'revoke all on table public.aos_team_full from public,anon,authenticated' in b
assert 'SAFE_USER_COLUMNS' in browser and 'SAFE_RRHH_COLUMNS' in browser
assert '"js": ["kronia-core.js", "k1-extension-auth.js", "content-script.js"]' in manifest
assert 'core.loginRequest(u, pw)' in content
assert 'historial: state.historial' not in core and 'data.historial' not in core
assert 'force row level security' in recovery and 'Sensitive identity reads remain least-privilege during recovery.' in recovery
m=json.loads((app/'k1-phase2-runtime-manifest.json').read_text())
assert m['contract']=='kronia-k1-current-runtime-v4' and m['chain']=='K1->PhaseS->F5->WA4->WA3->WA2->F4->Phase2/core'
assert all(len(v)==64 for v in m['files'].values())
print('KRONIA_K1_CURRENT_SOURCE_SECRET_CONTRACT=PASS')
print('KRONIA_K1_CURRENT_PHASE_S_CHAIN=PASS')
print('KRONIA_K1_CURRENT_NODE_MATERIALIZED_CONTRACT=PASS')
print('KRONIA_K1_CURRENT_RUNTIME_CONTRACT=PASS')
