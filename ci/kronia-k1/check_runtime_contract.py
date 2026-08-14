from pathlib import Path

server = Path('app/server.js').read_text(encoding='utf-8')
core = Path('app/public/kronia-core.js').read_text(encoding='utf-8')
login = Path('app/public/login.html').read_text(encoding='utf-8')
sales = Path('app/public/admin-sales.html').read_text(encoding='utf-8')
config = Path('app/public/admin-config.html').read_text(encoding='utf-8')

failures = []

def require(text, needle, label):
    if needle not in text:
        failures.append('MISSING: ' + label)

def forbid(text, needle, label):
    if needle in text:
        failures.append('FORBIDDEN: ' + label)

# Server: opaque bearer session is the authority, raw RPC/legacy body is not.
require(server, "aos_kronia_tool", 'server uses token-bound KronIA gateway')
forbid(server, "sbRpc(confirmarAccion.rpc", 'confirmed mutation directly executes raw RPC')
forbid(server, "validarSesionKronia(usuario, d.id_asesor", 'legacy body session remains authoritative')
require(server, "process.env.GROQ_API_KEY", 'Groq secret comes from server environment')
require(server, "process.env.GEMINI_API_KEY", 'Gemini secret comes from server environment')
require(server, "process.env.RESEND_API_KEY", 'Resend secret comes from server environment')
require(server, "process.env.ASCENDA_VERIFY_TOKEN", 'webhook verify token comes from environment')
forbid(server, "select=api_key", 'server fetches provider secret from browser-readable integration table')
require(server, "requireKroniaAdmin", 'agent control endpoints have an authoritative admin gate')

# Shared web core: web mode must not send role/sede authority in request body.
require(core, "sessionStorage", 'web KronIA session uses sessionStorage')
require(core, "aos_kronia_token", 'web KronIA loads canonical opaque token')
forbid(core, "payload.rol = state.user.rol", 'KronIA Core sends client role claim')
forbid(core, "h['X-AOS-User']", 'Whisper legacy identity header remains')

# Login: credentials/2FA code must not be generated/exposed to browser via direct login RPC.
require(login, "/api/auth/login", 'login uses server-side auth initiation')
require(login, "/api/auth/verify-2fa", '2FA verification stays server-side')
forbid(login, "/rest/v1/rpc/aos_login_v2", 'browser calls login_v2 directly')
forbid(login, "res.code", 'browser handles server-generated 2FA code')

# Native Sales editor uses same protected gateway as KronIA.
require(sales, "aos_kronia_tool", 'Sales editor uses protected gateway')
forbid(sales, "/rest/v1/rpc/aos_editar_venta", 'Sales editor bypasses protected gateway')

# Integration UI may read safe metadata but cannot read/write secret columns directly.
forbid(config, "aos_integraciones?select=*", 'integration UI selects secret columns')
forbid(config, "sbPatch('/rest/v1/aos_integraciones", 'integration UI writes secrets/table directly')

if failures:
    print('KRONIA_K1_RUNTIME_CONTRACT=FAIL')
    for f in failures:
        print(' -', f)
    raise SystemExit(1)

print('KRONIA_K1_RUNTIME_CONTRACT=PASS')
