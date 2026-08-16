from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]

def read(path):
    return (ROOT / path).read_text(encoding='utf-8')

def write(path, text):
    (ROOT / path).write_text(text, encoding='utf-8')

# 1) Source provider verify token must be environment-only.
s = read('app/server.js')
s, n = re.subn(r"const\s+VERIFY_TOKEN\s*=\s*['\"][^'\"]+['\"]", "const VERIFY_TOKEN = process.env.META_VERIFY_TOKEN || '__DISABLED__'", s, count=1)
if n != 1:
    raise SystemExit(f'expected exactly one hardcoded VERIFY_TOKEN, got {n}')
write('app/server.js', s)

# 2) Auth V3 app token is the only browser authority.
s = read('app/public/k1-browser-security.js')
s = s.replace("return sessionStorage.getItem('aos_app_token')||sessionStorage.getItem('aos_si_token')||''", "return sessionStorage.getItem('aos_app_token')||''")
if 'aos_si_token' in s:
    raise SystemExit('alternate Sales Intelligence token authority survived')
write('app/public/k1-browser-security.js', s)

# 3) K1 wraps CURRENT F5 chain; provider-secret ownership remains in certified lower boundary.
s = read('app/server-k1.js')
old = """async function loadResendRuntimeKey(){
  if(process.env.K1_SKIP_RUNTIME_SECRET_LOOKUP==='1')return String(process.env.RESEND_API_KEY||'');
  const r=await sbRequest('GET','/rest/v1/aos_integraciones?select=api_key&tipo=eq.resend&estado=eq.conectado&principal=eq.true&limit=1');
  const row=Array.isArray(r.data)&&r.data[0];
  if(row&&typeof row.api_key==='string'&&row.api_key.length>10)return row.api_key;
  return String(process.env.RESEND_API_KEY||'');
}
"""
if old not in s:
    raise SystemExit('obsolete K1 Resend lookup block not found')
s = s.replace(old, '')
old_boot = """async function bootstrap(){
  const resendKey=await loadResendRuntimeKey();
  const runtimeEnv=Object.assign({},process.env,{PORT:String(CURRENT_PORT)});
  if(resendKey)runtimeEnv.RESEND_API_KEY=resendKey; else delete runtimeEnv.RESEND_API_KEY;
  startInner(runtimeEnv);
  server.listen(EXTERNAL_PORT,'0.0.0.0',()=>console.log('[K1] security outer boundary listening',EXTERNAL_PORT,'-> current',CURRENT_PORT));
}
bootstrap().catch(err=>{console.error('[K1] secure bootstrap failed',err&&err.message?err.message:'unknown');process.exit(1);});"""
new_boot = """function bootstrap(){
  const runtimeEnv=Object.assign({},process.env,{PORT:String(CURRENT_PORT)});
  startInner(runtimeEnv);
  server.listen(EXTERNAL_PORT,'0.0.0.0',()=>console.log('[K1] security outer boundary listening',EXTERNAL_PORT,'-> current',CURRENT_PORT));
}
bootstrap();"""
if old_boot not in s:
    raise SystemExit('obsolete K1 bootstrap block not found')
s = s.replace(old_boot, new_boot)
if "spawn(process.execPath,['server-f5.js']" not in s:
    raise SystemExit('K1 does not wrap CURRENT F5 root')
if 'loadResendRuntimeKey' in s or 'aos_integraciones?select=api_key' in s:
    raise SystemExit('obsolete K1 provider-secret lookup survived')
write('app/server-k1.js', s)

# 4) Browser security boundary is committed, not injected by build mutation.
tag = '<script src="/k1-browser-security.js"></script>'
for fn in ('app/public/app.html', 'app/public/cerebro.html'):
    s = read(fn)
    if tag not in s:
        idx = s.lower().rfind('</body>')
        if idx < 0:
            raise SystemExit(f'{fn}: body anchor missing')
        s = s[:idx] + tag + '\n' + s[idx:]
    if fn.endswith('cerebro.html'):
        s = s.replace('\nconnectRT();\n', '\n/* K1: direct audit Realtime disabled; sanitized polling remains. */\n', 1)
    write(fn, s)

# 5) Team password UX matches K1 backend policy.
s = read('app/public/admin-team.html')
for a, b in (
    ('pw.length<6', 'pw.length<10'),
    ('np.length<6', 'np.length<10'),
    ('Mínimo 6 caracteres', 'Mínimo 10 caracteres'),
    ('mínimo 6 caracteres', 'mínimo 10 caracteres'),
    ('Contraseña mínimo 6 caracteres', 'Contraseña mínimo 10 caracteres'),
):
    s = s.replace(a, b)
write('app/public/admin-team.html', s)

# 6) K1 becomes outer Railway runtime while preserving CURRENT code below it.
s = read('app/railway.json').replace('"startCommand": "node server-f5.js"', '"startCommand": "node server-k1.js"', 1)
write('app/railway.json', s)
s = read('app/nixpacks.toml')
s = s.replace('cmd = "node server.js"', 'cmd = "node server-k1.js"').replace('cmd = "node server-f5.js"', 'cmd = "node server-k1.js"')
write('app/nixpacks.toml', s)

# 7) Synthetic CURRENT schema shape only; never production rows.
p = ROOT / 'ci/kronia-k1-phase2/fixture_pre_k1.sql'
s = p.read_text(encoding='utf-8')
compat = r'''

-- K1 CURRENT synthetic schema compatibility (shape only; no production data).
alter table public.aos_usuarios
  add column if not exists auth_id uuid,
  add column if not exists telefono text,
  add column if not exists sede text default '',
  add column if not exists permisos jsonb default '{}'::jsonb,
  add column if not exists ultimo_login timestamptz,
  add column if not exists login_method text default 'password',
  add column if not exists sueldo numeric default 0,
  add column if not exists fecha_ingreso date,
  add column if not exists dni text default '',
  add column if not exists telefono_personal text default '',
  add column if not exists direccion text default '',
  add column if not exists contacto_emergencia text default '',
  add column if not exists invitacion_enviada boolean default false,
  add column if not exists cuenta_activada boolean default false,
  add column if not exists apellidos text default '',
  add column if not exists fecha_nacimiento date,
  add column if not exists lugar_nacimiento text default '',
  add column if not exists pais text default 'Perú',
  add column if not exists departamento text default '',
  add column if not exists provincia text default '',
  add column if not exists distrito text default '',
  add column if not exists tipo_contrato text default 'prueba',
  add column if not exists rh text default '',
  add column if not exists bono_metas numeric default 0,
  add column if not exists cmp text default '',
  add column if not exists servicios text[] default '{}'::text[];

alter table public.aos_rrhh
  add column if not exists sueldo numeric,
  add column if not exists fecha_ingreso date,
  add column if not exists fecha_salida date,
  add column if not exists meta numeric default 0,
  add column if not exists bonus_pct numeric default 0,
  add column if not exists label text,
  add column if not exists numero text,
  add column if not exists tiene_agenda text default 'NO',
  add column if not exists foto_url text,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();
'''
if 'K1 CURRENT synthetic schema compatibility' not in s:
    s += compat
p.write_text(s, encoding='utf-8')

# 8) Validator-only materializer. It never rewrites legacy credentials or injects service_role.
write('app/k1_phase2_materialize.py', r'''from pathlib import Path
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
''')

# 9) CURRENT runtime/source contract.
write('ci/kronia-k1-phase2/runtime_contract.py', r'''from pathlib import Path
import json,re,subprocess
root=Path(__file__).resolve().parents[2]; app=root/'app'
k1=(app/'server-k1.js').read_text(); inner=(app/'server.js').read_text(); browser=(app/'public/k1-browser-security.js').read_text()
apphtml=(app/'public/app.html').read_text(); brain=(app/'public/cerebro.html').read_text(); team=(app/'public/admin-team.html').read_text(); login=(app/'public/login.html').read_text(); popup=(root/'chrome-extension/popup.js').read_text(); extauth=(root/'chrome-extension/k1-extension-auth.js').read_text()
source_inner=subprocess.check_output(['git','show','HEAD:app/server.js'],cwd=root,text=True)
assert not re.search(r"const\s+VERIFY_TOKEN\s*=\s*['\"][^'\"]+",source_inner)
assert not re.search(r"process\.env\.RESEND_API_KEY\s*\|\|\s*['\"][^'\"]+",source_inner)
assert "const VERIFY_TOKEN = process.env.META_VERIFY_TOKEN || '__DISABLED__'" in inner
assert "spawn(process.execPath,['server-f5.js']" in k1
assert "spawn(process.execPath,['server-f4.js']" not in k1
assert 'loadResendRuntimeKey' not in k1 and 'aos_integraciones?select=api_key' not in k1
assert 'SUPABASE_SERVICE_ROLE_KEY' in k1 and 'aos_kronia_identity_v3' in k1 and 'aos_app_actor_v3' in k1
assert 'ORIGIN_NOT_ALLOWED' in k1 and 'RATE_LIMIT' in k1 and 'BODY_TOO_LARGE' in k1 and 'PASSWORD_EMAIL_FORBIDDEN' in k1
assert 'aos_si_token' not in browser and 'aos_app_token' in browser
assert '<script src="/k1-browser-security.js"></script>' in apphtml and '<script src="/k1-browser-security.js"></script>' in brain
assert '\nconnectRT();\n' not in brain
assert 'pw.length<10' in team or 'np.length<10' in team
assert 'aos_login_v3' in login and 'aos_verificar_2fa_v3' in login
assert '/api/kronia/login-request' in extauth and '/api/kronia/login-verify' in extauth
assert 'state.password' not in popup and 'kronia_session.password' not in popup
manifest=json.loads((app/'k1-phase2-runtime-manifest.json').read_text())
assert manifest['contract']=='kronia-k1-current-runtime-v3'
assert all(len(v)==64 for v in manifest['files'].values())
print('KRONIA_K1_CURRENT_SOURCE_SECRET_CONTRACT=PASS')
print('KRONIA_K1_CURRENT_RUNTIME_CHAIN=PASS')
print('KRONIA_K1_CURRENT_RUNTIME_CONTRACT=PASS')
''')

# 10) Dynamic smoke no longer supplies fake provider credentials to K1.
s = read('ci/kronia-k1-phase2/test_proxy_security.js')
s = s.replace(",META_VERIFY_TOKEN:'ci-disabled',K1_SKIP_RUNTIME_SECRET_LOOKUP:'1',RESEND_API_KEY:'ci-not-a-real-resend-key'", ",META_VERIFY_TOKEN:'ci-disabled'")
write('ci/kronia-k1-phase2/test_proxy_security.js', s)

# 11) Certificate assertions updated from old Phase2-direct K1 to CURRENT F5-wrapped K1.
s = read('.github/workflows/kronia-k1-phase2-security.yml')
s = s.replace("grep -q 'KRONIA_K1_PHASE2_SOURCE_SECRET_CONTRACT=PASS' /tmp/k1-runtime-contract.txt", "grep -q 'KRONIA_K1_CURRENT_SOURCE_SECRET_CONTRACT=PASS' /tmp/k1-runtime-contract.txt")
s = s.replace("grep -q 'KRONIA_K1_PHASE2_RUNTIME_SECRET_HANDOFF=PASS' /tmp/k1-runtime-contract.txt", "grep -q 'KRONIA_K1_CURRENT_RUNTIME_CHAIN=PASS' /tmp/k1-runtime-contract.txt")
s = s.replace("grep -q \"server-phase2.js\" app/server-k1.js", "grep -q \"server-f5.js\" app/server-k1.js")
write('.github/workflows/kronia-k1-phase2-security.yml', s)

print('K1_CURRENT_V3_PATCH=PASS')
