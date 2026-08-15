from pathlib import Path
import json
root = Path(__file__).resolve().parents[2]
wa4 = (root/'app/server-wa4.js').read_text()
f5_path = root/'app/server-f5.js'
f5 = f5_path.read_text() if f5_path.exists() else ''
router = (root/'app/ai-router.js').read_text()
hook = (root/'app/legacy-groq-model-hook.js').read_text()
mig = (root/'supabase/migrations/20260815203000_wa4_ai_sales_router_v1.sql').read_text()
refresh = (root/'supabase/migrations/20260815204500_groq_gpt_oss_model_refresh.sql').read_text()
secret = (root/'supabase/migrations/20260815205000_integration_secret_boundary_v1.sql').read_text()
secret_rb = (root/'supabase/rollbacks/20260815205000_integration_secret_boundary_v1.rollback.sql').read_text()
rail = json.loads((root/'app/railway.json').read_text())
start = rail['deploy']['startCommand']
direct = start == 'node server-wa4.js'
f5_wrapped = start == 'node server-f5.js' and "['server-wa4.js']" in f5 and 'proxy(req,res)' in f5
assert direct or f5_wrapped, 'Railway must start WA-4 directly or through certified F5 wrapper'
assert 'server-wa3.js' in wa4
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
