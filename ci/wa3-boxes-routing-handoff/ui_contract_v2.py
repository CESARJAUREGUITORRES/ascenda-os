from pathlib import Path

root = Path(__file__).resolve().parents[2]
shell = (root / 'app/public/wa-shell-integration.js').read_text(encoding='utf-8')
panel = (root / 'app/public/wa-multiagent-v2-panel.js').read_text(encoding='utf-8')
server = (root / 'app/server-wa3-v2.js').read_text(encoding='utf-8')
wa4 = (root / 'app/server-wa4.js').read_text(encoding='utf-8')

# Shell mounts V2 after the already-certified native/layout layers and keeps Push bootstrap intact.
assert "MULTI_SRC='/wa-multiagent-v2-panel.js?v=20260822-wa3-multiagent-v2-p01'" in shell
assert 'function ensureMulti()' in shell
assert 'return ensureMulti();' in shell
assert "PUSH_SRC='/notification-push-s14.js?v=20260818-s15-5-shell-mount-p01'" in shell
assert 'ensurePush().catch' in shell

# Agent console supports explicit readiness, aggregate queue, safe claim and supervisor readiness.
for token in ['AVAILABLE','AWAY','OFFLINE','/api/wa3/queue-summary','/api/wa3/presence','/api/wa3/claim-next','/api/wa3/team-summary','Tomar siguiente','Equipo WA']:
    assert token in panel, token

# The aggregate queue UI must not depend on unowned customer fields.
for forbidden in ['contact_number','message_body','conversation_id']:
    assert forbidden not in panel, forbidden

# V2 server is additive and proxies to the existing WA-3 authority.
assert "['server-wa3.js']" in server
assert "'/api/wa3/queue-summary'" in server
assert "'/api/wa3/team-summary'" in server
assert "'/api/wa3/presence'" in server
assert "'/api/wa3/claim-next'" in server
assert 'requireActor(req,res,true)' in server
assert "privacy:'NO_CUSTOMER_DATA'" in server
assert 'contact_number' not in server
assert 'message_body' not in server

# WA-4 keeps its role while mounting the V2 boundary immediately beneath it.
assert "['server-wa3-v2.js']" in wa4
assert 'Copilot only' in wa4

print('WA-3 V2 UI/boundary contract: PASS')
