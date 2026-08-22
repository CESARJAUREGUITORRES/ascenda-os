from pathlib import Path

root = Path(__file__).resolve().parents[2]
shell = (root / 'app/public/wa-shell-integration.js').read_text(encoding='utf-8')
panel = (root / 'app/public/wa-multiagent-v2-panel.js').read_text(encoding='utf-8')
server = (root / 'app/server-wa3-v2.js').read_text(encoding='utf-8')
wa4 = (root / 'app/server-wa4.js').read_text(encoding='utf-8')

assert "MULTI_SRC='/wa-multiagent-v2-panel.js?v=20260822-wa3-multiagent-v2-p03'" in shell
assert 'function ensureMulti()' in shell
assert 'return ensureMulti();' in shell
assert "PUSH_SRC='/notification-push-s14.js?v=20260818-s15-5-shell-mount-p01'" in shell
assert 'ensurePush().catch' in shell

for token in ['AVAILABLE','AWAY','OFFLINE','/api/wa3/queue-summary','/api/wa3/presence','/api/wa3/claim-next','/api/wa3/team-summary','Tomar siguiente','Equipo WA','WA3_NOT_OWNER','ownershipLostRemount','wa3v2-owner-chip','Meta aceptó el mensaje','5000','syncChip','desired=o.dataset.baseLabel']:
    assert token in panel, token

assert "d.error==='WA3_NOT_OWNER'" in panel
assert "ownership_lost:true" in panel
assert "X.timer=setInterval(function(){if(!document.hidden)refresh();},5000)" in panel
assert "var disabled=a.effective_status!=='AVAILABLE'&&!o.selected" in panel
assert "if(o.disabled!==disabled)o.disabled=disabled" in panel
assert "if(old&&old.textContent===lab.text&&old.className===cls)return" in panel
assert "if(o.textContent!==desired)o.textContent=desired" in panel

for forbidden in ['contact_number','message_body','conversation_id']:
    assert forbidden not in panel, forbidden

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
assert 'Copilot only' in wa4

print('WA-3 V2 UI/boundary contract: PASS')
