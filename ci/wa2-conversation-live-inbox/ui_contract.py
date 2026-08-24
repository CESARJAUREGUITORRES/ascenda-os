from pathlib import Path
import json

root = Path(__file__).resolve().parents[2]
server = (root / 'app/server-wa2.js').read_text(encoding='utf-8')
wa3_path = root / 'app/server-wa3.js'
wa3 = wa3_path.read_text(encoding='utf-8') if wa3_path.exists() else ''
wa3v2_path = root / 'app/server-wa3-v2.js'
wa3v2 = wa3v2_path.read_text(encoding='utf-8') if wa3v2_path.exists() else ''
wa4_path = root / 'app/server-wa4.js'
wa4 = wa4_path.read_text(encoding='utf-8') if wa4_path.exists() else ''
f5_path = root / 'app/server-f5.js'
f5 = f5_path.read_text(encoding='utf-8') if f5_path.exists() else ''
f17_path = root / 'app/server-f17.js'
f17 = f17_path.read_text(encoding='utf-8') if f17_path.exists() else ''
phase_s_path = root / 'app/server-phase-s.js'
phase_s = phase_s_path.read_text(encoding='utf-8') if phase_s_path.exists() else ''
s152_path = root / 'app/server-phase-s-f17.js'
s152 = s152_path.read_text(encoding='utf-8') if s152_path.exists() else ''
ui = (root / 'app/public/admin-whatsapp.html').read_text(encoding='utf-8')
railway = json.loads((root / 'app/railway.json').read_text(encoding='utf-8'))
migration = (root / 'supabase/migrations/20260815175500_wa2_conversation_live_inbox_v1.sql').read_text(encoding='utf-8')
rollback = (root / 'supabase/rollbacks/20260815175500_wa2_conversation_live_inbox_v1.rollback.sql').read_text(encoding='utf-8')

assert "const PANEL='admin-whatsapp'" in server
assert "p_required_panel:PANEL" in server
assert "p_require_2fa:true" in server
assert "nivel_jerarquia" in server and ">2" in server
assert "row.activo!==true" in server
assert "x-aos-app-token" in server
assert "SUPABASE_SERVICE_ROLE_KEY" in server
assert "'/rest/v1/aos_usuarios?id=eq.'" in server

assert "['server-f4.js']" in server
assert "proxy(req,res)" in server
assert "/api/wa/inbox" in server
assert "/api/wa/conversations/" in server
assert "WA2_RATE_LIMIT" in server
assert "Cache-Control':'no-store" in server
assert "X-Ascenda-WA2-Inbox':'v1'" in server

for forbidden in ('supabase.co', 'SUPABASE_SERVICE_ROLE_KEY', 'SUPABASE_ANON_KEY', '/rest/v1/', 'apikey'):
    assert forbidden not in ui, f'frontend leaks/directly depends on {forbidden}'
assert "X-AOS-App-Token" in ui
assert "/api/wa/inbox" in ui
assert "/api/wa/conversations/" in ui
assert "2500" in ui and "12000" in ui
assert "WA-2 es observación segura" in ui
assert "Respuesta humana, asignación e IA se habilitan en WA-3/WA-4" in ui
assert "textContent" in ui or "esc(" in ui

start=railway['deploy']['startCommand']
# ASC-PERF/Studio containment may prepend this exact fail-closed runtime flag.
# Normalize only this known prefix; arbitrary env wrappers remain rejected.
studio_fail_closed_prefix='env AOS_STUDIO_BACKGROUND_ENABLED=false '
normalized_start=start[len(studio_fail_closed_prefix):] if start.startswith(studio_fail_closed_prefix) else start
sentinel_phase_s="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s.js"
sentinel_phase_s_email="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs --require ./email-runtime-env-compat.cjs' node server-phase-s.js"
sentinel_s152="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs' node server-phase-s-f17.js"
sentinel_s152_email="env NODE_OPTIONS='--require ./sentinel-sentry-init.cjs --require ./email-runtime-env-compat.cjs' node server-phase-s-f17.js"
direct=normalized_start=='node server-wa2.js'
wa3_wrapped=(normalized_start=='node server-wa3.js' and "['server-wa2.js']" in wa3 and 'proxy(req,res)' in wa3)
wa4_to_wa3_v1=("['server-wa3.js']" in wa4 and 'proxy(req,res)' in wa4)
wa4_to_wa3_v2=("['server-wa3-v2.js']" in wa4 and 'proxy(req,res)' in wa4 and "['server-wa3.js']" in wa3v2 and 'proxy(req,res)' in wa3v2)
wa4_authority=wa4_to_wa3_v1 or wa4_to_wa3_v2
wa4_wrapped=(normalized_start=='node server-wa4.js' and wa4_authority and "['server-wa2.js']" in wa3 and 'proxy(req,res)' in wa3)
f5_wrapped=(normalized_start=='node server-f5.js' and "['server-wa4.js']" in f5 and 'proxy(req,res)' in f5 and wa4_authority and "['server-wa2.js']" in wa3 and 'proxy(req,res)' in wa3)
phase_s_entry=normalized_start in ('node server-phase-s.js',sentinel_phase_s,sentinel_phase_s_email)
phase_s_wrapped=(phase_s_entry and "['server-f5.js']" in phase_s and 'proxy(req,res)' in phase_s and "['server-wa4.js']" in f5 and 'proxy(req,res)' in f5 and wa4_authority and "['server-wa2.js']" in wa3 and 'proxy(req,res)' in wa3)
s152_entry=normalized_start in ('node server-phase-s-f17.js',sentinel_s152,sentinel_s152_email)
s152_wrapped=(s152_entry and "a[0]==='server-f5.js'" in s152 and "a[0]='server-f17.js'" in s152 and "require('./server-phase-s.js')" in s152 and "['server-f5.js']" in phase_s and 'proxy(req,res)' in phase_s and "['server-f5.js']" in f17 and "['server-wa4.js']" in f5 and 'proxy(req,res)' in f5 and wa4_authority and "['server-wa2.js']" in wa3 and 'proxy(req,res)' in wa3)
assert direct or wa3_wrapped or wa4_wrapped or f5_wrapped or phase_s_wrapped or s152_wrapped, 'Railway must start WA-2 directly or through certified WA-3/WA-3V2/WA-4/F5/Phase-S/F17 wrappers'
if normalized_start in (sentinel_phase_s,sentinel_phase_s_email,sentinel_s152,sentinel_s152_email):
    assert 'NODE_OPTIONS' not in str(railway.get('build',{}).get('buildCommand','')), 'Runtime preloads must not contaminate build'

assert 'aos_wa_conversations_v1' in migration
assert 'aos_wa_conversation_events_v1' in migration
assert 'conversation_id' in migration
assert 'aos_wa2_bind_conversation_v1' in migration
assert 'aos_wa2_project_message_v1' in migration
assert 'trg_aos_wa2_project_insert_v1' in migration
assert 'trg_aos_wa2_project_backfill_v1' in migration
assert 'on conflict (conversation_key) do nothing' in migration.lower()
assert 'after insert on public.aos_wa_messages_v1' in migration.lower()
assert "old.conversation_id is null and new.conversation_id is not null" in migration.lower()
assert "v_ts > c.last_read_at" in migration
assert "coalesce(c.closed_at, '-infinity'::timestamptz)" in migration
assert 'force row level security' in migration.lower()
assert "where nivel_jerarquia = 1" in migration
assert "and two_factor is true" in migration
assert 'aos_mensajes' not in migration and 'aos_canales' not in migration
assert 'drop table' not in migration.lower()

assert 'trg_aos_wa2_bind_conversation_v1' in rollback
assert 'trg_aos_wa2_project_insert_v1' in rollback
assert 'trg_aos_wa2_project_backfill_v1' in rollback
assert 'aos_wa2_bind_conversation_v1' in rollback
assert 'aos_wa2_project_message_v1' in rollback
assert "array_remove" in rollback
assert "delete from public.aos_paneles_disponibles where id='admin-whatsapp'" in rollback
assert 'drop table' not in rollback.lower()
assert 'force row level security' in rollback.lower()
print('WA-2 UI/runtime/security contracts: PASS')
