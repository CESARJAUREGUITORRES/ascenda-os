from pathlib import Path
import hashlib, json, re

ROOT=Path(__file__).resolve().parent

def read(p): return (ROOT/p).read_text(encoding='utf-8')
def write(p,s): (ROOT/p).write_text(s,encoding='utf-8')

p='server.js'; s=read(p)
m=re.search(r"const SB_KEY = 'eyJ[^']+'",s)
if not m: raise SystemExit('K1 materialize: SB_KEY anchor missing')
s=s[:m.start()]+"const SB_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || ''\nif (!SB_KEY) { console.error('[K1] SUPABASE_SERVICE_ROLE_KEY required'); process.exit(1) }"+s[m.end():]

s,n_verify=re.subn(r"const\s+VERIFY_TOKEN\s*=\s*'[^']*'","const VERIFY_TOKEN = process.env.META_VERIFY_TOKEN || '__DISABLED__'",s,count=1)
s,n_resend=re.subn(r"process\.env\.RESEND_API_KEY\s*\|\|\s*'[^']+'","process.env.RESEND_API_KEY || ''",s)
if re.search(r"const\s+VERIFY_TOKEN\s*=\s*['\"][^'\"]+",s): raise SystemExit('K1 materialize: VERIFY_TOKEN hardcoded fallback survived')
if re.search(r"process\.env\.RESEND_API_KEY\s*\|\|\s*['\"][^'\"]+",s): raise SystemExit('K1 materialize: Resend hardcoded fallback survived')
write(p,s)
print(f'K1_RUNTIME_SECRET_NORMALIZE=PASS verify_replaced={n_verify} resend_replaced={n_resend}')

tag='<script src="/k1-browser-security.js"></script>'
p='public/app.html'; s=read(p)
if tag not in s:
    if '</body>' not in s.lower(): raise SystemExit('K1 materialize: app body anchor missing')
    idx=s.lower().rfind('</body>'); s=s[:idx]+tag+'\n'+s[idx:]
write(p,s)

p='public/cerebro.html'; s=read(p)
brain_anchor="const H = {'apikey':SK,'Authorization':'Bearer '+SK,'Content-Type':'application/json'};"
if tag not in s:
    if brain_anchor not in s: raise SystemExit('K1 materialize: Brain Supabase header anchor missing')
    split=brain_anchor+"\nwindow._SK=SK;\n</script>\n"+tag+"\n<script>"
    s=s.replace(brain_anchor,split,1)
if '/* K1: direct audit Realtime disabled; sanitized polling remains. */' not in s:
    if s.count('\nconnectRT();\n')!=1: raise SystemExit('K1 materialize: Brain connectRT anchor mismatch')
    s=s.replace('\nconnectRT();\n','\n/* K1: direct audit Realtime disabled; sanitized polling remains. */\n',1)
write(p,s)

p='public/admin-team.html'; s=read(p)
s=s.replace('pw.length<6','pw.length<10')
s=s.replace('np.length<6','np.length<10')
s=s.replace('Mínimo 6 caracteres','Mínimo 10 caracteres')
s=s.replace('mínimo 6 caracteres','mínimo 10 caracteres')
s=s.replace('Contraseña mínimo 6 caracteres','Contraseña mínimo 10 caracteres')
write(p,s)

targets=['server.js','server-k1.js','server-f4.js','server-phase2.js','public/app.html','public/cerebro.html','public/admin-team.html','public/k1-browser-security.js','public/login.html','public/phase2-auth-shim.js','public/phase2-security-shim.js','public/phase2-service-worker.js']
manifest={'contract':'kronia-k1-current-runtime-v2','files':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in targets}}
write('k1-phase2-runtime-manifest.json',json.dumps(manifest,sort_keys=True,indent=2)+'\n')
print('KRONIA_K1_PHASE2_RUNTIME=PASS')
for p,h in manifest['files'].items(): print(p,h)
