from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[2]
MIG=ROOT/'supabase'/'migrations'
K1=[
 '20260814170000_kronia_k1_private_credentials_auth_v3.sql',
 '20260814171000_kronia_k1_app_token_control_plane.sql',
 '20260814171500_kronia_k1_identity_sync.sql',
 '20260814171600_kronia_k1_feed_schema_alignment.sql',
 '20260814171800_kronia_k1_auth_v3_branded_alignment.sql',
 '20260814172000_kronia_k1_team_profile_alignment.sql',
 '20260814172100_kronia_k1_authority_session_revocation.sql',
]

def fail(msg):
    raise SystemExit('KRONIA_K1_STATIC_SECURITY=FAIL '+msg)

def text(p):
    return p.read_text(encoding='utf-8').replace('\r\n','\n')

sql='\n'.join(text(MIG/f) for f in K1)
low=sql.lower()

# SECURITY DEFINER functions must explicitly pin search_path.
for f in K1:
    s=text(MIG/f)
    starts=list(re.finditer(r'(?is)create\s+(?:or\s+replace\s+)?function\s+([^\s(]+)\s*\(',s))
    for i,m in enumerate(starts):
        end=starts[i+1].start() if i+1<len(starts) else len(s)
        block=s[m.start():end]
        if re.search(r'(?i)security\s+definer',block):
            header=block[:block.lower().find('as $') if 'as $' in block.lower() else min(len(block),1800)]
            if not re.search(r'(?i)set\s+search_path\s*=',header):
                fail(f+': SECURITY DEFINER without pinned search_path: '+m.group(1))

# No K1 path may re-establish public provider-secret authority.
for pat,label in [
    (r'(?is)select\s+i\.api_key\s+into\s+v_api_key\s+from\s+public\.aos_integraciones','legacy Resend read'),
    (r"(?is)api_key\s*=\s*case\s+when\s+p_data\s*\?\s*'api_key'.*?else\s+api_key\s+end",'public integration api_key write'),
    (r"(?is)api_secret\s*=\s*case\s+when\s+p_data\s*\?\s*'api_secret'.*?else\s+api_secret\s+end",'public integration api_secret write'),
]:
    if re.search(pat,sql): fail(label)
if 'aos_integration_secrets_v1' not in sql: fail('private provider vault missing')

# Sensitive tables may never receive browser write authority from K1 migrations.
# GRANT statements in these migrations are one-line statements. Keep the parser
# bounded to that physical statement line so function grants can never bleed into
# a later table grant, even when comments/function bodies contain many semicolons.
sensitive_tables={
    'aos_usuarios','aos_rrhh','aos_integraciones','aos_integration_secrets_v1',
    'aos_auth_credentials','aos_app_sessions_v3','aos_login_challenges_v3',
    'aos_auth_codes','aos_kronia_acciones','aos_security_log'
}
write_privs={'all','insert','update','delete','truncate','references','trigger'}
grant_re=re.compile(
    r'(?im)^\s*grant\s+([^;\n]+?)\s+on\s+(?:table\s+)?public\.(aos_[a-z0-9_]+)\s+to\s+([^;\n]+);'
)
for m in grant_re.finditer(sql):
    priv_expr=m.group(1).strip().lower()
    table=m.group(2).strip().lower()
    recipients={x.strip().lower() for x in m.group(3).split(',')}
    if table not in sensitive_tables or not recipients.intersection({'public','anon','authenticated'}):
        continue
    normalized=re.sub(r'\([^)]*\)','',priv_expr)
    priv_tokens={x.strip() for x in normalized.split(',')}
    if priv_tokens.intersection(write_privs):
        fail('browser write grant on sensitive table: '+table+' privileges='+priv_expr+' recipients='+','.join(sorted(recipients)))

# Full Team PII view must be service-side only and browser use must go through the tokenized feed.
if 'revoke all on table public.aos_team_full from public,anon,authenticated' not in low:
    fail('aos_team_full browser revoke missing')
if 'aos_team_feed_v3' not in low or "'admin-team'" not in low:
    fail('admin-team tokenized feed missing')

server=text(ROOT/'app'/'server-k1.js')
browser=text(ROOT/'app'/'public'/'k1-browser-security.js')
team=text(ROOT/'app'/'public'/'admin-team.html')
core=text(ROOT/'chrome-extension'/'kronia-core.js')
content=text(ROOT/'chrome-extension'/'content-script.js')
manifest=text(ROOT/'chrome-extension'/'manifest.json')

# Server authority: fail closed, canonical app token, no browser identity headers as authority.
for needle in ['SUPABASE_SERVICE_ROLE_KEY','aos_kronia_identity_v3','aos_app_actor_v3','APP_SESSION_REQUIRED','ORIGIN_NOT_ALLOWED','RATE_LIMIT','BODY_TOO_LARGE','PASSWORD_EMAIL_FORBIDDEN']:
    if needle not in server: fail('server gate missing '+needle)
if re.search(r"(?i)req\.headers\[['\"]x-aos-(?:user|id)['\"]\].*?identity",server):
    fail('legacy identity header authority')
if 'loadResendRuntimeKey' in server or 'aos_integraciones?select=api_key' in server:
    fail('K1 server owns legacy provider lookup')

# One browser session authority only.
if 'aos_si_token' in browser or 'aos_si_token' in team: fail('alternate Sales Intelligence token authority')
if 'aos_app_token' not in browser or 'aos_app_token' not in team: fail('canonical app token missing')

# Chrome: same Auth V3 adapter in popup/content; never persist password or business conversation history.
if '"k1-extension-auth.js"' not in manifest: fail('Chrome K1 auth adapter not registered')
if 'core.loginRequest(u, pw)' not in content: fail('floating Chrome password Auth V3 flow missing')
if 'historial: state.historial' in core or 'data.historial' in core: fail('Chrome conversation history persisted')
if re.search(r'(?i)(password|contrase(?:n|ñ)a)\s*:',core): fail('password persisted in KronIA core')

recovery=text(ROOT/'supabase'/'rollbacks'/'20260814_kronia_k1_phase2_safe_recovery.sql').lower()
for needle in ['aos_integration_secrets_v1','force row level security','aos_team_full','aos_auth_credentials']:
    if needle not in recovery: fail('recovery invariant missing '+needle)

print('KRONIA_K1_STATIC_SECURITY=PASS')
