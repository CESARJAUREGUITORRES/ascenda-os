from pathlib import Path
import re

root=Path(__file__).resolve().parents[2]
shell=(root/'app/public/wa-shell-integration.js').read_text(encoding='utf-8')
final_mode=re.search(r'/wa-multiagent-final-panel\.js\?v=(?:20260822-wa3-final-p0[12]|20260824-wa35-[a-z0-9-]+)',shell) is not None
panel=(root/('app/public/wa-multiagent-final-panel.js' if final_mode else 'app/public/wa-multiagent-v2-panel.js')).read_text(encoding='utf-8')
server=(root/'app/server-wa3-v2.js').read_text(encoding='utf-8')
wa4=(root/'app/server-wa4.js').read_text(encoding='utf-8')

assert final_mode or "MULTI_SRC='/wa-multiagent-v2-panel.js?v=20260822-wa3-multiagent-v2-p03'" in shell
assert 'function ensureMulti()' in shell
assert 'return ensureMulti();' in shell
assert "PUSH_SRC='/notification-push-s14.js?v=20260818-s15-5-shell-mount-p01'" in shell
assert 'ensurePush().catch' in shell
for token in ['/api/wa3/queue-summary','/api/wa3/claim-next','/api/wa3/team-summary','WA3_NOT_OWNER','ownershipLostRemount','Meta aceptó el mensaje','5000']:
    assert token in panel, token
for forbidden in ['contact_number','message_body','conversation_id']:
    assert forbidden not in panel, forbidden
assert "d.error==='WA3_NOT_OWNER'" in panel
assert 'ownership_lost:true' in panel
assert "var disabled=a.effective_status!=='AVAILABLE'&&!o.selected" in panel
assert 'if(o.disabled!==disabled)o.disabled=disabled' in panel
assert "['server-wa3.js']" in server
assert "'/api/wa3/queue-summary'" in server
assert "'/api/wa3/team-summary'" in server
assert "'/api/wa3/presence'" in server
assert "'/api/wa3/claim-next'" in server
assert 'requireActor(req,res,true)' in server
assert "privacy:'NO_CUSTOMER_DATA'" in server
assert 'contact_number' not in server
assert 'message_body' not in server
assert "['server-wa3-v2.js']" in wa4
assert 'server-only L10 autonomous CANARY orchestration' in wa4
assert 'L4/L8 remain the sole autonomous send/preflight authority' in wa4
assert 'WA-3 remains human ownership authority' in wa4
print('WA-3 V2 boundary contract: PASS mode='+('FINAL' if final_mode else 'V2'))
