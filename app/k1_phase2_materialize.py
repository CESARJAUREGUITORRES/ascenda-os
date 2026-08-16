from pathlib import Path
import hashlib, json, re
ROOT=Path(__file__).resolve().parent
def read(p): return (ROOT/p).read_text(encoding='utf-8')
server=read('server.js'); k1=read('server-k1.js'); browser=read('public/k1-browser-security.js')
if re.search(r"const\s+VERIFY_TOKEN\s*=\s*['\"][^'\"]+",server): raise SystemExit('K1: hardcoded VERIFY_TOKEN')
if re.search(r"process\.env\.RESEND_API_KEY\s*\|\|\s*['\"][^'\"]+",server): raise SystemExit('K1: hardcoded Resend fallback')
if "spawn(process.execPath,['server-f5.js']" not in k1: raise SystemExit('K1: CURRENT F5 root missing')
if 'loadResendRuntimeKey' in k1 or 'aos_integraciones?select=api_key' in k1: raise SystemExit('K1: obsolete provider-secret lookup')
if 'aos_si_token' in browser: raise SystemExit('K1: alternate browser token authority')
for html in ('public/app.html','public/cerebro.html'):
    if '<script src="/k1-browser-security.js"></script>' not in read(html): raise SystemExit('K1: browser boundary missing '+html)
targets=['server-k1.js','server-f5.js','server-wa4.js','server-wa3.js','server-wa2.js','server-f4.js','server-phase2.js','server.js','public/app.html','public/cerebro.html','public/admin-team.html','public/k1-browser-security.js','public/login.html','public/phase2-auth-shim.js','public/phase2-security-shim.js','public/phase2-service-worker.js']
manifest={'contract':'kronia-k1-current-runtime-v3','files':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in targets}}
(ROOT/'k1-phase2-runtime-manifest.json').write_text(json.dumps(manifest,sort_keys=True,indent=2)+'\n',encoding='utf-8')
print('KRONIA_K1_CURRENT_RUNTIME=PASS')
