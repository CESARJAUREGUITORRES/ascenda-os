from pathlib import Path
import hashlib, json, re

ROOT=Path(__file__).resolve().parent

def read(p): return (ROOT/p).read_text(encoding='utf-8')
def write(p,s): (ROOT/p).write_text(s,encoding='utf-8')

# Inner server is not externally reachable after K1 proxy cutover. It needs
# service_role because K1 closure removes browser/anon grants from raw RPCs,
# authoritative logs and integration secrets.
p='server.js'; s=read(p)
m=re.search(r"const SB_KEY = 'eyJ[^']+'",s)
if not m: raise SystemExit('K1 materialize: SB_KEY anchor missing')
s=s[:m.start()]+"const SB_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || ''\nif (!SB_KEY) { console.error('[K1] SUPABASE_SERVICE_ROLE_KEY required'); process.exit(1) }"+s[m.end():]

# Historical inline secrets are never valid fallback paths in K1. Secrets must
# exist in the runtime secret manager or the dependent feature fails closed.
s=re.sub(r"const VERIFY_TOKEN = '[^']*'","const VERIFY_TOKEN = process.env.META_VERIFY_TOKEN || '__DISABLED__'",s,count=1)
s,n_resend=re.subn(r"process\.env\.RESEND_API_KEY\s*\|\|\s*'[^']+'","process.env.RESEND_API_KEY || ''",s)
if n_resend < 2: raise SystemExit(f'K1 materialize: expected Resend hardcoded fallbacks, replaced {n_resend}')
if re.search(r"process\.env\.RESEND_API_KEY\s*\|\|\s*['\"][^'\"]+",s): raise SystemExit('K1 materialize: Resend fallback survived')
write(p,s)

# Global browser boundary. Main app hosts dynamic admin fragments, so injecting
# once in app.html covers Team/Config/Sales/Agents/Email/Studio. Brain is standalone.
tag='<script src="/k1-browser-security.js"></script>'
for p in ['public/app.html','public/cerebro.html']:
    s=read(p)
    if tag not in s:
        if '</body>' not in s.lower(): raise SystemExit(f'K1 materialize: body anchor missing in {p}')
        idx=s.lower().rfind('</body>')
        s=s[:idx]+tag+'\n'+s[idx:]
    write(p,s)

# Deterministic manifest proves the exact runtime produced by Railway.
targets=['server.js','server-k1.js','server-phase2.js','public/app.html','public/cerebro.html','public/k1-browser-security.js','public/login.html','public/phase2-auth-shim.js','public/phase2-security-shim.js','public/phase2-service-worker.js']
manifest={'contract':'kronia-k1-phase2-runtime-v1','files':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in targets}}
write('k1-phase2-runtime-manifest.json',json.dumps(manifest,sort_keys=True,indent=2)+'\n')
print('KRONIA_K1_PHASE2_RUNTIME=PASS')
for p,h in manifest['files'].items(): print(p,h)
