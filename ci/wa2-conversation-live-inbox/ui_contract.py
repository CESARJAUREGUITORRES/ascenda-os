from pathlib import Path
import json

root = Path(__file__).resolve().parents[2]
server = (root / 'app/server-wa2.js').read_text(encoding='utf-8')
ui = (root / 'app/public/admin-whatsapp.html').read_text(encoding='utf-8')
railway = json.loads((root / 'app/railway.json').read_text(encoding='utf-8'))
migration = (root / 'supabase/migrations/20260815175500_wa2_conversation_live_inbox_v1.sql').read_text(encoding='utf-8')
rollback = (root / 'supabase/rollbacks/20260815175500_wa2_conversation_live_inbox_v1.rollback.sql').read_text(encoding='utf-8')

# Server boundary: strong session, explicit panel, administrator defense-in-depth.
assert "const PANEL='admin-whatsapp'" in server
assert "p_required_panel:PANEL" in server
assert "p_require_2fa:true" in server
assert "nivel_jerarquia" in server and ">2" in server
assert "row.activo!==true" in server
assert "x-aos-app-token" in server
assert "SUPABASE_SERVICE_ROLE_KEY" in server
assert "'/rest/v1/aos_usuarios?id=eq.'" in server

# WA-2 does not replace WA-1: it wraps server-f4 and proxies non-inbox traffic.
assert "['server-f4.js']" in server
assert "proxy(req,res)" in server
assert "/api/wa/inbox" in server
assert "/api/wa/conversations/" in server
assert "WA2_RATE_LIMIT" in server
assert "Cache-Control':'no-store" in server
assert "X-Ascenda-WA2-Inbox':'v1'" in server

# Browser UI must never know Supabase/service credentials or use direct PostgREST.
for forbidden in ('supabase.co', 'SUPABASE_SERVICE_ROLE_KEY', 'SUPABASE_ANON_KEY', '/rest/v1/', 'apikey'):
    assert forbidden not in ui, f'frontend leaks/directly depends on {forbidden}'
assert "X-AOS-App-Token" in ui
assert "/api/wa/inbox" in ui
assert "/api/wa/conversations/" in ui
assert "2500" in ui and "12000" in ui
assert "WA-2 es observación segura" in ui
assert "Respuesta humana, asignación e IA se habilitan en WA-3/WA-4" in ui
assert "textContent" in ui or "esc(" in ui

# Deployment and schema invariants.
assert railway['deploy']['startCommand'] == 'node server-wa2.js'
assert 'aos_wa_conversations_v1' in migration
assert 'aos_wa_conversation_events_v1' in migration
assert 'conversation_id' in migration
assert 'force row level security' in migration.lower()
assert "where nivel_jerarquia = 1" in migration
assert "and two_factor is true" in migration
assert 'aos_mensajes' not in migration and 'aos_canales' not in migration
assert 'drop table' not in migration.lower()

# Recovery must fail closed and preserve captured evidence.
assert 'drop trigger' in rollback.lower()
assert 'drop function' in rollback.lower()
assert "array_remove" in rollback
assert "delete from public.aos_paneles_disponibles where id='admin-whatsapp'" in rollback
assert 'drop table' not in rollback.lower()
assert 'force row level security' in rollback.lower()

print('WA-2 UI/runtime/security contracts: PASS')
