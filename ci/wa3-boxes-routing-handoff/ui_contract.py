from pathlib import Path
import json

root=Path(__file__).resolve().parents[2]
server=(root/'app/server-wa3.js').read_text(encoding='utf-8')
wa4_path=root/'app/server-wa4.js'
wa4=wa4_path.read_text(encoding='utf-8') if wa4_path.exists() else ''
f5_path=root/'app/server-f5.js'
f5=f5_path.read_text(encoding='utf-8') if f5_path.exists() else ''
phase_s_path=root/'app/server-phase-s.js'
phase_s=phase_s_path.read_text(encoding='utf-8') if phase_s_path.exists() else ''
ui=(root/'app/public/admin-whatsapp-wa3.html').read_text(encoding='utf-8')
railway=json.loads((root/'app/railway.json').read_text(encoding='utf-8'))
mig=(root/'supabase/migrations/20260815190500_wa3_boxes_routing_handoff_v1.sql').read_text(encoding='utf-8')
rb=(root/'supabase/rollbacks/20260815190500_wa3_boxes_routing_handoff_v1.rollback.sql').read_text(encoding='utf-8')

# Explicit runtime chain Phase-S -> F5 -> WA4 -> WA3 -> WA2. No generic wrapper acceptance.
assert "['server-wa2.js']" in server
assert "proxy(req,res)" in server
assert "X-Ascenda-WA3-Routing':'v1'" in server
start=railway['deploy']['startCommand']
direct=start=='node server-wa3.js'
wa4_wrapped=(start=='node server-wa4.js' and "['server-wa3.js']" in wa4 and 'proxy(req,res)' in wa4)
f5_wrapped=(start=='node server-f5.js' and "['server-wa4.js']" in f5 and 'proxy(req,res)' in f5 and "['server-wa3.js']" in wa4 and 'proxy(req,res)' in wa4)
phase_s_wrapped=(start=='node server-phase-s.js' and "['server-f5.js']" in phase_s and 'proxy(req,res)' in phase_s and "['server-wa4.js']" in f5 and 'proxy(req,res)' in f5 and "['server-wa3.js']" in wa4 and 'proxy(req,res)' in wa4)
assert direct or wa4_wrapped or f5_wrapped or phase_s_wrapped, 'Railway must start WA-3 directly or through certified WA-4/F5/Phase-S wrappers'
assert '/api/wa3/bootstrap' in server
assert '/api/wa3/inbox' in server
assert '/claim-next' in server
assert '/route' in server and '/release' in server and '/mode' in server and '/send' in server
assert 'aos_wa3_human_send_authorize_v1' in server
assert "type:'text'" in server
assert 'WA_CANARY_MODE' in server and 'WA_CANARY_ALLOW_TO' in server
assert 'validIdempotencyKey' in server and 'canaryAllows' in server
assert 'aos_wa_outbound_requests_v1' in server
assert 'aos_wa_messages_v1' in server
assert 'message.human_accepted' in server
assert 'WA3_RATE_LIMIT' in server

# Browser never accesses Supabase/Graph directly and cannot bypass ownership.
for forbidden in ('supabase.co','/rest/v1/','SUPABASE_SERVICE_ROLE_KEY','WHATSAPP_ACCESS_TOKEN','graph.facebook.com','apikey'):
    assert forbidden not in ui, f'WA3 browser leaks/directly depends on {forbidden}'
assert 'X-AOS-App-Token' in ui
assert '/api/wa3/bootstrap' in ui and '/api/wa3/inbox' in ui
assert '/claim-next' in ui and '/route' in ui and '/release' in ui and '/mode' in ui and '/send' in ui
assert 'Solo el owner puede responder' in ui
assert 'IA no envía en WA-3' in ui
assert 'FORZADO OFF' in ui
assert 'esc(' in ui

# Data/security invariants.
for marker in ('aos_wa_routing_control_v1','aos_wa_boxes_v1','aos_wa_box_members_v1','aos_wa_assignments_v1','aos_wa_routing_events_v1'):
    assert marker in mig
assert 'one_current_idx' in mig
assert 'for update skip locked' in mig.lower()
assert "'HUMAN_ACTIVE','AI_COPILOT'" in mig
assert "v_mode not in ('HUMAN_ACTIVE','AI_COPILOT')" in mig
assert 'ai_send_enabled boolean not null default false check (ai_send_enabled = false)' in mig
assert 'ai_send_enabled=false' in mig
assert "values ('whatsapp-agent'" in mig
assert "array_append" not in mig.lower(), 'migration must not auto-grant whatsapp-agent to users'
assert 'force row level security' in mig.lower()
assert 'WA3_ROUTING_EVENT_APPEND_ONLY' in mig
assert 'WA3_NOT_OWNER' in mig
assert 'WA3_HUMAN_SEND_DISABLED' in mig
assert 'WA3_CAPACITY_REACHED' in mig
assert 'auto_route.rejected' in mig

# Recovery is fail-closed and keeps evidence.
assert 'auto_routing_enabled=false' in rb
assert 'human_send_enabled=false' in rb
assert 'ai_send_enabled=false' in rb
assert "state='RELEASED'" in rb
assert "then 'HUMAN_REQUESTED'" in rb
assert "array_remove" in rb
assert "delete from public.aos_paneles_disponibles where id='whatsapp-agent'" in rb
for evidence in ('aos_wa_boxes_v1','aos_wa_assignments_v1','aos_wa_routing_events_v1'):
    assert f'drop table if exists public.{evidence}' not in rb.lower()

print('WA-3 UI/runtime/security contracts: PASS')
