from pathlib import Path
import hashlib, json, re

ROOT=Path(__file__).resolve().parent

def read(p): return (ROOT/p).read_text(encoding='utf-8')
def write(p,s): (ROOT/p).write_text(s,encoding='utf-8')

def require_single(pattern, text, label, flags=0):
    matches=list(re.finditer(pattern,text,flags))
    if len(matches)!=1:
        raise SystemExit(f'K1 materialize: {label} expected once, got {len(matches)}')
    return matches[0]

# Inner server is not externally reachable after K1 proxy cutover. It needs
# service_role because K1 closure removes browser/anon grants from raw RPCs,
# authoritative logs and integration secrets. Accept an already-materialized
# source as a valid idempotent state, but never an ambiguous mixed state.
p='server.js'; s=read(p)
service_line="const SB_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || ''\nif (!SB_KEY) { console.error('[K1] SUPABASE_SERVICE_ROLE_KEY required'); process.exit(1) }"
hard_sb=list(re.finditer(r"(?m)^const SB_KEY = 'eyJ[^']+'$",s))
if service_line in s:
    if hard_sb: raise SystemExit('K1 materialize: mixed hardcoded/service-role SB_KEY state')
else:
    if len(hard_sb)!=1: raise SystemExit(f'K1 materialize: SB_KEY anchor expected once, got {len(hard_sb)}')
    m=hard_sb[0]; s=s[:m.start()]+service_line+s[m.end():]

# Source may already be sanitized by the K1 one-shot source cleanup. Keep this
# transform idempotent and fail closed if any hardcoded provider fallback remains.
s,n_verify=re.subn(r"const\s+VERIFY_TOKEN\s*=\s*'[^']*'","const VERIFY_TOKEN = process.env.META_VERIFY_TOKEN || '__DISABLED__'",s,count=1)
s,n_resend=re.subn(r"process\.env\.RESEND_API_KEY\s*\|\|\s*'[^']+'","process.env.RESEND_API_KEY || ''",s)
if re.search(r"const\s+VERIFY_TOKEN\s*=\s*['\"][^'\"]+",s):
    raise SystemExit('K1 materialize: VERIFY_TOKEN hardcoded fallback survived')
if re.search(r"process\.env\.RESEND_API_KEY\s*\|\|\s*['\"][^'\"]+",s):
    raise SystemExit('K1 materialize: Resend hardcoded fallback survived')
if "const VERIFY_TOKEN = process.env.META_VERIFY_TOKEN || '__DISABLED__'" not in s:
    raise SystemExit('K1 materialize: fail-closed VERIFY_TOKEN state missing')
write(p,s)
print(f'K1_RUNTIME_SECRET_NORMALIZE=PASS verify_replaced={n_verify} resend_replaced={n_resend}')

# Main app hosts dynamic admin fragments; user interactions happen after this
# boundary is installed, so one injection before </body> covers them.
tag='<script src="/k1-browser-security.js"></script>'
p='public/app.html'; s=read(p)
if tag not in s:
    body_close=list(re.finditer(r'(?i)</body>',s))
    if len(body_close)!=1: raise SystemExit(f'K1 materialize: app body anchor expected once, got {len(body_close)}')
    idx=body_close[0].start(); s=s[:idx]+tag+'\n'+s[idx:]
if s.count(tag)!=1: raise SystemExit('K1 materialize: app K1 boundary duplicate/missing')
write(p,s)

# Brain connectivity code evolved after Phase2. Inject immediately after the
# canonical H header declaration using a whitespace-tolerant structural regex,
# not a brittle historical literal. This guarantees window._SK exists before
# the K1 boundary intercepts audit polling. Direct audit Realtime is disabled;
# sanitized incremental polling remains active.
p='public/cerebro.html'; s=read(p)
if tag not in s:
    h=require_single(r"(?m)^(const\s+H\s*=\s*\{[^\n]*\};)[ \t]*$",s,'Brain Supabase header')
    split=h.group(1)+"\nwindow._SK=SK;\n</script>\n"+tag+"\n<script>"
    s=s[:h.start()]+split+s[h.end():]
else:
    if 'window._SK=SK;' not in s:
        raise SystemExit('K1 materialize: Brain boundary exists without public key handoff')

rt_marker='/* K1: direct audit Realtime disabled; sanitized polling remains. */'
rt_call=re.compile(r"(?m)^[ \t]*connectRT\(\);[ \t]*$")
rt_matches=list(rt_call.finditer(s))
if rt_marker not in s:
    if len(rt_matches)!=1: raise SystemExit(f'K1 materialize: Brain connectRT call expected once, got {len(rt_matches)}')
    m=rt_matches[0]; s=s[:m.start()]+rt_marker+s[m.end():]
else:
    if rt_matches: raise SystemExit('K1 materialize: direct audit Realtime call survived marked state')

if s.count(tag)!=1: raise SystemExit('K1 materialize: Brain K1 boundary duplicate/missing')
if s.count('window._SK=SK;')!=1: raise SystemExit('K1 materialize: Brain public key handoff duplicate/missing')
if rt_call.search(s): raise SystemExit('K1 materialize: direct audit Realtime call survived')
if 'setInterval(poll, 8000)' not in s: raise SystemExit('K1 materialize: sanitized audit polling contract missing')
write(p,s)

# Team backend now enforces minimum 10 characters. Keep UI validation consistent
# so the legacy view cannot show a false-success path for 6–9 character values.
p='public/admin-team.html'; s=read(p)
s=s.replace('pw.length<6','pw.length<10')
s=s.replace('np.length<6','np.length<10')
s=s.replace('Mínimo 6 caracteres','Mínimo 10 caracteres')
s=s.replace('mínimo 6 caracteres','mínimo 10 caracteres')
s=s.replace('Contraseña mínimo 6 caracteres','Contraseña mínimo 10 caracteres')
if 'pw.length<6' in s or 'np.length<6' in s: raise SystemExit('K1 materialize: legacy Team password minimum survived')
write(p,s)

# Deterministic manifest proves the exact runtime produced by Railway.
targets=['server.js','server-k1.js','server-phase2.js','public/app.html','public/cerebro.html','public/admin-team.html','public/k1-browser-security.js','public/login.html','public/phase2-auth-shim.js','public/phase2-security-shim.js','public/phase2-service-worker.js']
manifest={'contract':'kronia-k1-phase2-runtime-v1','files':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in targets}}
write('k1-phase2-runtime-manifest.json',json.dumps(manifest,sort_keys=True,indent=2)+'\n')
print('KRONIA_K1_PHASE2_RUNTIME=PASS')
for p,h in manifest['files'].items(): print(p,h)