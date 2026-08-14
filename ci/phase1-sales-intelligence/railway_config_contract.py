import json
from pathlib import Path

cfg=json.loads(Path('app/railway.json').read_text(encoding='utf-8'))
assert cfg['deploy']['startCommand']=='node server.js'
st=cfg['environments']['staging-sales-intelligence']['deploy']
assert st['startCommand']=='node staging-server.js'
assert st['healthcheckPath']=='/health'
print('PHASE1_RAILWAY_ENV_ISOLATION=PASS')
