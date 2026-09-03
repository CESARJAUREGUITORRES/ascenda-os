from pathlib import Path
import re

root=Path(__file__).resolve().parents[2]
server=(root/'app/server-wa2.js').read_text(encoding='utf-8')
ui=(root/'app/public/admin-whatsapp.html').read_text(encoding='utf-8')
sql=(root/'supabase/migrations/20260903183000_wa_l7_cost_intelligence_v1.sql').read_text(encoding='utf-8')
rollback=(root/'supabase/rollbacks/20260903183000_wa_l7_cost_intelligence_v1.rollback.sql').read_text(encoding='utf-8')

# Server boundary: same existing admin-whatsapp + 2FA authority, exact UUID-scoped endpoint.
assert "const PANEL='admin-whatsapp'" in server
assert "p_required_panel:PANEL" in server and "p_require_2fa:true" in server
assert "async function conversationCost(req,res,id)" in server
assert "if(!UUID_RE.test(id))" in server
assert "/rest/v1/rpc/aos_wa_l7_journey_cost_v1" in server
assert "{p_conversation_id:id}" in server
assert re.search(r"/api/wa/conversations/.+?/cost",server)
assert "await conversationCost(req,res,mc[1])" in server
# L7 must not become an inbox-list enrichment/fan-out.
inbox_fn=server[server.index('async function inboxList'):server.index('async function inboxHealth')]
assert 'aos_wa_l7_' not in inbox_fn

# Browser never talks to Supabase directly and L7 is an optional lazy enrichment.
for forbidden in ('supabase.co','SUPABASE_SERVICE_ROLE_KEY','SUPABASE_ANON_KEY','/rest/v1/','apikey'):
    assert forbidden not in ui, f'frontend leaks/directly depends on {forbidden}'
assert "/api/wa/conversations/" in ui and "/cost" in ui
assert "function loadCost(force)" in ui
assert "Date.now()-S.costFetchedAt<15000" in ui
assert "Costos temporalmente no disponibles. El inbox y los mensajes siguen operativos." in ui
assert "Se carga de forma diferida para no competir con el inbox." in ui
assert "WA-L7 es read-only. SAFE-OFF y autoridad de envío siguen separados." in ui
assert all(x in ui for x in ('KNOWN','PARTIAL','UNKNOWN'))
assert all(x in ui for x in ('Costo/booking','Costo/asistencia','Costo/venta','Ingreso/Costo'))
# Existing fast inbox/message loop stays, but cost gets TTL/coalescing guard.
assert "var ms=document.hidden?12000:2500" in ui
assert "if(!S.active||S.costBusy)return" in ui
assert "loadMessages();loadCost(false)" in ui

# Database model is derived/scoped, never a hot-path trigger/materialization.
lower=sql.lower()
assert 'create materialized view' not in lower
assert 'refresh materialized view' not in lower
for hot in ('aos_wa_messages_v1','aos_wa_ai_runs_v1','aos_booking_operations_v2','aos_agenda_citas','aos_ventas'):
    assert not re.search(rf'create\s+trigger[^;]+on\s+public\.{hot}\b',lower,re.S), f'L7 trigger forbidden on {hot}'
assert 'aos_wa_l7_conversation_cost_v1(p_conversation_id uuid)' in lower
assert 'aos_wa_l7_journey_cost_v1(p_conversation_id uuid)' in lower
assert "where e.conversation_id=p_conversation_id" in lower
assert "where j.conversation_id=p_conversation_id" in lower
assert 'known' in lower and 'partial' in lower and 'unknown' in lower
assert 'cost_currency_mismatch_requires_fx' in lower
assert 'revenue_cost_currency_mismatch_requires_fx' in lower
assert 'phone' not in '\n'.join(line for line in lower.splitlines() if re.search(r'\b(join|where)\b',line) and 'comment' not in line), 'L7 DB joins/filters must not depend on phone'
assert 'name' not in '\n'.join(line for line in lower.splitlines() if re.search(r'\b(join|where)\b',line) and 'comment' not in line), 'L7 DB joins/filters must not depend on name'

# Recovery preserves history once governed pricing exists.
assert 'WA_L7_RECOVERY_BLOCKED_PRICING_HISTORY' in rollback
assert 'aos_wa_messages_v1' not in rollback
assert 'aos_wa_ai_runs_v1' not in rollback
assert 'aos_booking_operations_v2' not in rollback
assert 'aos_agenda_citas' not in rollback
assert 'aos_ventas' not in rollback
print('WA-L7 UI/performance isolation contracts: PASS')
