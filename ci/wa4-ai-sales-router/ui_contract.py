from pathlib import Path
import json
root = Path(__file__).resolve().parents[2]
wa4 = (root/'app/server-wa4.js').read_text()
wa3v2_path = root/'app/server-wa3-v2.js'
wa3v2 = wa3v2_path.read_text() if wa3v2_path.exists() else ''
f5_path = root/'app/server-f5.js'
f5 = f5_path.read_text() if f5_path.exists() else ''
f17_path = root/'app/server-f17.js'
f17 = f17_path.read_text() if f17_path.exists() else ''
phase_s_path = root/'app/server-phase-s.js'
phase_s = phase_s_path.read_text() if phase_s_path.exists() else ''
s152_path = root/'app/server-phase-s-f17.js'
s152 = s152_path.read_text() if s152_path.exists() else ''
router = (root/'app/ai-router.js').read_text()
hook = (root/'app/legacy-groq-model-hook.js').read_text()
mig = (root/'supabase/migrations/20260815203000_wa4_ai_sales_router_v1.sql').read_text()
refresh = (root/'supabase/migrations/20260815204500_groq_gpt_oss_model_refresh.sql').read_text()
secret = (root/'supabase/migrations/20260815205000_integration_secret_boundary_v1.sql').read_text()
secret_rb = (root/'supabase/rollbacks/20260815205000_integration_secret_boundary_v1.rollback.sql').read_text()
rail = json.loads((root/'app/railway.json').read_text())
start = rail['deploy']['startCommand']
studio_fail_closed_prefix='env AOS_STUDIO_BACKGROUND_ENABLED=false '
normalized_start=('env '+start[len(studio_fail_closed_prefix):]) if start.startswith(studio_fail_closed_prefix) else start
sentinel_phase_s = "env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s.js"
sentinel_phase_s_email = "env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs --require ./email-runtime-env-compat.cjs' node server-phase-s.js"
sentinel_s152 = "env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s-f17.js"
sentinel_s152_email = "env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs --require ./email-runtime-env-compat.cjs' node server-phase-s-f17.js"
direct = normalized_start == 'node server-wa4.js'
f5_wrapped = normalized_start == 'node server-f5.js' and "['server-wa4.js']" in f5 and 'proxy(req,res)' in f5
phase_s_entry = normalized_start in ('node server-phase-s.js', sentinel_phase_s, sentinel_phase_s_email)
phase_s_wrapped = (phase_s_entry and "['server-f5.js']" in phase_s and 'proxy(req,res)' in phase_s and "['server-wa4.js']" in f5 and 'proxy(req,res)' in f5)
s152_entry = normalized_start in ('node server-phase-s-f17.js', sentinel_s152, sentinel_s152_email)
s152_wrapped = (s152_entry and "a[0]==='server-f5.js'" in s152 and "a[0]='server-f17.js'" in s152 and "require('./server-phase-s.js')" in s152 and "['server-f5.js']" in phase_s and 'proxy(req,res)' in phase_s and "['server-f5.js']" in f17 and "['server-wa4.js']" in f5 and 'proxy(req,res)' in f5)
assert direct or f5_wrapped or phase_s_wrapped or s152_wrapped, 'Railway must start WA-4 directly or through certified F5/Phase-S/F17 wrappers'
if normalized_start in (sentinel_phase_s, sentinel_phase_s_email, sentinel_s152, sentinel_s152_email):
    assert 'NODE_OPTIONS' not in str(rail.get('build',{}).get('buildCommand','')), 'Runtime preloads must not contaminate build'
wa4_to_v1 = "['server-wa3.js']" in wa4 and 'proxy(req,res)' in wa4
wa4_to_v2_to_v1 = "['server-wa3-v2.js']" in wa4 and 'proxy(req,res)' in wa4 and "['server-wa3.js']" in wa3v2 and 'proxy(req,res)' in wa3v2
assert wa4_to_v1 or wa4_to_v2_to_v1, 'WA-4 must preserve the certified WA-3 authority directly or through explicit WA-3 V2 boundary'
assert 'aos_wa4_authorize_copilot_v1' in wa4
assert "auto_send:false" in wa4 or "auto_send: false" in wa4
assert 'graph.facebook.com' not in wa4
assert 'WHATSAPP_ACCESS_TOKEN' not in wa4
assert 'openai/gpt-oss-20b' in router and 'openai/gpt-oss-120b' in router
assert 'openai/gpt-oss-safeguard-20b' in router
assert 'llama-3.1-8b-instant' in hook and 'llama-3.3-70b-versatile' in hook
assert "ASCENDA_GROQ_COMPAT" in wa4 and "legacy_compat_ready" in wa4
assert 'aos_integration_secrets_v1' in wa4 and 'GROQ_API_KEY' in wa4 and 'GEMINI_API_KEY' in wa4
assert 'WA4_LEGACY_GROQ_SECRET_READ_REMAINS' in hook and 'RESEND_API_KEY' in hook
assert 'auto_reply_enabled boolean not null default false check (auto_reply_enabled = false)' in mig
assert 'Does not store raw prompt or raw model reply' in mig
assert "'clasificador','resumidor','recepcion'" in refresh
assert "'analista','analista_mkt','kronia','planificador'" in refresh
assert 'aos_integration_secrets_v1' in secret and 'force row level security' in secret.lower()
assert "api_key='',api_secret=''" in secret.replace(' ', '')
assert 'anon_integ_read_non_auth_provider' in secret and 'drop policy if exists' in secret.lower()
assert 'do not restore secrets' in secret_rb.lower()
print('WA-4 UI/runtime/security contracts: PASS')
